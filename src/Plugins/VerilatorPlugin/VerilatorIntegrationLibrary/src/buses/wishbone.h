//
// Copyright (c) 2010-2020 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef Wishbone_H
#define Wishbone_H
#include "bus.h"

struct Wishbone : public BaseBus
{
    virtual void tick(bool countEnable, unsigned long steps);
    virtual void write(unsigned long addr, unsigned long value);
    virtual unsigned long read(unsigned long addr);
    virtual void reset();
    void timeoutTick(bool condition, int timeout);

    unsigned char *wb_clk;
    unsigned char *wb_rst;
    unsigned long *wb_addr;
    unsigned long *wb_rd_dat;
    unsigned long *wb_wr_dat;
    unsigned char *wb_we;
    unsigned char *wb_sel;
    unsigned char *wb_stb;
    unsigned char *wb_ack;
    unsigned char *wb_cyc;
};
#endif
