#ifndef ASYNC_CLIENT_IPV6_H
#define ASYNC_CLIENT_IPV6_H

#include "AsyncClient.h"
#include "DetailNetCommonHead.h"
#include "NetCommOperate.h"
#include <string>

using std::string;

namespace simplecreator {

class AsyncClientV6:public AsyncClient
{
public:
	AsyncClientV6();
	virtual ~AsyncClientV6();

protected:
	// ���ӵ�ַԤ����
	virtual bool PreConnect(struct addrinfo *pAddrInfo);

};

}

#endif