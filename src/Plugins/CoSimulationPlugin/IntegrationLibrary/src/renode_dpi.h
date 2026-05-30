//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef RENODE_DPI_H
#define RENODE_DPI_H
#include "renode.h"

extern "C"
{
  void renodeDPIConnectInst(int id, int receiverPort, int senderPort, const char *address);
  void renodeDPIDisconnectInst(int id);
  bool renodeDPIIsConnectedInst(int id);
  bool renodeDPIReceiveInst(int id, uint32_t *actionId, uint64_t *address, uint64_t *value, int32_t *peripheralIndex);
  bool renodeDPITryReceiveInst(int id, uint32_t *actionId, uint64_t *address, uint64_t *value, int32_t *peripheralIndex);
  bool renodeDPISendInst(int id, uint32_t actionId, uint64_t address, uint64_t value, int32_t peripheralIndex);
  bool renodeDPISendToAsyncInst(int id, uint32_t actionId, uint64_t address, uint64_t value, int32_t peripheralIndex);
  bool renodeDPILogInst(int id, int logLevel, const char *data);
}

#endif
