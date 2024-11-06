//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#ifndef SOCKET_CHANNEL_H
#define SOCKET_CHANNEL_H
#include "communication_channel.h"
#include "../../libs/socket-cpp/Socket/TCPClient.h"

class SocketCommunicationChannel : public CommunicationChannel
{
public:
  SocketCommunicationChannel();
  void connect(int receiverPort, int senderPort, const char* address);
  void disconnect();
  bool getIsConnected();
  void handshakeValid();
  void log(int logLevel, const char* data) override;
  Protocol* receive() override;
  void sendMain(const Protocol message) override;
  void sendSender(const Protocol message) override;

private:
  bool isConnected;
  std::unique_ptr<CTCPClient> mainSocket;
  std::unique_ptr<CTCPClient> senderSocket;
};

#endif
