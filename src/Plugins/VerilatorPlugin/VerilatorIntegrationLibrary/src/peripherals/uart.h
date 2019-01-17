//
// Copyright (c) 2010-2019 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "../renode.h"
#include "../buses/bus.h"

enum UARTAction {
    txdRequest = 7,
    rxdRequest = 8
};

struct UART : RenodeAgent {
    public:
    UART(BaseBus* bus, unsigned char* txd, unsigned char* rxd, unsigned int prescaler);
    unsigned char* txd;
    unsigned char* rxd;
    unsigned int prescaler;

    private:
    void writeToBus(unsigned long addr, unsigned long value) override;
    void handleCustom(Protocol* message);
    void readTxd();
    void writeRxd(unsigned char value);
};