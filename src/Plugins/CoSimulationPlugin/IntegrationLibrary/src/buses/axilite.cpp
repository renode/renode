//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "axilite.h"
#include <stdexcept>

void AxiLite::tick(bool countEnable, uint64_t steps = 1)
{
    for(uint64_t i = 0; i < steps; i++) {
        setSignal<uint8_t>(clk, 1);
        setSignal<uint8_t>(clk, 0);
    }

    if(countEnable) {
        tickCounter += steps;
    }
}

void AxiLite::timeoutTick(uint8_t* signal, uint8_t expectedValue, int timeout = DEFAULT_TIMEOUT)
{
    do
    {
        tick(true);
        timeout--;
    }
    while((*signal != expectedValue) && timeout > 0);

    if(timeout == 0) {
        throw "Operation timeout";
    }
}

// VALID/READY handshake process (as a source)
void AxiLite::handshake_src(uint8_t* ready, uint8_t* valid, uint64_t* channel, uint64_t value)
{
    setSignal<uint64_t>(channel, value);
    setSignal<uint8_t>(valid, 1);
    // Don't wait if `ready` signal has been set (READY before VALID handshake)
    if(*ready != 1)
    {
        timeoutTick(ready, 1);
    }

    // The transfer occurs in the cycle AFTER the one with both ready and valid set
    tick(true);

    // Clear the data and valid signal
    setSignal<uint64_t>(channel, 0);
    setSignal<uint8_t>(valid, 0);
}

void AxiLite::write(int width, uint64_t addr, uint64_t value)
{
    setSignal<uint8_t>(wstrb, (1 << width) - 1);
    // Set write address and data
    handshake_src(awready, awvalid, awaddr, addr);
    handshake_src(wready, wvalid, wdata, value);
    setSignal<uint8_t>(wstrb, 0);


    // Wait for the write response
    setSignal<uint8_t>(bready, 1);
    if(*bvalid != 1) {
        timeoutTick(bvalid, 1);
    }
    tick(true);
    setSignal<uint8_t>(bready, 0);
}

uint64_t AxiLite::read(int width, uint64_t addr)
{
    // Set read address
    handshake_src(arready, arvalid, araddr, addr);

    // Read data
    setSignal<uint8_t>(rready, 1);
    if(*rvalid != 1)
    {
        timeoutTick(rvalid, 1);
    }
    uint64_t result = *rdata; // we have to fetch data before transaction end
    tick(true);
    setSignal<uint8_t>(rready, 0);
    return result;
}

void AxiLite::reset()
{
    uint8_t reset_active = 0;

// This parameter provides compability with old verilator-renode-integration 
// samples that used previous reset implementation

#ifdef INVERT_RESET
    reset_active = 1;
#endif
    setSignal<uint8_t>(rst, reset_active);
    tick(true, 2); // it's model feature to tick twice
    setSignal<uint8_t>(rst, !reset_active);
    tick(true);
}

void AxiLite::validateSignals()
{
    if(clk == nullptr) throw std::runtime_error("Signal 'clk' not assigned");
    if(rst == nullptr) throw std::runtime_error("Signal 'rst' not assigned");
    if(awvalid == nullptr) throw std::runtime_error("Signal 'awvalid' not assigned");
    if(awready == nullptr) throw std::runtime_error("Signal 'awready' not assigned");
    if(wstrb == nullptr) throw std::runtime_error("Signal 'wstrb' not assigned");
    if(wvalid == nullptr) throw std::runtime_error("Signal 'wvalid' not assigned");
    if(wready == nullptr) throw std::runtime_error("Signal 'wready' not assigned");
    if(bresp == nullptr) throw std::runtime_error("Signal 'bresp' not assigned");
    if(bvalid == nullptr) throw std::runtime_error("Signal 'bvalid' not assigned");
    if(bready == nullptr) throw std::runtime_error("Signal 'bready' not assigned");
    if(arvalid == nullptr) throw std::runtime_error("Signal 'arvalid' not assigned");
    if(arready == nullptr) throw std::runtime_error("Signal 'arready' not assigned");
    if(rresp == nullptr) throw std::runtime_error("Signal 'rresp' not assigned");
    if(rvalid == nullptr) throw std::runtime_error("Signal 'rvalid' not assigned");
    if(rready == nullptr) throw std::runtime_error("Signal 'rready' not assigned");
    if(awaddr == nullptr) throw std::runtime_error("Signal 'awaddr' not assigned");
    if(wdata == nullptr) throw std::runtime_error("Signal 'wdata' not assigned");
    if(araddr == nullptr) throw std::runtime_error("Signal 'araddr' not assigned");
    if(rdata == nullptr) throw std::runtime_error("Signal 'rdata' not assigned");
}
