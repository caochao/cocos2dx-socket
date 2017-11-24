#ifndef I_ASYNC_CLIENT_CALLBACK_H
#define I_ASYNC_CLIENT_CALLBACK_H

namespace simplecreator {

	//客户端操作代码
#define CLIENT_OPERATE_SUCCEED 0
#define CLIENT_ALREADY_CONNECT -1
#define CLIENT_HAVENOT_CONNECT -2
#define CLIENT_BUFFER_TOO_SMALL -3
#define CLIENT_FIND_DISCONNECT -4
#define CLIENT_INVALID_ADDR -5


	//客户端发生错误的场景
	enum EClientScene
	{
		ecsSend=1,
		ecsSelect=2,
		ecsAfterSelect=3,
		ecsFindError=4,
		ecsSelect2=5,
		ecsFindError2=6,
		ecsRecvError=7,
		ecsRecvZero=8
	};

class IAsyncClientCallback
{
public:

	virtual void OnConnect()=0;
	//如果不是非常严重的错误，那么socket不一定需要重连
	virtual void OnError( int nErrorCode, int nScene )=0;
	virtual void OnRecv( void *pBuffer, int nLen )=0;
};

}

#endif