//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

#include "renode_dpi.h"
#include "communication/socket_channel.h"

#include <atomic>
#include <string>

#ifdef _WIN32
#include <windows.h>
#include <process.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

const unsigned int connectionRetryDelayMs = 200;
static std::atomic<SocketCommunicationChannel*> socketChannel{nullptr};
static std::atomic<ConnectionStatus> connectionStatus{Unconnected};

#ifdef _WIN32
static HANDLE connectThreadHandle = NULL;
#else
static pthread_t connectThreadHandle;
static bool connectThreadJoinable = false;
#endif

static void platformSleepMs(unsigned int ms)
{
#ifdef _WIN32
    Sleep(ms);
#else
    usleep(ms * 1000);
#endif
}

static bool tryConnect(SocketConnectionArgs* args)
{
    SocketCommunicationChannel* candidate = new SocketCommunicationChannel();
    candidate->connect(args);

    if (candidate->isConnected()) {
        socketChannel.store(candidate);
        connectionStatus.store(Connected);
        return true;
    }

    delete candidate;
    return false;
}

static void connectLoopBody(SocketConnectionArgs* args)
{
    while (connectionStatus.load() == Connecting) {
        if(tryConnect(args)) {
            break;
        }
        platformSleepMs(connectionRetryDelayMs);
    }
    delete args;
}

#ifdef _WIN32
static unsigned __stdcall connectThreadEntry(void* arg)
{
    connectLoopBody(static_cast<SocketConnectionArgs*>(arg));
    return 0;
}
#else
static void* connectThreadEntry(void* arg)
{
    connectLoopBody(static_cast<SocketConnectionArgs*>(arg));
    return nullptr;
}
#endif

static void joinConnectThread()
{
#ifdef _WIN32
    if (connectThreadHandle != NULL) {
        WaitForSingleObject(connectThreadHandle, INFINITE);
        CloseHandle(connectThreadHandle);
        connectThreadHandle = NULL;
    }
#else
    if (connectThreadJoinable) {
        pthread_join(connectThreadHandle, nullptr);
        connectThreadJoinable = false;
    }
#endif
}

static void renodeConnect(uint32_t receiverPort, uint32_t senderPort, const char* address, bool inBackground, uint32_t timeoutMs)
{
    // The only other thread that can modify the status is the connecting thread and it only sets Connected
    ConnectionStatus status = connectionStatus.load();

    if (status == Connecting || status == Connected) {
        return;
    }

    joinConnectThread();

    connectionStatus.store(Connecting);

    SocketConnectionArgs* args = new SocketConnectionArgs;
    args->receiverPort = receiverPort;
    args->senderPort = senderPort;
    args->address = address;
    args->handshakeTimeout = timeoutMs;

    if (!inBackground) {
        tryConnect(args);

        delete args;
    } else {
#ifdef _WIN32
        connectThreadHandle = (HANDLE)_beginthreadex(
            NULL, 0, connectThreadEntry, args, 0, NULL);
        if (connectThreadHandle == NULL) {
            connectionStatus.store(Error);
            delete args;
        }
#else
        if (pthread_create(&connectThreadHandle, nullptr, connectThreadEntry, args) == 0) {
            connectThreadJoinable = true;
        } else {
            connectionStatus.store(Error);
            delete args;
        }
#endif
    }
}

void renodeDPIConnect(uint32_t receiverPort, uint32_t senderPort, const char* address, uint32_t timeoutMs)
{
    renodeConnect(receiverPort, senderPort, address, false, timeoutMs);
}

void renodeDPIConnectInBackground(uint32_t receiverPort, uint32_t senderPort, const char* address, uint32_t timeoutMs)
{
    renodeConnect(receiverPort, senderPort, address, true, 0);
}

void renodeDPIDisconnect()
{
    connectionStatus.store(Disconnected);
    joinConnectThread();
    SocketCommunicationChannel* ch = socketChannel.exchange(nullptr, std::memory_order_acq_rel);
    if (ch != nullptr) {
        ch->disconnect();
        delete ch;
    }
}

bool renodeDPIReceive(uint32_t* actionId, uint64_t* address, uint64_t* value, int32_t* peripheralIndex)
{
    if (connectionStatus.load() != Connected) {
        return false;
    }

    SocketCommunicationChannel* ch = socketChannel.load(std::memory_order_acquire);

    Protocol *message = ch->receive();
    if (message == nullptr) {
        return false;
    }

    *actionId = message->actionId;
    *address = message->addr;
    *value = message->value;
    *peripheralIndex = message->peripheralIndex;

    delete message;
    return true;
}

bool renodeDPITryReceive(uint32_t* actionId, uint64_t* address, uint64_t* value, int32_t* peripheralIndex)
{
    if (connectionStatus.load() != Connected) {
        return false;
    }

    SocketCommunicationChannel* ch = socketChannel.load(std::memory_order_acquire);
    Protocol *message = ch->tryReceive();
    if (message == nullptr) {
        return false;
    }

    *actionId = message->actionId;
    *address = message->addr;
    *value = message->value;
    *peripheralIndex = message->peripheralIndex;

    delete message;
    return true;
}

bool renodeDPISend(uint32_t actionId, uint64_t address, uint64_t value, int32_t peripheralIndex)
{
    if (connectionStatus.load() != Connected) {
        return false;
    }

    SocketCommunicationChannel* ch = socketChannel.load(std::memory_order_acquire);
    ch->sendMain(Protocol(actionId, address, value, peripheralIndex));
    return true;
}

bool renodeDPISendToAsync(uint32_t actionId, uint64_t address, uint64_t value, int32_t peripheralIndex)
{
    if (connectionStatus.load() != Connected) {
        return false;
    }

    SocketCommunicationChannel* ch = socketChannel.load(std::memory_order_acquire);
    ch->sendSender(Protocol(actionId, address, value, peripheralIndex));
    return true;
}

bool renodeDPILog(int logLevel, const char* data)
{
    if (connectionStatus.load() != Connected) {
        return false;
    }

    SocketCommunicationChannel* ch = socketChannel.load(std::memory_order_acquire);
    ch->log(logLevel, data);
    return true;
}

int32_t renodeDPIGetConnectionStatus()
{
    return connectionStatus.load();
}
