#include "IAsyncClient.h"

using namespace simplecreator;


// 异步通信超时
#define DEF_SOCKET_ASYNC_SEND_TIMEOUT 10000
#define DEF_SOCKET_ASYNC_RECV_TIMEOUT 0
// 同步通信超时
#define DEF_SOCKET_SYNC_SEND_TIMEOUT 3000
#define DEF_SOCKET_SYNC_RECV_TIMEOUT 0

IAsyncClient::IAsyncClient()
{
	m_pCallbackMgr = nullptr;

	m_iSendTimeoutTick = 0;
	m_iRecvTimeoutTick = 0;
	m_bSyncMode = false;
}

IAsyncClient::~IAsyncClient()
{

}

void simplecreator::IAsyncClient::SetCallback(IAsyncClientCallback* pCallbackMgr)
{
	m_pCallbackMgr = pCallbackMgr;
}


void simplecreator::IAsyncClient::OnConnect()
{
	if (m_pCallbackMgr != nullptr)
	{
		m_pCallbackMgr->OnConnect(  );
	}
}
void simplecreator::IAsyncClient::OnError( int nErrorCode, int nScene )
{
	if (m_pCallbackMgr != nullptr)
	{
		m_pCallbackMgr->OnError( nErrorCode, nScene );
	}
}
void simplecreator::IAsyncClient::OnRecv( void *pBuffer, int nLen )
{
	if (m_pCallbackMgr != nullptr)
	{
		m_pCallbackMgr->OnRecv( pBuffer, nLen );
	}
}

void simplecreator::IAsyncClient::SetSyncMode(bool bSyncMode)
{
	m_bSyncMode = bSyncMode;
}

bool simplecreator::IAsyncClient::IsSyncMode()
{
	return m_bSyncMode;
}

void simplecreator::IAsyncClient::SetSendTimeout(int iTimeoutTick)
{
	m_iSendTimeoutTick = iTimeoutTick;
}

void simplecreator::IAsyncClient::SetRecvTimeout(int iTimeoutTick)
{
	m_iRecvTimeoutTick = iTimeoutTick;
}

int simplecreator::IAsyncClient::GetSendTimeout()
{
	if (m_iSendTimeoutTick > 0)
	{
		return m_iSendTimeoutTick;
	}
	if (m_bSyncMode)
	{
		return DEF_SOCKET_SYNC_SEND_TIMEOUT;
	}
	return DEF_SOCKET_ASYNC_SEND_TIMEOUT;
}

int simplecreator::IAsyncClient::GetRecvTimeout()
{
	if (m_iRecvTimeoutTick > 0)
	{
		return m_iRecvTimeoutTick;
	}
	if (m_bSyncMode)
	{
		return DEF_SOCKET_SYNC_RECV_TIMEOUT;
	}
	return DEF_SOCKET_ASYNC_RECV_TIMEOUT;
}
