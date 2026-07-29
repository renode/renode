*** Variables ***
${MaskableOutputData0Low_OFFSET}        0x000
${MaskableOutputData0Hi_OFFSET}         0x004
${MaskableOutputData1Low_OFFSET}        0x008
${MaskableOutputData1Hi_OFFSET}         0x00C
${MaskableOutputData2Low_OFFSET}        0x010
${MaskableOutputData2Hi_OFFSET}         0x014
${MaskableOutputData3Low_OFFSET}        0x018
${MaskableOutputData3Hi_OFFSET}         0x01C
${MaskableOutputData4Low_OFFSET}        0x020
${MaskableOutputData4Hi_OFFSET}         0x024
${MaskableOutputData5Low_OFFSET}        0x028
${MaskableOutputData5Hi_OFFSET}         0x02C

${Data0_OFFSET}                         0x040
${Data1_OFFSET}                         0x044
${Data2_OFFSET}                         0x048
${Data3_OFFSET}                         0x04C
${Data4_OFFSET}                         0x050
${Data5_OFFSET}                         0x054

${Data_RO0_OFFSET}                      0x060
${Data_RO1_OFFSET}                      0x064
${Data_RO2_OFFSET}                      0x068
${Data_RO3_OFFSET}                      0x06C
${Data_RO4_OFFSET}                      0x070
${Data_RO5_OFFSET}                      0x074

${DirectionMode0_OFFSET}                0x204
${OutputEnable0_OFFSET}                 0x208
${IntMask0_OFFSET}                      0x20C
${IntEnable0_OFFSET}                    0x210
${IntDisable0_OFFSET}                   0x214
${IntStatus0_OFFSET}                    0x218
${IntType0_OFFSET}                      0x21C
${IntPolarity0_OFFSET}                  0x220
${IntAny0_OFFSET}                       0x224

${DirectionMode1_OFFSET}                0x244
${OutputEnable1_OFFSET}                 0x248
${IntMask1_OFFSET}                      0x24C
${IntEnable1_OFFSET}                    0x250
${IntDisable1_OFFSET}                   0x254
${IntStatus1_OFFSET}                    0x258
${IntType1_OFFSET}                      0x25C
${IntPolarity1_OFFSET}                  0x260
${IntAny1_OFFSET}                       0x264

${DirectionMode2_OFFSET}                0x284
${OutputEnable2_OFFSET}                 0x288
${IntMask2_OFFSET}                      0x28C
${IntEnable2_OFFSET}                    0x290
${IntDisable2_OFFSET}                   0x294
${IntStatus2_OFFSET}                    0x298
${IntType2_OFFSET}                      0x29C
${IntPolarity2_OFFSET}                  0x2A0
${IntAny2_OFFSET}                       0x2A4

${DirectionMode3_OFFSET}                0x2C4
${OutputEnable3_OFFSET}                 0x2C8
${IntMask3_OFFSET}                      0x2CC
${IntEnable3_OFFSET}                    0x2D0
${IntDisable3_OFFSET}                   0x2D4
${IntStatus3_OFFSET}                    0x2D8
${IntType3_OFFSET}                      0x2DC
${IntPolarity3_OFFSET}                  0x2E0
${IntAny3_OFFSET}                       0x2E4

${DirectionMode4_OFFSET}                0x304
${OutputEnable4_OFFSET}                 0x308
${IntMask4_OFFSET}                      0x30C
${IntEnable4_OFFSET}                    0x310
${IntDisable4_OFFSET}                   0x314
${IntStatus4_OFFSET}                    0x318
${IntType4_OFFSET}                      0x31C
${IntPolarity4_OFFSET}                  0x320
${IntAny4_OFFSET}                       0x324

${DirectionMode5_OFFSET}                0x344
${OutputEnable5_OFFSET}                 0x348
${IntMask5_OFFSET}                      0x34C
${IntEnable5_OFFSET}                    0x350
${IntDisable5_OFFSET}                   0x354
${IntStatus5_OFFSET}                    0x358
${IntType5_OFFSET}                      0x35C
${IntPolarity5_OFFSET}                  0x360
${IntAny5_OFFSET}                       0x364

${GPIO_UNSET_STR}                       GPIO: unset
${GPIO_SET_STR}                         GPIO: set

${SET_80}                               0x00000004
${SET_81}                               0x00000008
${SET_80_81}                            0x0000000C
${SET_80_94}                            0x00010004
${SET_80_81_94}                         0x0001000C


*** Keywords ***
Start Script
    Execute Command                     mach create
    Execute Command                     machine LoadPlatformDescription @platforms/cpus/zynqmp.repl
    Execute Command                     s
    # Create a loop between GPIO 80 and GPIO 81. 
    # Changing GPIO 80 should modify GPIO 81 and generate interrupt requests if conditions are fulfilled.
    Execute Command                     machine LoadPlatformDescriptionFromString "gpio: { 80 -> gpio@81 }" 
    Start Emulation   


*** Test Cases ***
Inputs / Outputs Correct
    Start Script
    Execute Command                     gpio WriteDoubleWord ${DirectionMode3_OFFSET} 0x00010004        # Configure 80 and 94 as output, all others as input
    ${val}=  Execute Command            gpio ReadDoubleWord ${Data_RO3_OFFSET}
    Should Be Equal As Integers         ${val}  0x00000000                                              # At reset, all GPIO should read as 0
    ${val}=  Execute Command            gpio ReadDoubleWord ${Data3_OFFSET}
    Should Be Equal As Integers         ${val}  0x00000000                              

    Execute Command                     gpio WriteDoubleWord ${Data3_OFFSET} ${SET_81}                  # Try to raise GPIO 81                              
    ${val}=  Execute Command            gpio ReadDoubleWord ${DataRO3_OFFSET}
    Should Be Equal As Integers         ${val}  0x00000000                                              # Write on input GPIO has no effect on the state of registers

    Execute Command                     gpio WriteDoubleWord ${Data3_OFFSET} ${SET_80}                  # Try to raise GPIO 80
    ${val}=  Execute Command            gpio ReadDoubleWord ${Data_RO3_OFFSET}
    Should Be Equal As Integers         ${val}  0x00000000                                              # Output not visible if OEN is disabled
    Execute Command                     gpio WriteDoubleWord ${OutputEnable3_OFFSET} ${SET_80_94}       # Enable output for registers 80 and 94
    ${val}=  Execute Command            gpio ReadDoubleWord ${Data_RO3_OFFSET}
    Should Be Equal As Integers         ${val}  ${SET_80_81}                                            # Output visible since OEN is disabled & 81 has been updated in consequence
    ${val}=  Execute Command            gpio ReadDoubleWord ${Data3_OFFSET}
    Should Be Equal As Integers         ${val}  ${SET_80}                                               # Value on output pins isn't necessarily value written to those pins

    Execute Command                     gpio WriteDoubleWord ${MaskableOutputData3Hi_OFFSET} 0x0001     # Write 1 for pin 94
    ${val}=  Execute Command            gpio ReadDoubleWord ${Data_RO3_OFFSET}
    Should Be Equal As Integers         ${val}  ${SET_80_81_94}                                         # Did not overwrite pin 80/81
    ${val}=  Execute Command            gpio ReadDoubleWord ${Data3_OFFSET}
    Should Be Equal As Integers         ${val}  ${SET_80_94}                                            # Did not overwrite pin 80/81
    # TODO - When testing this with another processor (e.g. Zynq7000), test that writes to banks 4-5 are not possible and reads return 0

Should Mask And Unmask As Intended
    Start Script

    Execute Command                     gpio WriteDoubleWord ${IntDisable3_OFFSET} 0xFFFFFFFF           # Mask all for bank 3
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntMask3_OFFSET}                          # Read mask register after this write
    Should Be Equal As Integers         ${val}  0xFFFFFFFF                                              # All interrupts masked

    Execute Command                     gpio WriteDoubleWord ${IntEnable3_OFFSET} ${SET_80}             # Unmask interrupt 80
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntMask3_OFFSET}                          # Read mask register after this write
    Should Be Equal As Integers         ${val}  0xFFFFFFFB                                              # All but interrupt 80 are masked

    Execute Command                     gpio WriteDoubleWord ${IntDisable3_OFFSET} ${SET_80}            # Re-mask 80
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntMask3_OFFSET}                          # Read mask register after this write
    Should Be Equal As Integers         ${val}  0xFFFFFFFF                                              # 80 got masked again

Interrupts Correct
    Start Script
    Execute Command                     logLevel 3 
    Execute Command                     logLevel -1 gpio

    ${val}=  Execute Command            gpio ReadDoubleWord ${IntStatus3_OFFSET}
    Should Be Equal As Integers         ${val}  0
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_UNSET_STR}

    # Level low interrupt for pin 81
    Execute Command                     gpio WriteDoubleWord ${IntType3_OFFSET} 0
    Execute Command                     gpio WriteDoubleWord ${IntPolarity3_OFFSET} 0
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntStatus3_OFFSET}
    Should Be Equal As Integers         ${val}  0xFFFFFFFF                                              # Interrupt is raised even if there was no edge
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_UNSET_STR}                                       # Interrupt is still masked
    Execute Command                     gpio WriteDoubleWord ${IntEnable3_OFFSET} ${SET_81}
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_SET_STR}                                         # Interrupt is unmasked - IRQ is raised
    Execute Command                     gpio WriteDoubleWord ${IntStatus3_OFFSET} 0xFFFFFFFF            # Acknowledge
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntStatus3_OFFSET}
    Should Be Equal As Integers         ${val}  0xFFFFFFFF                                              # Interrupt is raised again since level is still low
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_SET_STR}    
    Execute Command                     gpio WriteDoubleWord ${IntDisable3_OFFSET} ${SET_81}            # Masking
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_SET_STR}                                         # Masking does not lower IRQ, only acknowledge does
    Execute Command                     gpio WriteDoubleWord ${IntStatus3_OFFSET} 0xFFFFFFFF            # Acknowledge
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_UNSET_STR}                                       # Interrupt acknowledged now that IRQ is masked

    # Level high
    Execute Command                     gpio WriteDoubleWord ${IntType3_OFFSET} 0
    Execute Command                     gpio WriteDoubleWord ${IntPolarity3_OFFSET} 0xFFFFFFFF          # It's just easier to switch all lines to Level high for testing further
    Execute Command                     gpio WriteDoubleWord ${IntStatus3_OFFSET} 0xFFFFFFFF            # Acknowledge all previous "level low" IRQs
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntStatus3_OFFSET}
    Should Be Equal As Integers         ${val}  0                                                       # Interrupt conditions not met - no line is high currently
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_UNSET_STR}  
    Execute Command                     gpio WriteDoubleWord ${DirectionMode3_OFFSET} ${SET_81}         # Need the line to be output and OEN for writes to work
    Execute Command                     gpio WriteDoubleWord ${OutputEnable3_OFFSET} ${SET_81}          # Need the line to be output and OEN for writes to work
    Execute Command                     gpio WriteDoubleWord ${Data3_OFFSET} ${SET_81}
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntStatus3_OFFSET}
    Should Be Equal As Integers         ${val}  ${SET_81}                                               # Line is high -> Interrupt launched
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_UNSET_STR}                                       # Interrupt still masked
    Execute Command                     gpio WriteDoubleWord ${IntEnable3_OFFSET} ${SET_81}             # Unmask IRQ
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_SET_STR}                                         # Interrupt is unmasked - IRQ is raised
    Execute Command                     gpio WriteDoubleWord ${IntStatus3_OFFSET} ${SET_81}             # Acknowledge
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntStatus3_OFFSET}
    Should Be Equal As Integers         ${val}  ${SET_81}                                               # Interrupt is raised again since level is still low
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_SET_STR}    
    Execute Command                     gpio WriteDoubleWord ${IntDisable3_OFFSET} ${SET_81}            # Masking
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_SET_STR}                                         # Masking does not lower IRQ, only acknowledge does
    Execute Command                     gpio WriteDoubleWord ${IntStatus3_OFFSET} ${SET_81}             # Acknowledge
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_UNSET_STR}                                       # Interrupt acknowledged now that IRQ is masked

    # Both Edges
    Execute Command                     gpio WriteDoubleWord ${IntType3_OFFSET} ${SET_81}
    Execute Command                     gpio WriteDoubleWord ${IntAny3_OFFSET} ${SET_81}                
    Execute Command                     gpio WriteDoubleWord ${IntStatus3_OFFSET} ${SET_81}             # Ack previous interrupt

    Execute Command                     gpio WriteDoubleWord ${Data3_OFFSET} 0                          # Lower the line
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntStatus3_OFFSET}
    Should Be Equal As Integers         ${val}  ${SET_81}                                               # Interrupt was raised by falling edge
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_UNSET_STR}                                       # Interrupt is masked - no IRQ was raised
    Execute Command                     gpio WriteDoubleWord ${IntStatus3_OFFSET} ${SET_81}             # Acknowledge
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntStatus3_OFFSET}
    Should Be Equal As Integers         ${val}  0                                                       # No new interrupt because edge didn't happen
    
    Execute Command                     gpio WriteDoubleWord ${Data3_OFFSET} ${SET_81}                  # Raise the line
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntStatus3_OFFSET}
    Should Be Equal As Integers         ${val}  ${SET_81}                                               # Interrupt was raised by rising edge
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_UNSET_STR}                                       # Interrupt is masked - no IRQ was raised
    Execute Command                     gpio WriteDoubleWord ${IntStatus3_OFFSET} ${SET_81}             # Acknowledge
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntStatus3_OFFSET}
    Should Be Equal As Integers         ${val}  0                                                       # No new interrupt because edge didn't happen

    Execute Command                     gpio WriteDoubleWord ${IntPolarity3_OFFSET} 0xFFFFFFF7          # Changing polarity (on line 81 only) does not have an effect on both edges
    Execute Command                     gpio WriteDoubleWord ${IntEnable3_OFFSET} ${SET_81}             # Unmask IRQ
    Execute Command                     gpio WriteDoubleWord ${Data3_OFFSET} 0                          # Lower the line
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntStatus3_OFFSET}
    Should Be Equal As Integers         ${val}  ${SET_81}                                               # Interrupt was raised by falling edge
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_SET_STR}                                         # Interrupt is unmasked
    Execute Command                     gpio WriteDoubleWord ${IntStatus3_OFFSET} ${SET_81}             # Acknowledge
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntStatus3_OFFSET}
    Should Be Equal As Integers         ${val}  0                                                       # No new interrupt because edge didn't happen
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_UNSET_STR}                                  
    
    Execute Command                     gpio WriteDoubleWord ${Data3_OFFSET} ${SET_81}                  # Raise the line
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntStatus3_OFFSET}
    Should Be Equal As Integers         ${val}  ${SET_81}                                               # Interrupt was raised by rising edge
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_SET_STR}                                         # Interrupt is unmasked
    Execute Command                     gpio WriteDoubleWord ${IntStatus3_OFFSET} ${SET_81}             # Acknowledge
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntStatus3_OFFSET}
    Should Be Equal As Integers         ${val}  0                                                       # No new interrupt because edge didn't happen
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_UNSET_STR}                                  

    # Falling edge only
    Execute Command                     gpio WriteDoubleWord ${IntAny3_OFFSET} 0                        # Polarity is 0, Type is 1 already    

    Execute Command                     gpio WriteDoubleWord ${Data3_OFFSET} 0                          # Lower the line
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntStatus3_OFFSET}
    Should Be Equal As Integers         ${val}  ${SET_81}                                               # Interrupt was raised by falling edge
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_SET_STR}                                         # Interrupt is unmasked
    Execute Command                     gpio WriteDoubleWord ${IntStatus3_OFFSET} ${SET_81}             # Acknowledge
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntStatus3_OFFSET}
    Should Be Equal As Integers         ${val}  0                                                       # No new interrupt because edge didn't happen
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_UNSET_STR}                                  
    
    Execute Command                     gpio WriteDoubleWord ${Data3_OFFSET} ${SET_81}                  # Raise the line
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntStatus3_OFFSET}
    Should Be Equal As Integers         ${val}  0                                                       # No interrupt on rising edge
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_UNSET_STR}                                       # No interrupt

    # Rising edge only
    Execute Command                     gpio WriteDoubleWord ${IntPolarity3_OFFSET} 0xFFFFFFFF          # Type and Any are correct already
    Execute Command                     gpio WriteDoubleWord ${IntEnable3_OFFSET} 0                     # Mask IRQ, to test that no interrupt is emitted

    Execute Command                     gpio WriteDoubleWord ${Data3_OFFSET} 0                          # Lower the line
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntStatus3_OFFSET}
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntStatus3_OFFSET}
    Should Be Equal As Integers         ${val}  0                                                       # No interrupt on falling edge
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_UNSET_STR}   

    Execute Command                     gpio WriteDoubleWord ${Data3_OFFSET} ${SET_81}                  # Raise the line
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntStatus3_OFFSET}
    Should Be Equal As Integers         ${val}  ${SET_81}                                               # Interrupt was raised by rising edge
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_SET_STR}                                         # Interrupt is unmasked
    Execute Command                     gpio WriteDoubleWord ${IntStatus3_OFFSET} ${SET_81}             # Acknowledge   
    ${val}=  Execute Command            gpio ReadDoubleWord ${IntStatus3_OFFSET}
    Should Be Equal As Integers         ${val}  0                                                       # No new interrupt because edge didn't happen
    ${val}=  Execute Command            gpio IRQ
    Should Contain                      ${val}  ${GPIO_UNSET_STR}                                  
    
                            
