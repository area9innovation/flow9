#ifndef __FV_IOCTX_POOL_HPP__
#define __FV_IOCTX_POOL_HPP__



#include "declare.hpp"
#include "common.hpp"



namespace fv {
class IoCtxPool {
public:
	explicit IoCtxPool (size_t _nthread) {
		if (_nthread == 0) {
			_nthread = std::thread::hardware_concurrency () - 1;
			if (_nthread == 0)
				_nthread = 1;
		}
		//
		for (size_t i = 0; i < _nthread; ++i) {
			std::shared_ptr<fv::IoContext> _ioctx = std::make_shared<fv::IoContext> ();
			std::shared_ptr<fv::IoContext::work> _work = std::make_shared<fv::IoContext::work> (*_ioctx);
			m_ioctxs.push_back (_ioctx);
			m_works.push_back (_work);
		}
		m_main_ioctx = std::make_shared<fv::IoContext> ();
		m_main_work = std::make_shared<fv::IoContext::work> (*m_main_ioctx);
	}

	void Run () {
		std::vector<std::shared_ptr<std::thread>> _threads;
		for (size_t i = 0; i < m_ioctxs.size (); ++i) {
			_threads.emplace_back (std::make_shared<std::thread> ([] (std::shared_ptr<fv::IoContext> svr) { svr->run (); }, m_ioctxs [i]));
		}
		m_main_ioctx->run ();
		for (size_t i = 0; i < _threads.size (); ++i) {
			std::cout << "IoCtxPool -_threads [" << i << "]->join (); ............" << std::endl;
			_threads [i]->join ();
			std::cout << "IoCtxPool -_threads [" << i << "]->join (); - DONE" << std::endl;
		}
	}

	void Stop () {
		m_main_work = nullptr;
		m_works.clear ();
		m_main_ioctx->stop ();
		for (size_t i = 0; i < m_ioctxs.size (); ++i) {
			m_ioctxs [i]->stop ();
		}
		std::cout << "IoCtxPool - IS STOPPED" << std::endl;
	}

	size_t NumWorks() {
		return m_works.size();
	}

	fv::IoContext &GetMainContext () {
		return *m_main_ioctx;
	}

	fv::IoContext &GetContext () {
		return *m_ioctxs [m_cur_index++ % m_ioctxs.size ()];
	}

private:
	std::vector<std::shared_ptr<fv::IoContext>> m_ioctxs;
	std::vector<std::shared_ptr<fv::IoContext::work>> m_works;
	std::shared_ptr<fv::IoContext> m_main_ioctx;
	std::shared_ptr<fv::IoContext::work> m_main_work;
	size_t m_cur_index = 0;
};
}



#endif //__FV_IOCTX_POOL_HPP__
