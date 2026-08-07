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
  void renodeDPIConnect(uint32_t receiverPort, uint32_t senderPort, const char *address, uint32_t timeoutMs);
  void renodeDPIConnectInBackground(uint32_t receiverPort, uint32_t senderPort, const char *address, uint32_t timeoutMs);
  void renodeDPIDisconnect();
  int32_t renodeDPIGetConnectionStatus();
  bool renodeDPITryReceive(uint32_t *actionId, uint64_t *address, uint64_t *value, int32_t *peripheralIndex);
  bool renodeDPIReceive(uint32_t *actionId, uint64_t *address, uint64_t *value, int32_t *peripheralIndex);
  bool renodeDPISend(uint32_t actionId, uint64_t address, uint64_t value, int32_t peripheralIndex);
  bool renodeDPISendToAsync(uint32_t actionId, uint64_t address, uint64_t value, int32_t peripheralIndex);
  bool renodeDPILog(int32_t logLevel, const char *data);

  typedef enum : int32_t {
    Unconnected = 0,
    NeedsReconnection = 1,
    Connecting = 2,
    Connected = 3,
    Disconnected = 4,  // Indicate graceful disconnection
    Error = 5  // Error while connecting
  } ConnectionStatus;
}

#endif
