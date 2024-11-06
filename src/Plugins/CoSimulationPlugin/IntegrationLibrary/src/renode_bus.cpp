//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "renode_bus.h"
#include "communication/socket_channel.h"
static RenodeAgent* renodeAgent;

#define IO_THREADS 1

//=================================================
// RenodeAgent
//=================================================

RenodeAgent::RenodeAgent(BaseTargetBus* bus)
{
    targetInterfaces.push_back(std::unique_ptr<BaseTargetBus>(bus));
    targetInterfaces[0]->tickCounter = 0;
    firstInterface = bus;
    bus->setAgent(this);
}

RenodeAgent::RenodeAgent(BaseInitiatorBus* bus)
{
    initatorInterfaces.push_back(std::unique_ptr<BaseInitiatorBus>(bus));
    initatorInterfaces[0]->tickCounter = 0;
    firstInterface = bus;
    bus->setAgent(this);
}

void RenodeAgent::addBus(BaseTargetBus* bus)
{
    targetInterfaces.push_back(std::unique_ptr<BaseTargetBus>(bus));
    bus->setAgent(this);
}

void RenodeAgent::addBus(BaseInitiatorBus* bus)
{
    initatorInterfaces.push_back(std::unique_ptr<BaseInitiatorBus>(bus));
    bus->setAgent(this);
}

void RenodeAgent::writeToBus(int width, uint64_t addr, uint64_t value)
{
    try {
        targetInterfaces[0]->write(width, addr, value);
        communicationChannel->sendMain(Protocol(ok, 0, 0));
    }
    catch(const char* msg) {
        log(LOG_LEVEL_ERROR, msg);
        communicationChannel->sendMain(Protocol(error, 0, 0));
    }
}

void RenodeAgent::readFromBus(int width, uint64_t addr)
{
    try {
        uint64_t readValue = targetInterfaces[0]->read(width, addr);
        communicationChannel->sendMain(Protocol(readRequest, addr, readValue));
    }
    catch(const char* msg) {
        log(LOG_LEVEL_ERROR, msg);
        communicationChannel->sendMain(Protocol(error, 0, 0));
    }
}

void RenodeAgent::pushByteToAgent(uint64_t addr, uint8_t value)
{
    pushToAgent(pushByte, addr, value);
}

void RenodeAgent::pushWordToAgent(uint64_t addr, uint16_t value)
{
    pushToAgent(pushWord, addr, value);
}

void RenodeAgent::pushDoubleWordToAgent(uint64_t addr, uint32_t value)
{
    pushToAgent(pushDoubleWord, addr, value);
}

uint64_t RenodeAgent::requestDoubleWordFromAgent(uint64_t addr)
{
    return requestFromAgent(getDoubleWord, addr);
}

void RenodeAgent::pushToAgent(Action action, uint64_t addr, uint64_t value)
{
    communicationChannel->sendSender(Protocol(action, addr, value));
    Protocol* received = communicationChannel->receive();
    while (received->actionId != pushConfirmation)
    {
        handleRequest(received);
        delete received;
        received = communicationChannel->receive();
    }
    delete received;
}

uint64_t RenodeAgent::requestFromAgent(Action action, uint64_t addr)
{
    communicationChannel->sendSender(Protocol(action, addr, 0));
    Protocol* received = communicationChannel->receive();
    while (received->actionId != writeRequest)
    {
        handleRequest(received);
        delete received;
        received = communicationChannel->receive();
    }
    auto result = received->value;
    delete received;
    return result;
}

void RenodeAgent::tick(bool countEnable, uint64_t steps)
{
    for(auto& b : targetInterfaces)
        b->tick(countEnable, steps);
    for(auto& b : initatorInterfaces)
        b->tick(countEnable, steps);
}

void RenodeAgent::timeoutTick(uint8_t* signal, uint8_t expectedValue, int timeout)
{
    for(auto& b : targetInterfaces)
        b->timeoutTick(signal, expectedValue, timeout);
    for(auto& b : initatorInterfaces)
        b->timeoutTick(signal, expectedValue, timeout);
}

void RenodeAgent::reset()
{
    for(auto& b : targetInterfaces)
        b->reset();
    for(auto& b : initatorInterfaces)
        b->reset();
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

Protocol* RenodeAgent::receive()
{
    return communicationChannel->receive();
}

void RenodeAgent::registerInterrupt(uint8_t *irq, uint8_t irq_addr)
{
    if (irq == nullptr) {
        log(LOG_LEVEL_ERROR, "The irq address cannot be null");
        communicationChannel->sendMain(Protocol(error, 0, 0));
        return;
    }

    interrupts.push_back({irq, 0, irq_addr});
}

void RenodeAgent::handleInterrupts(void)
{
    for (unsigned long i = 0; i < interrupts.size(); i++) {
        if (*interrupts[i].irq != interrupts[i].prev_irq) {
            communicationChannel->sendSender(Protocol(interrupt, interrupts[i].irq_addr, *interrupts[i].irq));
            interrupts[i].prev_irq = *interrupts[i].irq;
        }
    }
}

void RenodeAgent::simulate(int receiverPort, int senderPort, const char* address)
{
    renodeAgent = this;
    SocketCommunicationChannel* channel = new SocketCommunicationChannel();
    communicationChannel = channel;
    channel->connect(receiverPort, senderPort, address);
    Protocol* result;
    reset();

    while(channel->getIsConnected()) {
        result = receive();
        handleRequest(result);
        delete result;
    }
}

void RenodeAgent::handleRequest(Protocol* request)
{
    switch(request->actionId) {
        case invalidAction:
            break;
        case tickClock:
        {
            long ticks = request->value - firstInterface->tickCounter;
            if(ticks < 0) {
                firstInterface->tickCounter -= request->value;
            }
            else {
                tick(false, ticks);
            }
            firstInterface->tickCounter = 0;
            communicationChannel->sendSender(Protocol(tickClock, 0, 0));
        }
            break;
        case writeRequestByte:
            writeToBus(1, request->addr, request->value);
            break;
        case writeRequestWord:
            writeToBus(2, request->addr, request->value);
            break;
        case writeRequest: // due to historical reasons, writeRequest defaults to 32bits
        case writeRequestDoubleWord:
            writeToBus(4, request->addr, request->value);
            break;
        case writeRequestQuadWord:
            writeToBus(8, request->addr, request->value);
            break;
        case readRequestByte:
            readFromBus(1, request->addr);
            break;
        case readRequestWord:
            readFromBus(2, request->addr);
            break;
        case readRequest: // due to historical reasons, writeRequest defaults to 32bits
        case readRequestDoubleWord:
            readFromBus(4, request->addr);
            break;
        case readRequestQuadWord:
            readFromBus(8, request->addr);
            break;
        case resetPeripheral:
            reset();
            break;
        case disconnect:
        {
            SocketCommunicationChannel* channel;
            if((channel = dynamic_cast<SocketCommunicationChannel*>(communicationChannel)) != nullptr) {
                communicationChannel->sendSender(Protocol(ok, 0, 0));
                channel->disconnect();
            }
            break;
        }
        default:
            handleCustomRequestType(request);
            break;
    }
}

//=================================================
// NativeCommunicationChannel
//=================================================

extern void handleMainMessage(void* ptr);
extern void handleSenderMessage(void* ptr);
extern void receive(void* ptr);

EXTERNAL_AS(action_intptr, HandleMainMessage, handleMainMessage);
EXTERNAL_AS(action_intptr, HandleSenderMessage, handleSenderMessage);
EXTERNAL_AS(action_intptr, Receive, receive);

void NativeCommunicationChannel::sendMain(const Protocol message)
{
    handleMainMessage(new Protocol(message));
}

void NativeCommunicationChannel::sendSender(const Protocol message)
{
    handleSenderMessage(new Protocol(message));
}

void NativeCommunicationChannel::log(int logLevel, const char* data)
{
    handleSenderMessage(new Protocol(logMessage, strlen(data) + 1, (uint64_t)data));
    handleSenderMessage(new Protocol(logMessage, 0, logLevel));
}

Protocol* NativeCommunicationChannel::receive()
{
    Protocol* message = new Protocol;
    ::receive(message);
    return message;
}

//=================================================
// Functions exported to Renode
//=================================================

void initialize_native()
{
    renodeAgent = Init();
    renodeAgent->communicationChannel = new NativeCommunicationChannel();
}

void handle_request(Protocol* request)
{
    renodeAgent->handleRequest(request);
}

void reset_peripheral()
{
    renodeAgent->reset();
}
