//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "uart.h"
#include <bitset>

/*
Line Control Register: Bit 7
Divisor latch access bit. Enables access to the divisor latch registers during
read or write operation to address 0 and 1. 0: Disabled (default) 1: Enabled

When DLAB is 1, then the Transmit Register address gets used as the Divisor
Latch Low Register instead.
*/
#define LINE_CTRL_REG 0x0C
#define LCR_DIVISOR_LATCH_MASK 0x80

UART_16550::UART_16550(BaseTargetBus* bus, uint8_t* txd, uint8_t* rxd, uint32_t prescaler, uint32_t tx_reg_addr, uint8_t* irq) 
                        : UART(bus, txd, rxd, prescaler, tx_reg_addr, irq) {

    //Set the Line Control Latch bit to off by default
    this->latch = 0;
}

void UART_16550::writeToBus(int width, uint64_t addr, uint64_t value) {
    RenodeAgent::writeToBus(width, addr, value);
    if(LINE_CTRL_REG == addr)
    {
        if(value & LCR_DIVISOR_LATCH_MASK)
            this->latch = 1;
        else
            this->latch = 0;
    }

    if( (addr == tx_reg_addr) && (0 == this->latch) ) {
        // We are waiting for low state on txd line, which indicates beginning of a transmission.
        // Invalid data can be read otherwise.
        RenodeAgent::timeoutTick(txd, 0);
        UART::Txd();
    }
}
