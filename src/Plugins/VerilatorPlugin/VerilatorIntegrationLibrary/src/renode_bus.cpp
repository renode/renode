//
// Copyright (c) 2010-2022 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "renode_bus.h"
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

void RenodeAgent::addBus(BaseTargetBus* bus)
{
    targetInterfaces.push_back(std::unique_ptr<BaseTargetBus>(bus));
    bus->setAgent(this);
}

void RenodeAgent::writeToBus(uint64_t addr, uint64_t value)
{
    try {
        targetInterfaces[0]->write(addr, value);
        communicationChannel->sendMain(Protocol(ok, 0, 0));
    }
    catch(const char* msg) {
        log(LOG_LEVEL_ERROR, msg);
        communicationChannel->sendMain(Protocol(error, 0, 0));
    }
}

void RenodeAgent::readFromBus(uint64_t addr)
{
    try {
        uint64_t readValue = targetInterfaces[0]->read(addr);
        communicationChannel->sendMain(Protocol(readRequest, addr, readValue));
    }
    catch(const char* msg) {
        log(LOG_LEVEL_ERROR, msg);
        communicationChannel->sendMain(Protocol(error, 0, 0));
    }
}

void RenodeAgent::pushToAgent(uint64_t addr, uint64_t value)
{
    communicationChannel->sendSender(Protocol(pushDoubleWord, addr, value));
}

uint64_t RenodeAgent::requestFromAgent(uint64_t addr)
{
    communicationChannel->sendSender(Protocol(getDoubleWord, addr, 0));
    Protocol* received = communicationChannel->receive();
    return received->value;
}

void RenodeAgent::tick(bool countEnable, uint64_t steps)
{
    for(auto& b : targetInterfaces)
        b->tick(countEnable, steps);
}

void RenodeAgent::timeoutTick(uint8_t* signal, uint8_t expectedValue, int timeout)
{
    for(auto& b : targetInterfaces)
        b->timeoutTick(signal, expectedValue, timeout);
}

void RenodeAgent::reset()
{
    for(auto& b : targetInterfaces)
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

    while(channel->isConnected) {
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
        case writeRequest:
            writeToBus(request->addr, request->value);
            break;
        case readRequest:
            readFromBus(request->addr);
            break;
        case resetPeripheral:
            reset();
            break;
        case disconnect:
        {
            SocketCommunicationChannel* channel;
            if((channel = dynamic_cast<SocketCommunicationChannel*>(communicationChannel)) != nullptr) {
                communicationChannel->sendSender(Protocol(ok, 0, 0));
                channel->isConnected = false;
            }
            break;
        }
        default:
            handleCustomRequestType(request);
            break;
    }
}

//=================================================
// SocketCommunicationChannel
//=================================================

SocketCommunicationChannel::SocketCommunicationChannel()
{
    ASocket::SettingsFlag dontLog = ASocket::NO_FLAGS;
    mainSocket.reset(new CTCPClient(NULL, dontLog));
    senderSocket.reset(new CTCPClient(NULL, dontLog));
}

void SocketCommunicationChannel::sendMain(const Protocol message)
{
    try {
        mainSocket->Send((char *)&message, sizeof(struct Protocol));
    }
    catch(const char* msg) {
        isConnected = false;
        throw msg;
    }
}

void SocketCommunicationChannel::sendSender(const Protocol message)
{
    try {
        senderSocket->Send((char *)&message, sizeof(struct Protocol));
    }
    catch(const char* msg) {
        isConnected = false;
        throw msg;
    }
}

void SocketCommunicationChannel::log(int logLevel, const char* data)
{
    sendSender(Protocol(logMessage, strlen(data), logLevel));
    senderSocket->Send(data, strlen(data));
}

Protocol* SocketCommunicationChannel::receive()
{
    Protocol* message = new Protocol;
    mainSocket->CTCPClient::Receive((char *)message,  sizeof(Protocol));
    return message;
}

void SocketCommunicationChannel::connect(int receiverPort, int senderPort, const char* address)
{
    mainSocket->Connect(address, std::to_string(receiverPort));
    senderSocket->Connect(address, std::to_string(senderPort));
    handshakeValid();
}

void SocketCommunicationChannel::handshakeValid()
{
    Protocol* received = receive();
    if(received->actionId == handshake) {
        sendMain(Protocol(handshake, 0, 0));
        isConnected = true;
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
