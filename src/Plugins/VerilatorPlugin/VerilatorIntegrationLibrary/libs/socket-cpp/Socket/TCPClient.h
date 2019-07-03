/*
* @file TCPClient.h
* @brief wrapper for TCP client
*
* @author Mohamed Amine Mzoughi <mohamed-amine.mzoughi@laposte.net>
* @date 2013-05-11
*/

#ifndef INCLUDE_TCPCLIENT_H_
#define INCLUDE_TCPCLIENT_H_

#include <algorithm>
#include <cstddef>   // size_t
#include <cstdlib>
#include <cstring>   // strerror, strlen, memcpy, strcpy
#include <ctime>
#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <vector>

#include "Socket.h"

class CTCPSSLClient;

class CTCPClient : public ASocket
{
   friend class CTCPSSLClient;

public:
   explicit CTCPClient(const LogFnCallback oLogger, const SettingsFlag eSettings = ALL_FLAGS);
   ~CTCPClient() override;

   // copy constructor and assignment operator are disabled
   CTCPClient(const CTCPClient&) = delete;
   CTCPClient& operator=(const CTCPClient&) = delete;

   // Setters - Getters (for unit tests)
   /*inline*/// void SetProgressFnCallback(void* pOwner, const ProgressFnCallback& fnCallback);
   /*inline*/// void SetProxy(const std::string& strProxy);
   /*inline auto GetProgressFnCallback() const
   {
      return m_fnProgressCallback.target<int(*)(void*, double, double, double, double)>();
   }
   inline void* GetProgressFnCallbackOwner() const { return m_ProgressStruct.pOwner; }*/
   //inline const std::string& GetProxy() const { return m_strProxy; }
   //inline const unsigned char GetSettingsFlags() const { return m_eSettingsFlags; }

	// Session
   bool Connect(const std::string& strServer, const std::string& strPort); // connect to a TCP server
   bool Disconnect(); // disconnect from the TCP server
   bool Send(const char* pData, const size_t uSize) const; // send data to a TCP server
   bool Send(const std::string& strData) const;
   bool Send(const std::vector<char>& Data) const;
   int  Receive(char* pData, const size_t uSize, bool bReadFully = true) const;

   bool SetRcvTimeout(unsigned int msec_timeout);
   bool SetRcvTimeout(struct timeval Timeout);
   bool SetSndTimeout(unsigned int msec_timeout);
   bool SetSndTimeout(struct timeval Timeout);

   bool IsConnected() const { return m_eStatus == CONNECTED; }
	
protected:
   enum SocketStatus
   {
      CONNECTED,
      DISCONNECTED
   };

   SocketStatus m_eStatus;
   Socket m_ConnectSocket; // ConnectSocket
   //unsigned m_uRetryCount;
   //unsigned m_uRetryPeriod;

   struct addrinfo* m_pResultAddrInfo;
   struct addrinfo  m_HintsAddrInfo;
};

#endif
