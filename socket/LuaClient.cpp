#include "LuaClient.h"
#include "AsyncClient.h"
#include "AsyncClientV6.h"

using namespace cocos2d;
using namespace std;

using namespace simplecreator;

CLuaClient::CLuaClient()
{
	m_nOnConnectHandle=0;
	m_nOnErrorHandle=0;
	m_nOnRecvHandle=0;

	m_recvData.SetNoDelByClear();
}

CLuaClient::~CLuaClient()
{

}

void CLuaClient::OnConnect()
{
	if( !m_nOnConnectHandle )
	{
		return;
	}

	cocos2d::LuaStack* pEngine = cocos2d::LuaEngine::getInstance()->getLuaStack();
	pEngine->executeFunctionByHandler( m_nOnConnectHandle, 0 );
}

void CLuaClient::OnError( int nErrorCode, int nScene )
{
	if( !m_nOnErrorHandle )
	{
		return;
	}

	cocos2d::LuaStack* pEngine = cocos2d::LuaEngine::getInstance()->getLuaStack();

	pEngine->pushInt( nErrorCode );
	pEngine->pushInt( nScene );
	pEngine->executeFunctionByHandler( m_nOnErrorHandle, 2 );
}

void CLuaClient::OnRecv( void *pBuffer, int nLen )
{
	m_recvData.AddBuffer( pBuffer, nLen );

	if( !m_nOnRecvHandle )
	{
		return;
	}
	cocos2d::LuaStack* pEngine = cocos2d::LuaEngine::getInstance()->getLuaStack();

	pEngine->executeFunctionByHandler( m_nOnRecvHandle, 0 );
}


void CLuaClient::RegisterOnConnect(LUA_FUNCTION nHandle)
{
	UnRegisterOnConnect();
	m_nOnConnectHandle=nHandle;
}

void CLuaClient::RegisterOnRecv( LUA_FUNCTION nHandle )
{
	UnRegisterOnRecv();
	m_nOnRecvHandle=nHandle;
}

void CLuaClient::RegisterOnError( LUA_FUNCTION nHandle )
{
	UnRegisterOnError();
	m_nOnErrorHandle=nHandle;
}


CNetData *CLuaClient::GetRecvData()
{
	return &m_recvData;
}

void CLuaClient::UnRegisterOnConnect()
{
	if( 0!=m_nOnConnectHandle )
	{
		cocos2d::LuaEngine::getInstance()->removeScriptHandler(m_nOnConnectHandle);
		m_nOnConnectHandle = 0;
	}
}

void CLuaClient::UnRegisterOnRecv()
{
	if( 0!=m_nOnRecvHandle )
	{
		cocos2d::LuaEngine::getInstance()->removeScriptHandler(m_nOnRecvHandle);
		m_nOnRecvHandle = 0;
	}
}

void CLuaClient::UnRegisterOnError()
{
	if( 0!=m_nOnErrorHandle )
	{
		cocos2d::LuaEngine::getInstance()->removeScriptHandler(m_nOnErrorHandle);
		m_nOnErrorHandle = 0;
	}
}