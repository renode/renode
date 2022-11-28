//
// Copyright (c) 2010-2022 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "axilite.h"

extern void updateTime();
void AxiLite::tick(bool countEnable, uint64_t steps = 1)
{
    for(uint64_t i = 0; i < steps; i++) {
        *clk = 1;
        evaluateModel();
        updateTime();
        *clk = 0;
        evaluateModel();
        updateTime();
    }

    if(countEnable) {
        tickCounter += steps;
    }
}

void AxiLite::timeoutTick(uint8_t* signal, uint8_t expectedValue, int timeout = DEFAULT_TIMEOUT)
{
    do
    {
        tick(true);
        timeout--;
    }
    while((*signal != expectedValue) && timeout > 0);

    if(timeout == 0) {
        throw "Operation timeout";
    }
}

// VALID/READY handshake process (as a source)
void AxiLite::handshake_src(uint8_t* ready, uint8_t* valid, uint64_t* channel, uint64_t value)
{
    *channel = value;
    *valid = 1;
    tick(true);
    // Don't wait if `ready` signal has been set (READY before VALID handshake)
    if(*ready != 1)
    {
        timeoutTick(ready, 1);
    }

    // The transfer occurs in the cycle AFTER the one with both ready and valid set
    tick(true);

    // Clear the data and valid signal
    *channel = 0;
    *valid = 0;
    tick(true);
}

void AxiLite::write(int width, uint64_t addr, uint64_t value)
{
    auto modulo = addr & (busWidth - 1);
    auto strobe = ((1 << width) - 1) << modulo;
    value <<= modulo * 8;
    addr &= ~(busWidth - 1);

    // Set write address and data
    handshake_src(awready, awvalid, awaddr, addr);
    *wstrb = strobe;
    handshake_src(wready, wvalid, wdata, value);
    *wstrb = 0;


    // Wait for the write response
    *bready = 1;
    if(*bvalid != 1) {
        timeoutTick(bvalid, 1);
    }
    tick(true);
    *bready = 0;
}

uint64_t AxiLite::read(int width, uint64_t addr)
{
    auto modulo = addr & (busWidth - 1);
    addr &= ~(busWidth - 1);

    // Set read address
    handshake_src(arready, arvalid, araddr, addr);

    // Read data
    *rready = 1;
    if(*rvalid != 1)
    {
        timeoutTick(rvalid, 1);
    }
    uint64_t result = *rdata; // we have to fetch data before transaction ends
    tick(true);
    *rready = 0;
    result >>= modulo * 8;
    return result;
}

void AxiLite::reset()
{
    uint8_t reset_active = 0;

// This parameter provides compability with old verilator-renode-integration 
// samples that used previous reset implementation

#ifdef INVERT_RESET
    reset_active = 1;
#endif
    *rst = reset_active;
    tick(true, 2); // it's model feature to tick twice
    *rst = !reset_active;
    tick(true);
}
