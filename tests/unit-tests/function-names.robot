*** Variables ***
${ZEPHYR_BIN}         @https://dl.antmicro.com/projects/renode/zephyr-3.6.0--samples_hello_world--kv260_r8.elf-s_414440-9d6b2002dffe7938f055fa7963884c6b0a578f65

*** Test Cases ***
LogFunctionNames Should Output Function Names Not ABS Symbols
    Execute Command           mach create
    Execute Command           machine LoadPlatformDescription @platforms/cpus/cortex-r8.repl

    Execute Command           sysbus LoadELF ${ZEPHYR_BIN}
    Execute Command           cpu0 LogFunctionNames true true
    Create Log Tester         1
    Wait For Log Entry        Entering function z_arm_reset (entry) at 0x5A8
    Wait For Log Entry        Entering function z_arm_platform_init (entry) at 0x2EA2
    Wait For Log Entry        Entering function z_arm_reset+0x54 (guessed) at 0x5FC
    Wait For Log Entry        Entering function z_prep_c (entry) at 0x620
    Wait For Log Entry        Entering function relocate_vector_table (entry) at 0x305C
    Wait For Log Entry        Entering function z_prep_c at 0x62C
    Wait For Log Entry        Entering function z_bss_zero (entry) at 0x1114
    Wait For Log Entry        Entering function z_early_memset (entry) at 0x31A8
    Wait For Log Entry        Entering function memset (entry) at 0x3534
