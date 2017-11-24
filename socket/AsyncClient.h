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

	//��������
	virtual bool Send( const char *pData, unsigned int nLen );

	//�������ݣ������һ������ΪNULL����ô���Ի���յ������ݵĳ��ȡ������һ������ΪNULL���ڶ�����������ʱָ���˳���
	//��ô����ָ�����ȵ����ݣ���������ڻ����������ֵ���ڶ����������᷵��ʵ�ʿ����ĳ��ȡ� 
	//virtual bool Recv( char *pData, unsigned int &nLen );

	//�Ͽ�����
	virtual bool Close();

	//����ϴβ�������
	virtual int GetLastError();

	//����ÿ�ε��ô˶����������д���,�����û�д�����ô����true
	virtual bool Process();

	//���ӵ�IP�Ͷ˿�
	virtual bool Connect( struct addrinfo *pAddrInfo, int nPort, bool bSyncMode=false );



	virtual bool IsConnect();

	virtual bool IsConnecting();

	virtual void SetSingleRecvLen( unsigned int nLen );
	virtual unsigned int GetSingleRecvLen();

	//���û�����ӣ��򷵻ؿ��ַ���
	virtual std::string GetHostIp();

protected:
	// ���ӵ�ַԤ����
	virtual bool PreConnect(struct addrinfo *pAddrInfo);
	
private:
	void ClearFDSet();
	void ResetFDSet();
	void SetConnectResult( bool bSucceed );

	// ͬ���շ��߳�
	virtual bool SendThread(bool* bWaitExit);
	virtual bool RecvThread(bool* bWaitExit);

	void OnSyncError(int nErrorCode, int nScene, bool bClose=false);
	void CheckSyncSend();

	// ͬ������ģʽ�²����շ�����
	virtual void StartSyncProcess();
	// ͬ������
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

	const static int nDefaultSingleRecvLen=4096; //Ĭ��һ�ν���4K��С
};

}

#endif