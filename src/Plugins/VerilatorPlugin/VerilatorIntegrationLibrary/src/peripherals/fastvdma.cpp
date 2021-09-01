//
// Copyright (c) 2010-2021 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "fastvdma.h"
#include <bitset>

FASTVDMA::FASTVDMA(BaseBus* bus, uint8_t* irq_reader, uint8_t* irq_writer) : RenodeAgent(bus) {
    this->irq_reader = irq_reader;
    this->irq_writer = irq_writer;
    prev_irq_reader = 0;
    prev_irq_writer = 0;
}

void FASTVDMA::eval() {
    if (irq_reader != nullptr) {
        if (*irq_reader != prev_irq_reader)
            communicationChannel->sendSender(Protocol(interrupt, reader_addr, *irq_reader));
        prev_irq_reader = *irq_reader;
    }

    if (irq_writer != nullptr) {
        if (*irq_writer !=  prev_irq_writer)
            communicationChannel->sendSender(Protocol(interrupt, writer_addr, *irq_writer));
        prev_irq_writer = *irq_writer;
    }
}
