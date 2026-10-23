*** Settings ***
Resource   ${RENODEKEYWORDS}

*** Keywords ***
Specific Test Setup
    Reset Emulation
    Create Machine

Create Machine
    Execute Command             mach create "test"
    Execute Command             machine LoadPlatformDescriptionFromString ${REPL_STRING}    

Create Single Bitmask
  [Arguments]  ${index}
  ${result}=   Evaluate   2**${index}
  [Return]   ${result}

Assert IRQ Is Set
    [Arguments]  ${module}   ${irqName}
    ${irqState}=                Execute Command  ${module} ${irqName}
    Should Contain              ${irqState}  GPIO: set

Assert IRQ Is Unset
    [Arguments]  ${module}   ${irqName}
    ${irqState}=                Execute Command  ${module} ${irqName}
    Should Contain              ${irqState}  GPIO: unset 