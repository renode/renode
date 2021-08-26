//
// Copyright (c) 2010-2022 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef RENODE_H
#define RENODE_H
#include <string.h>
#include <stdlib.h>
#include "../../../../Infrastructure/src/Emulator/Cores/renode/include/renode_imports.h"

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

// Action must be in sync with Renode's ActionType.
// Append new actions to the end to preserve compatibility.
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
  pushDoubleWord = 11,
  getDoubleWord = 12,
};

enum LogLevel
{
  LOG_LEVEL_NOISY   = -1,
  LOG_LEVEL_DEBUG   = 0,
  LOG_LEVEL_INFO    = 1,
  LOG_LEVEL_WARNING = 2,
  LOG_LEVEL_ERROR   = 3
};

#endif
