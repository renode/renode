//
// Copyright (c) 2010-2019 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef BaseBus_H
#define BaseBus_H

struct BaseBus
{
    public:
    virtual void tick(bool countEnable, unsigned long steps) = 0;
    virtual void write(unsigned long addr, unsigned long value) = 0;
    virtual unsigned long read(unsigned long addr) = 0;
    virtual void reset() = 0;
    void (*evaluateModel)();
    unsigned long tickCounter;
};

#endif
