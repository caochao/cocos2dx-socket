#ifndef SC_SOCKETOPERTHREAD_H
#define SC_SOCKETOPERTHREAD_H

#include "DetailNetCommonHead.h"
#include <thread>
#include <deque>

namespace simplecreator {

	class SocketOperThread
	{
	public:
		typedef std::function<bool(bool*)> SockerOperFunc;

		SocketOperThread();
		~SocketOperThread();

		void SetProcessFunction(SockerOperFunc fProcessFunc);

		void Stop();
		void Start();
		void Clear();

		void Run(bool* bWaitExit);

		bool IsStop();

	private:

		bool* m_bWaitExit;
		bool m_bStop;

		std::thread m_pThread;
		SockerOperFunc m_fProcessFunc;
	};

}
#endif