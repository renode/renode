//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef Axi_H
#define Axi_H
#include "bus.h"
#include <src/renode_bus.h>

enum class AxiBurstType  {FIXED = 0, INCR = 1, WRAP = 2, RESERVED = 3};

struct BaseAxi : virtual public BaseBus
{
    bool areSignalsConnected();
    BaseAxi(uint32_t dataWidth, uint32_t addrWidth);

    uint32_t dataWidth;
    uint32_t addrWidth;

    // Global AXI Signals
    uint8_t  *aclk = nullptr;
    uint8_t  *aresetn = nullptr;

    // Write Address Channel Signals
    uint8_t  *awid = nullptr;
    uint32_t *awaddr = nullptr;
    uint8_t  *awlen = nullptr;
    uint8_t  *awsize = nullptr;
    uint8_t  *awburst = nullptr;
    uint8_t  *awlock = nullptr;
    uint8_t  *awcache = nullptr;
    uint8_t  *awprot = nullptr;
    uint8_t  *awqos = nullptr;
    uint8_t  *awregion = nullptr;
    uint8_t  *awuser = nullptr;
    uint8_t  *awvalid = nullptr;
    uint8_t  *awready = nullptr;

    // Write Data Channel Signals
    uint32_t *wdata = nullptr;
    uint8_t  *wstrb = nullptr;
    uint8_t  *wlast = nullptr;
    uint8_t  *wuser = nullptr;
    uint8_t  *wvalid = nullptr;
    uint8_t  *wready = nullptr;

    // Write Response Channel Signals
    uint8_t  *bid = nullptr;
    uint8_t  *bresp = nullptr;
    uint8_t  *buser = nullptr;
    uint8_t  *bvalid = nullptr;
    uint8_t  *bready = nullptr;

    // Read Address Channel Signals
    uint8_t  *arid = nullptr;
    uint32_t *araddr = nullptr;
    uint8_t  *arlen = nullptr;
    uint8_t  *arsize = nullptr;
    uint8_t  *arburst = nullptr;
    uint8_t  *arlock = nullptr;
    uint8_t  *arcache = nullptr;
    uint8_t  *arprot = nullptr;
    uint8_t  *arqos = nullptr;
    uint8_t  *arregion = nullptr;
    uint8_t  *aruser = nullptr;
    uint8_t  *arvalid = nullptr;
    uint8_t  *arready = nullptr;

    // Read Data Channel Signals
    uint8_t  *rid = nullptr;
    uint32_t *rdata = nullptr;
    uint8_t  *rresp = nullptr;
    uint8_t  *rlast = nullptr;
    uint8_t  *ruser = nullptr;
    uint8_t  *rvalid = nullptr;
    uint8_t  *rready = nullptr;
};

struct Axi : public BaseAxi, virtual public BaseTargetBus
{
    Axi(uint32_t dataWidth, uint32_t addrWidth);
    virtual void tick(bool countEnable, uint64_t steps);
    virtual void write(int width, uint64_t addr, uint64_t value);
    virtual uint64_t read(int width, uint64_t addr);
    virtual void reset();

    void timeoutTick(uint8_t *signal, uint8_t value, int timeout);
};
#endif
