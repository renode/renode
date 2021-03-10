//
// Copyright (c) 2010-2021 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "axi.h"
#include <src/renode.h>
#include <cmath>

Axi::Axi(unsigned int dataWidth, unsigned int addrWidth)
{
    if(dataWidth != 32)
        throw "Unsupported AXI data width";

    this->dataWidth = dataWidth;

    if(addrWidth != 32)
        throw "Unsupported AXI address width";

    this->addrWidth = addrWidth;
}

void Axi::setAgent(RenodeAgent* agent)
{
    this->agent = agent;
}

void Axi::tick(bool countEnable, unsigned long steps = 1)
{
    for(int i = 0; i < steps; i++) {
        *aclk = 1;
        evaluateModel();
        *aclk = 0;
        evaluateModel();
    }

    if(countEnable) {
        tickCounter += steps;
    }
}

void Axi::timeoutTick(unsigned char *signal, unsigned char value, int timeout)
{
    do {
        tick(true);
        timeout--;
    } while ((*signal != value) && timeout > 0);

    if (timeout == 0) {
        throw "Operation timeout";
    }
}

void Axi::write(unsigned long addr, unsigned long value)
{
    *awvalid = 1;
    *awlen   = 0; // TODO: Variable write length
    *awsize  = 2; // TODO: Variable write width
    *awburst = static_cast<unsigned char>(AxiBurstType::INCR);
    *awaddr  = addr;

    this->agent->log(0, std::string("Axi write - AW"));

    timeoutTick(awready, 1);
    tick(true);
    *awvalid = 0;
    tick(true);

    this->agent->log(0, std::string("Axi write - W"));

    *wvalid = 1;
    *wdata = value;
    *wstrb = 0xF; // TODO: Byte selects
    *wlast = 1; // TODO: Variable write length

    timeoutTick(wready, 1);
    tick(true);
    *wvalid = 0;
    tick(true);

    this->agent->log(0, std::string("Axi write - B"));

    *bready = 1;

    timeoutTick(bvalid, 1);
    tick(true);
    *bready = 0;
    tick(true);
}

unsigned long Axi::read(unsigned long addr)
{
    unsigned long result;

    *arvalid = 1;
    *arlen   = 0; // TODO: Variable read length
    *arsize  = 2; // TODO: Variable read width
    *arburst = static_cast<unsigned char>(AxiBurstType::INCR);
    *araddr  = addr;

    this->agent->log(0, std::string("Axi read - AR"));

    timeoutTick(arready, 1);
    tick(true);
    *arvalid = 0;
    tick(true);

    this->agent->log(0, std::string("Axi read - R"));

    *rready = 1;

    timeoutTick(rvalid, 1);
    tick(true);
    result = *rdata;
    *rready = 0;
    tick(true);

    return result;
}

void Axi::reset()
{
    *aresetn = 1;
    tick(true);
    *aresetn = 0;
    tick(true);
}
