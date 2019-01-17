//
// Copyright (c) 2010-2019 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include <zmq.hpp>
#include <string>
#include "buses/bus.h"

#pragma pack(push, 1)
  struct Protocol {
    Protocol(int actionId, unsigned long addr, unsigned long value) {
      this->actionId = actionId;
      this->addr = addr;
      this->value = value;
    }

    int actionId;
    unsigned long addr;
    unsigned long value;
  };
#pragma pack(pop)

enum Action  {
  tickClock = 0,
  writeRequest = 1,
  readRequest = 2,
  resetPeripheral = 3,
  logMessage = 4,
  interrupt = 5,
  disconnect = 6
};

class RenodeAgent {
public:
  RenodeAgent(BaseBus* bus);
  void simulate(std::string receiverPort, std::string senderPort);
  void log(int logLevel, std::string message);
  
protected:
  virtual void writeToBus(unsigned long addr, unsigned long value);
  virtual unsigned long readFromBus(unsigned long addr);
  void replyBusRequest(Protocol message);
  virtual void handleCustom(Protocol* message) = 0;
  void send(Protocol request);
  BaseBus* bus;

private:
  zmq::context_t context;
  zmq::socket_t mainSocket;
  zmq::socket_t senderSocket;
  struct Protocol* receive();
};
