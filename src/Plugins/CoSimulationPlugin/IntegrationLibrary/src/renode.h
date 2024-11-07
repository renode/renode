//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef RENODE_H
#define RENODE_H
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

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

enum Action
{
#include "../hdl/includes/renode_action_enumerators.svh"
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
