#ifndef NET_COMM_OPERATE_H
#define NET_COMM_OPERATE_H
#include "DetailNetCommonHead.h"

namespace simplecreator {

class NetCommonOperate
{
public:
	//初始化网络，如果成功，nError为NET_OPERATE_SUCCEED,如果失败，nError为失败的代码
	bool InitNet( int &nError );

	//逆初始化网络，如果成功，nError为NET_OPERATE_SUCCEED,如果失败，nError为失败的代码
	bool UnInitNet( int &nError );

	//通过值作简单判断是否有效,类似于(socket==INVALID_SOCKET)
	bool IsEffectiveSocket( CP_SOCKET sock );

	//设置socket为非阻塞
	void SetSockUnblock( CP_SOCKET sock );

	// 设置发送超时时间(毫秒)
	void SetRecvTimeout(CP_SOCKET pSock, int iTimeoutTick);
	// 设置接收超时时间(毫秒)
	void SetSendTimeout(CP_SOCKET pSock, int iTimeoutTick);
	//设置不延迟
	void SetNoDelay(CP_SOCKET pSock, int on);

	//获得系统错误
	int GetSysLastError();

	//通用关闭套接字
	void CloseSocket( CP_SOCKET sock );

	//获得socket的错误
	int GetSocketError( CP_SOCKET sock );

	bool IsInProcess( int nErrorCode );
public:

	//操作成功标记
	const static int NET_OPERATE_SUCCEED=0;

	const static int ms_NormalIPDotCount=3;
};

}

#endif