//
// Copyright (c) 2010-2021 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef Wishbone_H
#define Wishbone_H
#include "bus.h"

struct Wishbone : public BaseBus
{
    virtual void tick(bool countEnable, uint64_t steps);
    virtual void write(uint64_t addr, uint64_t value);
    virtual uint64_t read(uint64_t addr);
    virtual void reset();
    void timeoutTick(bool condition, int timeout);

    uint8_t  *wb_clk;
    uint8_t  *wb_rst;
    uint64_t *wb_addr;
    uint64_t *wb_rd_dat;
    uint64_t *wb_wr_dat;
    uint8_t  *wb_we;
    uint8_t  *wb_sel;
    uint8_t  *wb_stb;
    uint8_t  *wb_ack;
    uint8_t  *wb_cyc;
};
#endif
