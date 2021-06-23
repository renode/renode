//
// Copyright (c) 2010-2021 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef Renode_H
#define Renode_H
#include <string>
#include <vector>
#include <stdlib.h>
#include "buses/bus.h"
#include "../libs/socket-cpp/Socket/TCPClient.h"
#include "../../../Infrastructure/src/Emulator/Cores/renode/include/renode_imports.h"

class RenodeAgent;
struct Protocol;

extern RenodeAgent* Init(void); //definition has to be provided in sim_main.cpp of verilated peripheral

extern "C"
{
  void initialize_native();
  void handle_request(Protocol* request);
  void reset_peripheral();
}

// Protocol must be in sync with Renode's ProtocolMessage
#pragma pack(push, 1)
struct Protocol
{
  Protocol() = default;
  Protocol(int actionId, uint64_t addr, uint64_t value)
  {
    this->actionId = actionId;
    this->addr = addr;
    this->value = value;
  }

  int actionId;
  uint64_t addr;
  uint64_t value;
};
#pragma pack(pop)

// Action must be in sync with Renode's ActionType
enum Action
{
  invalidAction = 0,
  tickClock = 1,
  writeRequest = 2,
  readRequest = 3,
  resetPeripheral = 4,
  logMessage = 5,
  interrupt = 6,
  disconnect = 7,
  error = 8,
  ok = 9,
  handshake = 10,
  pushData = 11,
  getData = 12
};

enum LogLevel
{
  LOG_LEVEL_NOISY   = -1,
  LOG_LEVEL_DEBUG   = 0,
  LOG_LEVEL_INFO    = 1,
  LOG_LEVEL_WARNING = 2,
  LOG_LEVEL_ERROR   = 3
};

class CommunicationChannel
{
public:
  virtual void sendMain(const Protocol message) = 0;
  virtual void sendSender(const Protocol message) = 0;
  virtual void log(int logLevel, const char* data) = 0;
  virtual Protocol* receive() = 0;
};

class RenodeAgent
{
public:
  RenodeAgent(BaseBus* bus);
  virtual void addBus(BaseBus* bus);
  virtual void writeToBus(uint64_t addr, uint64_t value);
  virtual void readFromBus(uint64_t addr);
  virtual void pushToAgent(uint64_t addr, uint64_t value);
  virtual uint64_t requestFromAgent(uint64_t addr);
  virtual void tick(bool countEnable, uint64_t steps);
  virtual void reset();
  virtual void handleCustomRequestType(Protocol* message);
  virtual void log(int level, const char* fmt, ...);
  virtual struct Protocol* receive();

  virtual void simulate(int receiverPort, int senderPort, const char* address);

  std::vector<BaseBus*> interfaces;

protected:
  CommunicationChannel* communicationChannel;

private:
  friend void ::handle_request(Protocol* request);
  friend void ::initialize_native(void);
  friend void ::reset_peripheral(void);
};

class SocketCommunicationChannel : public CommunicationChannel
{
public:
  SocketCommunicationChannel();
  void sendMain(const Protocol message) override;
  void sendSender(const Protocol message) override;
  void log(int logLevel, const char* data) override;
  Protocol* receive() override;

private:
  void handshakeValid();
  void connect(int receiverPort, int senderPort, const char* address);
  
  std::unique_ptr<CTCPClient> mainSocket;
  std::unique_ptr<CTCPClient> senderSocket;
  bool isConnected;

  friend void RenodeAgent::simulate(int receiverPort, int senderPort, const char* address);
};

class NativeCommunicationChannel : public CommunicationChannel
{
public:
  NativeCommunicationChannel() = default;
  void sendMain(const Protocol message) override;
  void sendSender(const Protocol message) override;
  void log(int logLevel, const char* data) override;
  Protocol* receive() override;
};

#endif
