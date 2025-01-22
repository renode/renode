//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef AxiLite_H
#define AxiLite_H
#include "bus.h"

struct AxiLite : public BaseTargetBus
{
    AxiLite() { }
    virtual void tick(bool countEnable, uint64_t steps);
    virtual void write(int width, uint64_t addr, uint64_t value);
    virtual uint64_t read(int width, uint64_t addr);
    virtual void reset();
    virtual bool areSignalsConnected();
    void handshake_src(uint8_t* ready, uint8_t* valid, uint64_t* channel, uint64_t value);
    void timeoutTick(uint8_t* signal, uint8_t expectedValue, int timeout);

    uint8_t  *clk = nullptr;
    uint8_t  *rst = nullptr;
    uint8_t  *rxd = nullptr;
    uint8_t  *txd = nullptr;
    uint8_t  *awvalid = nullptr;
    uint8_t  *awready = nullptr;
    uint8_t  *awprot = nullptr;
    uint8_t  *wstrb = nullptr;
    uint8_t  *wvalid = nullptr;
    uint8_t  *wready = nullptr;
    uint8_t  *bresp = nullptr;
    uint8_t  *bvalid = nullptr;
    uint8_t  *bready = nullptr;
    uint8_t  *arvalid = nullptr;
    uint8_t  *arready = nullptr;
    uint8_t  *arprot = nullptr;
    uint8_t  *rresp = nullptr;
    uint8_t  *rvalid = nullptr;
    uint8_t  *rready = nullptr;
    uint64_t *awaddr = nullptr;
    uint64_t *wdata = nullptr;
    uint64_t *araddr = nullptr;
    uint64_t *rdata = nullptr;
};
#endif
