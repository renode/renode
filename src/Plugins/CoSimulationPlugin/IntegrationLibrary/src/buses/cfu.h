//
// Copyright (c) 2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef CFU_H
#define CFU_H
#include <cstdint>
#include "bus.h"

struct Cfu
{
    virtual void tick(bool countEnable, uint64_t steps);
    virtual void reset();
    uint64_t execute(uint32_t functionID, uint32_t data0, uint32_t data1, int* error);
    void timeoutTick(uint8_t* signal, uint8_t expectedValue, int timeout);
    void (*evaluateModel)();

    uint64_t tickCounter;
};
#endif
