//
// Copyright (c) 2010-2021 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "wishbone.h"
#include <cstdio>

void Wishbone::setClock(uint8_t value)
{
    *wb_clk = value;
}

void Wishbone::prePosedgeTick()
{
}

void Wishbone::posedgeTick()
{
}

void Wishbone::negedgeTick()
{
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

    this->agent->timeoutTick(wb_ack, 1);

    *wb_stb = 0;
    *wb_cyc = 0;
    *wb_we = 0;
    *wb_sel = 0;

    this->agent->timeoutTick(wb_ack, 0);
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

    this->agent->timeoutTick(wb_ack, 1);
    uint64_t result = *wb_rd_dat;

    *wb_cyc = 0;
    *wb_stb = 0;
    *wb_sel = 0;

    this->agent->timeoutTick(wb_ack, 0);

    return result;
}

void Wishbone::setReset(uint8_t value) {
    *wb_rst = value;
}

void Wishbone::onResetAction()
{
}
