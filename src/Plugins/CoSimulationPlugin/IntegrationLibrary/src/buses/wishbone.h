//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef Wishbone_H
#define Wishbone_H
#include "bus.h"

class WishboneBase
{
public:
    uint8_t  *wb_clk = nullptr;
    uint8_t  *wb_rst = nullptr;
    uint64_t *wb_addr = nullptr;
    uint64_t *wb_rd_dat = nullptr;
    uint64_t *wb_wr_dat = nullptr;
    uint8_t  *wb_we = nullptr;
    uint8_t  *wb_sel = nullptr;
    uint8_t  *wb_stb = nullptr;
    uint8_t  *wb_ack = nullptr;
    uint8_t  *wb_cyc = nullptr;
    uint8_t  *wb_stall = nullptr;
    uint8_t   granularity;
    uint8_t   addr_lines;
};

class Wishbone : public WishboneBase, public BaseTargetBus
{
public:
    Wishbone() { }
    virtual void tick(bool countEnable, uint64_t steps);
    virtual void write(int width, uint64_t addr, uint64_t value);
    virtual uint64_t read(int width, uint64_t addr);
    virtual void reset();
    bool areSignalsConnected();
    void timeoutTick(uint8_t *signal, uint8_t value, int timeout);
};
#endif
