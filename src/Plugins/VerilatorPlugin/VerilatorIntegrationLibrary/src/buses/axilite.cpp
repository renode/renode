//
// Copyright (c) 2010-2021 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "axilite.h"

void AxiLite::tick(bool countEnable, uint64_t steps = 1)
{
    for(uint64_t i = 0; i < steps; i++) {
        *clk = 1;
        evaluateModel();
        *clk = 0;
        evaluateModel();
    }

    if(countEnable) {
        tickCounter += steps;
    }
}

void AxiLite::timeoutTick(uint8_t *condition, int timeout = 20)
{
    do {
        tick(true);
        timeout--;
    }
    while(!*condition && timeout > 0);

    if(timeout <= 0) {
        throw "Operation timeout";
    }
}

void AxiLite::write(uint64_t addr, uint64_t value)
{
    *awvalid = 1;
    *awaddr = addr;

    timeoutTick(awready);

    tick(true);
    *awaddr = 0;
    *awvalid = 0;
    tick(true);
    *wvalid = 1;
    *wdata = value;

    timeoutTick(wready);

    tick(true);
    *wvalid = 0;
    *wdata = 0;
    tick(true);
    *bready = 1;

    timeoutTick(bvalid);

    tick(true);
    *bready = 0;
    tick(true);
}

uint64_t AxiLite::read(uint64_t addr)
{
    *araddr = addr;
    *arvalid = 1;

    timeoutTick(arready);

    tick(true);
    *rready = 1;
    *arvalid = 0;

    timeoutTick(rvalid);

    uint64_t result = *rdata; // we have to fetch data before transaction end
    tick(true);
    *rready = 0;
    tick(true);
    return result;
}

void AxiLite::reset()
{
    *rst = 1;
    tick(true, 2); // it's model feature to tick twice
    *rst = 0;
    tick(true);
}
