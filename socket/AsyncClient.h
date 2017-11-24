#ifndef ASYNC_CLIENT_IPV4_H
#define ASYNC_CLIENT_IPV4_H

#include "IAsyncClient.h"
#include "DetailNetCommonHead.h"
#include "NetCommOperate.h"
#include "SocketOperThread.h"
#include <string>
#include <mutex> 

using std::string;

namespace simplecreator {

class AsyncClient:public IAsyncClient
{
public:
	AsyncClient();
	virtual ~AsyncClient();

	//发送数据
	virtual bool Send( const char *pData, unsigned int nLen );

	//接收数据，如果第一个参数为NULL，那么可以获得收到的数据的长度。如果第一个参数为NULL，第二个参数传入时指定了长度
	//那么拷贝指定长度的数据，但不会大于缓冲区的最大值，第二个参数将会返回实际拷贝的长度。 
	//virtual bool Recv( char *pData, unsigned int &nLen );

	//断开连接
	virtual bool Close();

	//获得上次操作错误
	virtual int GetLastError();

	//处理，每次调用此都会真正进行处理,如果都没有错误，那么返回true
	virtual bool Process();

	//连接的IP和端口
	virtual bool Connect( struct addrinfo *pAddrInfo, int nPort, bool bSyncMode=false );



	virtual bool IsConnect();

	virtual bool IsConnecting();

	virtual void SetSingleRecvLen( unsigned int nLen );
	virtual unsigned int GetSingleRecvLen();

	//如果没有连接，则返回空字符串
	virtual std::string GetHostIp();

protected:
	// 连接地址预处理
	virtual bool PreConnect(struct addrinfo *pAddrInfo);
	
private:
	void ClearFDSet();
	void ResetFDSet();
	void SetConnectResult( bool bSucceed );

	// 同步收发线程
	virtual bool SendThread(bool* bWaitExit);
	virtual bool RecvThread(bool* bWaitExit);

	void OnSyncError(int nErrorCode, int nScene, bool bClose=false);
	void CheckSyncSend();

	// 同步阻塞模式下并行收发处理
	virtual void StartSyncProcess();
	// 同步发送
	virtual bool SyncSend(const char *pData, unsigned int nLen);
	
protected:
	bool m_bConnect;
	bool m_bConnecting;
	bool m_bInit;
	int m_nLastError;

	NetCommonOperate m_netOperate;

	CP_SOCKET m_sock;

	string m_strHostIP;
private:
	fd_set m_fdRead;
	fd_set m_fdWrite;
	fd_set m_fdError;

	timeval m_timeOut;

	string m_strRecvBuffer;
	//string m_strSendBuffer;

	bool m_bSyncMode;
	SocketOperThread m_pSendThread;
	SocketOperThread m_pRecvThread;


	std::mutex m_pRecvMutex;
	bool m_bHasRecv;

	std::mutex m_pSendMutex;
	std::string m_sSendCacheStr;

	std::mutex m_pSocketMutex;

	string m_strSingleRecv;

	int m_nSingleRecvLen;

	const static int nDefaultSingleRecvLen=4096; //默认一次接收4K大小
};

}

#endif