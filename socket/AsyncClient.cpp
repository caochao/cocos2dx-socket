#include "AsyncClient.h"
#include "NetCommOperate.h"
#include "cocos2d.h"

using namespace simplecreator;

// 是否开启发送线程
#define ENABLE_ASYNCCLIENT_SENDTHREAD 0

AsyncClient::AsyncClient()
{
	m_bConnect=false;
	m_bInit=false;
	m_nLastError=0;
	m_sock=-1;
    m_timeOut.tv_sec=0;
    m_timeOut.tv_usec=0;

	m_nSingleRecvLen=nDefaultSingleRecvLen;
	m_bConnecting=false;

	m_strHostIP = "";

	m_sSendCacheStr = "";
	m_bHasRecv = false;

#if ENABLE_ASYNCCLIENT_SENDTHREAD
	m_pSendThread.SetProcessFunction(std::bind(&AsyncClient::SendThread, this, std::placeholders::_1));
#endif
	m_pRecvThread.SetProcessFunction(std::bind(&AsyncClient::RecvThread, this, std::placeholders::_1));
}

AsyncClient::~AsyncClient()
{
	if( m_sock!=-1 )
	{
		Close();
	}

	if( m_bInit )
	{
		int nError;
		m_netOperate.UnInitNet( nError );
	}

	m_pSendThread.Stop();
	m_pRecvThread.Stop();
}

void AsyncClient::ClearFDSet()
{
	FD_ZERO(&m_fdRead);
	FD_ZERO(&m_fdWrite);
	FD_ZERO(&m_fdError);
}

bool AsyncClient::Send( const char *pData, unsigned int nLen )
{
	if( !m_bConnect )
	{
		m_nLastError=CLIENT_HAVENOT_CONNECT;
		return false;
	}

#if ENABLE_ASYNCCLIENT_SENDTHREAD

	// 同步模式
	if (IsSyncMode())
	{
		return SyncSend(pData, nLen);
	}

#endif // ENABLE_ASYNCCLIENT_SENDTHREAD
    
	int nResult=(int)send( m_sock, pData, nLen, 0 );

	if( -1==nResult )
	{
		m_nLastError=m_netOperate.GetSysLastError();

		if( m_netOperate.IsInProcess( m_nLastError ) )
		{
			return true;
		}

		Close();
		OnError( m_nLastError, ecsSend );
		return false;
	}
	else
	{
		m_nLastError=CLIENT_OPERATE_SUCCEED;
	}
	//m_strSendBuffer.append( pData, nLen );

	return true;
}



bool AsyncClient::Close()
{
	m_pSendThread.Stop();
	m_pRecvThread.Stop();

	if (m_sock != -1)
	{
		m_netOperate.CloseSocket( m_sock );
		ClearFDSet();
	}

	if (!m_bConnect && !m_bConnecting)
	{
		m_sock = -1;
		m_bHasRecv = false;
		return false;
	}



	{
		std::lock_guard<std::mutex> pLock(m_pSocketMutex);
		
		m_sock=-1;
		m_bConnect=false;
		m_bConnecting=false;

		m_bHasRecv = false;
	}

	return true;
}

int AsyncClient::GetLastError()
{
	return m_nLastError;
}

void AsyncClient::StartSyncProcess()
{
	SetConnectResult(true);


	m_nLastError=CLIENT_OPERATE_SUCCEED;
	OnConnect();

	m_pRecvThread.Start();
}
void AsyncClient::CheckSyncSend()
{
	m_pSendThread.Start();
}


bool AsyncClient::RecvThread(bool* bWaitExit)
{

	CP_SOCKET pSocket;
	{
		std::lock_guard<std::mutex> pLock(m_pSocketMutex);

		if( !m_bConnect )
		{
			m_nLastError=CLIENT_HAVENOT_CONNECT;
			return false;
		}

		pSocket = m_sock;
	}

	m_strSingleRecv.resize( m_nSingleRecvLen );
	int nResult = (int)recv( pSocket, const_cast<char *>( m_strSingleRecv.c_str() ), m_strSingleRecv.size(), 0 );

	if (*bWaitExit)
	{
		return false;
	}

	if( -1==nResult )
	{
		m_nLastError=m_netOperate.GetSysLastError();
		//发现是-1，那么只通知不关闭
		OnSyncError( m_nLastError, ecsRecvError, true );
		return false;
	}
	else if( 0==nResult )
	{
		m_nLastError=m_netOperate.GetSysLastError();
		OnSyncError( m_nLastError, ecsRecvZero, true );
		return false;
	}
	else
	{
		m_nLastError=CLIENT_OPERATE_SUCCEED;
	}


	{
		std::lock_guard<std::mutex> pLock(m_pRecvMutex); //线程开始加锁，退出时自动解锁 

		m_strRecvBuffer.append( m_strSingleRecv.c_str(), nResult );

		// 如果主线程还没处理，不用再发消息，避免主线程无谓的多次调用OnRecv
		if (m_bHasRecv)
		{
			return true;
		}
		m_bHasRecv = true;
		cocos2d::Director::getInstance()->getScheduler()->performFunctionInCocosThread([&, this]
		{
			std::lock_guard<std::mutex> pLock(m_pRecvMutex); //线程开始加锁，退出时自动解锁 

			this->OnRecv( (void *)m_strRecvBuffer.c_str(), (int)m_strRecvBuffer.size() );
			m_strRecvBuffer.clear();

			m_bHasRecv = false;
		});
	}



	return true;
}

bool AsyncClient::SendThread(bool* bWaitExit)
{
	{
		std::lock_guard<std::mutex> pLock(m_pSocketMutex);

		if( !m_bConnect )
		{
			m_nLastError=CLIENT_HAVENOT_CONNECT;
			return false;
		}
	}


	std::string sCurSendCache = "";

	{
		std::lock_guard<std::mutex> pLock(m_pSendMutex); //线程开始加锁，退出时自动解锁 

		if (m_sSendCacheStr.empty())
		{
			return false;
		}

		sCurSendCache = m_sSendCacheStr;
		m_sSendCacheStr = "";
	}

		

	int nResult=(int)send( m_sock, sCurSendCache.c_str(), sCurSendCache.length(), 0 );

	if (*bWaitExit)
	{
		return false;
	}

	if( -1==nResult )
	{
		m_nLastError=m_netOperate.GetSysLastError();

		if( m_netOperate.IsInProcess( m_nLastError ) )
		{
			return true;
		}

		OnSyncError( m_nLastError, ecsSend, true );
		return false;
	}
	else
	{
		m_nLastError=CLIENT_OPERATE_SUCCEED;
	}

	return true;
}

void AsyncClient::OnSyncError(int nErrorCode, int nScene, bool bClose/*=false*/)
{
	cocos2d::Director::getInstance()->getScheduler()->performFunctionInCocosThread([nErrorCode, nScene, bClose, this]{
		if (!m_bConnect)
		{
			return;
		}

		if (bClose)
		{
			Close();
		}
		OnError(nErrorCode, nScene);
	});
}

bool AsyncClient::SyncSend(const char *pData, unsigned int nLen)
{
	std::lock_guard<std::mutex> pLock(m_pSendMutex); //线程开始加锁，退出时自动解锁 

	m_sSendCacheStr.append(pData, nLen);

	CheckSyncSend();
	return true;
}

bool AsyncClient::Process()
{
	// 同步处理
	if (IsSyncMode())
	{
		return false;
	}

	if( -1==m_sock )
	{
		return false;
	}

	ClearFDSet();
	ResetFDSet();

	if( m_bConnecting )
	{
		if( -1 == select(m_sock+1, NULL, &m_fdWrite, &m_fdError, &m_timeOut) )
		{
			m_nLastError=m_netOperate.GetSysLastError();
			Close();
			OnError( m_nLastError, ecsSelect );
			return false;
		}
        
        m_nLastError=m_netOperate.GetSocketError( m_sock );
        if(m_nLastError!=0)
        {
            Close();
			OnError( m_nLastError, ecsAfterSelect );
			return false;
        }

		if( FD_ISSET( m_sock, &m_fdWrite ) )
		{
			SetConnectResult(true);
            
            
			m_nLastError=CLIENT_OPERATE_SUCCEED;
			OnConnect();
			return true;
		}

		if( FD_ISSET( m_sock, &m_fdError ) )
		{
			SetConnectResult(false);
			m_nLastError=m_netOperate.GetSocketError( m_sock );
			Close();
			OnError( m_nLastError, ecsFindError );
			return false;
		}

		return true;
	}

	else
	{
		//因为是客户端，遍历的socket只有一个，在windows下，第一个参数是没有用的，为了兼容
		//但是在linux下，第一个参数必须为监测的scoket最大数+1，为了兼容linux，所以设置为
		if( -1 == select(m_sock+1, &m_fdRead, NULL, &m_fdError, &m_timeOut) )
		{
			m_nLastError=m_netOperate.GetSysLastError();
			Close();
			OnError( m_nLastError, ecsSelect2 );
			return false;
		}

		if( FD_ISSET( m_sock, &m_fdError ) )
		{
//			if( m_bConnecting )
//			{
//				SetConnectResult(false);
//			}
			m_nLastError=m_netOperate.GetSocketError( m_sock );
			Close();
			OnError( m_nLastError, ecsFindError2 );
			return false;
		}

		if( FD_ISSET( m_sock, &m_fdRead ) )
		{
//			if( m_bConnecting )
//			{
//				SetConnectResult(true);
//				m_nLastError=CLIENT_OPERATE_SUCCEED;
//			}
			m_strSingleRecv.resize( m_nSingleRecvLen );
			int nResult;
			nResult=(int)recv( m_sock, const_cast<char *>( m_strSingleRecv.c_str() ), m_strSingleRecv.size(), 0 );

			if( -1==nResult )
			{
				
 				m_nLastError=m_netOperate.GetSysLastError();
				//发现是-1，那么只通知不关闭
// 				Close();
 				OnError( m_nLastError, ecsRecvError );
				return true;
			}
			else if( 0==nResult )
			{
				m_nLastError=m_netOperate.GetSysLastError();
				Close();
				OnError( m_nLastError, ecsRecvZero );
				return false;
			}
			else
			{
				m_nLastError=CLIENT_OPERATE_SUCCEED;
			}
			m_strRecvBuffer.append( m_strSingleRecv.c_str(), nResult );
			this->OnRecv( (void *)m_strRecvBuffer.c_str(), (int)m_strRecvBuffer.size() );
			m_strRecvBuffer.clear();
		}
	}
	

// 	if( FD_ISSET( m_sock, &m_fdWrite ) )
// 	{
// 		if( m_bConnecting )
// 		{
// 			SetConnectResult(true);
// 			m_nLastError=CLIENT_OPERATE_SUCCEED;
// 		}
// 
// 		//如果长度大于默认队列的长度，那么发送时进行分割
// 		int nSendLen=m_strSendBuffer.size()>MAX_SEND_LENGTH?MAX_SEND_LENGTH:m_strSendBuffer.size();
// 		int nResult=send( m_sock, m_strSendBuffer.c_str(), nSendLen, NULL );
// 
// 		if( -1==nResult )
// 		{
// 			m_nLastError=m_netOperate.GetSysLastError();
// 			Close();
// 			return false;
// 		}
// 		else
// 		{
// 			m_nLastError=CLIENT_OPERATE_SUCCEED;
// 		}
// 		m_strSendBuffer.erase( 0, nResult );
// 	}

	

	return true;
}


bool AsyncClient::Connect( struct addrinfo *pAddrInfo, int nPort, bool bSyncMode/*=false */ )
{
	int nError;

	SetSyncMode(bSyncMode);

	if( !m_bInit )
	{
		if( !m_netOperate.InitNet( nError ) )
		{
			m_nLastError=nError;
			return false;
		}

		m_bInit=true;
	}


	if( m_bConnect )
	{
		m_nLastError=CLIENT_ALREADY_CONNECT;
		return false;
	}	

	if( m_bConnecting )
	{
		return true;
	}

	m_strHostIP = ""; 

	if( m_sock!=-1 )
	{
#ifdef _DEBUG
		throw "socket not -1";
#else
		printf("socket not -1 on connect!");
		Close();
#endif
	}

	if( m_sock==-1 )
	{
		m_sock = socket(pAddrInfo->ai_family, pAddrInfo->ai_socktype, 0);
		// 异步模式
		if (!IsSyncMode())
		{
			m_netOperate.SetSockUnblock( m_sock );
		}
		m_netOperate.SetSendTimeout(m_sock, GetSendTimeout());
		m_netOperate.SetRecvTimeout(m_sock, GetRecvTimeout());
	}

	if( m_sock==-1 )
	{
		m_nLastError=m_netOperate.GetSysLastError();
		return false;
	}
	
	if (!PreConnect(pAddrInfo))
	{
		return false;
	}
	
	if( connect( m_sock, pAddrInfo->ai_addr, pAddrInfo->ai_addrlen )==-1 )
	{
		m_nLastError=m_netOperate.GetSysLastError();
 		if( m_netOperate.IsInProcess( m_nLastError ) )
		{
			m_bConnecting=true;

			// 同步阻塞模式下并行收发处理
			if (IsSyncMode())
			{
				//StartSyncProcess();
				m_bConnect=false;
				Close();
				return false;
			}
 			return true;
		}
		m_bConnect=false;
		Close();
		return false;
	}

	//m_netOperate.SetSockUnblock( m_sock );

    m_bConnect=true;
    m_bConnecting=false;
	m_nLastError=CLIENT_OPERATE_SUCCEED;

	// 同步阻塞模式下并行收发处理
	if (IsSyncMode())
	{
		StartSyncProcess();
	}

	//OnConnect();
	return true;
}

bool AsyncClient::PreConnect(struct addrinfo *pAddrInfo)
{
	// 获取地址
	char szHostIP[32] = {};  
	struct sockaddr_in *sa = (struct sockaddr_in*)pAddrInfo->ai_addr;
#if CC_TARGET_PLATFORM != CC_PLATFORM_WINRT
	inet_ntop(AF_INET, &sa->sin_addr, szHostIP, 32); 
#else
	strcpy(szHostIP, inet_ntoa(sa->sin_addr));
#endif
	m_strHostIP = szHostIP; 

	/*
	// 初始化地址
	struct sockaddr_in srvAddr;  
	srvAddr.sin_family = AF_INET;  
	srvAddr.sin_addr.s_addr = inet_addr(szHostIP);  
	srvAddr.sin_port = htons(nPort);  
	*/

	return true;
}


bool AsyncClient::IsConnect()
{
	return m_bConnect;
}

bool AsyncClient::IsConnecting()
{
	return m_bConnecting;
}

void AsyncClient::ResetFDSet()
{
	FD_SET( m_sock, &m_fdRead );
	FD_SET( m_sock, &m_fdError );
	FD_SET( m_sock, &m_fdWrite );
}

void AsyncClient::SetConnectResult( bool bSucceed )
{
	m_bConnect=bSucceed;
	m_bConnecting=false;
}

void AsyncClient::SetSingleRecvLen( unsigned int nLen )
{
	m_nSingleRecvLen=nLen;
}

unsigned int AsyncClient::GetSingleRecvLen()
{
	return m_nSingleRecvLen;
}

std::string AsyncClient::GetHostIp()
{
	return m_strHostIP;
}
