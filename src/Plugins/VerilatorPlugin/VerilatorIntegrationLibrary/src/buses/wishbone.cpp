//
// Copyright (c) 2010-2020 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "wishbone.h"

void Wishbone::tick(bool countEnable, unsigned long steps = 1)
{
    for(int i = 0; i < steps; i++) {
        *wb_clk = 1;
        evaluateModel();
        *wb_clk = 0;
        evaluateModel();
    }

    if(countEnable) {
        tickCounter += steps;
    }
}

void Wishbone::timeoutTick(bool condition, int timeout = 20)
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

void Wishbone::write(unsigned long addr, unsigned long value)
{
    int timeout;

    *wb_we = 1;
    *wb_sel = 0xF;
    *wb_cyc = 1;
    *wb_stb = 1;
//  According to Wishbone B4 spec when using 32 bit bus with byte granularity
//  we drop 2 youngest bits
    *wb_addr = addr >> 2;
    *wb_wr_dat = value;

    timeoutTick(*wb_ack == 1);
    tick(true);

    *wb_stb = 0;
    *wb_cyc = 0;
    *wb_we = 0;
    *wb_sel = 0;

    timeoutTick(*wb_ack == 0);
    tick(true);
}

unsigned long Wishbone::read(unsigned long addr)
{
    int timeout;

    *wb_we = 0;
    *wb_sel = 0xF;
    *wb_cyc = 1;
    *wb_stb = 1;
    *wb_addr = addr >> 2;

    timeoutTick(*wb_ack == 1);
    tick(true);
    unsigned long result = *wb_rd_dat;

    *wb_cyc = 0;
    *wb_stb = 0;
    *wb_sel = 0;

    timeoutTick(*wb_ack == 0);
    tick(true);

    return result;
}

void Wishbone::reset()
{
    *wb_rst = 1;
    tick(true);
    *wb_rst = 0;
    tick(true);
}
