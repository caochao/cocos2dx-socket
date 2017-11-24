#ifndef I_ASYNC_CLIENT_H
#define I_ASYNC_CLIENT_H
#include "NetCommOperate.h"
#include "IAsyncClientCallback.h"
#include <string>

namespace simplecreator {

//   TCP/IP协议异步客户端的基类，所有TCP异步客户端都需要从这里派生。

class IAsyncClient
{
public:
	IAsyncClient();
	virtual ~IAsyncClient();

	//发送数据
	virtual bool Send( const char *pData, unsigned int nLen )=0;


	//断开连接
	virtual bool Close()=0;

	//获得上次错误
	virtual int GetLastError()=0;

	//处理，每次调用此都会真正进行处理,如果都没有错误，那么返回true
	virtual bool Process()=0;

	//连接的IP和端口
	virtual bool Connect( struct addrinfo *pAddrInfo, int nPort, bool bSyncMode=false )=0;

	// 设置同步连接模式
	void SetSyncMode(bool bSyncMode);
	// 是否同步连接模式
	bool IsSyncMode();

	//是否连接
	virtual bool IsConnect()=0;

	//是否正在连接
	virtual bool IsConnecting()=0;

	//设置单次接收的大小
	virtual void SetSingleRecvLen( unsigned int nLen )=0;
	
	//获得单次接收的大小值
	virtual unsigned int GetSingleRecvLen()=0;

	//如果没有连接，则返回空字符串
	virtual std::string GetHostIp()=0;

	// 设置发送超时时间(毫秒)
	void SetRecvTimeout(int iTimeoutTick);
	// 设置接收超时时间(毫秒)
	void SetSendTimeout(int iTimeoutTick);
	// 获取发送超时
	int GetSendTimeout();
	// 获取接收超时
	int GetRecvTimeout();

	// 设置回调处理器
	void SetCallback(IAsyncClientCallback* pCallbackMgr);

	void OnConnect();
	void OnError( int nErrorCode, int nScene );
	void OnRecv( void *pBuffer, int nLen );

public:
	const static int MAX_SEND_LENGTH=65536;

private:
	// 回调处理对象
	IAsyncClientCallback* m_pCallbackMgr;

	int m_iSendTimeoutTick;
	int m_iRecvTimeoutTick;

	bool m_bSyncMode;
};

}

#endif