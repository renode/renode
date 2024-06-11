*** Test Cases **
Should Pass Test
    Execute Command                 set example clicdirect-01
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicdirect-01.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct
