# This test suite uses Zephyr payloads for the
# mimxrt700_evk/mimxrt798s/cm33_cpu{0,1} platform
*** Keywords ***
Prepare Machine
    Execute Command                 mach clear
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/boards/mimxrt700_evk.repl

Load Zephyr Binary
    [Arguments]                     ${binary}  ${core}  ${disable_other_core}=True
    Execute Command                 sysbus LoadELF ${binary} cpu=${core}
    Execute Command                 ${core} VectorTableOffset `sysbus GetSymbolAddress "_vector_table" context=${core}`

    IF  "${core}" == "cpu0"
        ${other_core}=                  Set Variable  cpu1
    ELSE
        ${other_core}=                  Set Variable  cpu0
    END

    Run Keyword If                  ${disable_other_core}  Execute Command  ${other_core} IsHalted true

*** Test Cases ***
Should Run Boot Zephyr RTOS
    Prepare Machine
    Load Zephyr Binary              @https://dl.antmicro.com/projects/renode/mimxrt700_evk_mimxrt798s_cm33_cpu0--hello_world.elf-s_749016-f093063c426f0f51a4ed694996e12193fbab6262  cpu0

    Create Terminal Tester          sysbus.flexcomm0

    Wait For Line On Uart           *** Booting Zephyr OS build  includeUnfinishedLine=True
    Wait For Line On Uart           Hello World! mimxrt700_evk/mimxrt798s/cm33_cpu0

Should Run Core0 Zephyr Shell Module
    Prepare Machine
    Load Zephyr Binary              @https://dl.antmicro.com/projects/renode/mimxrt700_evk_mimxrt798s_cm33_cpu0--shell_module.elf-s_2480680-15aad5a26fbb09eb671dcc05a2a361a3738882f2  cpu0
    Create Terminal Tester          sysbus.flexcomm0

    Wait For Prompt On Uart         uart:~$
    Write Line To Uart
    Wait For Prompt On Uart         uart:~$
    Write Line To Uart              demo board
    Wait For Line On Uart           mimxrt700_evk

Should Run Core1 Zephyr Shell Module
    Prepare Machine
    Load Zephyr Binary              @https://dl.antmicro.com/projects/renode/mimxrt700_evk_mimxrt798s_cm33_cpu1--shell_module.elf-s_2364632-92d5e42bb63f42c1015dc45b6831f473b4e57a7d  cpu1
    Create Terminal Tester          sysbus.flexcomm19

    Wait For Prompt On Uart         uart:~$
    Write Line To Uart
    Wait For Prompt On Uart         uart:~$
    Write Line To Uart              demo board
    Wait For Line On Uart           mimxrt700_evk

Should Run Core0 Zephyr Philosophers
    Prepare Machine
    Load Zephyr Binary              @https://dl.antmicro.com/projects/renode/mimxrt700_evk_mimxrt798s_cm33_cpu0--philosophers.elf-s_789720-6c27fd55c15eb9f986fcf654637b4046945d42cc  cpu0
    Create Terminal Tester          sysbus.flexcomm0

    Wait For Line On Uart           Philosopher 5.*THINKING  treatAsRegex=true  pauseEmulation=true
    Wait For Line On Uart           Philosopher 5.*HOLDING  treatAsRegex=true  pauseEmulation=true
    Wait For Line On Uart           Philosopher 5.*EATING  treatAsRegex=true  pauseEmulation=true

Should Run Core1 Zephyr Philosophers
    Prepare Machine
    Load Zephyr Binary              @https://dl.antmicro.com/projects/renode/mimxrt700_evk_mimxrt798s_cm33_cpu1--philosophers.elf-s_675736-cf65e9273232e7ab87557db5b6871772db82ddff  cpu1
    Create Terminal Tester          sysbus.flexcomm19

    Wait For Line On Uart           Philosopher 5.*THINKING  treatAsRegex=true  pauseEmulation=true
    Wait For Line On Uart           Philosopher 5.*HOLDING  treatAsRegex=true  pauseEmulation=true
    Wait For Line On Uart           Philosopher 5.*EATING  treatAsRegex=true  pauseEmulation=true
