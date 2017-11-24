#ifndef _LUA_CLIENT_H_
#define _LUA_CLIENT_H_

#include "SmartAsyncClient.h"
#include "netdataoperate.h"
#include <string>
#include "CCLuaEngine.h"

USING_NS_CC;

namespace simplecreator {

class CLuaClient:public SmartAsyncClient
{
public:
	CLuaClient();
	virtual ~CLuaClient();


	void RegisterOnConnect(LUA_FUNCTION nHandle);
	void RegisterOnRecv( LUA_FUNCTION nHandle );
	void RegisterOnError( LUA_FUNCTION nHandle );

	//获得接收的数据
	CNetData *GetRecvData();

private:
	virtual void OnConnect();
	virtual void OnError( int nErrorCode, int nScene );
	virtual void OnRecv( void *pBuffer, int nLen );

	void UnRegisterOnConnect();
	void UnRegisterOnRecv();
	void UnRegisterOnError();

private:
	LUA_FUNCTION m_nOnConnectHandle;
	LUA_FUNCTION m_nOnRecvHandle;
	LUA_FUNCTION m_nOnErrorHandle;
	CNetData m_recvData;

};

}

#endif