//
// Copyright (c) 2010-2022 Antmicro
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

    if(addrWidth != 32)
        throw "Unsupported AXI address width";
}

Axi::Axi(uint32_t dataWidth, uint32_t addrWidth) : BaseAxi(dataWidth, addrWidth), BaseTargetBus(dataWidth, addrWidth)
{
}

void Axi::setClock(uint8_t value) {
    *aclk = value;
}

void Axi::prePosedgeTick()
{
}

void Axi::posedgeTick()
{
}

void Axi::negedgeTick()
{
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
        this->agent->timeoutTick(awready, 1);
    this->agent->tick(true, 1);
    *awvalid = 0;

    this->agent->log(0, "Axi write - W");

    *wvalid = 1;
    *wdata = value;
    *wstrb = (1 << width) - 1; // TODO: Byte selects
    *wlast = 1; // TODO: Variable write length

    if (*wready != 1)
        this->agent->timeoutTick(wready, 1);
    this->agent->tick(true, 1);
    *wvalid = 0;

    this->agent->log(0, "Axi write - B");

    *bready = 1;

    this->agent->timeoutTick(bvalid, 1);
    this->agent->tick(true, 1);
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
        this->agent->timeoutTick(arready, 1);
    this->agent->tick(true, 1);
    *arvalid = 0;

    this->agent->log(0, "Axi read - R");

    *rready = 1;

    this->agent->timeoutTick(rvalid, 1);
    result = *rdata;
    this->agent->tick(true, 1);
    *rready = 0;

    return result;
}

void Axi::setReset(uint8_t value) {
    *aresetn = value;
}

void Axi::onResetAction()
{
}
