//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef COMMUNICATION_CHANNEL_H
#define COMMUNICATION_CHANNEL_H
#include "../renode.h"

class CommunicationChannel
{
public:
  virtual void log(int logLevel, const char* data) = 0;
  virtual Protocol* receive() = 0;
  virtual void sendMain(const Protocol message) = 0;
  virtual void sendSender(const Protocol message) = 0;
};

#endif
