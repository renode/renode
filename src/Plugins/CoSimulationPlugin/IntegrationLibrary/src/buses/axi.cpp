//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "axi.h"
#include <cmath>

BaseAxi::BaseAxi(uint32_t dataWidth, uint32_t addrWidth)
{
    if(dataWidth != 32)
        throw "Unsupported AXI data width";

    this->dataWidth = dataWidth;

    if(addrWidth != 32)
        throw "Unsupported AXI address width";

    this->addrWidth = addrWidth;
}

Axi::Axi(uint32_t dataWidth, uint32_t addrWidth) : BaseAxi(dataWidth, addrWidth)
{
}

void Axi::tick(bool countEnable, uint64_t steps = 1)
{
    for(uint64_t i = 0; i < steps; i++) {
        *aclk = 1;
        evaluateModel();
        *aclk = 0;
        evaluateModel();
    }

    if(countEnable) {
        tickCounter += steps;
    }
}

void Axi::timeoutTick(uint8_t *signal, uint8_t value, int timeout = DEFAULT_TIMEOUT)
{
    do {
        tick(true);
        timeout--;
    } while ((*signal != value) && timeout > 0);

    if (timeout == 0) {
        throw "Operation timeout";
    }
}

void Axi::write(int width, uint64_t addr, uint64_t value)
{
    *awlen   = 0; // TODO: Variable write length
    *awsize  = 2; // TODO: Variable write width
    *awburst = static_cast<uint8_t>(AxiBurstType::INCR);
    *awaddr  = addr;

    this->agent->log(0, "Axi write - AW");

    *awvalid = 1;
    if (*awready != 1)
        timeoutTick(awready, 1);
    tick(true);
    *awvalid = 0;

    this->agent->log(0, "Axi write - W");

    *wvalid = 1;
    *wdata = value;
    *wstrb = (1 << width) - 1; // TODO: Byte selects
    *wlast = 1; // TODO: Variable write length

    if (*wready != 1)
        timeoutTick(wready, 1);
    tick(true);
    *wvalid = 0;

    this->agent->log(0, "Axi write - B");

    *bready = 1;

    timeoutTick(bvalid, 1);
    tick(true);
    *bready = 0;
}

uint64_t Axi::read(int width, uint64_t addr)
{
    uint64_t result;

    *arvalid = 1;
    *arlen   = 0; // TODO: Variable read length
    *arsize  = 2; // TODO: Variable read width
    *arburst = static_cast<uint8_t>(AxiBurstType::INCR);
    *araddr  = addr;

    this->agent->log(0, "Axi read - AR");

    if (*arready != 1)
        timeoutTick(arready, 1);
    tick(true);
    *arvalid = 0;

    this->agent->log(0, "Axi read - R");

    *rready = 1;

    timeoutTick(rvalid, 1);
    result = *rdata;
    tick(true);
    *rready = 0;

    return result;
}

void Axi::reset()
{
    *aresetn = 1;
    tick(true);
    *aresetn = 0;
    tick(true);
}
