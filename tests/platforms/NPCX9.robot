*** Variables ***
${UART}                       sysbus.cr_uart1
${URI}                        @https://dl.antmicro.com/projects/renode
${PLATFORM}                   platforms/boards/nuvoton_npcx9m6fb_evb.repl

${BOARD_WITH_LED}=  SEPARATOR=
...  """                                                            ${\n}
...  using "${PLATFORM}"                                            ${\n}
...  itim32_1:                                                      ${\n}
...  ${SPACE*4}apb2Frequency:  15000000                             ${\n}
...  itim64:                                                        ${\n}
...  ${SPACE*4}apb2Frequency:  15000000                             ${\n}
...  """


*** Test Cases ***
Should Blink With Led
    Execute Command             mach create
    Execute Command             machine LoadPlatformDescriptionFromString ${BOARD_WITH_LED}
    Execute Command             sysbus LoadELF @https://dl.antmicro.com/projects/renode/npcx9m6f_evb--zephyr-blinky.elf-s_441840-4b2511ac3dae96ad2bb3399bd0e1e7a5608ec44d

    Create Terminal Tester      ${UART}   defaultPauseEmulation=true

    Create LED Tester           sysbus.gpio6.red_led

    Wait For Line On Uart       Booting Zephyr OS build
    Assert LED Is Blinking      testDuration=4  onDuration=1  tolerance=0.05  offDuration=1


Should Run TMP108
    Execute Command             mach create
    Execute Command             machine LoadPlatformDescription @${PLATFORM}
    Execute Command             machine LoadPlatformDescriptionFromString "tmp108: Sensors.TMP108 @ smbus0 32"

    Execute Command             sysbus LoadELF @https://dl.antmicro.com/projects/renode/npcx9m6f_evb--zephyr-sensor-tmp108.elf-s_863952-eb8c2bd632d2e0ed4531bb7ef04d880e49cdd534

    Create Terminal Tester      ${UART}   defaultPauseEmulation=true

    Wait For Line On Uart       *** Booting Zephyr OS build
    Wait For Line On Uart       TI TMP108 Example, arm

    Execute Command             sysbus.smbus0.tmp108 Temperature 20
    Wait For Line On Uart       temperature is 20.0

    Execute Command             sysbus.smbus0.tmp108 Temperature 18
    Wait For Line On Uart       temperature is 18.0

    Execute Command             sysbus.smbus0.tmp108 Temperature 0
    Wait For Line On Uart       temperature is 0.0
