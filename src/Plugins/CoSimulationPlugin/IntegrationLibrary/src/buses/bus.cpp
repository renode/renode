//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

#include "src/buses/bus.h"
#include "src/renode.h"
#include "src/renode_bus.h"
#include <cstdio>

void BaseBus::setAgent(RenodeAgent *newAgent) {
    agent = newAgent;
    if (!areSignalsConnected()) {
        this->agent->fatalError();
    }
}

bool BaseBus::isSignalConnected(void *signal, const char *signalName) {
    bool isConnected = signal != NULL;
    if (!isConnected) {
        char buffer[200];
        snprintf(buffer, 200, "Signal '%s' not assigned", signalName);
        this->agent->log(LOG_LEVEL_ERROR, buffer);
    }
    return isConnected;
}
