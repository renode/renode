//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef AxiSlave_H
#define AxiSlave_H
#include "axi.h"
#include <src/renode_bus.h>

enum class AxiReadState  {AR, R};
enum class AxiWriteState {AW, W, B};

struct AxiSlave : public BaseAxi, public BaseInitiatorBus
{
    AxiSlave(uint32_t dataWidth, uint32_t addrWidth);
    virtual void tick(bool countEnable, uint64_t steps);
    virtual void timeoutTick(uint8_t* signal, uint8_t expectedValue, int timeout);
    virtual void write(uint64_t addr, uint64_t value);
    virtual uint64_t read(uint64_t addr);
    virtual void reset();

    void readWord(uint64_t addr, uint8_t sel);
    void writeWord(uint64_t addr, uint64_t data, uint8_t strb);

    void clearSignals();
    void updateSignals();
    void writeHandler();
    void readHandler();

    bool hasSpecifiedAdress() override { throw "unimplemented"; }
    uint64_t getSpecifiedAdress() override { throw "unimplemented"; }

    AxiWriteState writeState;
    AxiReadState  readState;

    uint8_t awready_new;
    uint8_t wready_new;
    uint8_t bvalid_new;

    uint8_t arready_new;
    uint8_t rvalid_new;
    uint8_t rlast_new;
    uint64_t rdata_new;

    AxiBurstType  writeBurstType;
    uint64_t      writeAddr;
    uint8_t       writeNumBytes;

    AxiBurstType  readBurstType;
    uint64_t      readAddr;
    uint8_t       readLen;
    uint8_t       readNumBytes;

    char buffer [50];
};
#endif
