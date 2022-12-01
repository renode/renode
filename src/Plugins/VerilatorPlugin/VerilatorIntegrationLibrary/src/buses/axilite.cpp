//
// Copyright (c) 2010-2022 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include <cstdio>
#include "axilite.h"

extern void updateTime();
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

void AxiLite::timeoutTick(uint8_t* signal, uint8_t expectedValue, int timeout = DEFAULT_TIMEOUT)
{
    while((*signal != expectedValue) && timeout > 0)
    {
        *clk = 1;
        evaluateModel();
        *clk = 0;
        evaluateModel();
        timeout--;
    }

    if(timeout == 0) {
        throw "Operation timeout";
    }
}

// VALID/READY handshake process (as a source)
void AxiLite::handshake_src(uint8_t* ready, uint8_t* valid, uint64_t* channel, uint64_t value)
{
    *channel = value;
    *valid = 1;
    if(*ready == 0) {
        timeoutTick(ready, 1);
    }
    // The transfer occurs in the cycle AFTER the one with both ready and valid set
    tick(true);

    // Clear the data and valid signal
    *valid = 0;
    *channel = 0;
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
    tick(true);


    // Wait for the write response
    *bready = 1;
    if(*bvalid != 1) {
        timeoutTick(bvalid, 1);
    }
    if(*bresp != 0) {
        char msg[200];
        snprintf(msg, 200, "Transaction failed while writing 0x%lX (%d bytes with strobe 0x%X) to 0x%lX - bresp equal to 0x%X",
            value, width, strobe, addr, *bresp);
        this->agent->log(LOG_LEVEL_ERROR, msg);
    }
    tick(true);
    *bready = 0;
    tick(true);
}

uint64_t AxiLite::read(int width, uint64_t addr)
{
    auto modulo = addr & (busWidth - 1);
    addr &= ~(busWidth - 1);

    // Set read address
    handshake_src(arready, arvalid, araddr, addr);

    // Read data
    *rready = 1;
    if(*rvalid != 1) {
        timeoutTick(rvalid, 1);
    } else {
        tick(true);
    }
    uint64_t result = *rdata; // we have to fetch data before transaction ends
    if(*rresp != 0) {
        char msg[200];
        snprintf(msg, 200, "Transaction failed while reading 0x%lX (%d bytes) from 0x%lX - rresp equal to 0x%X",
            result, width, addr, *bresp);
        this->agent->log(LOG_LEVEL_ERROR, msg);
    }
    *rready = 0;
    result >>= modulo * 8;
    tick(true);
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
    tick(true, 10);
}
