//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

#include "renode_dpi.h"
#include "communication/socket_channel.h"

static SocketCommunicationChannel *socketChannel;

bool renodeDPIReceive(uint32_t* actionId, uint64_t* address, uint64_t* value)
{
    if(!socketChannel->getIsConnected())
    {
        return false;
    }
    Protocol *message = socketChannel->receive();
    *actionId = message->actionId;
    *address = message->addr;
    *value = message->value;
    delete message;
    return true;
}

void renodeDPIConnect(int receiverPort, int senderPort, const char* address)
{
    socketChannel = new SocketCommunicationChannel();
    socketChannel->connect(receiverPort, senderPort, address);
}

void renodeDPIDisconnect()
{
    socketChannel->disconnect();
}

bool renodeDPIIsConnected()
{
    return socketChannel->getIsConnected();
}

bool renodeDPISend(uint32_t actionId, uint64_t address, uint64_t value)
{
    if(!socketChannel->getIsConnected())
    {
        return false;
    }
    socketChannel->sendMain(Protocol(actionId, address, value));
    return true;
}

bool renodeDPISendToAsync(uint32_t actionId, uint64_t address, uint64_t value)
{
    if(!socketChannel->getIsConnected())
    {
        return false;
    }
    socketChannel->sendSender(Protocol(actionId, address, value));
    return true;
}

void renodeDPILog(int logLevel, const char* data)
{
    socketChannel->log(logLevel, data);
}
