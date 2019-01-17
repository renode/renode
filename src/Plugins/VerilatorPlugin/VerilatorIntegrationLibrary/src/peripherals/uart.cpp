//
// Copyright (c) 2010-2019 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "uart.h"
#include <bitset>

UART::UART(BaseBus* bus, unsigned char* txd, unsigned char* rxd, unsigned int prescaler) : RenodeAgent(bus) {
    this->bus = bus;
    this->txd = txd;
    this->rxd = rxd;
    this->prescaler = prescaler;
}

void UART::readTxd() {
    std::bitset<8> buffer;
    bus->internalTick((prescaler*8)/2);
    bus->internalTick(prescaler*8);
    for(int i = 0; i < 8; i++) {
        buffer[i] = *txd;
        bus->internalTick(prescaler*8);
    }
    bus->internalTick(prescaler*8);
    send(Protocol(Protocol(txdRequest, 0, buffer.to_ulong())));
}

void UART::writeRxd(unsigned char value) {
    std::bitset<8> buffer(value);
    *rxd = 0;
    bus->internalTick(prescaler*8);
    for(int i = 7; i >= 0; i--) {
        *rxd = buffer[i];
        bus->internalTick(prescaler*8);
    }
    *rxd = 1;
    bus->internalTick(prescaler*8);
    send(Protocol(interrupt, 1, 0));
}

void UART::handleCustom(Protocol* message) {
    switch(message->actionId) {
        case rxdRequest:
            writeRxd(message->value);
            break;
    }
}

void UART::writeToBus(unsigned long addr, unsigned long value) {
    RenodeAgent::writeToBus(addr, value);
    if(addr == 4) {
        readTxd();
    }
}

