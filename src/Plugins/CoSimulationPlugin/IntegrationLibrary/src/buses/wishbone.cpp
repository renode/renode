//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "wishbone.h"
#include <cstdio>

void Wishbone::tick(bool countEnable, uint64_t steps = 1)
{
    for(uint32_t i = 0; i < steps; i++) {
        *wb_clk = 1;
        evaluateModel();
        *wb_clk = 0;
        evaluateModel();
    }

    if(countEnable) {
        tickCounter += steps;
    }
}

void Wishbone::timeoutTick(uint8_t *signal, uint8_t value, int timeout = DEFAULT_TIMEOUT)
{
    do {
        tick(true);
        timeout--;
    }
    while(*signal != value && timeout > 0);

// This additional tick prevents Wishbone controller from reacting instantly
// after the signal is set, as the change should be recognized after the next
// rising edge (`tick` function returns right before the rising edge). It's only
// an option because it may break communication with LiteX-generated IP cores.
#ifdef WISHBONE_EXTRA_WAIT_TICK
    tick(true);
#endif

    if(timeout == 0) {
        throw "Operation timeout";
    }
}

void Wishbone::write(int width, uint64_t addr, uint64_t value)
{
    if(width < granularity ) {
        char msg[] = "Unexpected write width %d"; // we sprintf to self, because width is never longer than 2 digits
        sprintf(msg, msg, width);
        throw msg;
    }
    *wb_we = 1;
    *wb_sel = (uint8_t)((1 << width) - 1);
    *wb_cyc = 1;
    *wb_stb = 1;

    *wb_addr = (addr >> (32 - addr_lines));
    *wb_wr_dat = value;

    timeoutTick(wb_ack, 1);

    *wb_stb = 0;
    *wb_cyc = 0;
    *wb_we = 0;
    *wb_sel = 0;

    timeoutTick(wb_ack, 0);
}

uint64_t Wishbone::read(int width, uint64_t addr)
{
    if(width < granularity) {
        char msg[] = "Unexpected read width %d"; // we sprintf to self, because width is never longer than 2 digits
        sprintf(msg, msg, width);
        throw msg;
    }
    *wb_we = 0;
    *wb_sel = (uint8_t)((1 << width) - 1);
    *wb_cyc = 1;
    *wb_stb = 1;
    *wb_addr = (addr >> (32 - addr_lines));

    timeoutTick(wb_ack, 1);
    uint64_t result = *wb_rd_dat;

    *wb_cyc = 0;
    *wb_stb = 0;
    *wb_sel = 0;

    timeoutTick(wb_ack, 0);

    return result;
}

void Wishbone::reset()
{
    *wb_rst = 1;
    tick(true);
    *wb_rst = 0;
    tick(true);
}
