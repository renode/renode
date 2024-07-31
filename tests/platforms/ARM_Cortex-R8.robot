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

Remap Exception Vector
    [Arguments]    ${cpu}  ${remapped_vector_base_addr}
    Execute Command                 ${cpu} ExceptionVectorAddress ${remapped_vector_base_addr}
    Wait For Log Entry              ${cpu}: Successfully set ExceptionVectorAddress to ${remapped_vector_base_addr} on a CPU supporting neither VBAR nor VTOR; such customization might not be possible on hardware.

Verify Exception Vector Base Address
    [Arguments]    ${cpu}  ${expected_vector_base_addr}

    ${expected_vector_udef_addr}    Set Variable  ${{ ${expected_vector_base_addr} + 0x4 }}

    # Let's make the first instruction invalid and try to execute it. It isn't placed at 0x0
    # because the undefined instruction handler's offset is 0x4. With the instruction placed
    # at 0x0 distinguishing between between 0x4 being a result of a single step and jumping
    # to the undefined instruction handler wouldn't be possible.
    ${program_start}=               Set Variable  0x1000
    Execute Command                 sysbus WriteDoubleWord ${program_start} 0xf1010200
    Execute Command                 ${cpu} PC ${program_start}

    # The next PC is expected to be the undefined instruction handler in the remapped vector.
    Execute Command                 ${cpu} Step
    Verify PC                       ${cpu}  ${expected_vector_udef_addr}

Verify PC
    [Arguments]                     ${cpu}  ${expected_value}

    ${pc}=  Execute Command         ${cpu} PC
    Should Be Equal As Integers     ${pc}  ${expected_value}

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

Test Remapping Exception Vector
    ${default_vector_base}          Set Variable    0x0
    ${remapped_vector_base_cpu0}    Set Variable    0x1000000
    ${remapped_vector_base_cpu2}    Set Variable    0x1234560

    Execute Command      using sysbus
    Execute Command      mach create
    Execute Command      machine LoadPlatformDescription @platforms/cpus/cortex-r8_smp.repl
    Create Log Tester    1

    # Prevent starting other CPUs when stepping one of them.
    FOR  ${cpu_idx}  IN RANGE  4
        Execute Command    cpu${cpu_idx} ExecutionMode SingleStep
    END

    # Let's remap exception vector for cpu0 and cpu2.
    Remap Exception Vector    cpu0    ${remapped_vector_base_cpu0}
    Remap Exception Vector    cpu2    ${remapped_vector_base_cpu2}

    # Verify exception vectors, it should be a default for other CPUs.
    Verify Exception Vector Base Address    cpu0    ${remapped_vector_base_cpu0}
    Verify Exception Vector Base Address    cpu1    ${default_vector_base}
    Verify Exception Vector Base Address    cpu2    ${remapped_vector_base_cpu2}
    Verify Exception Vector Base Address    cpu3    ${default_vector_base}
