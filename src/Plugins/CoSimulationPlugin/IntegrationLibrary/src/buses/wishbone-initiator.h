//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

#ifndef WishboneInitiator_H
#define WishboneInitiator_H

#include "src/renode.h"
#include "wishbone.h"

template <typename data_t, typename addr_t>
class WishboneInitiator : public WishboneBase, public BaseInitiatorBus
{
public:
    WishboneInitiator()
        : readState(0), writeState(0)
    {
    }

    void tick(bool countEnable, uint64_t steps) override
    {
        for (size_t i = 0; i < steps; i++)
        {
            readHandler();
            writeHandler();
            *wb_clk = high;
            evaluateModel();
            *wb_clk = low;
            evaluateModel();
        }

        clearSignals();

        if (countEnable)
            tickCounter += steps;
    }

    void timeoutTick(uint8_t* signal, uint8_t expectedValue, int timeout)
    {
        throw "Unsupported operation";
    }

    void readWord(uint64_t addr, uint8_t sel)
    {
#ifdef DEBUG
        agent->log(LOG_LEVEL_NOISY, "Wishbone read from: 0x%" PRIX64 ", sel: %i", addr, int(sel));
#endif
        data = agent->requestDoubleWordFromAgent(addr);

        constexpr size_t bits = 8;
        for (size_t i = 0; i < bits; i++)
        {
            if ((sel & (1 << i)) == 0)
                ((uint8_t *)&data)[i] = 0;
        }
    }

    void writeWord(uint64_t addr, uint64_t data, uint8_t sel)
    {
#ifdef DEBUG
        agent->log(LOG_LEVEL_NOISY, "Wishbone write to: 0x%" PRIX64 ", data: 0x%" PRIX64 ", sel: %i", addr, data, int(sel));
#endif

        switch (sel)
        {
        case 1 << 0:
            agent->pushByteToAgent(addr, ((uint8_t *)&data)[0]);
            break;
        case 1 << 1:
            agent->pushByteToAgent(addr + 1, ((uint8_t *)&data)[1]);
            break;
        case 1 << 2:
            agent->pushByteToAgent(addr + 2, ((uint8_t *)&data)[2]);
            break;
        case 1 << 3:
            agent->pushByteToAgent(addr + 3, ((uint8_t *)&data)[3]);
            break;

        case (1 << 0) | (1 << 1):
            agent->pushWordToAgent(addr, data & 0xFFFF);
            break;
        case (1 << 2) | (1 << 3):
            agent->pushWordToAgent(addr + 2, (data >> 16) & 0xFFFF);
            break;

        case 15:
            agent->pushDoubleWordToAgent(addr, data);
            break;

        default:
        {
            uint64_t oldData = agent->requestDoubleWordFromAgent(addr);

            constexpr size_t bits = 8;
            for (size_t i = 0; i < bits; i++)
            {
                if (sel & (1 << i))
                    ((uint8_t *)&oldData)[i] = ((uint8_t *)&data)[i];
            }

            agent->pushDoubleWordToAgent(addr, oldData);
            break;
        }
        }
    }

    void readHandler()
    {
        switch (readState)
        {
        case 0:
            if (*wb_cyc && *wb_stb && !*wb_we)
            {
                *wb_stall = low;
                *wb_ack = low;
                readWord(*wb_addr, *wb_sel);
                readState = 1;
            }
            break;
        case 1:
            *wb_stall = high;
            *wb_ack = high;
            *wb_rd_dat = data;
            readState = 0;
            break;
        }
    }

    void writeHandler()
    {
        switch (writeState)
        {
        case 0:
            if (*wb_cyc && *wb_stb && *wb_we)
            {
                *wb_stall = low;
                *wb_ack = low;
                writeWord(*wb_addr, *wb_wr_dat, *wb_sel);
                writeState = 1;
            }
            break;
        case 1:
            *wb_stall = high;
            *wb_ack = high;
            writeState = 0;
            break;
        }
    }

    void clearSignals()
    {
        *wb_stall = high;
        *wb_ack = low;
    }

    void reset()
    {
        *wb_rst = 1;
        tick(true, 1);
        *wb_rst = 0;
        tick(true, 1);
    }

    bool hasSpecifiedAdress() override
    {
        return *wb_cyc && *wb_stb;
    }
    
    uint64_t getSpecifiedAdress() override { return *wb_addr; }

    addr_t *wb_addr;
    data_t *wb_rd_dat;
    data_t *wb_wr_dat;

    uint8_t readState, writeState;
    uint64_t data;

    static constexpr uint32_t high = 1, low = 0;
};

#endif
