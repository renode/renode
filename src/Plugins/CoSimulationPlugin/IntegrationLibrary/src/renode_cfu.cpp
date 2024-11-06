//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "renode_cfu.h"
static RenodeAgent* renodeAgent;

#define IO_THREADS 1

//=================================================
// RenodeAgent
//=================================================

RenodeAgent::RenodeAgent(Cfu *_cfu) {
    cfu = _cfu;
    cfu->tickCounter = 0;
}

void RenodeAgent::tick(bool countEnable, uint64_t steps)
{
    cfu->tick(countEnable, steps);
}

void RenodeAgent::reset()
{
    cfu->reset();
}

uint64_t RenodeAgent::execute(uint32_t functionID, uint32_t data0, uint32_t data1, int* error)
{
    uint64_t result = 0;

    try {
        result = cfu->execute(functionID, data0, data1, error);
        *error = CFU_OK;
    }
    catch(const char* msg) {
        if (msg == "Operation timeout") {
            *error = CFU_TIMEOUT;
        } else {
            *error = CFU_FAIL;
        }
    }
    return result;
}

void RenodeAgent::handleCustomRequestType(Protocol* message)
{
    log(LOG_LEVEL_WARNING, "Unhandled request type: %d", message->actionId);
}

void RenodeAgent::log(int level, const char* fmt, ...)
{
    char s[1024];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(s, 1024, fmt, ap);
    communicationChannel->log(level, s);
    va_end(ap);
}

//=================================================
// NativeCommunicationChannel
//=================================================

extern void handleSenderMessage(void* ptr);
EXTERNAL_AS(action_intptr, HandleSenderMessage, handleSenderMessage);

void NativeCommunicationChannel::sendSender(const Protocol message)
{
    handleSenderMessage(new Protocol(message));
}

void NativeCommunicationChannel::log(int logLevel, const char* data)
{
    handleSenderMessage(new Protocol(logMessage, strlen(data) + 1, (uint64_t)data));
    handleSenderMessage(new Protocol(logMessage, 0, logLevel));
}

//=================================================
// Functions exported to Renode
//=================================================

uint64_t execute(uint32_t functionID, uint32_t data0, uint32_t data1, int* error)
{
    return renodeAgent->execute(functionID, data0, data1, error);
}

void initialize_native()
{
    renodeAgent = Init();
    renodeAgent->communicationChannel = new NativeCommunicationChannel();
}

void handle_request(Protocol* request)
{
    long ticks;
    switch(request->actionId) {
        case invalidAction:
            break;
        case tickClock:
            ticks = request->value - renodeAgent->cfu->tickCounter;
            if(ticks > 0) {
                renodeAgent->tick(false, ticks);
            }
            renodeAgent->cfu->tickCounter = 0;
            renodeAgent->communicationChannel->sendSender(Protocol(tickClock, 0, 0));
            break;
        case resetPeripheral:
            renodeAgent->reset();
            break;
        default:
            renodeAgent->handleCustomRequestType(request);
            break;
    }
}

void reset_peripheral()
{
    renodeAgent->reset();
}
