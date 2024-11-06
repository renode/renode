//
// Copyright (c) 2024 Antmicro
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

    uint8_t  *req_valid;     /* 1 bit */
    uint8_t  *req_ready;     /* 1 bit */
    uint16_t *req_func_id;   /* 10 bit */
    uint32_t *req_data0;     /* 32 bit */
    uint32_t *req_data1;     /* 32 bit */

    uint8_t  *resp_valid;    /* 1 bit */
    uint8_t  *resp_ready;    /* 1 bit */
    uint8_t  *resp_ok;       /* 1 bit */
    uint32_t *resp_data;     /* 32 bit */

    uint8_t  *rst;           /* 1 bit */
    uint8_t  *clk;           /* 1 bit */

    uint64_t tickCounter;
};
#endif
