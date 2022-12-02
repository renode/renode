//
// Copyright (c) 2010-2022 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef AxiLite_H
#define AxiLite_H
#include "bus.h"
#include <src/renode_bus.h>

struct AxiLite : public BaseTargetBus
{
    virtual void write(int width, uint64_t addr, uint64_t value);
    virtual uint64_t read(int width, uint64_t addr);
    virtual void onResetAction();
    void handshake_src(uint8_t* ready, uint8_t* valid, uint64_t* channel, uint64_t value);

    void prePosedgeTick();
    void posedgeTick();
    void negedgeTick();
    void setClock(uint8_t value);
    void setReset(uint8_t value);

    uint8_t  *clk;
    uint8_t  *rst;
    uint8_t  *rxd;
    uint8_t  *txd;
    uint8_t  *awvalid;
    uint8_t  *awready;
    uint8_t  *awprot;
    uint8_t  *wstrb;
    uint8_t  *wvalid;
    uint8_t  *wready;
    uint8_t  *bresp;
    uint8_t  *bvalid;
    uint8_t  *bready;
    uint8_t  *arvalid;
    uint8_t  *arready;
    uint8_t  *arprot;
    uint8_t  *rresp;
    uint8_t  *rvalid;
    uint8_t  *rready;
    uint64_t *awaddr;
    uint64_t *wdata;
    uint64_t *araddr;
    uint64_t *rdata;

// Used to allow some of the tests to be executed
#ifdef INVERT_RESET
    uint8_t reset_active = 1;
#else 
    uint8_t reset_active = 0;
#endif
};
#endif
