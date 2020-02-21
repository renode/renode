//
// Copyright (c) 2010-2019 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "uart.h"
#include <bitset>

const int trasmitRegisterAddress = 4;

UART::UART(BaseBus* bus, unsigned char* txd, unsigned char* rxd, unsigned int prescaler) : RenodeAgent(bus) {
    this->bus = bus;
    this->txd = txd;
    this->rxd = rxd;
    this->prescaler = prescaler;
}

void UART::Txd() {
    std::bitset<8> buffer;
    bus->tick(true, (prescaler * 8) / 2);
    bus->tick(true, prescaler * 8);
    for(int i = 0; i < 8; i++) {
        buffer[i] = *txd;
        bus->tick(true, prescaler * 8);
    }
    bus->tick(true, prescaler * 8);
    senderSocketSend(Protocol(Protocol(txdRequest, 0, buffer.to_ulong())));
}

void UART::Rxd(unsigned char value) {
    std::bitset<8> buffer(value);
    *rxd = 0;
    bus->tick(true, prescaler * 8);
    for(int i = 0; i < 8; i++) {
        *rxd = buffer[i];
        bus->tick(true, prescaler * 8);
    }
    *rxd = 1;
    bus->tick(true, prescaler * 8);
    senderSocketSend(Protocol(interrupt, 1, 0));
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
    if(addr == trasmitRegisterAddress) {
        Txd();
    }
}
