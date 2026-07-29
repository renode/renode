*** Variables ***
${MCR_OFFSET}                 0x0
${TCR_OFFSET}                 0x8
${CTAR0_OFFSET}               0xC
${CTAR1_OFFSET}               0x10
${CTAR2_OFFSET}               0x14
${CTAR3_OFFSET}               0x18
${SR_OFFSET}                  0x2C
${RSER_OFFSET}                0x30
${PUSHR_OFFSET}               0x34
${PUSHR_DATA_OFFSET}          0x36
${POPR_OFFSET}                0x38
${TXFR0_OFFSET}               0x3C
${TXFR1_OFFSET}               0x40
${TXFR2_OFFSET}               0x44
${TXFR3_OFFSET}               0x48
${TXFR4_OFFSET}               0x4C
${TXFR5_OFFSET}               0x50
${TXFR6_OFFSET}               0x54
${TXFR7_OFFSET}               0x58
${TXFR8_OFFSET}               0x5C
${TXFR9_OFFSET}               0x60
${TXFR10_OFFSET}              0x64
${TXFR11_OFFSET}              0x68
${TXFR12_OFFSET}              0x6C
${TXFR13_OFFSET}              0x70
${TXFR14_OFFSET}              0x74
${TXFR15_OFFSET}              0x78
${RXFR0_OFFSET}               0x7C
${RXFR1_OFFSET}               0x80
${RXFR2_OFFSET}               0x84
${RXFR3_OFFSET}               0x88
${RXFR4_OFFSET}               0x8C
${RXFR5_OFFSET}               0x90
${RXFR6_OFFSET}               0x94
${RXFR7_OFFSET}               0x98
${RXFR8_OFFSET}               0x9C
${RXFR9_OFFSET}               0xA0
${RXFR10_OFFSET}              0xA4
${RXFR11_OFFSET}              0xA8
${RXFR12_OFFSET}              0xAC
${RXFR13_OFFSET}              0xB0
${RXFR14_OFFSET}              0xB4
${RXFR15_OFFSET}              0xB8
${CTARE0_OFFSET}              0x11C
${CTARE0_OFFSET}              0x120
${CTARE0_OFFSET}              0x124
${CTARE0_OFFSET}              0x128
${SREX_OFFSET}                0x13C

*** Keywords ***
Start Script
    Execute Command                     include @tests/platforms/NXP_LS1043A_SPI_Slave.cs
    Execute Command                     include @platforms/cpus/ls1043a.repl
    Execute Command                     machine LoadPlatformDescriptionFromString "spiSlave: SPI.NXP_LS1043A_SPI_Slave @ dspi0 0"
    Start Emulation      

Get And Strip SR Register
    ${reg}=  Execute Command            dspi0 ReadDoubleWord ${SR_OFFSET}
    ${reg_2}=  Convert To Integer       ${reg}
    RETURN  ${reg_2}

Get TXFIFO Count
    ${reg}=  Get And Strip SR Register
    ${count}=  Evaluate                 ($reg >> 12) & 0xF
    RETURN  ${count}

Get TXFIFO Pointer
    ${reg}=  Get And Strip SR Register
    ${ptr}=    Evaluate                 ($reg >> 8) & 0xF
    RETURN  ${ptr}

Get CMDFIFO Count
    ${reg}=  Execute Command            dspi0 ReadDoubleWord ${SREX_OFFSET}
    ${reg_2}=  Convert To Integer       ${reg}
    ${count}=  Evaluate                 ($reg_2 >> 4) & 0x1F
    RETURN  ${count}

Get CMDFIFO Pointer
    ${reg}=  Execute Command            dspi0 ReadDoubleWord ${SREX_OFFSET}
    ${reg_2}=  Convert To Integer       ${reg}
    ${ptr}=    Evaluate                 $reg_2 & 0xF
    RETURN  ${ptr}

Get RXFIFO Count
    ${reg}=  Get And Strip SR Register
    ${count}=  Evaluate                 ($reg >> 4) & 0xF
    RETURN  ${count}

Get RXFIFO Pointer
    ${reg}=  Get And Strip SR Register
    ${ptr}=    Evaluate                 ($reg >> 0) & 0xF
    RETURN  ${ptr}

Get TCR Value
    ${reg}=  Execute Command            dspi0 ReadDoubleWord ${TCR_OFFSET}
    ${reg_2}=  Convert To Integer       ${reg}
    ${reg}=    Evaluate                 ($reg_2 >> 16) & 0xFF
    RETURN  ${reg}

Get SR_TCF  
    ${reg}=  Get And Strip SR Register
    ${flag}=  Evaluate                   ($reg >> 31) & 0x1
    RETURN  ${flag}

Get SR_TXRXF
    ${reg}=  Get And Strip SR Register
    ${flag}=  Evaluate                   ($reg >> 30) & 0x1
    RETURN  ${flag}

Get SR_EOQF
    ${reg}=  Get And Strip SR Register
    ${flag}=  Evaluate                   ($reg >> 28) & 0x1
    RETURN  ${flag}

Get SR_TFFF
    ${reg}=  Get And Strip SR Register
    ${flag}=  Evaluate                   ($reg >> 25) & 0x1
    RETURN  ${flag}

Get SR_BSYF
    ${reg}=  Get And Strip SR Register
    ${flag}=  Evaluate                   ($reg >> 24) & 0x1
    RETURN  ${flag}

Get SR_CMDTCF
    ${reg}=  Get And Strip SR Register
    ${flag}=  Evaluate                   ($reg >> 23) & 0x1
    RETURN  ${flag}

Get SR_RFOF
    ${reg}=  Get And Strip SR Register
    ${flag}=  Evaluate                   ($reg >> 19) & 0x1
    RETURN  ${flag}

Get SR_TFIWF
    ${reg}=  Get And Strip SR Register
    ${flag}=  Evaluate                   ($reg >> 18) & 0x1
    RETURN  ${flag}

Get SR_RFDF
    ${reg}=  Get And Strip SR Register
    ${flag}=  Evaluate                   ($reg >> 17) & 0x1
    RETURN  ${flag}

Get SR_CMDFFF
    ${reg}=  Get And Strip SR Register
    ${flag}=  Evaluate                   ($reg >> 16) & 0x1
    RETURN  ${flag}


*** Test Cases ***
Disabled TX FIFO test 
    Start Script
    Execute Command                     dspi0 WriteDoubleWord ${MCR_OFFSET} 0x80012C00  # Disable TX FIFO, Clear FIFO, unhalt, master mode, pscis 0
    Execute Command                     dspi0 WriteDoubleWord ${CTAR0_OFFSET} 0x78000000  #Set frame size to 16
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C016163  #End of queue, clear counter, transmits "ac"
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C016264  #End of queue, clear counter, transmits "bd"
    ${value}=  Execute Command          dspi0 ReadDoubleWord ${TXFR0_OFFSET}
    Should Be Equal As Integers         ${value}  0  # The pushed value should not have been pushed since TX FIFO is disabled
    ${value}=  Execute Command          dspi0 ReadDoubleWord ${RXFR0_OFFSET}
    Should Be Equal As Integers         ${value}  0x6264  # The received data should have been pushed
    ${value}=  Execute Command          dspi0 ReadDoubleWord ${RXFR1_OFFSET}
    Should Be Equal As Integers         ${value}  0x6365  # The received data should have been pushed
    ${value}=  Get RXFIFO Count        
    Should Be Equal As Integers         ${value}  2
    ${value}=  Execute Command          dspi0 ReadDoubleWord ${POPR_OFFSET}
    Should Be Equal As Integers         ${value}  0x6264  # The pushed value should not have been pushed since TX FIFO is disabled
    ${value}=  Get RXFIFO Count        
    Should Be Equal As Integers         ${value}  1
    ${value}=  Get RXFIFO Pointer        
    Should Be Equal As Integers         ${value}  1       # The next value to read should be in FIFO entry 1

Disabled RX FIFO test  
    Start Script
    Execute Command                     dspi0 WriteDoubleWord ${MCR_OFFSET} 0x80011C00    #Disable RX FIFO, Clear FIFO, unhalt, master mode, pscis 0
    Execute Command                     dspi0 WriteDoubleWord ${CTAR0_OFFSET} 0x78000000  #Set frame size to 16
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C016163  #End of queue, clear counter, transmits "ac"
       
    ${value}=  Execute Command          dspi0 ReadDoubleWord ${TXFR0_OFFSET}
    Should Be Equal As Integers         ${value}  0x0C016163  # The pushed value should have been pushed since TX FIFO is enabled
    ${value}=  Get TXFIFO Pointer        
    Should Be Equal As Integers         ${value}  1
    ${value}=  Execute Command          dspi0 ReadDoubleWord ${RXFR0_OFFSET}
    Should Be Equal As Integers         ${value}  0  # The received value should not have been stored since RX FIFO is disabled
    ${value}=  Get RXFIFO Count        
    Should Be Equal As Integers         ${value}  1

    # Without overflow test
    ${value}=  Get SR_RFOF
    Should Be Equal As Integers         ${value}  0  # No overflow yet
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C016365  #End of queue, clear counter, transmits "ce"
    ${value}=  Get SR_RFOF
    Should Be Equal As Integers         ${value}  1  # There has been an overflow
    Execute Command                     dspi0 WriteDoubleWord ${SR_OFFSET} 0x00080000  # Clear RFOF
    ${value}=  Get SR_RFOF
    Should Be Equal As Integers         ${value}  0  # RFOF has been cleared
    ${value}=  Get RXFIFO Count 
    Should Be Equal As Integers         ${value}  1
    ${value}=  Execute Command          dspi0 ReadDoubleWord ${POPR_OFFSET}
    Should Be Equal As Integers         ${value}  0x6264  # No overwrite : the old value was preserved
    ${value}=  Get RXFIFO Count       
    Should Be Equal As Integers         ${value}  0

    # With overflow test + interrupt
    Execute Command                     dspi0 WriteDoubleWord ${RSER_OFFSET} 0x00080000   # Allows interrupts for RFOF
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: unset  # Assert there is currently no IRQ
    Execute Command                     dspi0 WriteDoubleWord ${MCR_OFFSET} 0x81011C00    # Enable overflow, Disable RX FIFO, Clear FIFO, unhalt, master mode, pscis 0
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C016163  #End of queue, clear counter, transmits "ce"
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C016365  #End of queue, clear counter, transmits "ce"
    ${value}=  Get SR_RFOF
    Should Be Equal As Integers         ${value}  1  # There has been an Overflow
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: set  # Check interrupt is up for RFOF
    ${value}=  Get RXFIFO Count        
    Should Be Equal As Integers         ${value}  1  # Overflow should not have an effect on number of elems
    ${value}=  Execute Command          dspi0 ReadDoubleWord ${POPR_OFFSET}
    Should Be Equal As Integers         ${value}  0x6466  # Overwrite : the old value was erased, and we get the new one instead
    ${value}=  Get RXFIFO Count       
    Should Be Equal As Integers         ${value}  0

FIFO Clear / Fill And TCR Counter Test 
    Start Script
    Execute Command                     dspi0 WriteDoubleWord ${MCR_OFFSET} 0x80010C00    #Clear FIFO, unhalt, master mode, pscis 0
    Execute Command                     dspi0 WriteDoubleWord ${CTAR0_OFFSET} 0x38000000  #Set frame size to 8
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C010061  #End of queue, clear counter, transmits "a"
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x08010062  #End of queue, clear counter, transmits "b"
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x08010063  #End of queue, clear counter, transmits "c"
    ${value}=  Get TCR Value        
    Should Be Equal As Integers         ${value}  3
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C010064  #End of queue, clear counter, transmits "d"
    ${value}=  Get TCR Value        
    Should Be Equal As Integers         ${value}  1
    ${value}=  Execute Command          dspi0 ReadDoubleWord ${TXFR0_OFFSET}
    Should Be Equal As Integers         ${value}  0x0C010061
    ${value}=  Execute Command          dspi0 ReadDoubleWord ${TXFR1_OFFSET}
    Should Be Equal As Integers         ${value}  0x08010062
    ${value}=  Execute Command          dspi0 ReadDoubleWord ${TXFR2_OFFSET}
    Should Be Equal As Integers         ${value}  0x08010063
    ${value}=  Execute Command          dspi0 ReadDoubleWord ${TXFR3_OFFSET}
    Should Be Equal As Integers         ${value}  0x0C010064
    # TX FIFO is 0 since all data is immediately shifted out
    ${value}=  Get TXFIFO Pointer 
    Should Be Equal As Integers         ${value}  4
    ${value}=  Execute Command          dspi0 ReadDoubleWord ${RXFR0_OFFSET}
    Should Be Equal As Integers         ${value}  0x62
    ${value}=  Execute Command          dspi0 ReadDoubleWord ${RXFR1_OFFSET}
    Should Be Equal As Integers         ${value}  0x63
    ${value}=  Execute Command          dspi0 ReadDoubleWord ${RXFR2_OFFSET}
    Should Be Equal As Integers         ${value}  0x64
    ${value}=  Execute Command          dspi0 ReadDoubleWord ${RXFR3_OFFSET}
    Should Be Equal As Integers         ${value}  0x65
    ${value}=  Get RXFIFO Count        
    Should Be Equal As Integers         ${value}  4
    ${value}=  Execute Command          dspi0 ReadDoubleWord ${POPR_OFFSET}
    Should Be Equal As Integers         ${value}  0x62  # The pushed value should not have been pushed since TX FIFO is disabled
    ${value}=  Get RXFIFO Count       
    Should Be Equal As Integers         ${value}  3
    ${value}=  Get RXFIFO Pointer 
    Should Be Equal As Integers         ${value}  1

    # Clearing FIFOs and checking empty
    Execute Command                     dspi0 WriteDoubleWord ${MCR_OFFSET} 0x80010C00    #Clear FIFO, unhalt, master mode, pscis 0
    ${value}=  Get TXFIFO Count 
    Should Be Equal As Integers         ${value}  0
    ${value}=  Get TXFIFO Pointer        
    Should Be Equal As Integers         ${value}  0
    ${value}=  Get RXFIFO Count       
    Should Be Equal As Integers         ${value}  0
    ${value}=  Get RXFIFO Pointer        
    Should Be Equal As Integers         ${value}  0

Extended Mode Test
    Start Script
    Execute Command                     dspi0 WriteDoubleWord ${MCR_OFFSET} 0x80010C08  # Extended SPI, Clear FIFO, unhalt, master mode, pscis 0
    # Some SR & interrupts are only possible in Extended Spi mode:
    # CMDTCF is 0 when there is still 1 data to transfer with this command, it is 1 if all data has been transfered
    # TFIWF is 1 if we write data to data fifo while there is no command in the command fifo - w1c

    ${value}=  Get SR_TFIWF
    Should Be Equal As Integers         ${value}  0

    # Try to push data to DATA fifo when CMDFIFO is empty -> TWIWF triggered
    Execute Command                     dspi0 WriteWord ${PUSHR_DATA_OFFSET} 0x6162
    ${value}=  Get SR_TFIWF
    Should Be Equal As Integers         ${value}  1
    ${value}=  Get RXFIFO Count
    Should Be Equal As Integers         ${value}  0  # No transfer should have happened
    ${value}=  Get TXFIFO Count
    Should Be Equal As Integers         ${value}  0  # Data should have been discarded
    Execute Command                     dspi0 WriteDoubleWord ${SR_OFFSET} 0xFFFFFFFF  # Clear flag
    ${value}=  Get SR_TFIWF
    Should Be Equal As Integers         ${value}  0

    # Interrupt generation on TFIWF check
    Execute Command                     dspi0 WriteDoubleWord ${RSER_OFFSET} 0x00040000  # Enable TFIWF interrupts
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: unset  # Currently no interrupt
    Execute Command                     dspi0 WriteWord ${PUSHR_DATA_OFFSET} 0x6364
    ${value}=  Get SR_TFIWF
    Should Be Equal As Integers         ${value}  1
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: set  
    ${value}=  Get RXFIFO Count
    Should Be Equal As Integers         ${value}  0
    ${value}=  Get TXFIFO Count
    Should Be Equal As Integers         ${value}  0  # Data should have been discarded
    Execute Command                     dspi0 WriteDoubleWord ${SR_OFFSET} 0xFFFFFFFF
    ${value}=  Get SR_TFIWF
    Should Be Equal As Integers         ${value}  0  # Flag should have been cleared
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: unset  # Interrupt acknowledge
    Execute Command                     dspi0 WriteDoubleWord ${RSER_OFFSET} 0x00000000  # Disable all interrupts


    # CMD and DATA independance

    ## Push 2 cmd in the command FIFO
    Execute Command                     dspi0 WriteWord ${PUSHR_OFFSET} 0x0401  # First command without EOQ 
    Execute Command                     dspi0 WriteWord ${PUSHR_OFFSET} 0x0C01  # Second command with EOQ
    ${val}=  Get CMDFIFO Count
    Should Be Equal As Integers         ${val}  2

    Execute Command                     dspi0 WriteDoubleWord ${CTARE0_OFFSET} 2  # One command will be used for 2 transfers
    Execute Command                     dspi0 WriteWord ${PUSHR_DATA_OFFSET} 0x6566  # Pushing command word "ab"
    ${val}=  Execute Command            dspi0 ReadDoubleWord ${POPR_OFFSET}
    Should Be Equal As Integers         ${val}  0x6667
    ${val}=  Get SR_CMDTCF
    Should Be Equal As Integers         ${val}  0
    ${val}=  Get SR_EOQF
    Should Be Equal As Integers         ${val}  0

    Execute Command                     dspi0 WriteWord ${PUSHR_DATA_OFFSET} 0x6263  # Pushing command word "bc"
    ${val}=  Execute Command            dspi0 ReadDoubleWord ${POPR_OFFSET}
    Should Be Equal As Integers         ${val}  0x6364
    ${val}=  Get SR_CMDTCF
    Should Be Equal As Integers         ${val}  1  # Command has been used twice, which is what we specified
    ${val}=  Get SR_EOQF
    Should Be Equal As Integers         ${val}  0  # Command does not specify to set EOQF
    ${val}=  Get CMDFIFO Pointer
    Should Be Equal As Integers         ${val}  1  # Next command to be used is stored in the spot 1
    ${val}=  Get CMDFIFO Count
    Should Be Equal As Integers         ${val}  1  # Only 1 cmd left in fifo
    Execute Command                     dspi0 WriteDoubleWord ${SR_OFFSET} 0xFFFFFFFF  # Clear all flags


    # 2.6. Clear CMDTCF and Enable interrupts for CMDTCF 
    Execute Command                     dspi0 WriteDoubleWord ${RSER_OFFSET} 0x00800000  # Enable CMDTCF Interrupts
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: unset  # Currently no interrupt
    Execute Command                     dspi0 WriteDoubleWord ${CTARE0_OFFSET} 2  # One command will be used for 2 transfers

    Execute Command                     dspi0 WriteWord ${PUSHR_DATA_OFFSET} 0x7172  # Pushing command word "ab"
    ${val}=  Execute Command            dspi0 ReadDoubleWord ${POPR_OFFSET}
    Should Be Equal As Integers         ${val}  0x7273
    ${val}=  Get SR_CMDTCF
    Should Be Equal As Integers         ${val}  0  # We have yet to use the command a second time
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: unset  # Currently no interrupt
    ${val}=  Get SR_EOQF
    Should Be Equal As Integers         ${val}  1  # Command specify to set EOQF

    Execute Command                     dspi0 WriteWord ${PUSHR_DATA_OFFSET} 0x6263  # Pushing command word "bc"
    ${val}=  Execute Command            dspi0 ReadDoubleWord ${POPR_OFFSET}
    Should Be Equal As Integers         ${val}  0x6364
    ${val}=  Get SR_CMDTCF
    Should Be Equal As Integers         ${val}  1  # Command has been used twice
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: set  # Should have raised interrupt
    ${val}=  Get SR_EOQF
    Should Be Equal As Integers         ${val}  1  # Command specify to set EOQF
    ${val}=  Get CMDFIFO Pointer
    Should Be Equal As Integers         ${val}  2  # Next command to be used is stored in the spot 2
    ${val}=  Get CMDFIFO Count
    Should Be Equal As Integers         ${val}  0
    Execute Command                     dspi0 WriteDoubleWord ${SR_OFFSET} 0xFFFFFFFF  # Clear all flags
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: unset  # Currently no interrupt
    Execute Command                     dspi0 WriteDoubleWord ${RSER_OFFSET} 0x00000000  # Disable all interrupts


    # 32-bit transfers
    Execute Command                     dspi0 WriteDoubleWord ${MCR_OFFSET} 0x80010C08  # Extended SPI, Clear FIFO, unhalt, master mode, pscis 0
    ${val}=  Get RXFIFO Count                               # Assert we don't have anything in FIFO before launching test
    Should Be Equal As Integers         ${val}  0
    Execute Command                     dspi0 WriteDoubleWord ${CTARE0_OFFSET} 0x00010001  # 32 bit frames ; 1 data transfer per cmd
    Execute Command                     dspi0 WriteWord ${PUSHR_OFFSET} 0x0C01  # Command associated with this transfer
    Execute Command                     dspi0 WriteWord ${PUSHR_DATA_OFFSET} 0x6364  # Second part of the message - "cd" (since processor is little endian, it will push the end of the message before the beginning)
    ${val}=  Get SR_TCF
    Should Be Equal As Integers         ${val}  0  # No transfer should have happened since we only have half a message
    ${val}=  Get TXFIFO Count
    Should Be Equal As Integers         ${val}  1  # Data should still be sitting waiting fot the other half
    ${val}=  Get RXFIFO Count
    Should Be Equal As Integers         ${val}  0  # No data should have been received since none has been sent


    Execute Command                     dspi0 WriteWord ${PUSHR_DATA_OFFSET} 0x6162  # First part of the message - "ab"
    ${val}=  Get SR_TCF
    Should Be Equal As Integers         ${val}  1  # Now transfer has happened
    ${val}=  Get RXFIFO Count
    Should Be Equal As Integers         ${val}  1  # And we received 1 (and only 1) answer
    ${val}=  Execute Command            dspi0 ReadDoubleWord ${POPR_OFFSET}
    Should Be Equal As Integers         ${val}  0x62636465
    ${val}=  Get TXFIFO Pointer
    Should Be Equal As Integers         ${val}  2  # 32 bits transfer consumes 2 TX FIFO data
    ${val}=  Get RXFIFO Pointer
    Should Be Equal As Integers         ${val}  1  # But result is aggregated in a single RX FIFO entry

Check SR Register
    Start Script

    ## TXRXS
    ${val}=  Get SR_TXRXF
    Should Be Equal As Integers         ${val}  0  # Check TXRXS is 0 before launching module
    Execute Command                     dspi0 WriteDoubleWord ${MCR_OFFSET} 0x80010C00  # Clear FIFO, unhalt, master mode, pscis 0
    ${val}=  Get SR_TXRXF
    Should Be Equal As Integers         ${val}  1  # Check TXRXS is 1 now that module is lauched


    # TCF & RFDF & EOQF
    ${val}=  Get SR_TCF
    Should Be Equal As Integers         ${val}  0  # Check TCF is 0 before a transfer
    ${val}=  Get RXFIFO Count       
    Should Be Equal As Integers         ${val}  0
    ${val}=  Get SR_RFDF
    Should Be Equal As Integers         ${val}  0  # Check RFDF is 0 when RX FIFO is empty
    ${val}=  Get TXFIFO Count       
    Should Be Equal As Integers         ${val}  0
    ${val}=  Get SR_TFFF
    Should Be Equal As Integers         ${val}  1  # Since we do a send as soon as we can, TFFF should always be 1 (fifo not full)
    ${val}=  Get SR_CMDFFF
    Should Be Equal As Integers         ${val}  1  # CMDFFF should always be 1 (fifo not full) in non-extended mode & in emulation
    ${val}=  Get SR_EOQF
    Should Be Equal As Integers         ${val}  0  # Check EOQF is 0 when command does not specify EOQ
    ${val}=  Get SR_BSYF
    Should Be Equal As Integers         ${val}  0  # Busy flag is 0 when no transfer is ongoing
    ${val}=  Get SR_CMDTCF
    Should Be Equal As Integers         ${val}  0  # CMDTCF is 1 when data associated with command has been sent - nothing sent -> 0
    ${val}=  Get SR_TFIWF
    Should Be Equal As Integers         ${val}  0  # Invalid data write when no command in cmdfifo -> no data write = 0 on reset

    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x04016161  #End of queue, clear counter, transmits "aa"
    ${val}=  Get SR_TCF
    Should Be Equal As Integers         ${val}  1  # Check TCF is 1 after transfer
    ${val}=  Get SR_EOQF
    Should Be Equal As Integers         ${val}  0  # Check EOQF is 1 when command specifies EOQ
    ${val}=  Get RXFIFO Count       
    Should Be Equal As Integers         ${val}  1
    ${val}=  Get SR_RFDF
    Should Be Equal As Integers         ${val}  1  # Check RFDF is 1 when RX FIFO is not empty
    Execute Command                     dspi0 ReadDoubleWord ${POPR_OFFSET}
    ${val}=  Get RXFIFO Count       
    Should Be Equal As Integers         ${val}  0
    ${val}=  Get SR_RFDF
    Should Be Equal As Integers         ${val}  0  # Check RFDF is back to 0 when RX FIFO is read
    ${val}=  Get TXFIFO Count       
    Should Be Equal As Integers         ${val}  0
    ${val}=  Get SR_TFFF
    Should Be Equal As Integers         ${val}  1  # Since we do a send as soon as we can, TFFF should always be 1 (fifo not full)
    ${val}=  Get SR_CMDFFF
    Should Be Equal As Integers         ${val}  1  # CMDFFF should always be 1 (fifo not full) in non-extended mode & in emulation
    ${val}=  Get SR_BSYF
    Should Be Equal As Integers         ${val}  0  # Busy flag is 0 when no transfer is ongoing - transfer is done here
    ${val}=  Get SR_CMDTCF
    Should Be Equal As Integers         ${val}  1  # CMDTCF is 1 when data associated with command has been sent
    ${val}=  Get SR_TFIWF
    Should Be Equal As Integers         ${val}  0  # Invalid data write when no command in cmdfifo -> only possible in extended mode
   
    # EOQF test, pt.2
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C016161  #End of queue, clear counter, transmits "aa"
    ${val}=  Get SR_EOQF
    Should Be Equal As Integers         ${val}  1  # Check EOQF is 1 when command specifies EOQ

    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: unset  # Check interrupt is down because not allowed
    # Reset w1c flags
    Execute Command                     dspi0 WriteDoubleWord ${SR_OFFSET} 0xFFFFFFFF  # Write will have no effect on non-w1c registers (they are read only)

Test Interrupt Conditions
    # Interrupts exists for TCF, CMDFFF, EOQF, TFFF, CMDTCF, RFOF, TFIWF, RFDF
    # CMDTCF and TFIWF are only possible in extended SPI mode ; 
    # TFFF and CMDFFF should always be up since data is sent ASAP - not possible to fill FIFOs
    # RFOF interrupt is tested in the RX FIFO disabled case and Overflow test case

    # Value of all IRQ allowed is 0xD28E0000
    Start Script
    Execute Command                     dspi0 WriteDoubleWord ${MCR_OFFSET} 0x80010C00  # Clear FIFO, unhalt, master mode, pscis 0

    # CMDFFF interrupt - should always be up
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: unset  # Currently no interrupt
    ${val}=  Get SR_CMDFFF
    Should Be Equal As Integers         ${val}  1  # CMDFFF should always be 1 (fifo not full) in non-extended mode & in emulation
    Execute Command                     dspi0 WriteDoubleWord ${RSER_OFFSET} 0x40000000  # CMDFFF interrupt allowed
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: set  # Check interrupt is up for CMDFFF
    Execute Command                     dspi0 WriteDoubleWord ${SR_OFFSET} 0x00010000  # Lowers IRQ
    Execute Command                     dspi0 WriteDoubleWord ${RSER_OFFSET} 0x00000000  # Mask all

    # TFFF interrupt - should always be up
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: unset  # Currently no interrupt
    ${val}=  Get SR_TFFF
    Should Be Equal As Integers         ${val}  1  # TFFF should always be 1 (fifo not full) in non-extended mode & in emulation
    Execute Command                     dspi0 WriteDoubleWord ${RSER_OFFSET} 0x02000000  # TFFF interrupt allowed
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: set  # Check interrupt is up for TFFF
    Execute Command                     dspi0 WriteDoubleWord ${SR_OFFSET} 0x02000000  # Lowers IRQ
    Execute Command                     dspi0 WriteDoubleWord ${RSER_OFFSET} 0x00000000  # Mask all

    # RFDF interrupt - need to test 1 transfer when RX FIFO is empty, then full, then empty again
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: unset  # Currently no interrupt
    ${val}=  Get SR_RFDF
    Should Be Equal As Integers         ${val}  0  # Check RFDF is 0 when RX FIFO is empty
    Execute Command                     dspi0 WriteDoubleWord ${RSER_OFFSET} 0x00020000  # RFDF interrupt allowed
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x04016161  #End of queue, clear counter, transmits "aa"
    ${val}=  Get SR_RFDF
    Should Be Equal As Integers         ${val}  1  # Check RFDF is 1 when RX FIFO is not empty
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: set  # Check interrupt is up for RFDF
    Execute Command                     dspi0 ReadDoubleWord ${POPR_OFFSET}
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: unset  # Currently no interrupt
    ${val}=  Get SR_RFDF
    Should Be Equal As Integers         ${val}  0  # Check RFDF is 0 when RX FIFO is empty
    Execute Command                     dspi0 WriteDoubleWord ${RSER_OFFSET} 0x00000000  # Mask all

    # TCF interrupt - need to test 1 transfer (w/o EOQ flag)
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: unset  # Currently no interrupt
    ${val}=  Get SR_TCF
    Should Be Equal As Integers         ${val}  1  # A transfer happened previously and has been completed
    Execute Command                     dspi0 WriteDoubleWord ${SR_OFFSET} 0x80000000  # Clear TCF interrupt
    ${val}=  Get SR_TCF
    Should Be Equal As Integers         ${val}  0
    Execute Command                     dspi0 WriteDoubleWord ${RSER_OFFSET} 0x80000000  # TCF interrupt allowed
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x04016161  #End of queue, clear counter, transmits "aa"
    ${val}=  Get SR_TCF
    Should Be Equal As Integers         ${val}  1  # Check TCF is 1 after transfer
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: set  # Check interrupt is up for TCF
    Execute Command                     dspi0 WriteDoubleWord ${SR_OFFSET} 0x80000000  # Clear TCF interrupt
    ${val}=  Get SR_TCF
    Should Be Equal As Integers         ${val}  0
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: unset  # Currently no interrupt
    Execute Command                     dspi0 WriteDoubleWord ${RSER_OFFSET} 0x00000000  # Mask all

    # EOQF interrupt - need to test 1 transfer (w/ EOQ flag)
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: unset  # Currently no interrupt
    ${val}=  Get SR_EOQF
    Should Be Equal As Integers         ${val}  0
    Execute Command                     dspi0 WriteDoubleWord ${RSER_OFFSET} 0x10000000  # EOQF interrupt allowed
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C016161  #End of queue, clear counter, transmits "aa"
    ${val}=  Get SR_EOQF
    Should Be Equal As Integers         ${val}  1  # Check EOQF is 1 when command specifies EOQ
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: set  # Check interrupt is up for EOQF
    Execute Command                     dspi0 WriteDoubleWord ${SR_OFFSET} 0x10000000  # Clear TCF interrupt
    ${val}=  Get SR_EOQF
    Should Be Equal As Integers         ${val}  0

RX FIFO Overflow Test
    Start Script
    Execute Command                     dspi0 WriteDoubleWord ${MCR_OFFSET} 0x80010C00  # RX Overwrite, Clear FIFO, unhalt, master mode, pscis 0
    Execute Command                     dspi0 WriteDoubleWord ${CTAR0_OFFSET} 0x38000000  #Set frame size to 8
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C010061  #End of queue, clear counter, transmits "a"
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C010062  #End of queue, clear counter, transmits "b"
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C010063  #End of queue, clear counter, transmits "c"
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C010064  #End of queue, clear counter, transmits "d"
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C010065  #End of queue, clear counter, transmits "e"
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C010066  #End of queue, clear counter, transmits "f"
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C010067  #End of queue, clear counter, transmits "h"
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C010068  #End of queue, clear counter, transmits "i"
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C010069  #End of queue, clear counter, transmits "j"
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C01006A  #End of queue, clear counter, transmits "k"
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C01006B  #End of queue, clear counter, transmits "l"
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C01006C  #End of queue, clear counter, transmits "m"
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C01006D  #End of queue, clear counter, transmits "n"
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C01006E  #End of queue, clear counter, transmits "o"
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C01006F  #End of queue, clear counter, transmits "p"
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C010070  #End of queue, clear counter, transmits "q"
    
    ${value}=  Execute Command          dspi0 ReadDoubleWord ${RXFR15_OFFSET}
    Should Be Equal As Integers         ${value}  0x71     # Expected current value

    ${value}=  Get SR_RFOF
    Should Be Equal As Integers         ${value}  0  # No overflow happened yet
    
    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C010080  #Pushing a value that should overflow
    ${value}=  Execute Command          dspi0 ReadDoubleWord ${RXFR15_OFFSET}
    Should Be Equal As Integers         ${value}  0x71     # Overflow disabled - value didn't change
    
    ${value}=  Get SR_RFOF
    Should Be Equal As Integers         ${value}  1  # There has been an overflow
    Execute Command                     dspi0 WriteDoubleWord ${SR_OFFSET} 0x00080000  # Clear RFOF
    ${value}=  Get SR_RFOF
    Should Be Equal As Integers         ${value}  0  # RFOF has been cleared


    # Now test overwrite 
    Execute Command                     dspi0 WriteDoubleWord ${RSER_OFFSET} 0x00080000   # Allows interrupts for RFOF
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: unset  # Assert there is currently no IRQ
    Execute Command                     dspi0 WriteDoubleWord ${MCR_OFFSET} 0x81010000  # RX Overwrite, Clear FIFO, unhalt, master mode, pscis 0

    Execute Command                     dspi0 WriteDoubleWord ${PUSHR_OFFSET} 0x0C010080  #Pushing a value that should overflow

    ${value}=  Get SR_RFOF
    Should Be Equal As Integers         ${value}  1  # There has been an overflow
    ${val}=  Execute Command            dspi0 IRQ
    Should Contain                      ${val}  GPIO: set  # Check interrupt is up for RFOF

    ${value}=  Execute Command          dspi0 ReadDoubleWord ${RXFR15_OFFSET}
    Should Be Equal As Integers         ${value}  0x81     # Overflow enabled - value changed
