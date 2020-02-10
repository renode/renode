//
// Copyright (c) 2010-2019 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "renode.h"

#define IO_THREADS 1

RenodeAgent::RenodeAgent(BaseBus* bus)
    : context(IO_THREADS),
      mainSocket(context, ZMQ_PAIR),
      senderSocket(context, ZMQ_PAIR)
{
    this->bus = bus;
    bus->tickCounter = 0;
}

void RenodeAgent::writeToBus(unsigned long addr, unsigned long value)
{
    try {
        bus->write(addr, value);
        mainSocketSend(Protocol(ok, 0, 0));
    }
    catch(const char* msg) {
        log(3, msg);
        mainSocketSend(Protocol(error, 0, 0));
        isConnected = false;
    }
}

void RenodeAgent::readFromBus(unsigned long addr)
{
    try {
        unsigned long readValue = bus->read(addr);
        mainSocketSend(Protocol(readRequest, addr, readValue));
    }
    catch(const char* msg) {
        log(3, msg);
        mainSocketSend(Protocol(error, 0, 0));
        isConnected = false;
    }
}

void RenodeAgent::handshakeValid()
{
    Protocol* received = receive();
    if(received->actionId == handshake) {
        mainSocketSend(Protocol(handshake, 0, 0));
        isConnected = true;
    }
}

void RenodeAgent::simulate(int receiverPort, int senderPort)
{
    mainSocket.connect("tcp://localhost:" + std::to_string(receiverPort));
    senderSocket.connect("tcp://localhost:" + std::to_string(senderPort));

    Protocol *result;
    long ticks;
    unsigned long readValue;
    handshakeValid();
    bus->reset();

    while(isConnected) {
        result = receive();
        switch(result->actionId) {
            case invalidAction:
                break;
            case tickClock:
                ticks = result->value - bus->tickCounter;
                if(ticks < 0) {
                    bus->tickCounter -= result->value;
                }
                else {
                    bus->tick(false, ticks);
                }
                bus->tickCounter = 0;
                break;
            case writeRequest:
                writeToBus(result->addr, result->value);
                break;
            case readRequest:
                readFromBus(result->addr);
                break;
            case resetPeripheral:
                bus->reset();
                break;
            case disconnect:
                isConnected = false;
                senderSocketSend(Protocol(ok, 0, 0));
                break;
            default:
                handleCustomRequestType(result);
                break;
        }
    }
}

void RenodeAgent::handleCustomRequestType(Protocol* message)
{
    log(2, std::string("Unhandled request type: %d", message->actionId));
}

void RenodeAgent::log(int logLevel, std::string data)
{
    senderSocketSend(Protocol(logMessage, 0, logLevel));
    senderSocketSend(data);
}

void RenodeAgent::mainSocketSend(Protocol message)
{
    mainSocket.send(&message, sizeof(struct Protocol));
}

void RenodeAgent::senderSocketSend(Protocol request)
{
    senderSocket.send(&request, sizeof(Protocol));
}

void RenodeAgent::senderSocketSend(std::string text)
{
    zmq::message_t message(text.size());
    std::memcpy (message.data(), text.data(), text.size());
    senderSocket.send(message);
}

Protocol* RenodeAgent::receive()
{
    size_t length = sizeof(Protocol);
    char *buffer = new char[length];
    mainSocket.recv(buffer, length);
    return (Protocol *)buffer;
}