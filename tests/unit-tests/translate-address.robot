*** Variables ***
${UART}                       sysbus.uart
${URI}                        @https://dl.antmicro.com/projects/renode

*** Keywords ***
Create Machine
    [Arguments]  ${elf}

    Execute Command          mach create
    Execute Command          machine LoadPlatformDescription @platforms/cpus/sifive-fe310.repl
    Execute Command          sysbus LoadELF ${URI}/${elf}

Pause At
    [Arguments]  ${address}  ${continues}=0

    Execute Command           cpu AddHook ${address} "cpu.Pause()"
    Start Emulation

    FOR  ${i}  IN RANGE  0  ${continues}
        Wait For Pause        5
        Execute Command       cpu Step 1
        Execute Command       cpu ExecutionMode Continuous
    END

    Wait For Pause            5

*** Test Cases ***
Translate Address Should Fail
          # Address values are binary dependant
          Create Machine            hifive1_revb--zephyr-shared_mem.elf-s_873884-6c6aac93b93d8faf8d747eeaaa6fa1744a1dc1bb

          Execute Command           using sysbus

          # This pauses at calling entry in z_thread_entry @ lib/os/thread_entry.c for enc thread
          Pause At                  0x20011be4  continues=2

  ${pa}=  Execute Command           cpu TranslateAddress 0x80000364 InstructionFetch    # would cause page fault
          Should Contain            ${pa}       0xFFFFFFFFFFFFFFFF

          Provides                  unmapped_address

Translate Address Should Be Able To Map Address
          Requires                  unmapped_address

  ${pa}=  Execute Command           cpu TranslateAddress 0x800100000 InstructionFetch   # would not cause page fault
          Should Contain            ${pa}       0x0000000000100000 
 
