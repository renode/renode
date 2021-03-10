//
// Copyright (c) 2010-2021 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef AxiSlave_H
#define AxiSlave_H
#include "axi.h"
#include <src/renode.h>
#include <cstdint>

enum class AxiReadState  {AR, R};
enum class AxiWriteState {AW, W, B};

struct AxiSlave : public Axi
{
    AxiSlave(unsigned int dataWidth, unsigned int addrWidth);
    virtual void tick(bool countEnable, unsigned long steps);
    virtual void write(unsigned long addr, unsigned long value);
    virtual unsigned long read(unsigned long addr);
    virtual void reset();

    void readWord(uint64_t addr);
    void writeWord(uint64_t addr, uint32_t data, uint8_t strb);

    void clearSignals();
    void updateSignals();
    void writeHandler();
    void readHandler();

    AxiWriteState writeState;
    AxiReadState  readState;

    unsigned char awready_new;
    unsigned char wready_new;
    unsigned char bvalid_new;

    unsigned char arready_new;
    unsigned char rvalid_new;
    unsigned char rlast_new;
    unsigned long rdata_new;

    AxiBurstType  writeBurstType;
    uint64_t      writeAddr;
    uint8_t       writeLen;
    uint8_t       writeNumBytes;

    AxiBurstType  readBurstType;
    uint64_t      readAddr;
    uint8_t       readLen;
    uint8_t       readNumBytes;

    char buffer [50];
};
#endif
