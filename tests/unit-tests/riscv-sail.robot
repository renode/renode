*** Settings ***
Suite Setup                   Get Test Cases

*** Variables ***
@{binaries_paths}=            /home/marti/Downloads/sail-riscv/test/riscv-tests
@{pattern}=                   rv64ua-p-*.elf
@{excludes}=                  
${PLATFORM}                   @platforms/cpus/sifive-fu540.repl

*** Keywords *** 
Get Test Cases
    Setup
    @{binaries}=  List Files In Directory Recursively  @{binaries_paths}  @{pattern}  @{excludes}
    Set Suite Variable  @{binaries}

Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription ${PLATFORM}

*** Test Cases ***
Should Pass Tests
    FOR  ${binary}  IN  @{binaries}
        Log To Console              Running test ${binary}
        Create Machine 
        Create Log Tester           1
        Execute Command             sysbus LoadELF @${binary}
        Execute Command             e51 LogFunctionNames true true
        Execute Command             start
        Wait For Log Entry          Entering function pass
        Reset Emulation 
    END
