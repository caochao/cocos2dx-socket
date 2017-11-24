#include "SmartAsyncClient.h"

#include "AsyncClient.h"

#if CC_TARGET_PLATFORM != CC_PLATFORM_WINRT
#include "AsyncClientV6.h"
#endif

using namespace cocos2d;
using namespace std;

using namespace simplecreator;

SmartAsyncClient::SmartAsyncClient()
{
	m_bUseIPV6 = false;
	m_pSocketMgr = nullptr;
	m_bSyncMode = false;

	m_iSendTimeoutTick = 0;
	m_iRecvTimeoutTick = 0;
}

SmartAsyncClient::~SmartAsyncClient()
{
	if (m_pSocketMgr != nullptr)
	{
		delete m_pSocketMgr;
		m_pSocketMgr = nullptr;
	}
}


bool simplecreator::SmartAsyncClient::SyncConnect(const char *szHost, int nPort)
{
	return Connect(szHost, nPort, true);
}

bool simplecreator::SmartAsyncClient::IsSyncConnect()
{
	return m_bSyncMode;
}


bool SmartAsyncClient::Connect( const char *szHost, int nPort, bool bSyncMode/*=false */ )
{
	struct addrinfo* pGetAddr = nullptr;
	if (!checkCreateSocket(szHost, nPort, pGetAddr))
	{
		return false;
	}

	if (m_pSocketMgr == nullptr)
	{
		return false;
	}

	m_bSyncMode = bSyncMode;
	return m_pSocketMgr->Connect( pGetAddr, nPort, m_bSyncMode );
}

bool SmartAsyncClient::checkCreateSocket(const char *szHost, int nPort, struct addrinfo* &pGetAddr)
{
	// 自动识别网络类型
	bool bChooseIPV6 = false;


	char szPort[10] = {0}; // string to be converted
	sprintf( szPort, "%d", nPort );


	
	struct addrinfo *result;  

	struct addrinfo addrCriteria;  
	memset(&addrCriteria, 0, sizeof(addrCriteria));  // bzero
	addrCriteria.ai_family=AF_UNSPEC;  
	addrCriteria.ai_socktype=SOCK_STREAM;  
	addrCriteria.ai_protocol=IPPROTO_TCP;  
	int ret = getaddrinfo(szHost, szPort, &addrCriteria, &result); 
	if (ret != 0) { 
		return false; 
	} 
	

	struct addrinfo *pCurAddr = nullptr;  
	struct addrinfo *pLastIpv4 = nullptr;
	struct addrinfo *pLastIpv6 = nullptr;
	struct addrinfo *pFirstAddr = nullptr;
	for (pCurAddr = result; pCurAddr != NULL; pCurAddr = pCurAddr->ai_next) { 
		switch (pCurAddr->ai_family){ 
		case AF_UNSPEC: 
			break; 
		case AF_INET: 
			pLastIpv4 = pCurAddr;
			if (pFirstAddr == nullptr) pFirstAddr = pCurAddr;
			break; 

#if CC_TARGET_PLATFORM != CC_PLATFORM_WINRT
		case AF_INET6: 
			pLastIpv6 = pCurAddr;
			if (pFirstAddr == nullptr) pFirstAddr = pCurAddr;
			break; 
#endif
		} 
	} 	 

	// 优先选择ipv6 (默认地址是ipv6才连)
	if (pLastIpv6 != nullptr && pFirstAddr == pLastIpv6)
	{
		bChooseIPV6 = true;
		pGetAddr = pLastIpv6;
	}
	else if(pLastIpv4 != nullptr)
	{
		bChooseIPV6 = false;
		pGetAddr = pLastIpv4;
	}
	else
	{
		return false;
	}

#if CC_TARGET_PLATFORM != CC_PLATFORM_WINRT
	// 根据需求创建对应的协议
	if (bChooseIPV6)
	{
		if (m_pSocketMgr != nullptr && !m_bUseIPV6)
		{
			delete m_pSocketMgr;
			m_pSocketMgr = nullptr;
		}
		if (m_pSocketMgr == nullptr)
		{
			m_pSocketMgr = new AsyncClientV6();
		}
	}
	else
#endif
	{
		if (m_pSocketMgr != nullptr && m_bUseIPV6)
		{
			delete m_pSocketMgr;
			m_pSocketMgr = nullptr;
		}
		if (m_pSocketMgr == nullptr)
		{
			m_pSocketMgr = new AsyncClient();
		}
	}
	m_bUseIPV6 = bChooseIPV6;

	if (m_pSocketMgr == nullptr)
	{
		return false;
	}

	m_pSocketMgr->SetRecvTimeout(m_iRecvTimeoutTick);
	m_pSocketMgr->SetSendTimeout(m_iSendTimeoutTick);

	m_pSocketMgr->SetCallback(this);

	return true;
}



bool SmartAsyncClient::SendData( CNetData *pNetData )
{
	if( !pNetData )
	{
		return false;
	}

	if (!m_pSocketMgr)
	{
		return false;
	}

	return m_pSocketMgr->Send( pNetData->GetBuffer().c_str(), (int)pNetData->GetBuffer().size() );
}

bool SmartAsyncClient::Process()
{
	if (!m_pSocketMgr)
	{
		return false;
	}
	return m_pSocketMgr->Process();
}

bool SmartAsyncClient::Close()
{
	if (!m_pSocketMgr)
	{
		return false;
	}
	return m_pSocketMgr->Close();
}

bool SmartAsyncClient::IsConnect()
{
	if (!m_pSocketMgr)
	{
		return false;
	}
	return m_pSocketMgr->IsConnect();
}

bool SmartAsyncClient::IsConnecting()
{
	if (!m_pSocketMgr)
	{
		return false;
	}
	return m_pSocketMgr->IsConnecting();
}

int SmartAsyncClient::GetLastError()
{
	if (!m_pSocketMgr)
	{
		return 0;
	}
	return m_pSocketMgr->GetLastError();
}

void simplecreator::SmartAsyncClient::SetSingleRecvLen(unsigned int nLen)
{
	if (!m_pSocketMgr)
	{
		return;
	}
	return m_pSocketMgr->SetSingleRecvLen(nLen);
}

unsigned int simplecreator::SmartAsyncClient::GetSingleRecvLen()
{
	if (!m_pSocketMgr)
	{
		return 0;
	}
	return m_pSocketMgr->GetSingleRecvLen();
}

std::string simplecreator::SmartAsyncClient::GetHostIp()
{
	if (!m_pSocketMgr)
	{
		return "";
	}
	return m_pSocketMgr->GetHostIp();
}

void simplecreator::SmartAsyncClient::SetRecvTimeout(int iTimeoutTick)
{
	m_iRecvTimeoutTick = iTimeoutTick;
	if (!m_pSocketMgr)
	{
		return ;
	}
	m_pSocketMgr->SetRecvTimeout(iTimeoutTick);
}

void simplecreator::SmartAsyncClient::SetSendTimeout(int iTimeoutTick)
{
	m_iSendTimeoutTick = iTimeoutTick;
	if (!m_pSocketMgr)
	{
		return ;
	}
	m_pSocketMgr->SetSendTimeout(iTimeoutTick);
}

int simplecreator::SmartAsyncClient::GetSendTimeout()
{
	return m_iSendTimeoutTick;
}

int simplecreator::SmartAsyncClient::GetRecvTimeout()
{
	return m_iRecvTimeoutTick;
}
