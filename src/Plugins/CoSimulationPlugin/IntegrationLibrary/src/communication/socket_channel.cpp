//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

#include "socket_channel.h"

#ifdef _WIN32
#include <winsock2.h>
#else
#include <sys/ioctl.h>
#endif

SocketCommunicationChannel::SocketCommunicationChannel()
    : connected(false)
{
    ASocket::SettingsFlag dontLog = ASocket::NO_FLAGS;
    mainSocket.reset(new CTCPClient(NULL, dontLog));
    senderSocket.reset(new CTCPClient(NULL, dontLog));
}

void SocketCommunicationChannel::connect(int receiverPort, int senderPort, const char* address)
{
    bool mainOk = mainSocket->Connect(address, std::to_string(receiverPort));
    bool senderOk = senderSocket->Connect(address, std::to_string(senderPort));
    if (!mainOk || !senderOk) {
        return;
    }
    mainSocket->SetRcvTimeout(2000);
    senderSocket->SetRcvTimeout(2000);
    handshakeValid();
}

void SocketCommunicationChannel::disconnect()
{
    connected = false;
}

bool SocketCommunicationChannel::isConnected()
{
    return connected;
}

void SocketCommunicationChannel::handshakeValid()
{
    Protocol* received = receive();
    if (received == nullptr) {
        mainSocket->Disconnect();
        senderSocket->Disconnect();
        return;
    }
    if (received->actionId == handshake) {
        sendMain(Protocol(handshake, 0, 0, noPeripheralIndex));
        connected = true;
    } else {
        mainSocket->Disconnect();
        senderSocket->Disconnect();
    }
    delete received;
}

void SocketCommunicationChannel::log(int logLevel, const char* data)
{
    sendSender(Protocol(logMessage, strlen(data), logLevel, noPeripheralIndex));
    senderSocket->Send(data, strlen(data));
}

Protocol* SocketCommunicationChannel::receive()
{
    Protocol* message = new Protocol;
    int ret = mainSocket->CTCPClient::Receive((char *)message, sizeof(Protocol), true);

    if(ret <= 0) {
        delete message;
        return nullptr;
    }

    return message;
}

Protocol* SocketCommunicationChannel::tryReceive()
{
#ifdef _WIN32
    u_long available = 0;
    if (ioctlsocket(mainSocket->GetSocketDescriptor(), FIONREAD, &available) != 0) {
        return nullptr;
    }
#else
    int available = 0;
    if (ioctl(mainSocket->GetSocketDescriptor(), FIONREAD, &available) != 0) {
        return nullptr;
    }
#endif

    if (available < (int)sizeof(Protocol)) {
        return nullptr;
    }

    Protocol* message = new Protocol;
    int ret = mainSocket->CTCPClient::Receive((char *)message, sizeof(Protocol), true);
    if (ret <= 0) {
        delete message;
        return nullptr;
    }
    return message;
}

void SocketCommunicationChannel::sendMain(const Protocol message)
{
    try {
        mainSocket->Send((char *)&message, sizeof(struct Protocol));
    }
    catch(const char* msg) {
        connected = false;
        throw msg;
    }
}

void SocketCommunicationChannel::sendSender(const Protocol message)
{
    try {
        senderSocket->Send((char *)&message, sizeof(struct Protocol));
    }
    catch(const char* msg) {
        connected = false;
        throw msg;
    }
}

