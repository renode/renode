//
// Copyright (c) 2010-2022 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef BaseBus_H
#define BaseBus_H

#include <cstdint>

class BaseBus
{
public:
    virtual void tick(bool countEnable, uint64_t steps) = 0;
    virtual void timeoutTick(uint8_t* signal, uint8_t expectedValue, int timeout) = 0;
    virtual void reset() = 0;
    void (*evaluateModel)();
    uint64_t tickCounter;
};

class BaseTargetBus : public BaseBus
{
public:
    virtual void write(uint64_t addr, uint64_t value) = 0;
    virtual uint64_t read(uint64_t addr) = 0;
};

#endif
