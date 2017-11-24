#include "SocketOperThread.h"
#include "platform/CCPlatformMacros.h"



simplecreator::SocketOperThread::SocketOperThread()
{
	m_bStop = true;
	m_bWaitExit = nullptr;
	m_fProcessFunc = nullptr;
	//m_pThread = nullptr;

}


void simplecreator::SocketOperThread::SetProcessFunction(SockerOperFunc fProcessFunc)
{
	m_fProcessFunc = fProcessFunc;
}


simplecreator::SocketOperThread::~SocketOperThread()
{
	if (!m_bStop)
	{
		Stop();
	}

	/*
	if (m_pThread)
	{
		if (m_pThread->joinable())
		{
			m_pThread->join();
		}
	}
	CC_SAFE_DELETE(m_pThread);
	*/
}

void simplecreator::SocketOperThread::Stop()
{
	if (!m_bStop)
	{
		if (m_bWaitExit)
		{
			*m_bWaitExit = true;
		}
	}
	m_bStop = true;

	/*
	if (m_pThread)
	{
		if (m_pThread->joinable())
		{
			m_pThread->join();
		}
	}
	*/
	//CC_SAFE_DELETE(m_pThread);
}

void simplecreator::SocketOperThread::Start()
{
	if (!m_bStop)
	{
		//*m_bWaitExit = false;
		//return;
		Stop();
	}
	m_bStop = false;

	//CC_SAFE_DELETE(m_pThread);

	m_bWaitExit = new bool(false);
	m_pThread = std::thread(&SocketOperThread::Run, this, m_bWaitExit);
	m_pThread.detach();
}

void simplecreator::SocketOperThread::Clear()
{

}

void simplecreator::SocketOperThread::Run(bool* bWaitExit)
{
	while (!(*bWaitExit))
	{
		if (!m_fProcessFunc)
		{
			continue;
		}
		if (!m_fProcessFunc(bWaitExit))
		{
			break;
		}
	}
	if (!(*bWaitExit))
	{
		m_bStop = true;
	}
	CC_SAFE_DELETE(bWaitExit);
}



bool simplecreator::SocketOperThread::IsStop()
{
	return m_bStop;
}