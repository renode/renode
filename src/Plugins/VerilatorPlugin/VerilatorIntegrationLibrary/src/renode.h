//
// Copyright (c) 2010-2019 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include <zmq.hpp>
#include <string>
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

  int actionId;
  unsigned long addr;
  unsigned long value;
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
  handshake = 10
};

class RenodeAgent
{
public:
  RenodeAgent(BaseBus* bus);
  void simulate(int receiverPort, int senderPort);
  void log(int logLevel, std::string message);

protected:
  virtual void writeToBus(unsigned long addr, unsigned long value);
  virtual void readFromBus(unsigned long addr);
  void mainSocketSend(Protocol message);
  void senderSocketSend(Protocol request);
  void senderSocketSend(std::string text);
  virtual void handleCustomRequestType(Protocol* message);
  BaseBus* bus;

private:
  zmq::context_t context;
  zmq::socket_t mainSocket;
  zmq::socket_t senderSocket;
  bool isConnected;
  void handshakeValid();
  struct Protocol* receive();
};
