//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "uart.h"
#include <bitset>

UART::UART(BaseTargetBus* bus, uint8_t* txd, uint8_t* rxd, uint32_t prescaler, uint32_t tx_reg_addr, uint8_t* irq) : RenodeAgent(bus) {
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
            communicationChannel->sendSender(Protocol(interrupt, 1, 1));
        }

        if (*irq == 0 && prev_irq == 1) {
            communicationChannel->sendSender(Protocol(interrupt, 1, 0));
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
    communicationChannel->sendSender(Protocol(txdRequest, 0, buffer.to_ulong()));
}

void UART::Rxd(uint8_t value) {
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

void UART::writeToBus(int width, uint64_t addr, uint64_t value) {
    RenodeAgent::writeToBus(width, addr, value);
    if(addr == tx_reg_addr) {
        // We are waiting for low state on txd line, which indicates beginning of a transmission.
        // Invalid data can be read otherwise.
        timeoutTick(txd, 0);
        Txd();
    }
}
