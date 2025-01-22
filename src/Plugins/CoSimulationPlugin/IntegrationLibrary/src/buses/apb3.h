//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef APB3_H
#define APB3_H
#include "bus.h"

struct APB3 : public BaseTargetBus
{
    virtual void tick(bool countEnable, uint64_t steps);
    virtual void write(int width, uint64_t addr, uint64_t value);
    virtual uint64_t read(int width, uint64_t addr);
    virtual void reset();
    virtual bool areSignalsConnected();
    void initSignals();
    void timeoutTick(uint8_t* signal, uint8_t expectedValue, int timeout);

    uint8_t   *pclk = nullptr;
    uint8_t   *prst = nullptr;
    uint8_t   *paddr = nullptr;        // IN
    uint8_t   *psel = nullptr;         // IN
    uint8_t   *penable = nullptr;      // IN
    uint8_t   *pwrite = nullptr;       // IN
    uint32_t  *pwdata = nullptr;       // IN
    uint8_t   *pready = nullptr;       // OUT
    uint32_t  *prdata = nullptr;       // OUT
    uint8_t   *pslverr = nullptr;      // IN
    uint8_t   *pstrb = &pstrb_default; // OUT

private:
    uint8_t pstrb_default = 0;
};
#endif
