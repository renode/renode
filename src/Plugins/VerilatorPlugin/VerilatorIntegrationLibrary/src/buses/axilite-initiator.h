//
// Copyright (c) 2010-2022 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef AxiLiteInitiator_H
#define AxiLiteInitiator_H
#include "bus.h"

enum AxiLiteReadState {AR, R};
enum AxiLiteWriteState {AW, W, B};

struct AxiLiteInitiator : public BaseInitiatorBus
{
    uint8_t  *rxd;
    uint8_t  *txd;

    // Global
    uint8_t  *clk;
    uint8_t  *rst;

    // Write address channel
    uint8_t  *awvalid;
    uint8_t  *awready;
    uint64_t *awaddr;
    uint8_t  *awprot; // not supported

    // Write data channel
    uint8_t  *wvalid;
    uint8_t  *wready;
    uint64_t *wdata;
    uint8_t  *wstrb;

    // Write response channel
    uint8_t  *bvalid;
    uint8_t  *bready;
    uint8_t  *bresp;

    // Read address channel
    uint8_t  *arvalid;
    uint8_t  *arready;
    uint64_t *araddr;
    uint8_t  *arprot; // not supported

    // Read data channel
    uint8_t  *rvalid;
    uint8_t  *rready;
    uint64_t *rdata;
    uint8_t  *rresp;

    virtual void tick(bool countEnable, uint64_t steps);
    virtual void timeoutTick(uint8_t *signal, uint8_t expectedValue, int timeout);
    void prePosedgeTick();
    void posedgeTick();
    void negedgeTick();

    virtual void reset();
    void clearSignals();
    void updateSignals();

    void readHandler();
    void writeHandler();

    void readWord(uint64_t addr, uint8_t sel);
    void writeWord(uint64_t addr, uint64_t data, uint8_t strb);

    AxiLiteWriteState writeState = AxiLiteWriteState::AW;
    uint64_t writeAddr = 0;
    uint64_t writeData = 0;

    AxiLiteReadState readState = AxiLiteReadState::AR;

    // Signals to be updated post rising edge evaluation
    uint8_t arready_new = 0;
    uint8_t rvalid_new = 0;
    uint64_t rdata_new = 0;

    uint8_t awready_new = 0;
    uint8_t wready_new = 0;
    uint8_t bvalid_new = 0;

    uint64_t getSpecifiedAdress() override;
    bool hasSpecifiedAdress() override;
};
#endif
