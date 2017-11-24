#include "AsyncClientV6.h"
#include "NetCommOperate.h"

using namespace simplecreator;

AsyncClientV6::AsyncClientV6()
{

}

AsyncClientV6::~AsyncClientV6()
{
}


bool simplecreator::AsyncClientV6::PreConnect(struct addrinfo *pAddrInfo)
{

	// 获取地址
	char szHostIP[128] = {};  
	struct sockaddr_in6 *sa = (struct sockaddr_in6*)pAddrInfo->ai_addr;  
	inet_ntop(AF_INET6, &sa->sin6_addr, szHostIP, 128); 
	
	m_strHostIP = szHostIP;
	
	/*
	// 初始化地址
	struct sockaddr_in6 srvAddr;  
	memset(&srvAddr, 0, sizeof(srvAddr)); //注意初始化  
	srvAddr.sin6_family = AF_INET6;  
	srvAddr.sin6_port = htons(nPort);   
	if (inet_pton(AF_INET6, szHostIP, &srvAddr.sin6_addr) < 0)  
	{  
		m_nLastError=CLIENT_INVALID_ADDR;
		return false;
	}
	*/
	return true;
}
