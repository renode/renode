//
// Copyright (c) 2010-2021 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef Axi_H
#define Axi_H
#include "bus.h"
#include <src/renode.h>
#include <cstdint>

enum class AxiBurstType  {FIXED = 0, INCR = 1, WRAP = 2, RESERVED = 3};

struct Axi : public BaseBus
{
    Axi(unsigned int dataWidth, unsigned int addrWidth);
    virtual void tick(bool countEnable, unsigned long steps);
    virtual void write(unsigned long addr, unsigned long value);
    virtual unsigned long read(unsigned long addr);
    virtual void reset();

    void timeoutTick(unsigned char *signal, unsigned char value, int timeout = 20);

    void setAgent(RenodeAgent* agent);
    RenodeAgent* agent;

    unsigned int  dataWidth;
    unsigned int  addrWidth;

    // Global AXI Signals
    unsigned char *aclk;
    unsigned char *aresetn;

    // Write Address Channel Signals
    unsigned char *awid;
    uint32_t      *awaddr;
    uint8_t       *awlen;
    unsigned char *awsize;
    unsigned char *awburst;
    unsigned char *awlock;
    unsigned char *awcache;
    unsigned char *awprot;
    unsigned char *awqos;
    unsigned char *awregion;
    unsigned char *awuser;
    unsigned char *awvalid;
    unsigned char *awready;

    // Write Data Channel Signals
    uint32_t      *wdata;
    unsigned char *wstrb;
    unsigned char *wlast;
    unsigned char *wuser;
    unsigned char *wvalid;
    unsigned char *wready;

    // Write Response Channel Signals
    unsigned char *bid;
    unsigned char *bresp;
    unsigned char *buser;
    unsigned char *bvalid;
    unsigned char *bready;

    // Read Address Channel Signals
    unsigned char *arid;
    uint32_t      *araddr;
    uint8_t       *arlen;
    unsigned char *arsize;
    unsigned char *arburst;
    unsigned char *arlock;
    unsigned char *arcache;
    unsigned char *arprot;
    unsigned char *arqos;
    unsigned char *arregion;
    unsigned char *aruser;
    unsigned char *arvalid;
    unsigned char *arready;

    // Read Data Channel Signals
    unsigned char *rid;
    uint32_t      *rdata;
    unsigned char *rresp;
    unsigned char *rlast;
    unsigned char *ruser;
    unsigned char *rvalid;
    unsigned char *rready;
};
#endif
