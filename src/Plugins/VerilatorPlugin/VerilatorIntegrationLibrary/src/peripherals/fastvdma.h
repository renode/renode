//
// Copyright (c) 2010-2021 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "../renode_bus.h"
#include "../buses/bus.h"

struct FASTVDMA : RenodeAgent
{
public:
    FASTVDMA(BaseBus* bus, uint8_t* irq_reader=nullptr, uint8_t* irq_writer=nullptr);
    void eval();
    uint8_t* irq_reader;
    uint8_t* irq_writer;
    uint8_t  prev_irq_reader;
    uint8_t  prev_irq_writer;
    const uint8_t writer_addr = 0;
    const uint8_t reader_addr = 1;
};
