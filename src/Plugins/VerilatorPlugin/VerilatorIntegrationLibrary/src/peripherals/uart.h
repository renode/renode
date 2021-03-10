//
// Copyright (c) 2010-2019 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "../renode.h"
#include "../buses/bus.h"

// UARTAction must be in sync with Renode's protocol
enum UARTAction
{
    txdRequest = 13,
    rxdRequest = 14
};

struct UART : RenodeAgent
{
    public:
    UART(BaseBus* bus, unsigned char* txd, unsigned char* rxd, unsigned int prescaler, unsigned int tx_reg_addr=4, unsigned char* irq=nullptr);
    void eval();
    unsigned char* txd;
    unsigned char* rxd;
    unsigned char* irq;
    unsigned int prescaler;
    unsigned int tx_reg_addr;
    unsigned char prev_irq;

    private:
    void writeToBus(unsigned long addr, unsigned long value) override;
    void handleCustomRequestType(Protocol* message) override;
    void Txd();
    void Rxd(unsigned char value);
};