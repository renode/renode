//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef Axi_H
#define Axi_H
#include "bus.h"
#include <src/renode_bus.h>

enum class AxiBurstType  {FIXED = 0, INCR = 1, WRAP = 2, RESERVED = 3};

struct BaseAxi
{
    BaseAxi(uint32_t dataWidth, uint32_t addrWidth);

    uint32_t dataWidth;
    uint32_t addrWidth;

    // Global AXI Signals
    uint8_t  *aclk;
    uint8_t  *aresetn;

    // Write Address Channel Signals
    uint8_t  *awid;
    uint32_t *awaddr;
    uint8_t  *awlen;
    uint8_t  *awsize;
    uint8_t  *awburst;
    uint8_t  *awlock;
    uint8_t  *awcache;
    uint8_t  *awprot;
    uint8_t  *awqos;
    uint8_t  *awregion;
    uint8_t  *awuser;
    uint8_t  *awvalid;
    uint8_t  *awready;

    // Write Data Channel Signals
    uint32_t *wdata;
    uint8_t  *wstrb;
    uint8_t  *wlast;
    uint8_t  *wuser;
    uint8_t  *wvalid;
    uint8_t  *wready;

    // Write Response Channel Signals
    uint8_t  *bid;
    uint8_t  *bresp;
    uint8_t  *buser;
    uint8_t  *bvalid;
    uint8_t  *bready;

    // Read Address Channel Signals
    uint8_t  *arid;
    uint32_t *araddr;
    uint8_t  *arlen;
    uint8_t  *arsize;
    uint8_t  *arburst;
    uint8_t  *arlock;
    uint8_t  *arcache;
    uint8_t  *arprot;
    uint8_t  *arqos;
    uint8_t  *arregion;
    uint8_t  *aruser;
    uint8_t  *arvalid;
    uint8_t  *arready;

    // Read Data Channel Signals
    uint8_t  *rid;
    uint32_t *rdata;
    uint8_t  *rresp;
    uint8_t  *rlast;
    uint8_t  *ruser;
    uint8_t  *rvalid;
    uint8_t  *rready;
};

struct Axi : public BaseAxi, public BaseTargetBus
{
    Axi(uint32_t dataWidth, uint32_t addrWidth);
    virtual void tick(bool countEnable, uint64_t steps);
    virtual void write(int width, uint64_t addr, uint64_t value);
    virtual uint64_t read(int width, uint64_t addr);
    virtual void reset();

    void timeoutTick(uint8_t *signal, uint8_t value, int timeout);
};
#endif
