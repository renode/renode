//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef RENODE_CFU_H
#define RENODE_CFU_H
#include <stdarg.h>
#include <stdio.h>
#include "buses/cfu.h"
#include "renode.h"

class RenodeAgent;
struct Protocol;

enum CfuStatus
{
  CFU_OK      = 0,
  CFU_FAIL    = 1,
  CFU_TIMEOUT = 2,
};

extern RenodeAgent *Init(void); //definition has to be provided in sim_main.cpp of cosimulated CFU

extern "C"
{
  uint64_t execute(uint32_t functionID, uint32_t data0, uint32_t data1, int* error);
  void initialize_native();
  void handle_request(Protocol* request);
  void reset_peripheral();
}

class NativeCommunicationChannel
{
public:
  NativeCommunicationChannel() = default;
  void sendSender(const Protocol message);
  void log(int logLevel, const char* data);
  Protocol* receive();
};

class RenodeAgent
{
public:
  RenodeAgent(Cfu *cfu);
  virtual void reset();
  virtual uint64_t execute(uint32_t functionID, uint32_t data0, uint32_t data1, int* error);
  virtual void handleCustomRequestType(Protocol* message);
  virtual void log(int level, const char* fmt, ...);
  virtual void tick(bool countEnable, uint64_t steps);

  Cfu *cfu;

protected:
  NativeCommunicationChannel* communicationChannel;

private:
  friend void ::handle_request(Protocol* request);
  friend void ::initialize_native(void);
  friend void ::reset_peripheral(void);
};

#endif
