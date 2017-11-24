#ifndef _AUTO_ASYNC_CLIENT_H_
#define _AUTO_ASYNC_CLIENT_H_

#include "IAsyncClient.h"
#include "IAsyncClientCallback.h"
#include "netdataoperate.h"
#include <string>
#include "CCLuaEngine.h"
#include <string>

USING_NS_CC;

namespace simplecreator {

// 自动协议连接socket
class SmartAsyncClient: public IAsyncClientCallback
{
public:
	bool SendData( CNetData *pNetData );


	virtual bool Connect( const char *szHost, int nPort, bool bSyncMode=false );
	virtual bool Process();
	virtual bool Close();
	virtual bool IsConnect();
	virtual bool IsConnecting();
	virtual int GetLastError();

	// 同步连接
	virtual bool SyncConnect( const char *szHost, int nPort );
	virtual bool IsSyncConnect();

	virtual void SetSingleRecvLen( unsigned int nLen );
	virtual unsigned int GetSingleRecvLen();

	// 设置发送超时时间(毫秒)
	void SetRecvTimeout(int iTimeoutTick);
	// 设置接收超时时间(毫秒)
	void SetSendTimeout(int iTimeoutTick);
	// 获取发送超时
	int GetSendTimeout();
	// 获取接收超时
	int GetRecvTimeout();

	//如果没有连接，则返回空字符串
	virtual std::string GetHostIp();

protected:
	SmartAsyncClient();
	~SmartAsyncClient();

private:

	bool checkCreateSocket(const char *szHost, int nPort, struct addrinfo* &pGetAddr);

	IAsyncClient* m_pSocketMgr;
	bool m_bUseIPV6;

	bool m_bSyncMode;

	int m_iSendTimeoutTick;
	int m_iRecvTimeoutTick;
};

}

#endif