#include "NetCommOperate.h"
#include <string>
using namespace std;
#if (defined(WIN32) || defined(WIN64))
#pragma comment(lib,"ws2_32.lib")
#endif

using namespace simplecreator;

bool NetCommonOperate::InitNet( int &nError )
{
#if (defined(WIN32) || defined(WIN64))
	WSADATA  Ws;
	if ( WSAStartup(MAKEWORD(2,2), &Ws) != 0 )
	{
		nError=GetLastError();
		return false;
	}
	else
	{
		nError=NET_OPERATE_SUCCEED;
		return true;
	}

#else
	nError=NET_OPERATE_SUCCEED;
    signal(SIGPIPE,SIG_IGN);
	return true;

#endif
}

bool NetCommonOperate::UnInitNet( int &nError )
{
#if (defined(WIN32) || defined(WIN64))
	if( WSACleanup()!=0 )
	{
		nError=WSAGetLastError();
		return false;
	}
	else
	{
		nError=NET_OPERATE_SUCCEED;
		return true;
	}


#else
	nError=NET_OPERATE_SUCCEED;
	return true;

#endif
}

bool NetCommonOperate::IsEffectiveSocket( CP_SOCKET sock )
{
	return -1==sock;
}

int NetCommonOperate::GetSysLastError()
{
// 	int nLastError=0;
// 	int nLen=sizeof(nLastError);
// 	getsockopt(sock, SOL_SOCKET, SO_ERROR, (char*)&nLastError, &nLen);
// 
// 	return nLastError;
#if (defined(WIN32) || defined(WIN64))
	return GetLastError();
#else
    return errno;
#endif
}

void NetCommonOperate::CloseSocket( CP_SOCKET sock )
{
#if (defined(WIN32) || defined(WIN64))
	closesocket(sock);
#else
	close(sock);
#endif
}

void NetCommonOperate::SetSockUnblock( CP_SOCKET sock )
{
#if (defined(WIN32) || defined(WIN64))
	u_long mode=1;
	ioctlsocket(sock,FIONBIO,&mode);
#else
    fcntl(sock, F_SETFL, O_NDELAY);
#endif
}

int NetCommonOperate::GetSocketError( CP_SOCKET sock )
{
#if (defined(CC_TARGET_OS_IPHONE) || defined(CC_TARGET_OS_MAC))
    unsigned int nLen=sizeof(int);
#else
    int nLen=sizeof(int);
#endif

    int nError=0;
    getsockopt(sock, SOL_SOCKET, SO_ERROR, (char*)&nError, &nLen);

    return nError;
}

bool NetCommonOperate::IsInProcess( int nErrorCode )
{
#if (defined(WIN32) || defined(WIN64))
	if( nErrorCode==WSAEWOULDBLOCK )
	{
		return true;
	}
#else
	if( nErrorCode==EINPROGRESS )
	{
		return true;
	}
#endif

	return false;
}

void simplecreator::NetCommonOperate::SetSendTimeout(CP_SOCKET pSock, int iTimeoutTick)
{
#if (defined(WIN32) || defined(WIN64))
	setsockopt(pSock, SOL_SOCKET, SO_SNDTIMEO, (const char*)&iTimeoutTick, sizeof(iTimeoutTick));
#else
	int sec = iTimeoutTick / 1000;
	int usec = iTimeoutTick - sec * 1000;
	struct timeval timeo = {sec, usec};
	socklen_t len = sizeof(timeo);
	setsockopt(pSock, SOL_SOCKET, SO_SNDTIMEO, &timeo, len);
#endif
}

void simplecreator::NetCommonOperate::SetRecvTimeout(CP_SOCKET pSock, int iTimeoutTick)
{
#if (defined(WIN32) || defined(WIN64))
	setsockopt(pSock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&iTimeoutTick, sizeof(iTimeoutTick));
#else
	int sec = iTimeoutTick / 1000;
	int usec = iTimeoutTick - sec * 1000;
	struct timeval timeo = {sec, usec};
	socklen_t len = sizeof(timeo);
	setsockopt(pSock, SOL_SOCKET, SO_RCVTIMEO, &timeo, len);
#endif
}

void simplecreator::NetCommonOperate::SetNoDelay(CP_SOCKET pSock, int on)
{
#if (defined(WIN32) || defined(WIN64))
	setsockopt(pSock, IPPROTO_TCP, TCP_NODELAY, (const char *)&on, sizeof(on));
#else
	setsockopt(pSock, IPPROTO_TCP, TCP_NODELAY, (void *)&on, sizeof(on));
#endif
}
