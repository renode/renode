//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

#include "renode_dpi.h"
#include "communication/socket_channel.h"

#define MAX_DPI_INSTANCES 8
static SocketCommunicationChannel *socketChannels[MAX_DPI_INSTANCES] = { nullptr };

extern "C" void renodeDPIConnectInst(int id, int receiverPort,
                                     int senderPort, const char *address)
{
    if(id < 0 || id >= MAX_DPI_INSTANCES) return;
    /* clean up any existing connection */
    if(socketChannels[id] != nullptr)
    {
        delete socketChannels[id];
    }
    socketChannels[id] = new SocketCommunicationChannel();
    socketChannels[id]->connect(receiverPort, senderPort, address);
}

extern "C" void renodeDPIDisconnectInst(int id)
{
    if(id < 0 || id >= MAX_DPI_INSTANCES) return;
    if(socketChannels[id] != nullptr)
    {
        socketChannels[id]->disconnect();
        delete socketChannels[id];
        socketChannels[id] = nullptr;
    }
}

extern "C" bool renodeDPIIsConnectedInst(int id)
{
    if(id < 0 || id >= MAX_DPI_INSTANCES) return false;
    return socketChannels[id] != nullptr &&
           socketChannels[id]->isConnected();
}

extern "C" bool renodeDPIReceiveInst(int id,
                                     uint32_t *actionId,
                                     uint64_t *address,
                                     uint64_t *value,
                                     int32_t *peripheralIndex)
{
    if(!renodeDPIIsConnectedInst(id)) return false;
    Protocol *msg = socketChannels[id]->receive();
    *actionId = msg->actionId;
    *address = msg->addr;
    *value = msg->value;
    *peripheralIndex = msg->peripheralIndex;
    delete msg;
    return true;
}

extern "C" bool renodeDPITryReceiveInst(int id,
                                        uint32_t *actionId,
                                        uint64_t *address,
                                        uint64_t *value,
                                        int32_t *peripheralIndex)
{
    if(!renodeDPIIsConnectedInst(id)) return false;
    Protocol msg;
    if(!socketChannels[id]->tryReceive(&msg)) return false;
    *actionId = msg.actionId;
    *address = msg.addr;
    *value = msg.value;
    *peripheralIndex = msg.peripheralIndex;
    return true;
}

extern "C" bool renodeDPISendInst(int id,
                                  uint32_t actionId,
                                  uint64_t address,
                                  uint64_t value,
                                  int32_t peripheralIndex)
{
    if(!renodeDPIIsConnectedInst(id)) return false;
    socketChannels[id]->sendMain(Protocol(actionId, address, value, peripheralIndex));
    return true;
}

extern "C" bool renodeDPISendToAsyncInst(int id,
                                         uint32_t actionId,
                                         uint64_t address,
                                         uint64_t value,
                                         int32_t peripheralIndex)
{
    if(!renodeDPIIsConnectedInst(id)) return false;
    socketChannels[id]->sendSender(Protocol(actionId, address, value, peripheralIndex));
    return true;
}

extern "C" bool renodeDPILogInst(int id,
                                 int logLevel,
                                 const char *data)
{
    if(!renodeDPIIsConnectedInst(id)) return false;
    socketChannels[id]->log(logLevel, data);
    return true;
}
