//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

#ifndef Cpu_h
#define Cpu_h

#include "../renode.h"
#include "../renode_bus.h"
#include "cpu-interface.h"

class CpuAgent : public RenodeAgent
{
public:
    using RenodeAgent::RenodeAgent;

    void addCPU(DebuggableCPU *cpu)
    {
        this->cpu = cpu;
    }

    void tick(bool countEnable, uint64_t steps) override
    {
        for (size_t i = 0; i < steps; i++)
        {
            for (auto &bus : initatorInterfaces)
            {
                bus->readHandler();
                bus->writeHandler();
            }
            cpu->clkHigh();
            cpu->evaluateModel();
            cpu->clkLow();
            cpu->evaluateModel();

            for (auto &bus : initatorInterfaces)
                bus->clearSignals();
        }
        if (countEnable)
            tickCounter += steps;
    }

    void handleRequest(Protocol *message) override
    {
        switch (message->actionId)
        {
        case interrupt:
            cpu->onGPIO(message->addr, message->value);
            break;

        case registerGet:
            communicationChannel->sendSender(Protocol(registerGet, message->addr, getRegister(message->addr)));
            break;

        case registerSet:
            setRegister(message->addr, message->value);
            communicationChannel->sendSender(Protocol(registerSet, 0, 0));
            break;

        case singleStepMode:
            if (message->value)
            {
                if (!inSingleStepMode)
                    enterSingleStepMode();
            }
            else
            {
                if (inSingleStepMode)
                    exitSingleStepMode();
            }
            communicationChannel->sendSender(Protocol(singleStepMode, 0, 0));
            break;

        case tickClock:
        {
            int64_t ticks = 0;
            if (!inSingleStepMode)
            {
                ticks = message->value - tickCounter;
                if (ticks < 0)
                    tickCounter -= message->value;
                else
                {
                    tick(false, ticks);
                    tickCounter = 0;
                }

                bool halted = cpu->isHalted();
                if (wasHalted != halted)
                {
                    communicationChannel->sendSender(Protocol(isHalted, 0, halted));
                    wasHalted = halted;
                }
            }
            ticks = ticks > 0 ? ticks : 0;
            communicationChannel->sendSender(Protocol(tickClock, 0, ticks));
        }
        break;

        case step:
        {
            int64_t ticks = 0;
            if (inSingleStepMode)
            {
                ticks = message->value - tickCounter;
                if (ticks < 0)
                    tickCounter -= message->value;
                else
                {
                    for (int64_t i = 0; i < ticks; i++)
                    {
                        waitForNonDebugProgramInstruction();
                        waitForFirstDebugProgramInstruction();
                    }
                    tickCounter = 0;
                }

                ticks = ticks > 0 ? ticks : 0;
                communicationChannel->sendSender(Protocol(step, 0, ticks));
            }
        }
        break;

        default:
            RenodeAgent::handleRequest(message);
            break;
        }
    }

    void reset() override
    {
        cpu->reset();
    }

    uint64_t getRegister(uint64_t id)
    {
        log(LOG_LEVEL_DEBUG, "Start getRegister");
        debugProgram = cpu->getRegisterGetProgram(id);

        cpu->debugRequest(true);
        waitForFirstDebugProgramInstruction();
        if (!inSingleStepMode)
            cpu->debugRequest(false);
        runDebugProgram(true);

        log(LOG_LEVEL_DEBUG, "End getRegister");
        return debugProgramReturnValue;
    }

    void setRegister(uint64_t id, uint64_t value)
    {
        log(LOG_LEVEL_DEBUG, "Start setRegister");
        debugProgram = cpu->getRegisterSetProgram(id, value);

        cpu->debugRequest(true);
        waitForFirstDebugProgramInstruction();
        if (!inSingleStepMode)
            cpu->debugRequest(false);
        runDebugProgram(false);

        log(LOG_LEVEL_DEBUG, "End setRegister");
    }

    void enterSingleStepMode()
    {
        log(LOG_LEVEL_DEBUG, "Start enterSingleStepMode");
        debugProgram = cpu->getEnterSingleStepModeProgram();

        cpu->debugRequest(true);
        waitForFirstDebugProgramInstruction();
        cpu->debugRequest(false);
        runDebugProgram(false);

        log(LOG_LEVEL_DEBUG, "End enterSingleStepMode");
        inSingleStepMode = true;
        debugProgram = cpu->getSingleStepModeProgram();
    }

    void exitSingleStepMode()
    {
        log(LOG_LEVEL_DEBUG, "Start exitSingleStepMode");
        inSingleStepMode = false;
        debugProgram = cpu->getExitSingleStepModeProgram();

        cpu->debugRequest(true);
        waitForFirstDebugProgramInstruction();
        cpu->debugRequest(false);
        runDebugProgram(false);

        log(LOG_LEVEL_DEBUG, "End exitSingleStepMode");
        waitForNonDebugProgramInstruction();
        debugProgram = {};
    }

    void pushByteToAgent(uint64_t addr, uint8_t value) override
    {
        if (!inDebugMode)
            RenodeAgent::pushByteToAgent(addr, value);
        else
            debugProgramReturn(addr, value);
    }

    void pushWordToAgent(uint64_t addr, uint16_t value) override
    {
        if (!inDebugMode)
            RenodeAgent::pushWordToAgent(addr, value);
        else
            debugProgramReturn(addr, value);
    }

    void pushDoubleWordToAgent(uint64_t addr, uint32_t value) override
    {
        if (!inDebugMode)
            RenodeAgent::pushDoubleWordToAgent(addr, value);
        else
            debugProgramReturn(addr, value);
    }


    uint64_t requestDoubleWordFromAgent(uint64_t addr) override
    {
        if (!inDebugMode)
        {
            debugProgramOrPrefetch = debugProgramOrPrefetch && (lastRequestAddress + 4 == addr);
            lastRequestAddress = addr;

            if (inSingleStepMode && inDebugProgramRange(addr))
            {
                debugProgramOrPrefetch = true;
                return debugProgram.memory[(addr - debugProgram.address) / 4];
            }
            else
            {
                if (debugProgramOrPrefetch)
                    return debugProgram.memory.back(); // CPU is prefetching debug program
                else
                    return RenodeAgent::requestDoubleWordFromAgent(addr);
            }
        }
        else
        {
            debugProgramOrPrefetch = true;
            lastRequestAddress = addr;

            if (inDebugProgramRange(addr))
            {
                debugProgramReadCount++;
                uint64_t idx = (addr - debugProgram.address) / 4;
                if (idx + 1 == debugProgram.memory.size())
                    debugProgramReadLastInstruction = true;
                return debugProgram.memory[idx];
            }
            else
                return debugProgram.memory.back(); // CPU is probably prefetching, last program instruction should be debug return instruction
        }
    }

private:
    void waitForFirstDebugProgramInstruction()
    {
        bool adressSpecified = false;

        while (true)
        {
            for (auto &bus : initatorInterfaces)
            {
                log(LOG_LEVEL_DEBUG, "Waiting for first debug program instruction access");
                if (bus->hasSpecifiedAdress() && bus->getSpecifiedAdress() == debugProgram.address)
                {
                    log(LOG_LEVEL_DEBUG, "Finished waiting");
                    adressSpecified = true;
                    break;
                }
            }
            if (adressSpecified)
                break;
            tick(false, 1);
            tickCounter++;
        }
    }

    void waitForNonDebugProgramInstruction()
    {
        bool adressSpecified = false;

        while (true)
        {
            for (auto &bus : initatorInterfaces)
            {
                log(LOG_LEVEL_DEBUG, "Waiting for non debug program instruction access");
                if (bus->hasSpecifiedAdress() && !inDebugProgramRange(bus->getSpecifiedAdress()) && !debugProgramOrPrefetch)
                {
                    log(LOG_LEVEL_DEBUG, "Finished waiting");
                    adressSpecified = true;
                    break;
                }
            }
            if (adressSpecified)
                break;
            tick(false, 1);
            tickCounter++;
        }
    }

    void runDebugProgram(bool withReturnSuccess)
    {
        if (inSingleStepMode) // Re-enter debug mode after running program
            cpu->debugRequest(true);

        inDebugMode = true;

        debugProgramReadCount = 0;
        debugProgramReturnSuccess = false;
        debugProgramReadLastInstruction = false;

        while (debugProgramReadCount < debugProgram.readCount || (!debugProgramReturnSuccess && withReturnSuccess) || !debugProgramReadLastInstruction)
        {
            log(LOG_LEVEL_DEBUG, "runDebugProgram tick start");
            tick(false, 1);
            log(LOG_LEVEL_DEBUG, "runDebugProgram tick end");
        }

        inDebugMode = false;

        if (inSingleStepMode)
        {
            waitForFirstDebugProgramInstruction();
            cpu->debugRequest(false);
            debugProgram = cpu->getSingleStepModeProgram();
        }
    }

    void debugProgramReturn(uint64_t addr, uint64_t value)
    {
        if (addr != 0)
                throw "debug program writes to non 0 address";
            if (debugProgramReturnSuccess)
                throw "debug program have already written return value";

            debugProgramReturnValue = value;
            debugProgramReturnSuccess = true;
    }

    bool inDebugProgramRange(uint64_t addr)
    {
        return addr >= debugProgram.address && addr < debugProgram.address + debugProgram.memory.size() * 4;
    }

    DebuggableCPU *cpu = nullptr;
    DebuggableCPU::DebugProgram debugProgram;
    uint64_t debugProgramReadCount = 0;
    uint64_t debugProgramReturnValue;
    int64_t tickCounter = 0;
    uint64_t lastRequestAddress = 0;
    bool debugProgramReturnSuccess = false;
    bool debugProgramReadLastInstruction = false;
    bool wasHalted = false;

    bool inDebugMode = false;
    bool inSingleStepMode = false;

    bool debugProgramOrPrefetch = false;
};

#endif
