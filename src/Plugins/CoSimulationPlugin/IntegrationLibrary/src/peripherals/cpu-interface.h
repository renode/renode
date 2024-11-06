//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

#ifndef Cpu_H
#define Cpu_H

#include <vector>
#include "gpio-receiver.h"
#include "can-halt.h"
#include "has-clk.h"
#include "peripheral.h"

class CPU : public Peripheral, public GPIOReceiver, public CanHalt, public HasCLk
{
};

class DebuggableCPU : public CPU
{
public:
    class DebugProgram
    {
    public:
        uint64_t address;
        uint64_t readCount;
        std::vector<uint64_t> memory;
    };
    virtual void debugRequest(bool value) = 0;
    virtual DebugProgram getRegisterGetProgram(uint64_t id) = 0;
    virtual DebugProgram getRegisterSetProgram(uint64_t id, uint64_t value) = 0;
    virtual DebugProgram getEnterSingleStepModeProgram() = 0;
    virtual DebugProgram getExitSingleStepModeProgram() = 0;
    virtual DebugProgram getSingleStepModeProgram() = 0;
};

#endif
