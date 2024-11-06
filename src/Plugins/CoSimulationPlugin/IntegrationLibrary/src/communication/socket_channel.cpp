//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

#include "socket_channel.h"

SocketCommunicationChannel::SocketCommunicationChannel()
{
    ASocket::SettingsFlag dontLog = ASocket::NO_FLAGS;
    mainSocket.reset(new CTCPClient(NULL, dontLog));
    senderSocket.reset(new CTCPClient(NULL, dontLog));
}

void SocketCommunicationChannel::connect(int receiverPort, int senderPort, const char* address)
{
    mainSocket->Connect(address, std::to_string(receiverPort));
    senderSocket->Connect(address, std::to_string(senderPort));
    handshakeValid();
}

void SocketCommunicationChannel::disconnect()
{
    isConnected = false;
}

bool SocketCommunicationChannel::getIsConnected()
{
    return isConnected;
}

void SocketCommunicationChannel::handshakeValid()
{
    Protocol* received = receive();
    if(received->actionId == handshake) {
        sendMain(Protocol(handshake, 0, 0));
        isConnected = true;
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

