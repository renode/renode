//
// Copyright (c) 2010-2021 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "axi-slave.h"
#include <src/renode.h>
#include <cmath>

AxiSlave::AxiSlave(unsigned int dataWidth, unsigned int addrWidth) : Axi(dataWidth, addrWidth)
{
    writeState = AxiWriteState::AW;
    readState = AxiReadState::AR;

    arready_new = 0;
    rvalid_new = 0;
    rlast_new = 0;
    rdata_new = 0;

    awready_new = 0;
    wready_new = 0;
    bvalid_new = 0;
}

void AxiSlave::tick(bool countEnable, unsigned long steps = 1)
{
    for(int i = 0; i < steps; i++) {
        readHandler();
        writeHandler();
        *aclk = 1;
        evaluateModel();
        updateSignals();
        *aclk = 0;
        evaluateModel();
    }

    // Since we can run out of steps during an AXI transaction we must let
    // the AXI master know that we can't accept more data at the moment.
    // To do that we set all handshake signals to 0 and readHandler/writeHandler
    // will handle resuming the transaction once tick is called again.
    clearSignals();

    if(countEnable) {
        tickCounter += steps;
    }
}

// Clear signals when leaving tick

void AxiSlave::clearSignals()
{
    // Read
    *arready = arready_new = 0;
    *rvalid  = rvalid_new  = 0;
    *rdata   = rdata_new   = 0;
    // Write
    *awready = awready_new = 0;
    *wready  = wready_new  = 0;
    *bvalid  = bvalid_new  = 0;
}

// Update signals after rising edge

void AxiSlave::updateSignals()
{
    // Read
    *arready = arready_new;
    *rvalid  = rvalid_new;
    *rlast   = rlast_new;
    *rdata   = rdata_new;
    // Write
    *awready = awready_new;
    *wready  = wready_new;
    *bvalid  = bvalid_new;
}

// Sample signals before rising edge in handlers

void AxiSlave::readWord(uint64_t addr)
{
    sprintf(buffer, "Axi read from: 0x%X", addr);
    this->agent->log(0, buffer);
    rdata_new = this->agent->requestFromAgent(addr);
}

void AxiSlave::readHandler()
{
    switch(readState) {
        case AxiReadState::AR:
            arready_new = 1;
            if(*arready == 1 && *arvalid == 1) {
                arready_new   = 0;

                readLen       = *arlen;
                readNumBytes  = pow(2, *arsize);
                readState     = AxiReadState::R;
                readBurstType = static_cast<AxiBurstType>(*awburst);
                readAddr      = uint64_t((*araddr)/readNumBytes) * readNumBytes;

                rlast_new     = (readLen == 0);

                if(readAddr != *araddr)
                    throw "Unaligned transfers are not supported";

                if(readBurstType != AxiBurstType::INCR)
                    throw "Unsupported AXI read burst type";

                if(readNumBytes != int(dataWidth/8))
                    throw "Narrow bursts are not supported";

                this->agent->log(0, std::string("Axi read start"));

                readWord(readAddr);
            }
            break;
        case AxiReadState::R:
            rvalid_new = 1;

            if(*rready == 1 && *rvalid == 1) {
                if(readLen == 0) {
                    readState = AxiReadState::AR;
                    rvalid_new = 0;
                    rlast_new = 0;
                    this->agent->log(0, std::string("Axi read transfer completed"));
                } else {
                    readLen--;
                    readAddr += int(dataWidth/8); // TODO: make data width configurable
                    readWord(readAddr);
                    rlast_new = (readLen == 0);
                }
            }
            break;
        default:
            readState = AxiReadState::AR;
            break;
    }
}

void AxiSlave::writeWord(uint64_t addr, uint32_t data, uint8_t strb)
{
    sprintf(buffer, "Axi write to: 0x%X, data: 0x%X", addr, data);
    this->agent->log(0, buffer);
    this->agent->pushToAgent(writeAddr, *wdata);
}

void AxiSlave::writeHandler()
{
    switch(writeState) {
        case AxiWriteState::AW:
            awready_new = 1;
            if(*awready == 1 && *awvalid == 1) {
                awready_new    = 0;

                writeLen       = *awlen;
                writeNumBytes  = pow(2, *awsize);
                writeState     = AxiWriteState::W;
                writeBurstType = static_cast<AxiBurstType>(*awburst);
                writeAddr      = uint64_t((*awaddr)/writeNumBytes) * writeNumBytes;

                if(writeAddr != *awaddr)
                    throw "Unaligned transfers are not supported";

                if(writeBurstType != AxiBurstType::INCR)
                    throw "Unsupported AXI write burst type";

                if(writeNumBytes != int(dataWidth/8))
                    throw "Narrow bursts are not supported";

                this->agent->log(0, std::string("Axi write start"));
            }
            break;
        case AxiWriteState::W:
            wready_new = 1;
            if(*wready == 1 && *wvalid == 1) {
                writeWord(writeAddr, *wdata, *wstrb);
                if(writeLen == 0) {
                    writeState = AxiWriteState::B;
                    wready_new = 0;
                } else {
                    writeLen--;
                    writeAddr += int(dataWidth/8); // TODO: make data width configurable
                }
            }
            break;
        case AxiWriteState::B:
            bvalid_new = 1;
            if(*bready == 1 && *bvalid == 1) {
                bvalid_new = 0;
                writeState = AxiWriteState::AW;
                this->agent->log(0, std::string("Axi write transfer completed"));
            }
            break;
        default:
            writeState = AxiWriteState::AW;
            break;
    }
}

void AxiSlave::reset()
{
    *aresetn = 1;
    tick(true);
    *aresetn = 0;
    tick(true);
}

// You can't read/write using slave bus
void AxiSlave::write(unsigned long addr, unsigned long value)
{
    throw "Unsupported";
}

unsigned long AxiSlave::read(unsigned long addr)
{
    throw "Unsupported";
}
