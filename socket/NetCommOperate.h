#ifndef NET_COMM_OPERATE_H
#define NET_COMM_OPERATE_H
#include "DetailNetCommonHead.h"

namespace simplecreator {

class NetCommonOperate
{
public:
	//��ʼ�����磬����ɹ���nErrorΪNET_OPERATE_SUCCEED,���ʧ�ܣ�nErrorΪʧ�ܵĴ���
	bool InitNet( int &nError );

	//���ʼ�����磬����ɹ���nErrorΪNET_OPERATE_SUCCEED,���ʧ�ܣ�nErrorΪʧ�ܵĴ���
	bool UnInitNet( int &nError );

	//ͨ��ֵ�����ж��Ƿ���Ч,������(socket==INVALID_SOCKET)
	bool IsEffectiveSocket( CP_SOCKET sock );

	//����socketΪ������
	void SetSockUnblock( CP_SOCKET sock );

	// ���÷��ͳ�ʱʱ��(����)
	void SetRecvTimeout(CP_SOCKET pSock, int iTimeoutTick);
	// ���ý��ճ�ʱʱ��(����)
	void SetSendTimeout(CP_SOCKET pSock, int iTimeoutTick);
	//���ò��ӳ�
	void SetNoDelay(CP_SOCKET pSock, int on);

	//���ϵͳ����
	int GetSysLastError();

	//ͨ�ùر��׽���
	void CloseSocket( CP_SOCKET sock );

	//���socket�Ĵ���
	int GetSocketError( CP_SOCKET sock );

	bool IsInProcess( int nErrorCode );
public:

	//�����ɹ����
	const static int NET_OPERATE_SUCCEED=0;

	const static int ms_NormalIPDotCount=3;
};

}

#endif