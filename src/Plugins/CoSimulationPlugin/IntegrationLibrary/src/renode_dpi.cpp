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

static std::atomic<SocketCommunicationChannel*> socketChannel{nullptr};
static std::atomic<bool> connectThreadRunning{false};
static std::atomic<bool> shouldStopConnect{false};

// Initialised true at C++ static-init time, which runs once per DLL load
static std::atomic<bool> dllFreshSinceLoad{true};

#ifdef _WIN32
static HANDLE connectThreadHandle = NULL;
#else
static pthread_t connectThreadHandle;
static bool connectThreadJoinable = false;
#endif

struct ConnectArgs {
    int receiverPort;
    int senderPort;
    std::string address;
};

static void platformSleepMs(unsigned int ms)
{
#ifdef _WIN32
    Sleep(ms);
#else
    usleep(ms * 1000);
#endif
}

static void connectLoopBody(ConnectArgs* args)
{
    while (!shouldStopConnect.load()) {
        SocketCommunicationChannel* candidate = new SocketCommunicationChannel();
        candidate->connect(args->receiverPort, args->senderPort, args->address.c_str());

        if (candidate->isConnected()) {
            socketChannel.store(candidate, std::memory_order_release);
            break;
        }

        delete candidate;
        platformSleepMs(100);
    }
    connectThreadRunning.store(false);
    delete args;
}

#ifdef _WIN32
static unsigned __stdcall connectThreadEntry(void* arg)
{
    connectLoopBody(static_cast<ConnectArgs*>(arg));
    return 0;
}
#else
static void* connectThreadEntry(void* arg)
{
    connectLoopBody(static_cast<ConnectArgs*>(arg));
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

void renodeDPIConnect(int receiverPort, int senderPort, const char* address)
{
    if (renodeDPIIsConnected()) {
        return;
    }

    bool expected = false;
    if (!connectThreadRunning.compare_exchange_strong(expected, true)) {
        return;
    }

    joinConnectThread();

    ConnectArgs* args = new ConnectArgs;
    args->receiverPort = receiverPort;
    args->senderPort = senderPort;
    args->address = address;

    shouldStopConnect.store(false);

#ifdef _WIN32
    connectThreadHandle = (HANDLE)_beginthreadex(
        NULL, 0, connectThreadEntry, args, 0, NULL);
    if (connectThreadHandle == NULL) {
        delete args;
        connectThreadRunning.store(false);
    }
#else
    if (pthread_create(&connectThreadHandle, nullptr, connectThreadEntry, args) == 0) {
        connectThreadJoinable = true;
    } else {
        delete args;
        connectThreadRunning.store(false);
    }
#endif
}

void renodeDPIDisconnect()
{
    shouldStopConnect.store(true);
    joinConnectThread();
    SocketCommunicationChannel* ch = socketChannel.exchange(nullptr, std::memory_order_acq_rel);
    if (ch != nullptr) {
        ch->disconnect();
        delete ch;
    }
}

bool renodeDPIIsConnected()
{
    SocketCommunicationChannel* ch = socketChannel.load(std::memory_order_acquire);
    return ch != nullptr && ch->isConnected();
}

bool renodeDPIReceive(uint32_t* actionId, uint64_t* address, uint64_t* value, int32_t* peripheralIndex)
{
    SocketCommunicationChannel* ch = socketChannel.load(std::memory_order_acquire);
    if (ch == nullptr || !ch->isConnected()) {
        return false;
    }

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
    SocketCommunicationChannel* ch = socketChannel.load(std::memory_order_acquire);
    if (ch == nullptr || !ch->isConnected()) {
        return false;
    }
    ch->sendMain(Protocol(actionId, address, value, peripheralIndex));
    return true;
}

bool renodeDPISendToAsync(uint32_t actionId, uint64_t address, uint64_t value, int32_t peripheralIndex)
{
    SocketCommunicationChannel* ch = socketChannel.load(std::memory_order_acquire);
    if (ch == nullptr || !ch->isConnected()) {
        return false;
    }
    ch->sendSender(Protocol(actionId, address, value, peripheralIndex));
    return true;
}

bool renodeDPILog(int logLevel, const char* data)
{
    SocketCommunicationChannel* ch = socketChannel.load(std::memory_order_acquire);
    if (ch == nullptr || !ch->isConnected()) {
        return false;
    }
    ch->log(logLevel, data);
    return true;
}

bool renodeDPIIsDllFresh()
{
    return dllFreshSinceLoad.exchange(false, std::memory_order_acq_rel);
}
