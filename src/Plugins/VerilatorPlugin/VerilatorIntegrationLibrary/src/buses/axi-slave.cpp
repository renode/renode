//
// Copyright (c) 2010-2022 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "axi-slave.h"
#include <cmath>
#include <cinttypes>

AxiSlave::AxiSlave(uint32_t dataWidth, uint32_t addrWidth) : BaseAxi(dataWidth, addrWidth), BaseInitiatorBus(dataWidth, addrWidth)
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

void AxiSlave::setClock(uint8_t value) {
    *aclk = value;
}

void AxiSlave::prePosedgeTick()
{
    readHandler();
    writeHandler();
}

void AxiSlave::posedgeTick()
{
    updateSignals();
}

void AxiSlave::negedgeTick()
{
}
// Sample signals before rising edge in handlers

void AxiSlave::readWord(uint64_t addr, uint8_t sel = 0)
{
    sprintf(buffer, "Axi read from: 0x%" PRIX64, addr);
    this->agent->log(0, buffer);
    rdata_new = this->agent->requestFromAgent(addr, busWidth);
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
                readBurstType = static_cast<AxiBurstType>(*arburst);
                readAddr      = uint64_t((*araddr)/readNumBytes) * readNumBytes;

                rlast_new     = (readLen == 0);

                if(readAddr != *araddr)
                    throw "Unaligned transfers are not supported";

                if(readBurstType != AxiBurstType::INCR)
                    throw "Unsupported AXI read burst type";

                if(readNumBytes != int(dataWidth/8))
                    throw "Narrow bursts are not supported";

                this->agent->log(0, "Axi read start");

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
                    this->agent->log(0, "Axi read transfer completed");
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

void AxiSlave::writeWord(uint64_t addr, uint64_t data, uint8_t strb)
{
    sprintf(buffer, "Axi write to: 0x%" PRIX64 ", data: 0x%" PRIX64 "", addr, data);
    this->agent->log(0, buffer);
    this->agent->pushToAgent(writeAddr, *wdata, busWidth);
}

void AxiSlave::writeHandler()
{
    switch(writeState) {
        case AxiWriteState::AW:
            awready_new = 1;
            if(*awready == 1 && *awvalid == 1) {
                awready_new    = 0;

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

                this->agent->log(0, "Axi write start");
            }
            break;
        case AxiWriteState::W:
            wready_new = 1;
            if(*wready == 1 && *wvalid == 1) {
                writeWord(writeAddr, *wdata, *wstrb);
                if(*wlast) {
                    writeState = AxiWriteState::B;
                    wready_new = 0;
                } else {
                    writeAddr += int(dataWidth/8); // TODO: make data width configurable
                }
            }
            break;
        case AxiWriteState::B:
            bvalid_new = 1;
            if(*bready == 1 && *bvalid == 1) {
                bvalid_new = 0;
                writeState = AxiWriteState::AW;
                this->agent->log(0, "Axi write transfer completed");
            }
            break;
        default:
            writeState = AxiWriteState::AW;
            break;
    }
}
void AxiSlave::setReset(uint8_t value) {
    *aresetn = value;
}

void AxiSlave::onResetAction()
{
}

// You can't read/write using slave bus
void AxiSlave::write(uint64_t addr, uint64_t value)
{
    throw "Unsupported";
}

uint64_t AxiSlave::read(uint64_t addr)
{
    throw "Unsupported";
}
