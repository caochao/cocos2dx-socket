#ifndef DETAIL_NET_COMMON_HEAD_H

#define DETAIL_NET_COMMON_HEAD_H

#include "CCPlatformConfig.h"

#if (CC_TARGET_PLATFORM == CC_PLATFORM_WIN32) || (CC_TARGET_PLATFORM == CC_PLATFORM_WINRT)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN 1
#endif
#include <WINSOCK2.H>  
#pragma comment(lib,"WS2_32")

#include <WS2TCPIP.h>

#if (CC_TARGET_PLATFORM == CC_PLATFORM_WINRT)
#include "inet_ntop_winrt.h"
#endif

#else 


#include <netdb.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <netinet/in.h>
//#include <net/ethernet.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/times.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <netdb.h>
#include <unistd.h>
#include <arpa/inet.h>
#if defined(CC_TARGET_OS_IPHONE)
#include <sys/signal.h>
#else
#include <signal.h>
#endif

#endif


#ifdef WIN_PLATFORM

#define CP_SOCKET SOCKET

#else

#define CP_SOCKET int

#endif

#endif

