//
// Copyright (c) 2010-2021 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "apb3.h"
#include <cstdio>

void APB3::setClock(uint8_t value) {
    *pclk = value;
}

void APB3::prePosedgeTick()
{
}

void APB3::posedgeTick()
{
}

void APB3::negedgeTick()
{
}

void APB3::write(int width, uint64_t addr, uint64_t value)
{
    if(width != 4) {
        char msg[] = "APB3 implementation only handles 4-byte accesses, tried %d"; // we sprintf to self, because width is never longer than 2 digits
        sprintf(msg, msg, width);
        throw msg;
    }
    *psel = 1;
    *pwrite = 1;
    *paddr = addr;
    *pwdata = value;

    this->agent->timeoutTick(pready, 1);

    *penable = 1;

    this->agent->tick(true, 1);

    *psel = 0;
    *penable = 0;

    this->agent->tick(true, 1);
}

uint64_t APB3::read(int width, uint64_t addr)
{
    if(width != 4) {
        char msg[] = "APB3 implementation only handles 4-byte accesses, tried %d"; // we sprintf to self, because width is never longer than 2 digits
        sprintf(msg, msg, width);
        throw msg;
    }
    *psel = 1;
    *pwrite = 0;
    *paddr = addr;

    this->agent->timeoutTick(pready, 1);

    *penable = 1;

    this->agent->tick(true, 1);

    uint64_t result = *prdata;

    *psel = 0;
    *penable = 0;

    this->agent->tick(true, 1);

    return result;
}

void APB3::setReset(uint8_t value) {
    *prst = value;
}

void APB3::onResetAction()
{
}