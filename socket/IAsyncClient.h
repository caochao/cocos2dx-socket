#ifndef I_ASYNC_CLIENT_H
#define I_ASYNC_CLIENT_H
#include "NetCommOperate.h"
#include "IAsyncClientCallback.h"
#include <string>

namespace simplecreator {

//   TCP/IPЭ���첽�ͻ��˵Ļ��࣬����TCP�첽�ͻ��˶���Ҫ������������

class IAsyncClient
{
public:
	IAsyncClient();
	virtual ~IAsyncClient();

	//��������
	virtual bool Send( const char *pData, unsigned int nLen )=0;


	//�Ͽ�����
	virtual bool Close()=0;

	//����ϴδ���
	virtual int GetLastError()=0;

	//����ÿ�ε��ô˶����������д���,�����û�д�����ô����true
	virtual bool Process()=0;

	//���ӵ�IP�Ͷ˿�
	virtual bool Connect( struct addrinfo *pAddrInfo, int nPort, bool bSyncMode=false )=0;

	// ����ͬ������ģʽ
	void SetSyncMode(bool bSyncMode);
	// �Ƿ�ͬ������ģʽ
	bool IsSyncMode();

	//�Ƿ�����
	virtual bool IsConnect()=0;

	//�Ƿ���������
	virtual bool IsConnecting()=0;

	//���õ��ν��յĴ�С
	virtual void SetSingleRecvLen( unsigned int nLen )=0;
	
	//��õ��ν��յĴ�Сֵ
	virtual unsigned int GetSingleRecvLen()=0;

	//���û�����ӣ��򷵻ؿ��ַ���
	virtual std::string GetHostIp()=0;

	// ���÷��ͳ�ʱʱ��(����)
	void SetRecvTimeout(int iTimeoutTick);
	// ���ý��ճ�ʱʱ��(����)
	void SetSendTimeout(int iTimeoutTick);
	// ��ȡ���ͳ�ʱ
	int GetSendTimeout();
	// ��ȡ���ճ�ʱ
	int GetRecvTimeout();

	// ���ûص�������
	void SetCallback(IAsyncClientCallback* pCallbackMgr);

	void OnConnect();
	void OnError( int nErrorCode, int nScene );
	void OnRecv( void *pBuffer, int nLen );

public:
	const static int MAX_SEND_LENGTH=65536;

private:
	// �ص��������
	IAsyncClientCallback* m_pCallbackMgr;

	int m_iSendTimeoutTick;
	int m_iRecvTimeoutTick;

	bool m_bSyncMode;
};

}

#endif