//
// Copyright (c) 2010-2022 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

#include "axilite-initiator.h"
#include "../renode_bus.h"

AxiLiteInitiator::AxiLiteInitiator(uint32_t dataWidth, uint32_t addrWidth) : BaseInitiatorBus(dataWidth, addrWidth)
{
}

void AxiLiteInitiator::updateSignals()
{
    *arready = arready_new;
    *rvalid = rvalid_new;
    *rdata = rdata_new;

    *awready = awready_new;
    *wready = wready_new;
    *bvalid = bvalid_new;
}

void AxiLiteInitiator::setClock(uint8_t value) {
    *clk = value;
}

void AxiLiteInitiator::prePosedgeTick()
{
    readHandler();
    writeHandler();
}

void AxiLiteInitiator::posedgeTick()
{
    updateSignals();
}

void AxiLiteInitiator::negedgeTick()
{
}

void AxiLiteInitiator::readWord(uint64_t addr, uint8_t sel = 0)
{
    this->agent->log(0, "[AxiLiteInitiator] Read word from: %x", addr);
    rdata_new = this->agent->requestFromAgent(addr, busWidth);
}

bool isStrobeValid(uint8_t strobe)
{
    std::vector<int> valid_strobes = {0x1, 0x2, 0x3, 0x4, 0x8, 0xc, 0xf, 0x10, 0x20, 0x30, 0x40, 0x80, 0xc0, 0xf0, 0xff};

    for (const auto strb: valid_strobes)
        if (strobe == strb)
            return true;
    return false;
}

void AxiLiteInitiator::writeWord(uint64_t addr, uint64_t data, uint8_t strb)
{
    this->agent->log(0, "[AxiLiteInitiator] Write word: addr: %x data: %x strb: %d", addr, data, strb);

    if (!isStrobeValid(strb)) {
        //todo log error
        return;
    }
    // In case of a full write
    if (strb == ((1 << busWidth) - 1)) {
        this->agent->pushToAgent(addr, data, busWidth);
        return;
    }

    uint64_t bytes_to_write = __builtin_popcount(strb);

    uint64_t valid_data_mask = ((uint64_t)1 << (bytes_to_write * 8)) - 1;

    // Find the first set LSB of strb to calculate the valid data offset
    uint32_t data_shift = __builtin_ctz(strb);

    this->agent->pushToAgent(addr, (data >> data_shift) & valid_data_mask, bytes_to_write);

}

void AxiLiteInitiator::readHandler()
{
    switch (readState) {
    case AxiLiteReadState::AR:
        arready_new = 1;
        if (*arready == 1 && *arvalid == 1) {
            this->agent->log(0, "[AxiLiteInitiator] Read start");
            arready_new = 0;
            readWord(*araddr);
            readState = AxiLiteReadState::R;
        }
        break;

    case AxiLiteReadState::R:
        rvalid_new = 1;
        if (*rvalid == 1 && *rready == 1) {
            // rresp is always 0
            this->agent->log(0, "[AxiLiteInitiator] Read end");
            rvalid_new = 0;
            readState = AxiLiteReadState::AR;
        }
        break;

    default:
        readState = AxiLiteReadState::AR;
        break;
    }
}

void AxiLiteInitiator::writeHandler()
{
    switch (writeState) {
    case AxiLiteWriteState::AW:
        awready_new = 1;
        if (*awready == 1 && *awvalid == 1) {
            this->agent->log(0, "[AxiLiteInitiator] Write start");
            awready_new = 0;
            writeAddr = *awaddr;
            writeState = AxiLiteWriteState::W;
        }
        break;

    case AxiLiteWriteState::W:
        wready_new = 1;
        if (*wready == 1 && *wvalid == 1) {
            wready_new = 0;
            writeData = *wdata;
            writeWord(writeAddr, writeData, *wstrb);
            writeState = AxiLiteWriteState::B;
        }
        break;

    case AxiLiteWriteState::B:
        bvalid_new = 1;
        if (*bvalid == 1 && *bready == 1) {
            // bresp is always 0
            this->agent->log(0, "[AxiLiteInitiator] Write end");
            bvalid_new = 0;
            writeState = AxiLiteWriteState::AW;
        }
        break;

    default:
        writeState = AxiLiteWriteState::AW;
        break;
    }
}

void AxiLiteInitiator::setReset(uint8_t value) {
    *rst = value;
}

void AxiLiteInitiator::onResetAction()
{
    // It is required from the AxiInitiator to drive rvalid and bvalid signals
    // low during the reset
    *rvalid = 0;
    *bvalid = 0;
}

uint64_t AxiLiteInitiator::getSpecifiedAdress()
{
    throw "Unimplemented";
}
bool AxiLiteInitiator::hasSpecifiedAdress()
{
    throw "Unimplemented";
}
