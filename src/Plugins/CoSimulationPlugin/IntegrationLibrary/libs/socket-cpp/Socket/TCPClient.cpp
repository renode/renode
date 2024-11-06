/**
* @file TCPClient.cpp
* @brief implementation of the TCP client class
* @author Mohamed Amine Mzoughi <mohamed-amine.mzoughi@laposte.net>
*/

#include "TCPClient.h"

CTCPClient::CTCPClient(const LogFnCallback oLogger,
                       const SettingsFlag eSettings /*= ALL_FLAGS*/) :
   ASocket(oLogger, eSettings),
   m_eStatus(DISCONNECTED),
   m_ConnectSocket(INVALID_SOCKET),
   m_pResultAddrInfo(nullptr)
   //m_uRetryCount(0),
   //m_uRetryPeriod(0)
{

}

// Method for setting receive timeout. Can be called after Connect
bool CTCPClient::SetRcvTimeout(unsigned int msec_timeout) {
#ifndef WINDOWS
	struct timeval t = ASocket::TimevalFromMsec(msec_timeout);

	return this->SetRcvTimeout(t);
#else
    int iErr;

    // it's expecting an int but it doesn't matter...
    iErr = setsockopt(m_ConnectSocket, SOL_SOCKET, SO_RCVTIMEO, (char*)&msec_timeout, sizeof(struct timeval));
    if (iErr < 0) {
        if (m_eSettingsFlags & ENABLE_LOG)
            m_oLog("[TCPServer][Error] CTCPClient::SetRcvTimeout : Socket error in SO_RCVTIMEO call to setsockopt.");

        return false;
    }

    return true;
#endif
}

#ifndef WINDOWS
bool CTCPClient::SetRcvTimeout(struct timeval timeout) {
	int iErr;

	iErr = setsockopt(m_ConnectSocket, SOL_SOCKET, SO_RCVTIMEO, (char*) &timeout, sizeof(struct timeval));
	if (iErr < 0) {
		if (m_eSettingsFlags & ENABLE_LOG)
			m_oLog("[TCPServer][Error] CTCPClient::SetRcvTimeout : Socket error in SO_RCVTIMEO call to setsockopt.");

		return false;
	}

	return true;
}
#endif

// Method for setting send timeout. Can be called after Connect
bool CTCPClient::SetSndTimeout(unsigned int msec_timeout) {
#ifndef WINDOWS
	struct timeval t = ASocket::TimevalFromMsec(msec_timeout);

	return this->SetSndTimeout(t);
#else
    int iErr;

    // it's expecting an int but it doesn't matter...
    iErr = setsockopt(m_ConnectSocket, SOL_SOCKET, SO_SNDTIMEO, (char*)&msec_timeout, sizeof(struct timeval));
    if (iErr < 0) {
        if (m_eSettingsFlags & ENABLE_LOG)
            m_oLog("[TCPServer][Error] CTCPClient::SetSndTimeout : Socket error in SO_SNDTIMEO call to setsockopt.");

        return false;
    }

    return true;
#endif
}

#ifndef WINDOWS
bool CTCPClient::SetSndTimeout(struct timeval timeout) {
	int iErr;

	iErr = setsockopt(m_ConnectSocket, SOL_SOCKET, SO_SNDTIMEO, (char*) &timeout, sizeof(struct timeval));
	if (iErr < 0) {
		if (m_eSettingsFlags & ENABLE_LOG)
			m_oLog("[TCPServer][Error] CTCPClient::SetSndTimeout : Socket error in SO_SNDTIMEO call to setsockopt.");

		return false;
	}

	return true;
}
#endif

// Connexion au serveur
bool CTCPClient::Connect(const std::string& strServer, const std::string& strPort)
{
   if (m_eStatus == CONNECTED)
   {
      Disconnect();
      if (m_eSettingsFlags & ENABLE_LOG)
         m_oLog("[TCPClient][Warning] Opening a new connexion. The last one was automatically closed.");
   }

   #ifdef WINDOWS
   ZeroMemory(&m_HintsAddrInfo, sizeof(m_HintsAddrInfo));
   /* AF_INET is used to specify the IPv4 address family. */
   m_HintsAddrInfo.ai_family = AF_INET;			
   /* SOCK_STREAM is used to specify a stream socket. */
   m_HintsAddrInfo.ai_socktype = SOCK_STREAM;
   /* IPPROTO_TCP is used to specify the TCP protocol. */
   m_HintsAddrInfo.ai_protocol = IPPROTO_TCP;

   /* Resolve the server address and port */
   int iResult = getaddrinfo(strServer.c_str(), strPort.c_str(), &m_HintsAddrInfo, &m_pResultAddrInfo);
   if (iResult != 0)
   {
      if (m_eSettingsFlags & ENABLE_LOG)
         m_oLog(StringFormat("[TCPClient][Error] getaddrinfo failed : %d", iResult));

      if (m_pResultAddrInfo != nullptr)
      {
         freeaddrinfo(m_pResultAddrInfo);
         m_pResultAddrInfo = nullptr;
      }

      return false;
   }

   // socket creation
   m_ConnectSocket = socket(m_pResultAddrInfo->ai_family,   // AF_INET
                            m_pResultAddrInfo->ai_socktype, // SOCK_STREAM
                            m_pResultAddrInfo->ai_protocol);// IPPROTO_TCP

   if (m_ConnectSocket == INVALID_SOCKET)
   {
      if (m_eSettingsFlags & ENABLE_LOG)
         m_oLog(StringFormat("[TCPClient][Error] socket failed : %d", WSAGetLastError()));

      freeaddrinfo(m_pResultAddrInfo);
      m_pResultAddrInfo = nullptr;
      return false;
   }

   // Fixes windows 0.2 second delay sending (buffering) data.
   int on = 1;
   int iErr;
   
   iErr = setsockopt(m_ConnectSocket, IPPROTO_TCP, TCP_NODELAY, (char*)&on, sizeof(on));
   if (iErr == INVALID_SOCKET)
   {
      if (m_eSettingsFlags & ENABLE_LOG)
         m_oLog("[TCPClient][Error] Socket error in call to setsockopt");

      closesocket(m_ConnectSocket);
      freeaddrinfo(m_pResultAddrInfo); m_pResultAddrInfo = nullptr;

      return false;
   }
   
   /*
   SOCKET ConnectSocket = INVALID_SOCKET;
   struct sockaddr_in clientService; 

   ConnectSocket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
   if (ConnectSocket == INVALID_SOCKET) {
      printf("Error at socket(): %ld\n", WSAGetLastError());
      WSACleanup();
      return 1;
   }

   // The sockaddr_in structure specifies the address family,
   // IP address, and port of the server to be connected to.
   clientService.sin_family = AF_INET;
   clientService.sin_addr.s_addr = inet_addr("127.0.0.1");
   clientService.sin_port = htons(27015);
   */

   // connexion to the server
   //unsigned uRetry = 0;
   //do
   //{
      iResult = connect(m_ConnectSocket,
                        m_pResultAddrInfo->ai_addr,
                        static_cast<int>(m_pResultAddrInfo->ai_addrlen));
//iResult = connect(m_ConnectSocket, (SOCKADDR*)&clientService, sizeof(clientService));

      //if (iResult != SOCKET_ERROR)
         //break;

      // retry mechanism
      //if (uRetry < m_uRetryCount)
         //if (m_eSettingsFlags & ENABLE_LOG)
            /*m_oLog(StringFormat("[TCPClient][Error] connect retry %u after %u second(s)",
            m_uRetryCount + 1, m_uRetryPeriod));*/

      //if (m_uRetryPeriod > 0)
      //{
         //for (unsigned uSec = 0; uSec < m_uRetryPeriod; uSec++)
            //Sleep(1000);
      //}
   //} while (iResult == SOCKET_ERROR && ++uRetry < m_uRetryCount);
   
   freeaddrinfo(m_pResultAddrInfo);
   m_pResultAddrInfo = nullptr;

   if (iResult != SOCKET_ERROR)
   {
      m_eStatus = CONNECTED;
      return true;
   }
   if (m_eSettingsFlags & ENABLE_LOG)
      m_oLog(StringFormat("[TCPClient][Error] Unable to connect to server : %d", WSAGetLastError()));

   #else
   memset(&m_HintsAddrInfo, 0, sizeof m_HintsAddrInfo);
   m_HintsAddrInfo.ai_family = AF_INET; // AF_INET or AF_INET6 to force version or use AF_UNSPEC
   m_HintsAddrInfo.ai_socktype = SOCK_STREAM;
   //m_HintsAddrInfo.ai_flags = 0;
   //m_HintsAddrInfo.ai_protocol = 0; /* Any protocol */

   int iAddrInfoRet = getaddrinfo(strServer.c_str(), strPort.c_str(), &m_HintsAddrInfo, &m_pResultAddrInfo);
   if (iAddrInfoRet != 0)
   {
      if (m_eSettingsFlags & ENABLE_LOG)
         m_oLog(StringFormat("[TCPClient][Error] getaddrinfo failed : %s", gai_strerror(iAddrInfoRet)));

      if (m_pResultAddrInfo != nullptr)
      {
         freeaddrinfo(m_pResultAddrInfo);
         m_pResultAddrInfo = nullptr;
      }

      return false;
   }

   /* getaddrinfo() returns a list of address structures.
    * Try each address until we successfully connect(2).
    * If socket(2) (or connect(2)) fails, we (close the socket
    * and) try the next address. */
   struct addrinfo* pResPtr = m_pResultAddrInfo;
   for (pResPtr = m_pResultAddrInfo; pResPtr != nullptr; pResPtr = pResPtr->ai_next)
   {
      // create socket
      m_ConnectSocket = socket(pResPtr->ai_family, pResPtr->ai_socktype, pResPtr->ai_protocol);
      if (m_ConnectSocket < 0) // or == -1
         continue;

      // connexion to the server
      int iConRet = connect(m_ConnectSocket, pResPtr->ai_addr, pResPtr->ai_addrlen);
      if (iConRet >= 0) // or != -1
      {
         /* Success */
         m_eStatus = CONNECTED;
         
         if (m_pResultAddrInfo != nullptr)
         {
            freeaddrinfo(m_pResultAddrInfo);
            m_pResultAddrInfo = nullptr;
         }

         return true;
      }

      close(m_ConnectSocket);
   }

   if (m_pResultAddrInfo != nullptr)
   {
      freeaddrinfo(m_pResultAddrInfo); /* No longer needed */
      m_pResultAddrInfo = nullptr;
   }

   /* No address succeeded */
   if (m_eSettingsFlags & ENABLE_LOG)
      m_oLog("[TCPClient][Error] no such host.");

   #endif

   return false;
}

bool CTCPClient::Send(const char* pData, const size_t uSize) const
{
   if (!pData || !uSize)
      return false;

   if (m_eStatus != CONNECTED)
   {
      if (m_eSettingsFlags & ENABLE_LOG)
         m_oLog("[TCPClient][Error] send failed : not connected to a server.");
      
      return false;
   }

   size_t total = 0;
   do
   {
      const int flags = 0;
      int nSent;

      nSent = send(m_ConnectSocket, pData + total, uSize - total, flags);

      if (nSent < 0)
      {
         if (m_eSettingsFlags & ENABLE_LOG)
            m_oLog("[TCPClient][Error] Socket error in call to send.");

         return false;
      }
      total += nSent;
   } while(total < uSize);
   
   return true;
}

bool CTCPClient::Send(const std::string& strData) const
{
   return Send(strData.c_str(), strData.length());
}

bool CTCPClient::Send(const std::vector<char>& Data) const
{
   return Send(Data.data(), Data.size());
}

/* ret > 0   : bytes received
 * ret == 0  : connection closed
 * ret < 0   : recv failed
 */
int CTCPClient::Receive(char* pData, const size_t uSize, bool bReadFully /*= true*/) const
{
   if (!pData || !uSize)
      return -2;

   if (m_eStatus != CONNECTED)
   {
      if (m_eSettingsFlags & ENABLE_LOG)
         m_oLog("[TCPClient][Error] recv failed : not connected to a server.");

      return -1;
   }

   #ifdef WINDOWS
   int tries = 0;
   #endif

   size_t total = 0;
   do
   {
      int nRecvd = recv(m_ConnectSocket, pData + total, uSize - total, 0);

      if (nRecvd == 0)
      {
         // peer shut down
         break;
      }
      
      #ifdef WINDOWS
      if ((nRecvd < 0) && (WSAGetLastError() == WSAENOBUFS))
      {
         // On long messages, Windows recv sometimes fails with WSAENOBUFS, but
         // will work if you try again.
         if ((tries++ < 1000))
         {
           Sleep(1);
           continue;
         }

         if (m_eSettingsFlags & ENABLE_LOG)
            m_oLog("[TCPClient][Error] Socket error in call to recv.");

         break;
      }
      #endif

      total += nRecvd;

   } while (bReadFully && (total < uSize));
   
   return total;
}

bool CTCPClient::Disconnect()
{
   if (m_eStatus != CONNECTED)
      return true;

   m_eStatus = DISCONNECTED;

   #ifdef WINDOWS
   // shutdown the connection since no more data will be sent
   int iResult = shutdown(m_ConnectSocket, SD_SEND);
   if (iResult == SOCKET_ERROR)
   {
      if (m_eSettingsFlags & ENABLE_LOG)
         m_oLog(StringFormat("[TCPClient][Error] shutdown failed : %d", WSAGetLastError()));
      
      return false;
   }
   closesocket(m_ConnectSocket);

   if (m_pResultAddrInfo != nullptr)
   {
      freeaddrinfo(m_pResultAddrInfo);
      m_pResultAddrInfo = nullptr;
   }
   #else
   close(m_ConnectSocket);
   #endif

   m_ConnectSocket = INVALID_SOCKET;

   return true;
}

CTCPClient::~CTCPClient()
{
   if (m_eStatus == CONNECTED)
      Disconnect();
}
