//
// Copyright (c) 2010-2021 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef RENODE_BUS_H
#define RENODE_BUS_H
#include <vector>
#include "buses/bus.h"
#include "../libs/socket-cpp/Socket/TCPClient.h"
#include "renode.h"

class RenodeAgent;
struct Protocol;

extern RenodeAgent* Init(void); //definition has to be provided in sim_main.cpp of verilated peripheral

extern "C"
{
  void initialize_native();
  void handle_request(Protocol* request);
  void reset_peripheral();
}

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
  virtual void timeoutTick(uint8_t* signal, uint8_t expectedValue, int timeout = 2000);
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
