*** Test Cases **
Should Pass Test
    Execute Command                 set example clicnomint-03
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicnomint-03.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct
