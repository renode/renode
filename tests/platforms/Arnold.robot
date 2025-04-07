*** Variables ***
${UART}                       sysbus.uart
${STDOUT}                     sysbus.stdout
${URI}                        @https://dl.antmicro.com/projects/renode

*** Keywords ***
Create Machine
    [Arguments]  ${elf}

    Execute Command          mach create
    Execute Command          machine LoadPlatformDescription @platforms/boards/A2_CV32E40P.repl

    Execute Command          sysbus LoadELF ${URI}/${elf}

Create Test File
    [Arguments]              ${file}
    ${string} =              Set Variable   ${EMPTY}
    FOR  ${index}  IN RANGE  128
         ${string}=          Catenate  ${string}  00  ${index}
    END

    ${bytes}=                Convert To Bytes  ${string}  int
    Create Binary File       ${file}  ${bytes}

*** Test Cases ***
Should Print Hello to UART
    Create Machine           arnold-pulp-hello-s_354412-d0f4d2860104d3bb1d4524c4ee76ef476bbe1d1e
    Create Terminal Tester   ${UART}

    Start Emulation

    Wait For Line On Uart    Hello !

Should Set GPIO Output to High
    Create Machine           arnold-pulp-gpio-s_380728-f9f273e2063a3ea7d4f9607cce4d7f12ea10bf63
    Execute Command          machine LoadPlatformDescriptionFromString "gpio: { 5 -> led@0 }; led: Miscellaneous.LED @ gpio 5"

    Create LED Tester        sysbus.gpio.led

    Start Emulation

    Assert LED State         true  1

Should Print to UART Using a Timer
    Create Machine            arnold-pulp-timer-s_365004-fc268eecd231afb88a571748c864b6c3ab0bcb5d
    Create Terminal Tester    ${UART}

    Set Test Variable         ${SLEEP_TIME}                 163
    Set Test Variable         ${SLEEP_TOLERANCE}            10
    Set Test Variable         ${REPEATS}                    20

    Start Emulation

    ${l}=               Create List
    ${MAX_SLEEP_TIME}=  Evaluate  ${SLEEP_TIME} + ${SLEEP_TOLERANCE}

    FOR  ${i}  IN RANGE  0  ${REPEATS}
         ${r}        Wait For Line On Uart     Entered user handler
                     Append To List            ${l}  ${r.Timestamp}
    END

    FOR  ${i}  IN RANGE  1  ${REPEATS}
         ${i1}=  Get From List   ${l}                       ${i - 1}
         ${i2}=  Get From List   ${l}                       ${i}
         ${d}=   Evaluate        ${i2} - ${i1}
                 Should Be True  ${d} >= ${SLEEP_TIME}      Too short sleep detected between entries ${i} and ${i + 1}: expected ${SLEEP_TIME}, got ${d}
                 Should Be True  ${d} <= ${MAX_SLEEP_TIME}  Too long sleep detected between entires ${i} and ${i + 1}: expected ${SLEEP_TIME}, got ${d}
    END

Should Echo Characters on UART
    Create Machine            arnold-pulp-echo-s_387788-cf79547cd654f7ebad125546dd2c98e58b47731e
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     Entered test

    Write Char On Uart        t
    Wait For Prompt On Uart   t
    Write Char On Uart        e
    Wait For Prompt On Uart   e
    Write Char On Uart        s
    Wait For Prompt On Uart   s
    Write Char On Uart        t
    Wait For Prompt On Uart   t

Should Fail When I2S Not Configured
    Create Machine            arnold-pulp-i2s_capture-s_566452-62d9e3e48551334dac1ab17af371728e66586c7a
    Create Log Tester         1

    Start Emulation

    Wait For Log Entry        Starting reception without an input file! Aborting

Should Output I2S Samples From File
    Create Machine            arnold-pulp-i2s_capture-s_566452-62d9e3e48551334dac1ab17af371728e66586c7a

    ${input_file}=            Allocate Temporary File
    Create Test File          ${input_file}
    Execute Command           sysbus.i2s InputFile '${input_file}'
    Create Terminal Tester    ${STDOUT}

    Start Emulation

    Wait For Line On Uart     Value of sample 0 = 0
    Wait For Line On Uart     Value of sample 127 = 127

Should Run I2C test
    Create Machine            arnold-pulp-i2c-s_389340-a622fbd1302bc8a0a52b70f8713bc028f341c902
    Execute Command           machine LoadPlatformDescriptionFromString "i2c_echo: Mocks.EchoI2CDevice @ i2c0 0x55"

    # There is a problem with the rt_i2c_write() function in the simulation.
    # It configures the DMA transfer with the first set of commands (CFG, START, WRITE address, RPT, WRITE), but fails to continue with the next one.
    # The i2c_step1() callback is being called as a result of the interrupt, but it doesn't start the transfer of the actual data.
    # It looks like the state of the X8 register is wrong - it should contain a base address of the controller, but instead it is 0.
    # As a result the write that should be directed to I2C's register ends up in the memory.
    #
    # The code belows patches the value of the register by setting it to the TxBufferBaseAddress register of the i2c0 device
    # in the i2c_step1() function (https://github.com/pulp-platform/pulp-rt/blob/master/kernel/riscv/udma-v3.S#L305).
    #
    # WARNING: the addresses below are binary-specific and should be adapted after rebuilding the demo

    Execute Command           sysbus.cpu AddHook 0x1c008208 "self.SetRegisterUlong(12, 0x1a102190)"
    Execute Command           sysbus.cpu AddHook 0x1c00822c "self.SetRegisterUlong(12, 0x1a102190)"

    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     Entering test
    Wait For Line On Uart     reading...
    Wait For Line On Uart      0x0: 0x0
    Wait For Line On Uart      0x1: 0x0
    Wait For Line On Uart      0x2: 0x0
    Wait For Line On Uart      0x3: 0x0
    Wait For Line On Uart     writing...
    Wait For Line On Uart     readng again...
    Wait For Line On Uart      0x0: 0x0
    Wait For Line On Uart      0x1: 0x1
    Wait For Line On Uart      0x2: 0x2
    Wait For Line On Uart      0x3: 0x3
    Wait For Line On Uart     the end

SPI Should Send Bytes
    Create Machine           arnold--pulp-rt-examples--spim-send.elf-s_414648-d0100af113d67254d957e26c9ea62c014a753a0c
    Execute Command          machine LoadPlatformDescriptionFromString "dummySlave: Mocks.DummySPISlave @ spi"
    Create Log Tester        0.1
    Execute Command          logLevel 0 spi.dummySlave

    Start Emulation

    Wait For Log Entry       Data received: 0x0
    Wait For Log Entry       Data received: 0x1
    Wait For Log Entry       Data received: 0x2
    Wait For Log Entry       Data received: 0x3
    Wait For Log Entry       Data received: 0x4
    Wait For Log Entry       Data received: 0x5
    Wait For Log Entry       Data received: 0x6
    Wait For Log Entry       Data received: 0x7
    Wait For Log Entry       Data received: 0x8
    Wait For Log Entry       Data received: 0x9
    Wait For Log Entry       Data received: 0xA
    Wait For Log Entry       Data received: 0xB
    Wait For Log Entry       Data received: 0xC
    Wait For Log Entry       Data received: 0xD
    Wait For Log Entry       Data received: 0xE
    Wait For Log Entry       Data received: 0xF

SPI Should Send Bytes Async
    Create Machine           arnold--spim-async.elf-s_417852-3cf040621fd22ac14bd67be8decfe3a84f7d8d78
    Execute Command          machine LoadPlatformDescriptionFromString "dummySlave: Mocks.DummySPISlave @ spi"
    Create Terminal Tester   sysbus.uart
    Create Log Tester        0.1
    Execute Command          logLevel 0 spi.dummySlave

    Start Emulation

    Wait For Line On Uart    Executing callback!
    Wait For Log Entry       Data received: 0x0
    Wait For Log Entry       Data received: 0x1F
    Wait For Line On Uart    Executing callback!
    Wait For Log Entry       Data received: 0x0
    Wait For Log Entry       Data received: 0x1F
    Wait For Line On Uart    Executing callback!
    Wait For Log Entry       Data received: 0x0
    Wait For Log Entry       Data received: 0x1F

SPI Should Receive Bytes
    Create Machine           arnold--pulp-rt-examples--spim-receive.elf-s_414528-ba2983aef41f1493d1f6b13c58ea0d7b843bf57a
    Execute Command          machine LoadPlatformDescriptionFromString "dummySlave: Mocks.DummySPISlave @ spi"
    Create Log Tester        0.1
    Execute Command          logLevel 0 spi.dummySlave

    ${res}=  Execute Command         sysbus ReadDoubleWord 0x1C00A7F8
    Should Contain                   ${res}      0x00000000
    ${res}=  Execute Command         sysbus ReadDoubleWord 0x1C00A7FC
    Should Contain                   ${res}      0x00000000
    ${res}=  Execute Command         sysbus ReadDoubleWord 0x1C00A800
    Should Contain                   ${res}      0x00000000
    ${res}=  Execute Command         sysbus ReadDoubleWord 0x1C00A804
    Should Contain                   ${res}      0x00000000

    FOR  ${i}  IN RANGE  0  16
        Execute Command              sysbus.spi.dummySlave EnqueueValue ${i}
    END

    Start Emulation

    Wait For Log Entry               Data received: 0x0 (idx: 15)
    ${res}=  Execute Command         sysbus ReadDoubleWord 0x1C00A7F8
    Should Contain                   ${res}      0x03020100
    ${res}=  Execute Command         sysbus ReadDoubleWord 0x1C00A7FC
    Should Contain                   ${res}      0x07060504
    ${res}=  Execute Command         sysbus ReadDoubleWord 0x1C00A800
    Should Contain                   ${res}      0x0B0A0908
    ${res}=  Execute Command         sysbus ReadDoubleWord 0x1C00A804
    Should Contain                   ${res}      0x0F0E0D0C

Should Read Frames From Camera
    Create Machine           arnold-pulp-camera-s_391968-f3ac0d1bcaf06ba5811c3e5c333aeac8286c5bdc
    Execute Command          machine LoadPlatformDescriptionFromString "himax: Sensors.HiMaxHM01B0 @ camera_controller"

    Execute Command          sysbus.camera_controller.himax AddFrame ${URI}/images/person_image_0.jpg-s_3853-7f2125e28423fa117a1079d84785b17c9b70f62d

    Create Terminal Tester   ${UART}
    Start Emulation

    Wait For Line On Uart    Entering main controller
    Wait For Line On Uart    Frame 1 captured!
    Wait For Line On Uart    0xff 0xd8 0xff 0xe0 0x0 0x10 0x4a 0x46
    Wait For Line On Uart    Frame 2 captured!
    Wait For Line On Uart    0xff 0xd8 0xff 0xe0 0x0 0x10 0x4a 0x46
    Wait For Line On Uart    Frame 3 captured!
    Wait For Line On Uart    0xff 0xd8 0xff 0xe0 0x0 0x10 0x4a 0x46
    Wait For Line On Uart    Frame 4 captured!
    Wait For Line On Uart    0xff 0xd8 0xff 0xe0 0x0 0x10 0x4a 0x46
    Wait For Line On Uart    Frame 5 captured!
    Wait For Line On Uart    0xff 0xd8 0xff 0xe0 0x0 0x10 0x4a 0x46
    Wait For Line On Uart    Frame 6 captured!
    Wait For Line On Uart    0xff 0xd8 0xff 0xe0 0x0 0x10 0x4a 0x46
    Wait For Line On Uart    Frame 7 captured!
    Wait For Line On Uart    0xff 0xd8 0xff 0xe0 0x0 0x10 0x4a 0x46
    Wait For Line On Uart    Frame 8 captured!
    Wait For Line On Uart    0xff 0xd8 0xff 0xe0 0x0 0x10 0x4a 0x46
    Wait For Line On Uart    Frame 9 captured!
    Wait For Line On Uart    0xff 0xd8 0xff 0xe0 0x0 0x10 0x4a 0x46
    Wait For Line On Uart    Frame 10 captured!
    Wait For Line On Uart    0xff 0xd8 0xff 0xe0 0x0 0x10 0x4a 0x46
    Wait For Line On Uart    Test success
