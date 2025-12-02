*** Settings ***
Test Setup                          Create Machine

*** Keywords ***
Create Machine
    Execute Command                 include @platforms/cpus/egis_et171.repl
    Create Log Tester               0

*** Test Cases ***
Reading From Trigger Type Array Should Not Be Unhandled
    Execute Command                 plic ReadDoubleWord 0x1080
    Should Not Be In Log            plic: Unhandled read from offset 0x1080

Trigger Type Should Be Level
    ${actual_trigger_types}=        Execute Command  plic ReadDoubleWord 0x1080
    ${expected_trigger_types}=      Set Variable  0
    Should Be Equal As Integers     ${actual_trigger_types}  ${expected_trigger_types}  Interrupt trigger types should be set to Level-triggered

First Bit Of First Type Register Should Always Be Zero
    ${register_contents}=           Execute Command  plic ReadDoubleWord 0x1080
    ${first_bit}=                   Evaluate  ${register_contents.strip()} & 0b1
    ${hardwired_zero}=              Set Variable  0
    # Zero is not a valid interrupt source number so bit 0 of the first register must be hardwired to 0.
    Should Be Equal As Integers     ${first_bit}  ${hardwired_zero}  First bit of first register should be zero
