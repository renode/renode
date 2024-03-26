*** Keywords ***
Create Machine
    [Arguments]                     ${elf_file}
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/cortex-r8.repl

    Execute Command                 sysbus LoadELF @${elf_file}
    Create Terminal Tester          sysbus.uart1    timeout=5   defaultPauseEmulation=true

Run Hello World
    [Arguments]                     ${elf_file}     ${board_name}
    Create Machine                  ${elf_file}
    Start Emulation
    Wait For Line On Uart           *** Booting Zephyr OS build
    Wait For Line On Uart           Hello World! ${board_name}

Run Philosophers
    [Arguments]                     ${elf_file}
    Create Machine                  ${elf_file}
    Start Emulation
    Wait For Line On Uart           Philosopher 5.*THINKING     treatAsRegex=true
    Wait For Line On Uart           Philosopher 5.*HOLDING      treatAsRegex=true
    Wait For Line On Uart           Philosopher 5.*EATING       treatAsRegex=true

Run Shell Module
    [Arguments]                     ${elf_file}
    Create Machine                  ${elf_file}
    Start Emulation
    Wait For Prompt On Uart         uart:~$
    Write Line To Uart
    Wait For Prompt On Uart         uart:~$
    Write Line To Uart              demo board
    Wait For Line On Uart           kv260_r8

*** Test Cases ***
Should Run Hello World 3.6.0
    Run Hello World                 https://dl.antmicro.com/projects/renode/zephyr-3.6.0--samples_hello_world--kv260_r8.elf-s_414440-9d6b2002dffe7938f055fa7963884c6b0a578f65   kv260_r8/zynqmp_rpu_r8

Should Run Philosophers 3.6.0
    Run Philosophers                https://dl.antmicro.com/projects/renode/zephyr-3.6.0--samples_philosophers--kv260_r8.elf-s_459704-7ede6e5bb6dec1e16e83c23ea5f97279302c3bbb

Should Run Shell Module 3.6.0
    Run Shell Module                https://dl.antmicro.com/projects/renode/zephyr-3.6.0--samples_subsys_shell_shell_module--kv260_r8.elf-s_1340080-84f1f45dafb5b55727b8a8ae19636f2464339489

Should Run Hello World 3.4.0
    Run Hello World                 https://dl.antmicro.com/projects/renode/zephyr-3.4.0--samples_hello_world--kv260_r8.elf-s_373384-c63ba3672f7e6457c6aedc178068b7e5784a5b0b   board_kv260_r8

Should Run Philosophers 3.4.0
    Run Philosophers                https://dl.antmicro.com/projects/renode/zephyr-3.4.0--samples_philosophers--kv260_r8.elf-s_490412-601fea129a84738c54aeefb92092ca6d6e1f8119

Should Run Shell Module 3.4.0
    Run Shell Module                https://dl.antmicro.com/projects/renode/zephyr-3.4.0--samples_subsys_shell_shell_module--kv260_r8.elf-s_1276220-ad5d7f3f1f7c813135c874bd77e1e25cc4510298
