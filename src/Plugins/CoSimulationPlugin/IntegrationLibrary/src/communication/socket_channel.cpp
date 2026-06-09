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
    if (!mainSocket->Connect(address, std::to_string(receiverPort))) {
        return;
    }

    // To handle the partial-connect race we hold mainSocket
    // open and retry senderSocket briefly before giving up.
    bool senderOk = false;
    for (int i = 0; i < 20; ++i) {
        if (senderSocket->Connect(address, std::to_string(senderPort))) {
            senderOk = true;
            break;
        }
#ifdef _WIN32
        Sleep(50);
#else
        usleep(50000);
#endif
    }

    if (!senderOk) {
        mainSocket->Disconnect();
        return;
    }
    mainSocket->SetRcvTimeout(60000);
    senderSocket->SetRcvTimeout(60000);
    handshakeValid();

    if (connected) {
        // Once the handshake is done, drop back to a normal timeout so
        // request/response paths (read_transaction, write_transaction) fail
        // promptly if Renode goes away mid-operation.
        mainSocket->SetRcvTimeout(5000);
        senderSocket->SetRcvTimeout(5000);
    }
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

