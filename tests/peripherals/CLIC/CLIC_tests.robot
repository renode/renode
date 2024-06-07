*** Test Cases ***
Should Pass clicdirect-01_default
    Execute Command                 set example clicdirect-01_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicdirect-01_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicdirect-01_ecall
    Execute Command                 set example clicdirect-01_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicdirect-01_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicdirect-01_ecall_int1clear
    Execute Command                 set example clicdirect-01_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicdirect-01_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicdirect-01_int1clear
    Execute Command                 set example clicdirect-01_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicdirect-01_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-01_default
    Execute Command                 set example cliclevel-01_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/cliclevel-01_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-01_ecall
    Execute Command                 set example cliclevel-01_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/cliclevel-01_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-01_ecall_int1clear
    Execute Command                 set example cliclevel-01_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/cliclevel-01_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-01_int1clear
    Execute Command                 set example cliclevel-01_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/cliclevel-01_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-02_default
    Execute Command                 set example cliclevel-02_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/cliclevel-02_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-02_ecall
    Execute Command                 set example cliclevel-02_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/cliclevel-02_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-02_ecall_int1clear
    Execute Command                 set example cliclevel-02_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/cliclevel-02_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-02_int1clear
    Execute Command                 set example cliclevel-02_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/cliclevel-02_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-03_default
    Execute Command                 set example cliclevel-03_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/cliclevel-03_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-03_ecall
    Execute Command                 set example cliclevel-03_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/cliclevel-03_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-03_ecall_int1clear
    Execute Command                 set example cliclevel-03_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/cliclevel-03_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-03_int1clear
    Execute Command                 set example cliclevel-03_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/cliclevel-03_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-04_default
    Execute Command                 set example cliclevel-04_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/cliclevel-04_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-04_ecall
    Execute Command                 set example cliclevel-04_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/cliclevel-04_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-04_ecall_int1clear
    Execute Command                 set example cliclevel-04_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/cliclevel-04_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-04_int1clear
    Execute Command                 set example cliclevel-04_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/cliclevel-04_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-01_default
    Execute Command                 set example clicnomint-01_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicnomint-01_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-01_ecall
    Execute Command                 set example clicnomint-01_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicnomint-01_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-01_ecall_int1clear
    Execute Command                 set example clicnomint-01_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicnomint-01_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-01_int1clear
    Execute Command                 set example clicnomint-01_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicnomint-01_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-02_default
    Execute Command                 set example clicnomint-02_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicnomint-02_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-02_ecall
    Execute Command                 set example clicnomint-02_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicnomint-02_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-02_ecall_int1clear
    Execute Command                 set example clicnomint-02_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicnomint-02_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-02_int1clear
    Execute Command                 set example clicnomint-02_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicnomint-02_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-03_default
    Execute Command                 set example clicnomint-03_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicnomint-03_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-03_ecall
    Execute Command                 set example clicnomint-03_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicnomint-03_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-03_ecall_int1clear
    Execute Command                 set example clicnomint-03_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicnomint-03_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-03_int1clear
    Execute Command                 set example clicnomint-03_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicnomint-03_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvdirect-01_default
    Execute Command                 set example clicshvdirect-01_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvdirect-01_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvdirect-01_ecall
    Execute Command                 set example clicshvdirect-01_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvdirect-01_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvdirect-01_ecall_int1clear
    Execute Command                 set example clicshvdirect-01_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvdirect-01_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvdirect-01_int1clear
    Execute Command                 set example clicshvdirect-01_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvdirect-01_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvinhv-01_default
    Execute Command                 set example clicshvinhv-01_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvinhv-01_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvinhv-01_ecall
    Execute Command                 set example clicshvinhv-01_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvinhv-01_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvinhv-01_ecall_int1clear
    Execute Command                 set example clicshvinhv-01_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvinhv-01_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvinhv-01_int1clear
    Execute Command                 set example clicshvinhv-01_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvinhv-01_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-01_default
    Execute Command                 set example clicshvlevel-01_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-01_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-01_ecall
    Execute Command                 set example clicshvlevel-01_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-01_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-01_ecall_int1clear
    Execute Command                 set example clicshvlevel-01_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-01_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-01_int1clear
    Execute Command                 set example clicshvlevel-01_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-01_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-02_default
    Execute Command                 set example clicshvlevel-02_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-02_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-02_ecall
    Execute Command                 set example clicshvlevel-02_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-02_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-02_ecall_int1clear
    Execute Command                 set example clicshvlevel-02_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-02_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-02_int1clear
    Execute Command                 set example clicshvlevel-02_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-02_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-03_default
    Execute Command                 set example clicshvlevel-03_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-03_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-03_ecall
    Execute Command                 set example clicshvlevel-03_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-03_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-03_ecall_int1clear
    Execute Command                 set example clicshvlevel-03_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-03_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-03_int1clear
    Execute Command                 set example clicshvlevel-03_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-03_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-04_default
    Execute Command                 set example clicshvlevel-04_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-04_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-04_ecall
    Execute Command                 set example clicshvlevel-04_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-04_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-04_ecall_int1clear
    Execute Command                 set example clicshvlevel-04_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-04_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-04_int1clear
    Execute Command                 set example clicshvlevel-04_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-04_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-05_default
    Execute Command                 set example clicshvlevel-05_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-05_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-05_ecall
    Execute Command                 set example clicshvlevel-05_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-05_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-05_ecall_int1clear
    Execute Command                 set example clicshvlevel-05_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-05_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-05_int1clear
    Execute Command                 set example clicshvlevel-05_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-05_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-06_default
    Execute Command                 set example clicshvlevel-06_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-06_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-06_ecall
    Execute Command                 set example clicshvlevel-06_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-06_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-06_ecall_int1clear
    Execute Command                 set example clicshvlevel-06_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-06_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-06_int1clear
    Execute Command                 set example clicshvlevel-06_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-06_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-07_default
    Execute Command                 set example clicshvlevel-07_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-07_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-07_ecall
    Execute Command                 set example clicshvlevel-07_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-07_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-07_ecall_int1clear
    Execute Command                 set example clicshvlevel-07_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-07_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-07_int1clear
    Execute Command                 set example clicshvlevel-07_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-07_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-08_default
    Execute Command                 set example clicshvlevel-08_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-08_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-08_ecall
    Execute Command                 set example clicshvlevel-08_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-08_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-08_ecall_int1clear
    Execute Command                 set example clicshvlevel-08_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-08_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-08_int1clear
    Execute Command                 set example clicshvlevel-08_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-08_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-09_default
    Execute Command                 set example clicshvlevel-09_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-09_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-09_ecall
    Execute Command                 set example clicshvlevel-09_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-09_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-09_ecall_int1clear
    Execute Command                 set example clicshvlevel-09_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-09_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-09_int1clear
    Execute Command                 set example clicshvlevel-09_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicshvlevel-09_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicwfi-01_default
    Execute Command                 set example clicwfi-01_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicwfi-01_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicwfi-01_ecall
    Execute Command                 set example clicwfi-01_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicwfi-01_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicwfi-01_ecall_int1clear
    Execute Command                 set example clicwfi-01_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicwfi-01_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass clicwfi-01_int1clear
    Execute Command                 set example clicwfi-01_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/clicwfi-01_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicdeleg-01_default
    Execute Command                 set example sclicdeleg-01_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicdeleg-01_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicdeleg-01_ecall
    Execute Command                 set example sclicdeleg-01_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicdeleg-01_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicdeleg-01_ecall_int1clear
    Execute Command                 set example sclicdeleg-01_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicdeleg-01_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicdeleg-01_int1clear
    Execute Command                 set example sclicdeleg-01_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicdeleg-01_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-01_default
    Execute Command                 set example sclicmdisable-01_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicmdisable-01_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-01_ecall
    Execute Command                 set example sclicmdisable-01_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicmdisable-01_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-01_ecall_int1clear
    Execute Command                 set example sclicmdisable-01_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicmdisable-01_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-01_int1clear
    Execute Command                 set example sclicmdisable-01_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicmdisable-01_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-02_default
    Execute Command                 set example sclicmdisable-02_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicmdisable-02_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-02_ecall
    Execute Command                 set example sclicmdisable-02_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicmdisable-02_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-02_ecall_int1clear
    Execute Command                 set example sclicmdisable-02_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicmdisable-02_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-02_int1clear
    Execute Command                 set example sclicmdisable-02_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicmdisable-02_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-03_default
    Execute Command                 set example sclicmdisable-03_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicmdisable-03_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-03_ecall
    Execute Command                 set example sclicmdisable-03_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicmdisable-03_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-03_ecall_int1clear
    Execute Command                 set example sclicmdisable-03_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicmdisable-03_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-03_int1clear
    Execute Command                 set example sclicmdisable-03_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicmdisable-03_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicnodeleg-01_default
    Execute Command                 set example sclicnodeleg-01_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicnodeleg-01_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicnodeleg-01_ecall
    Execute Command                 set example sclicnodeleg-01_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicnodeleg-01_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicnodeleg-01_ecall_int1clear
    Execute Command                 set example sclicnodeleg-01_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicnodeleg-01_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicnodeleg-01_int1clear
    Execute Command                 set example sclicnodeleg-01_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicnodeleg-01_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-01_default
    Execute Command                 set example sclicorder-01_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicorder-01_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-01_ecall
    Execute Command                 set example sclicorder-01_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicorder-01_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-01_ecall_int1clear
    Execute Command                 set example sclicorder-01_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicorder-01_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-01_int1clear
    Execute Command                 set example sclicorder-01_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicorder-01_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-02_default
    Execute Command                 set example sclicorder-02_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicorder-02_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-02_ecall
    Execute Command                 set example sclicorder-02_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicorder-02_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-02_ecall_int1clear
    Execute Command                 set example sclicorder-02_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicorder-02_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-02_int1clear
    Execute Command                 set example sclicorder-02_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicorder-02_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-03_default
    Execute Command                 set example sclicorder-03_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicorder-03_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-03_ecall
    Execute Command                 set example sclicorder-03_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicorder-03_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-03_ecall_int1clear
    Execute Command                 set example sclicorder-03_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicorder-03_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-03_int1clear
    Execute Command                 set example sclicorder-03_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicorder-03_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-04_default
    Execute Command                 set example sclicorder-04_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicorder-04_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-04_ecall
    Execute Command                 set example sclicorder-04_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicorder-04_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-04_ecall_int1clear
    Execute Command                 set example sclicorder-04_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicorder-04_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-04_int1clear
    Execute Command                 set example sclicorder-04_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicorder-04_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-01_default
    Execute Command                 set example sclicprivorder-01_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicprivorder-01_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-01_ecall
    Execute Command                 set example sclicprivorder-01_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicprivorder-01_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-01_ecall_int1clear
    Execute Command                 set example sclicprivorder-01_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicprivorder-01_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-01_int1clear
    Execute Command                 set example sclicprivorder-01_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicprivorder-01_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-02_default
    Execute Command                 set example sclicprivorder-02_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicprivorder-02_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-02_ecall
    Execute Command                 set example sclicprivorder-02_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicprivorder-02_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-02_ecall_int1clear
    Execute Command                 set example sclicprivorder-02_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicprivorder-02_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-02_int1clear
    Execute Command                 set example sclicprivorder-02_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicprivorder-02_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-03_default
    Execute Command                 set example sclicprivorder-03_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicprivorder-03_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-03_ecall
    Execute Command                 set example sclicprivorder-03_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicprivorder-03_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-03_ecall_int1clear
    Execute Command                 set example sclicprivorder-03_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicprivorder-03_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-03_int1clear
    Execute Command                 set example sclicprivorder-03_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicprivorder-03_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-01_default
    Execute Command                 set example sclicsdisable-01_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicsdisable-01_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-01_ecall
    Execute Command                 set example sclicsdisable-01_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicsdisable-01_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-01_ecall_int1clear
    Execute Command                 set example sclicsdisable-01_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicsdisable-01_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-01_int1clear
    Execute Command                 set example sclicsdisable-01_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicsdisable-01_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-02_default
    Execute Command                 set example sclicsdisable-02_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicsdisable-02_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-02_ecall
    Execute Command                 set example sclicsdisable-02_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicsdisable-02_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-02_ecall_int1clear
    Execute Command                 set example sclicsdisable-02_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicsdisable-02_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-02_int1clear
    Execute Command                 set example sclicsdisable-02_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicsdisable-02_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-03_default
    Execute Command                 set example sclicsdisable-03_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicsdisable-03_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-03_ecall
    Execute Command                 set example sclicsdisable-03_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicsdisable-03_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-03_ecall_int1clear
    Execute Command                 set example sclicsdisable-03_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicsdisable-03_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-03_int1clear
    Execute Command                 set example sclicsdisable-03_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicsdisable-03_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicwfi-01_default
    Execute Command                 set example sclicwfi-01_default
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicwfi-01_default.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicwfi-01_ecall
    Execute Command                 set example sclicwfi-01_ecall
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicwfi-01_ecall.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicwfi-01_ecall_int1clear
    Execute Command                 set example sclicwfi-01_ecall_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicwfi-01_ecall_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

Should Pass sclicwfi-01_int1clear
    Execute Command                 set example sclicwfi-01_int1clear
    Execute Command                 set example_elf @tests/peripherals/CLIC/binaries/sclicwfi-01_int1clear.elf
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              All signatures correct

