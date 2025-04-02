*** Keywords ***
Test Memory
    [Arguments]  ${address}  ${expected_value}
    ${actual_value}=         Execute Command  sysbus ReadDoubleWord ${address}
    Should Be Equal As Numbers    ${actual_value}  ${expected_value}

Execute Loop And Verify Counter
    [Arguments]  ${expected_value}
    Execute Command          sysbus.cpu Step 2
    Test Memory              0xf0000004  ${expected_value}

*** Test Cases ***
Should Parse Monitor in CPU Hook
    Execute Command          include @scripts/single-node/miv.resc
    Execute Command          cpu AddHook `cpu PC` "monitor.Parse('log \\"message from the cpu hook\\"')"

    Create Log Tester        1
    Start Emulation

    Wait For Log Entry       message from the cpu hook


Should Stop On Peripheral Read Watchpoint
    Execute Command          mach create
    Execute Command          machine LoadPlatformDescriptionFromString "cpu: CPU.ARMv7A @ sysbus { cpuType: \\"cortex-a9\\" }"
    Execute Command          machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x1000 }"
    Execute Command          machine PyDevFromFile @scripts/pydev/counter.py 0xf0000004 0x4 True "ctr"

    # counter should increment on every read on sysbus
    Test Memory              0xf0000004  0x0
    Test Memory              0xf0000004  0x1

    # ldrb r0, [r1]
    Execute Command          sysbus WriteDoubleWord 0x10 0xe5d10000
    # b 0x10
    Execute Command          sysbus WriteDoubleWord 0x14 0xeafffffd

    Execute Command          sysbus.cpu PC 0x10
    Execute Command          sysbus.cpu SetRegister 1 0xf0000004

    # add an empty watchpoint
    Execute Command          sysbus AddWatchpointHook 0xf0000004 1 Read ""

    # make sure nothing read the counter after adding the watchpoint
    Test Memory              0xf0000004  0x2

    # it's expected for counter to increase by 2 as a result of
    # executing the `ldrb` instruction followed by the memory test
    Execute Loop And Verify Counter   0x4
    Execute Loop And Verify Counter   0x6
    Execute Loop And Verify Counter   0x8

Test Enabling Systick And Pausing Emulation From CortexM Hook
    # This test shouldn't take much more than 1s but if the systick logic is wrong, it can get stuck.
    [Timeout]                10s

    ${platform}=             catenate  SEPARATOR=
    ...  nvic: IRQControllers.NVIC @ sysbus 0xe000e000 { -> cpu@0 }          ${\n}
    ...  cpu: CPU.CortexM @ sysbus { cpuType: \\"cortex-m0\\"; nvic: nvic }  ${\n}
    ...  mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x10000 }             ${\n}

    Execute Command          mach create
    Execute Command          machine LoadPlatformDescriptionFromString "${platform}"
    Create Log Tester        0.001

    # Enable all NVIC logs and set reload value zero.
    Execute Command          logLevel -1 nvic
    Execute Command          nvic WriteDoubleWord 0x14 0x0

    # Empty memory acts as NOPs in ARM so not loading anything to memory isn't an issue.
    Execute Command          cpu PC 0x0

    # Let's make CPU enable systick and pause emulation soon after from hooks. This will freeze
    # Renode if systick's underlying LimitTimer really can be enabled with limit zero.
    Execute Command          cpu AddHook 0x10 "machine.SystemBus.WriteDoubleWord(0xe000e010, 0x1)"
    Execute Command          cpu AddHook 0x20 "machine.PauseAndRequestEmulationPause()"

    # Let's wait for the systick enabling attempt and machine pausing.
    Wait For Log Entry       Systick_NS enabled but it won't be started as long as the reload value is zero
    Wait For Log Entry       Machine paused

Test Translation Block Fetch Hook
    Execute Command          i @scripts/single-node/stm32l072.resc
    Execute Command          cpu LogTranslationBlockFetch True
    Create Log Tester        1

    Wait For Log Entry       cpu: Fetching block @ 0x08004E4C - z_arm_reset
    Wait For Log Entry       cpu: Fetching block @ 0x0800471C - stm32_clock_control_init
    Wait For Log Entry       cpu: Fetching block @ 0x08009ED8 - idle
    Wait For Log entry       cpu: Fetching block @ 0x0800483E - sys_clock_isr
