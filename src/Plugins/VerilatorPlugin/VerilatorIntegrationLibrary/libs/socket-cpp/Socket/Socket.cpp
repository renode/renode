/**
* @file Socket.cpp
* @brief implementation of the Socket class
* @author Mohamed Amine Mzoughi <mohamed-amine.mzoughi@laposte.net>
*/

#include "Socket.h"

#include <iostream>
#include <vector>

#ifdef WINDOWS
WSADATA ASocket::s_wsaData;
#endif

ASocket::SocketGlobalInitializer& ASocket::SocketGlobalInitializer::instance()
{
   static SocketGlobalInitializer inst{};
   return inst;
}

ASocket::SocketGlobalInitializer::SocketGlobalInitializer()
{
   // In windows, this will init the winsock DLL stuff
#ifdef WINDOWS
   // MAKEWORD(2,2) version 2.2 of Winsock
   int iWinSockInitResult = WSAStartup(MAKEWORD(2, 2), &s_wsaData);

   if (iWinSockInitResult != 0)
   {
      std::cerr << ASocket::StringFormat("[TCPClient][Error] WSAStartup failed : %d", iWinSockInitResult);
   }
#endif
}

ASocket::SocketGlobalInitializer::~SocketGlobalInitializer()
{
#ifdef WINDOWS
   /* call WSACleanup when done using the Winsock dll */
   WSACleanup();
#endif
}

/**
* @brief constructor of the Socket
*
* @param Logger - a callabck to a logger function void(const std::string&)
*
*/
ASocket::ASocket(const LogFnCallback& oLogger,
                 const SettingsFlag eSettings /*= ALL_FLAGS*/) :
   m_oLog(oLogger),
   m_eSettingsFlags(eSettings),
   m_globalInitializer(SocketGlobalInitializer::instance())
{

}

/**
* @brief destructor of the socket object
* It's a pure virtual destructor but an implementation is provided below.
* this to avoid creating a dummy pure virtual method to transform the class
* to an abstract one.
*/
ASocket::~ASocket()
{

}

/**
* @brief returns a formatted string
*
* @param [in] strFormat string with one or many format specifiers
* @param [in] parameters to be placed in the format specifiers of strFormat
*
* @retval string formatted string
*/
std::string ASocket::StringFormat(const std::string strFormat, ...)
{
   va_list args;
   va_start (args, strFormat);
   size_t len = std::vsnprintf(NULL, 0, strFormat.c_str(), args);
   va_end (args);
   std::vector<char> vec(len + 1);
   va_start (args, strFormat);
   std::vsnprintf(&vec[0], len + 1, strFormat.c_str(), args);
   va_end (args);
   return &vec[0];
}

/**
* @brief waits for a socket's read status change
*
* @param [in] sd socket descriptor to be selected
* @param [in] msec waiting period in milliseconds, a value of 0 implies no timeout
*
* @retval int 0 on timeout, -1 on error and 1 on success.
*/
int ASocket::SelectSocket(const ASocket::Socket sd, const size_t msec)
{
   if (sd < 0)
   {
      return -1;
   }

   struct timeval tval;
   struct timeval* tvalptr = nullptr;
   fd_set rset;
   int res;

   if (msec > 0)
   {
      tval.tv_sec = msec / 1000;
      tval.tv_usec = (msec % 1000) * 1000;
      tvalptr = &tval;
   }

   FD_ZERO(&rset);
   FD_SET(sd, &rset);

   // block until socket is readable.
   res = select(sd + 1, &rset, nullptr, nullptr, tvalptr);

   if (res <= 0)
      return res;

   if (!FD_ISSET(sd, &rset))
      return -1;

   return 1;
}

/**
* @brief waits for a set of sockets read status change
*
* @param [in] pSocketsToSelect pointer to an array of socket descriptors to be selected
* @param [in] count elements count of pSocketsToSelect
* @param [in] msec waiting period in milliseconds, a value of 0 implies no timeout
* @param [out] selectedIndex index of the socket that is ready to be read
*
* @retval int 0 on timeout, -1 on error and 1 on success.
*/
int ASocket::SelectSockets(const ASocket::Socket* pSocketsToSelect, const size_t count,
                           const size_t msec, size_t& selectedIndex)
{
   if (!pSocketsToSelect || count == 0)
   {
      return -1;
   }

   fd_set rset;
   int res = -1;

   struct timeval tval;
   struct timeval* tvalptr = nullptr;
   if (msec > 0)
   {
      tval.tv_sec = msec / 1000;
      tval.tv_usec = (msec % 1000) * 1000;
      tvalptr = &tval;
   }

   FD_ZERO(&rset);

   int max_fd = -1;
   for (size_t i = 0; i < count; i++)
   {
      FD_SET(pSocketsToSelect[i], &rset);

      if (pSocketsToSelect[i] > max_fd)
      {
         max_fd = pSocketsToSelect[i];
      }
   }

   // block until one socket is ready to read.
   res = select(max_fd + 1, &rset, nullptr, nullptr, tvalptr);

   if (res <= 0)
      return res;

   // find the first socket which has some activity.
   for (size_t i = 0; i < count; i++)
   {
      if (FD_ISSET(pSocketsToSelect[i], &rset))
      {
         selectedIndex = i;
         return 1;
      }
   }

   return -1;
}

/**
* @brief converts a value representing milliseconds into a struct timeval
*
* @param [time_msec] a time value in milliseconds
*
* @retval time_msec converted to struct timeval
*/
struct timeval ASocket::TimevalFromMsec(unsigned int time_msec){
   struct timeval t;

   t.tv_sec = time_msec / 1000;
   t.tv_usec = (time_msec % 1000) * 1000;

   return t;
}
