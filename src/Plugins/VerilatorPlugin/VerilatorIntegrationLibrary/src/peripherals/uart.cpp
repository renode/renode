//
// Copyright (c) 2010-2019 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "uart.h"
#include <bitset>

UART::UART(BaseBus* bus, unsigned char* txd, unsigned char* rxd, unsigned int prescaler, unsigned int tx_reg_addr, unsigned char* irq) : RenodeAgent(bus) {
    this->txd = txd;
    this->rxd = rxd;
    this->irq = irq;

    this->prescaler = prescaler;
    this->tx_reg_addr = tx_reg_addr;
    this->prev_irq = 0;

    // Set rxd line idle state
    *this->rxd = 1;
}

void UART::eval() {
    if (irq != nullptr) {
        if (*irq == 1 && prev_irq == 0) {
            senderSocketSend(Protocol(interrupt, 1, 1));
        }

        if (*irq == 0 && prev_irq == 1) {
            senderSocketSend(Protocol(interrupt, 1, 0));
        }
        prev_irq = *irq;
    }
}

void UART::Txd() {
    std::bitset<8> buffer;
    tick(true, (prescaler * 8) / 2);
    tick(true, prescaler * 8);
    for(int i = 0; i < 8; i++) {
        buffer[i] = *txd;
        tick(true, prescaler * 8);
    }
    tick(true, prescaler * 8);
    senderSocketSend(Protocol(Protocol(txdRequest, 0, buffer.to_ulong())));
}

void UART::Rxd(unsigned char value) {
    std::bitset<8> buffer(value);
    *rxd = 0;
    tick(true, prescaler * 8);
    for(int i = 0; i < 8; i++) {
        *rxd = buffer[i];
        tick(true, prescaler * 8);
    }
    *rxd = 1;
    tick(true, prescaler * 8);
}

void UART::handleCustomRequestType(Protocol* message) {
    switch(message->actionId) {
        case rxdRequest:
            Rxd(message->value);
            break;
    }
}

void UART::writeToBus(unsigned long addr, unsigned long value) {
    RenodeAgent::writeToBus(addr, value);
    if(addr == tx_reg_addr) {
        Txd();
    }
}
