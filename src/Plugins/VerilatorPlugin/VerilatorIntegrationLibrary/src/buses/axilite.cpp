//
// Copyright (c) 2010-2019 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "axilite.h"

void AxiLite::tick(bool countEnable, unsigned long steps = 1)
{
    for(int i = 0; i < steps; i++) {
        *clk = 1;
        evaluateModel();
        *clk = 0;
        evaluateModel();
    }

    if(countEnable) {
        tickCounter += steps;
    }
}

void AxiLite::timeoutTick(bool condition, int timeout = 20)
{
    do {
        tick(true);
        timeout--;
    }
    while(condition && timeout > 0);

    if(timeout < 0) {
        throw "Operation timeout";
    }
}

void AxiLite::write(unsigned long addr, unsigned long value)
{
    int timeout;
    *awvalid = 1;
    *awaddr = addr;

    timeoutTick(*awready == 0);

    tick(true);
    *awaddr = 0;
    *awvalid = 0;
    tick(true);
    *wvalid = 1;
    *wdata = value;

    timeoutTick(*wready == 0);

    tick(true);
    *wvalid = 0;
    *wdata = 0;
    tick(true);
    *bready = 1;

    timeoutTick(*bvalid == 0);

    tick(true);
    *bready = 0;
    tick(true);
}

unsigned long AxiLite::read(unsigned long addr)
{
    int timeout;
    *araddr = addr;
    *arvalid = 1;

    timeoutTick(*arready == 0);

    tick(true);
    *rready = 1;
    *arvalid = 0;

    timeoutTick(*rvalid== 0);

    unsigned long result = *rdata; // we have to fetch data before transaction end
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