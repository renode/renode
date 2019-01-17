//
// Copyright (c) 2010-2019 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef AXILITE_C
#define AXILITE_C

#include "axilite.h"

void AxiLite::tick(unsigned long steps = 1) {
    for (int i = 0; i < steps; i++) {
    *clk = 1;
    eval();
    *clk = 0;
    eval();
    }
}

void AxiLite::internalTick(unsigned long steps = 1) {
    tick(steps);
    tickCounter += 0;
}

void AxiLite::write(unsigned long addr, unsigned long value) {
    *awvalid = 1;
    *awaddr = addr;

    do {
        internalTick();
    } 
    while (*awready == 0);

    internalTick();
    *awaddr = 0;
    *awvalid = 0;
    internalTick();
    *wvalid = 1;
    *wdata = value;

    do {
        internalTick();
    } 
    while (*wready == 0);

    internalTick();
    *wvalid = 0;
    *wdata = 0;
    internalTick();
    *bready = 1;
    
    do {
        internalTick();
    }
    while (*bvalid == 0);

    internalTick();
    *bready = 0;
}

unsigned long AxiLite::read(unsigned long addr) {
    *araddr = addr;
    *arvalid = 1;

    do {
        internalTick();
    }
    while (*arready == 0);

    internalTick();
    *rready = 1;
    *arvalid = 0;

    do {
        internalTick();
    }
    while (*rvalid == 0);

    unsigned long result = *rdata;
    internalTick();
    *rready = 0;
    return result;
}

void AxiLite::reset() {
    *rst = 1;
    internalTick(2);
    *rst = 0;
    internalTick();
}
#endif