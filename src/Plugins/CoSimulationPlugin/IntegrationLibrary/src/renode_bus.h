//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef RENODE_BUS_H
#define RENODE_BUS_H
#include <memory>
#include <vector>

#include "../../../../Infrastructure/src/Emulator/Cores/renode/include/renode_imports.h"
#include "src/renode.h"
#include "src/buses/bus.h"
#include "src/communication/communication_channel.h"

class BaseBus;
class BaseInitiatorBus;
class BaseTargetBus;
class RenodeAgent;
struct Protocol;

extern RenodeAgent* Init(); //definition has to be provided in sim_main.cpp of cosimulated peripheral

extern "C"
{
  void initialize_native();
  void handle_request(Protocol* request);
  void reset_peripheral();
}

class RenodeAgent
{
public:
  RenodeAgent();
  virtual void addBus(BaseInitiatorBus* bus);
  virtual void addBus(BaseTargetBus* bus);
  virtual void writeToBus(int width, uint64_t addr, uint64_t value);
  virtual void readFromBus(int width, uint64_t addr);
  virtual void pushByteToAgent(uint64_t addr, uint8_t value);
  virtual void pushWordToAgent(uint64_t addr, uint16_t value);
  virtual void pushDoubleWordToAgent(uint64_t addr, uint32_t value);
  virtual uint64_t requestDoubleWordFromAgent(uint64_t addr);
  virtual void pushToAgent(Action action, uint64_t addr, uint64_t value);
  virtual uint64_t requestFromAgent(Action action, uint64_t addr);
  virtual void tick(bool countEnable, uint64_t steps);
  virtual void timeoutTick(uint8_t* signal, uint8_t expectedValue, int timeout = 2000);
  virtual void reset();
  virtual void fatalError();
  virtual void handleCustomRequestType(Protocol* message);
  virtual void log(int level, const char* fmt, ...);
  virtual struct Protocol* receive();
  virtual void registerInterrupt(uint8_t *irq, uint8_t irq_addr);
  virtual void handleInterrupts(void);
  virtual void connect(int receiverPort, int senderPort, const char* address);
  virtual void connectNative();
  virtual void simulate();
  virtual void handleRequest(Protocol* request);

  std::vector<std::unique_ptr<BaseTargetBus>> targetInterfaces;
  std::vector<std::unique_ptr<BaseInitiatorBus>> initatorInterfaces;

protected:
  void addBus(BaseBus* bus);
  struct Interrupt {
    uint8_t* irq;
    uint8_t prev_irq;
    uint8_t irq_addr;
  };

  std::vector<Interrupt> interrupts;
  CommunicationChannel* communicationChannel;
  BaseBus* firstInterface;

private:
  void handleDisconnect();
  friend void ::handle_request(Protocol* request);
  friend void ::initialize_native(void);
  friend void ::reset_peripheral(void);
};

class NativeCommunicationChannel : public CommunicationChannel
{
public:
  NativeCommunicationChannel() = default;
  void sendMain(const Protocol message) override;
  void sendSender(const Protocol message) override;
  void log(int logLevel, const char* data) override;
  Protocol* receive() override;
  bool isConnected() override;
};

#endif
