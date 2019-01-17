//
// Copyright (c) 2010-2019 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "renode.h"

RenodeAgent::RenodeAgent(BaseBus* bus)
    : context(1),
      mainSocket(context, ZMQ_PAIR),
      senderSocket(context, ZMQ_PAIR) {
    this->bus = bus;
    bus->tickCounter = 0;
}

void RenodeAgent::writeToBus(unsigned long addr, unsigned long value) {
    bus->write(addr, value);
}

unsigned long RenodeAgent::readFromBus(unsigned long addr) {
    return bus->read(addr);
}

void RenodeAgent::simulate(std::string receiverPort, std::string senderPort) {
    
    mainSocket.connect("tcp://localhost:" + receiverPort);
    senderSocket.connect("tcp://localhost:" + senderPort);
    Protocol *result;
    bool isFinished = false;
    bus->reset();

    while (!isFinished) {
        result = receive();
        switch(result->actionId) {
            case tickClock:
                bus->tick(result->value - bus->tickCounter);
                bus->tickCounter = 0;
                break;
            case writeRequest:
                writeToBus(result->addr, result->value);
                break;
            case readRequest:
                replyBusRequest(Protocol(readRequest, result->addr, readFromBus(result->addr)));
                break;
            case resetPeripheral:
                bus->reset();
                break;    
            case disconnect:
                isFinished = true;
                break;
            default:
                handleCustom(result);
                break;
        }
    }
}


void RenodeAgent::log(int logLevel, std::string data) {
    send(Protocol(logMessage, 0, 0));
    senderSocket.send(&logLevel, sizeof(int));
    zmq::message_t message(data.size());
    std::memcpy (message.data(), data.data(), data.size());
    senderSocket.send(message);
}

void RenodeAgent::replyBusRequest(Protocol message) {  
    mainSocket.send(&message, sizeof(struct Protocol)); 
}

void RenodeAgent::send(Protocol request) {
    senderSocket.send(&request, sizeof(Protocol));
}

Protocol* RenodeAgent::receive() {
    size_t length = sizeof(Protocol);
    char *buffer = new char[length];
    mainSocket.recv(buffer, length);
    Protocol *result = (Protocol *)buffer;
    return result;
}




