*** Variables ***
${UART}                           sysbus.duart0

${DIRECTION_OFFSET}               0x00
${DRAIN_OFFSET}                   0x04
${DATA_OFFSET}                    0x08
${INTERRUPT_OFFSET}               0x0C
${MASK_OFFSET}                    0x10
${FALLING_IER_OFFSET}             0x14

${SET_14}                        0x00020000
${SET_15}                        0x00010000
${SET_14_15}                     0x00030000

${GPIO_UNSET_STR}                GPIO: unset
${GPIO_SET_STR}                  GPIO: set

*** Keywords ***
Start Script
    Execute Script                scripts/single-node/nxp-ls1043a.resc
    # Create a loop between GPIO 14 and GPIO 15. 
    # Changing GPIO 14 should modify GPIO 15 and generate interrupt requests if conditions are fulfilled.
    Execute Command               machine LoadPlatformDescriptionFromString "gpio1: { 14 -> gpio1@15 }" 
    Start Emulation   


*** Test Cases ***
GPIO Test Case
    Start Script

    # Set GPIO 14 as output and GPIO 15 as input
    Execute Command               gpio1 WriteDoubleWord ${DIRECTION_OFFSET} ${SET_14}
    
    # Assert IRQ is currently unset
    ${value}=  Execute Command    gpio1 IRQ
    Should Contain                ${value}  ${GPIO_UNSET_STR}

    # All interrupts are masked by default
    Execute Command               gpio1 WriteDoubleWord 0x10 0
    
    # Raise GPIO 14 ; assert GPIO 14 and 15 are up
    Execute Command               gpio1 WriteDoubleWord ${DATA_OFFSET} ${SET_14}
    ${value}=  Execute Command    gpio1 ReadDoubleWord ${DATA_OFFSET}
    Should Be Equal As Integers   ${value}  ${SET_14_15}

    # Assert interrupt request has been emitted, but IRQ is still low since interrupt is masked
    ${value}=  Execute Command    gpio1 ReadDoubleWord ${INTERRUPT_OFFSET}
    Should Be Equal As Integers   ${value}  ${SET_15}
    ${value}=  Execute Command    gpio1 IRQ
    Should Contain                ${value}  ${GPIO_UNSET_STR}  
    # Unset IRQ
    Execute Command               gpio1 WriteDoubleWord ${INTERRUPT_OFFSET} ${SET_15}
    
    # Lower GPIO 14 ; assert GPIO 14 and 15 are down
    # Here we set 15 since 15 is assumed to be up in the previous test ; we do not lower 15, only 14
    Execute Command               gpio1 WriteDoubleWord ${DATA_OFFSET} ${SET_15}
    # But 15 should be lowered by OnGPIO since 14 is lowered
    ${value}=  Execute Command    gpio1 ReadDoubleWord ${DATA_OFFSET}
    Should Be Equal As Integers   ${value}  0

    # Assert interrupt request has been emitted, but IRQ is still low since interrupt is masked
    ${value}=  Execute Command    gpio1 ReadDoubleWord ${INTERRUPT_OFFSET}
    Should Be Equal As Integers   ${value}  ${SET_15}
    ${value}=  Execute Command    gpio1 IRQ
    Should Contain                ${value}  ${GPIO_UNSET_STR}  
    # Unset IRQ
    Execute Command               gpio1 WriteDoubleWord ${INTERRUPT_OFFSET} ${SET_15}      

    # Set GPIO 15 interrupt trigger to falling edge only, and unmask it
    Execute Command               gpio1 WriteDoubleWord ${FALLING_IER_OFFSET} ${SET_15}   
    Execute Command               gpio1 WriteDoubleWord ${MASK_OFFSET} ${SET_15}       
   
    # Raise GPIO 14 ; assert GPIO 14 and 15 are up
    Execute Command               gpio1 WriteDoubleWord ${DATA_OFFSET} ${SET_14}
    ${value}=  Execute Command    gpio1 ReadDoubleWord ${DATA_OFFSET}
    Should Be Equal As Integers   ${value}  ${SET_14_15}
   
    # Assert interrupt has not been generated on rising edge 
    ${value}=  Execute Command    gpio1 ReadDoubleWord ${INTERRUPT_OFFSET}
    Should Be Equal As Integers   ${value}  0
    ${value}=  Execute Command    gpio1 IRQ
    Should Contain                ${value}  ${GPIO_UNSET_STR}   
   
    # Lower GPIO 14 ; assert GPIO 14 and 15 are down
    # Here we set 15 since 15 is assumed to be up in the previous test ; we do not lower 15, only 14
    Execute Command               gpio1 WriteDoubleWord ${DATA_OFFSET} ${SET_15}
    # But 15 should be lowered by OnGPIO since 14 is lowered
    ${value}=  Execute Command    gpio1 ReadDoubleWord ${DATA_OFFSET}
    Should Be Equal As Integers   ${value}  0
   
    # Assert IRQ was raised & acknowledge it
    ${value}=  Execute Command    gpio1 ReadDoubleWord ${INTERRUPT_OFFSET}
    Should Be Equal As Integers   ${value}  ${SET_15}
    ${value}=  Execute Command    gpio1 IRQ
    Should Contain                ${value}  ${GPIO_SET_STR}   
    # Unset IRQ
    Execute Command               gpio1 WriteDoubleWord ${INTERRUPT_OFFSET} ${SET_15}
    ${value}=  Execute Command    gpio1 IRQ
    Should Contain                ${value}  ${GPIO_UNSET_STR} 
