//
// Copyright (c) 2010-2022 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

#include "axilite-initiator.h"
#include "../renode_bus.h"

// Tick and tick related functions are implemented with future enhancements in mind
void AxiLiteInitiator::tick(bool countEnable, uint64_t steps = 1)
{
    for (uint64_t i = 0; i < steps; i++) {
        prePosedgeTick();
        *clk = 1;
        posedgeTick();
        *clk = 0;
        negedgeTick();
    }

    // Since we don't handle all interfaces at once and evaluation can be called from
    // the different interface we need to set ready/valid signals low after executing
    // all the available steps
    clearSignals();

    if (countEnable) {
        tickCounter += steps;
    }
}

void AxiLiteInitiator::clearSignals()
{
    arready_new = *arready;
    rvalid_new = *rvalid;
    rdata_new = *rdata;
    awready_new = *awready;
    wready_new = *wready;
    bvalid_new = *bvalid;

    // Read
    *arready = 0;
    *rvalid = 0;
    *rdata = 0;

    // Write
    *awready = 0;
    *wready = 0;
    *bvalid = 0;
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

void AxiLiteInitiator::prePosedgeTick()
{
    readHandler();
    writeHandler();
}

void AxiLiteInitiator::posedgeTick()
{
    evaluateModel();
    updateSignals();
}

void AxiLiteInitiator::negedgeTick()
{
    evaluateModel();
}

void AxiLiteInitiator::readWord(uint64_t addr, uint8_t sel = 0)
{
    this->agent->log(0, "[AxiLiteInitiator] Read word from: %x", addr);
    rdata_new = this->agent->requestFromAgent(addr);
}

void AxiLiteInitiator::writeWord(uint64_t addr, uint64_t data, uint8_t strb)
{
    this->agent->log(0, "[AxiLiteInitiator] Write word: addr: %x data: %x strb: %d", addr, data, strb);

    // Added temporary; can be removed when verilator-width changes are merged
    uint64_t busWidth = 8;

    // In case of a full write
    if (strb == ((1 << busWidth) - 1)) {
        this->agent->pushToAgent(addr, data);
        return;
    }

    uint64_t bytes_to_write = __builtin_popcount(strb);
    // We support only consecutive bytes transfers, therefore,
    // the valid data can be accessed with a mask of consecutive 0xff
    uint64_t valid_data_mask = ((uint64_t)1 << (bytes_to_write << 3)) - 1;

    // Find the first set LSB of strb to calculate the valid data offset
    uint32_t data_offset = __builtin_popcount((strb & ~(strb - 1)) - 1);

    // If valid bytes are not consecutive throw exception
    if ((((1 << bytes_to_write) - 1) << data_offset) != strb) {
        throw "Unsupported write strobe value";
    }

    this->agent->pushToAgent(addr, (data >> data_offset) & valid_data_mask);

}

void AxiLiteInitiator::readHandler()
{
    switch (readState) {
    case AxiLiteReadState::AR:
        arready_new = 1;
        if (*arready == 1 && *arvalid == 1) {
            this->agent->log(0, "[AxiLiteInitiator] Read start");
            arready_new = 0;
            readAddr = *araddr;
            readWord(readAddr);
            readState = AxiLiteReadState::R;
        }
        break;

    case AxiLiteReadState::R:
        rvalid_new = 1;
        if (*rvalid == 1 && *rready == 1) {
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

void AxiLiteInitiator::timeoutTick(uint8_t *signal, uint8_t expectedValue, int timeout)
{
    do {
        tick(true);
        timeout -= 1;
    } while ((*signal != expectedValue) && timeout > 0);

    if (timeout == 0) {
        throw "Operation timeout";
    }
}

void AxiLiteInitiator::reset()
{
    uint8_t reset_active = 0;
// Used to allow some of the tests to be executed
#ifdef INVERT_RESET
    reset_active = 1;
#endif

    *rst = reset_active;
    // It is required from the AxiInitiator to drive rvalid and bvalid signals
    // low during the reset
    *rvalid = 0;
    *bvalid = 0;
    tick(true, 1);
    *rst = !reset_active;
    tick(true);
}

uint64_t AxiLiteInitiator::getSpecifiedAdress()
{
    throw "Unimplemented";
}
bool AxiLiteInitiator::hasSpecifiedAdress()
{
    throw "Unimplemented";
}