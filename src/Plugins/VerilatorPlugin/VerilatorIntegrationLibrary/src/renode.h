//
// Copyright (c) 2010-2021 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef Renode_H
#define Renode_H
#include <zmq.hpp>
#include <string>
#include <vector>
#include "buses/bus.h"

// Protocol must be in sync with Renode's ProtocolMessage
#pragma pack(push, 1)
struct Protocol
{
  Protocol(int actionId, unsigned long addr, unsigned long value)
  {
    this->actionId = actionId;
    this->addr = addr;
    this->value = value;
  }

  uint32_t actionId;
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

class RenodeAgent
{
public:
  RenodeAgent(BaseBus* bus);
  void simulate(int receiverPort, int senderPort);
  void log(int logLevel, std::string message);
  void addBus(BaseBus* bus);
  virtual void pushToAgent(unsigned long addr, unsigned long value);
  virtual unsigned long requestFromAgent(unsigned long addr);
protected:
  virtual void tick(bool countEnable, unsigned long steps);
  virtual void reset();
  virtual void writeToBus(unsigned long addr, unsigned long value);
  virtual void readFromBus(unsigned long addr);
  void mainSocketSend(Protocol message);
  void senderSocketSend(Protocol request);
  void senderSocketSend(std::string text);
  virtual void handleCustomRequestType(Protocol* message);
  std::vector<BaseBus*> interfaces;

private:
  zmq::context_t context;
  zmq::socket_t mainSocket;
  zmq::socket_t senderSocket;
  bool isConnected;
  void handshakeValid();
  struct Protocol* receive();
};
#endif
