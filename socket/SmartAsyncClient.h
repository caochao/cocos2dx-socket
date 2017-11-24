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

// �Զ�Э������socket
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

	// ͬ������
	virtual bool SyncConnect( const char *szHost, int nPort );
	virtual bool IsSyncConnect();

	virtual void SetSingleRecvLen( unsigned int nLen );
	virtual unsigned int GetSingleRecvLen();

	// ���÷��ͳ�ʱʱ��(����)
	void SetRecvTimeout(int iTimeoutTick);
	// ���ý��ճ�ʱʱ��(����)
	void SetSendTimeout(int iTimeoutTick);
	// ��ȡ���ͳ�ʱ
	int GetSendTimeout();
	// ��ȡ���ճ�ʱ
	int GetRecvTimeout();

	//���û�����ӣ��򷵻ؿ��ַ���
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