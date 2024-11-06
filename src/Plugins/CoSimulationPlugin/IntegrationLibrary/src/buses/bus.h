//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef BaseBus_H
#define BaseBus_H

#include <cstdint>

#ifndef DEFAULT_TIMEOUT
#define DEFAULT_TIMEOUT 2000
#endif

class RenodeAgent;

class BaseBus
{
public:
    BaseBus() : agent(nullptr), tickCounter(0) {}
    virtual void tick(bool countEnable, uint64_t steps) = 0;
    virtual void timeoutTick(uint8_t* signal, uint8_t expectedValue, int timeout) = 0;
    virtual void reset() = 0;
    void (*evaluateModel)();
    virtual void setAgent(RenodeAgent *newAgent)
    {
        agent = newAgent;
    }
protected:
    friend class RenodeAgent;
    RenodeAgent *agent;
    uint64_t tickCounter;
    template<typename T>
    void setSignal(T* signal, T value)
    {
        *signal = value;
        evaluateModel();
    }
};

class BaseTargetBus : public BaseBus
{
public:
    virtual void write(int width, uint64_t addr, uint64_t value) = 0;
    virtual uint64_t read(int width, uint64_t addr) = 0;
};

class BaseInitiatorBus : public BaseBus
{
public:
    virtual void readWord(uint64_t addr, uint8_t sel) = 0;
    virtual void writeWord(uint64_t addr, uint64_t data, uint8_t sel) = 0;
    virtual void readHandler() = 0;
    virtual void writeHandler() = 0;
    virtual void clearSignals() = 0;
    virtual bool hasSpecifiedAdress() = 0;
    virtual uint64_t getSpecifiedAdress() = 0;
};
#endif
