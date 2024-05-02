#ifndef __FV_COMMON_HPP__
#define __FV_COMMON_HPP__



#include <chrono>
#include <functional>
#include <mutex>
#include <string>
#include <thread>
#include <unordered_map>

#include "declare.hpp"
#include "ioctx_pool.hpp"



namespace fv {
struct CaseInsensitiveHash {
	size_t operator() (const std::string &str) const noexcept {
		size_t h = 0;
		std::hash<int> hash {};
		for (auto c : str)
			h ^= hash (::tolower (c)) + 0x9e3779b9 + (h << 6) + (h >> 2);
		return h;
	}
};
struct CaseInsensitiveEqual {
	bool operator() (const std::string &str1, const std::string &str2) const noexcept {
		return str1.size () == str2.size () && std::equal (str1.begin (), str1.end (), str2.begin (), [] (char a, char b) {
			return tolower (a) == tolower (b);
		});
	}
};
using CaseInsensitiveMap = std::unordered_map<std::string, std::string, CaseInsensitiveHash, CaseInsensitiveEqual>;



struct Exception: public std::exception {
	Exception (std::string _err): m_err (_err) {}
	//template<typename ...Args>
	//Exception (std::string _err, Args ..._args): m_err (fmt::format (_err, _args...)) {}
	const char* what() const noexcept override { return m_err.c_str (); }

private:
	std::string m_err = "";
};



struct AsyncMutex {
	AsyncMutex (bool _init_locked = false): m_locked (_init_locked) {}

	bool IsLocked () {
		std::unique_lock _ul { m_mtx };
		return m_locked;
	}

	bool TryLock () {
		std::unique_lock _ul { m_mtx };
		if (!m_locked) {
			m_locked = true;
			return true;
		} else {
			return false;
		}
	}

	Task<void> Lock () {
		std::unique_lock _ul { m_mtx, std::defer_lock };
		while (true) {
			_ul.lock ();
			if (!m_locked) {
				m_locked = true;
				co_return;
			}
			_ul.unlock ();
			co_await _delay (std::chrono::milliseconds (1));
		}
	}

	Task<bool> Lock (TimeSpan _timeout) {
		std::unique_lock _ul { m_mtx, std::defer_lock };
		auto _elapsed = std::chrono::system_clock::now () + _timeout;
		while (_elapsed > std::chrono::system_clock::now ()) {
			_ul.lock ();
			if (!m_locked) {
				m_locked = true;
				co_return true;
			}
			_ul.unlock ();
			co_await _delay (std::chrono::milliseconds (1));
		}
		co_return false;
	}

	void LockSync () {
		std::unique_lock _ul { m_mtx, std::defer_lock };
		while (true) {
			_ul.lock ();
			if (!m_locked) {
				m_locked = true;
				return;
			}
			_ul.unlock ();
			std::this_thread::sleep_for (std::chrono::milliseconds (1));
		}
	}

	void Unlock () {
		std::unique_lock _ul { m_mtx };
		if (!m_locked)
			throw Exception ("Cannot unlock a unlocked mutex");
		m_locked = false;
	}

private:
	static Task<void> _delay (TimeSpan _dt) {
		asio::steady_timer timer (co_await asio::this_coro::executor);
		timer.expires_after (_dt);
		co_await timer.async_wait (UseAwaitable);
	}

	bool m_locked = false;
	std::recursive_mutex m_mtx {};
};



struct AsyncSemaphore {
	AsyncSemaphore (size_t _init_count = 1): m_count (_init_count) {}

	size_t GetResCount () {
		std::unique_lock _ul { m_mtx };
		return m_count;
	}

	bool TryAcquire () {
		std::unique_lock _ul { m_mtx };
		if (m_count > 0) {
			--m_count;
			return true;
		} else {
			return false;
		}
	}

	Task<void> Acquire () {
		std::unique_lock _ul { m_mtx, std::defer_lock };
		while (true) {
			_ul.lock ();
			if (m_count > 0) {
				--m_count;
				co_return;
			}
			_ul.unlock ();
			co_await _delay (std::chrono::milliseconds (1));
		}
	}

	Task<bool> Acquire (TimeSpan _timeout) {
		std::unique_lock _ul { m_mtx, std::defer_lock };
		auto _elapsed = std::chrono::system_clock::now () + _timeout;
		while (_elapsed > std::chrono::system_clock::now ()) {
			_ul.lock ();
			if (m_count > 0) {
				--m_count;
				co_return true;
			}
			_ul.unlock ();
			co_await _delay (std::chrono::milliseconds (1));
		}
		co_return false;
	}

	void Release () {
		std::unique_lock _ul { m_mtx };
		++m_count;
	}

private:
	static Task<void> _delay (TimeSpan _dt) {
		asio::steady_timer timer (co_await asio::this_coro::executor);
		timer.expires_after (_dt);
		co_await timer.async_wait (UseAwaitable);
	}

	size_t m_count;
	std::recursive_mutex m_mtx {};
};

struct CancelToken {
	CancelToken (std::chrono::system_clock::time_point _cancel_time) { m_cancel_time = _cancel_time; }
	CancelToken (TimeSpan _expire) { m_cancel_time = std::chrono::system_clock::now () + _expire; }
	void Cancel () { m_cancel_time = std::chrono::system_clock::now (); }
	bool IsCancel () { return std::chrono::system_clock::now () <= m_cancel_time; }
	TimeSpan GetRemaining () { return m_cancel_time - std::chrono::system_clock::now (); }

private:
	std::chrono::system_clock::time_point m_cancel_time;
};

struct Tasks {
	template<typename F>
	static void RunAsync (F &&f) {
		std::unique_lock _ul { m_mtx };
		if (!m_pool)
			throw Exception ("You should invoke Init method first");
		//
		using TRet = decltype (f ());
		if constexpr (std::is_void<TRet>::value) {
			GetContext ().post (std::forward<F> (f));
		} else if constexpr (std::is_same<TRet, Task<void>>::value) {
			asio::co_spawn (GetContext (), std::forward<F> (f), asio::detached);
		} else {
			static_assert (std::is_void<TRet>::value || std::is_same<TRet, Task<void>>::value, "Unsupported returns type");
		}
	}
	template<typename F>
	static void RunMainAsync (F &&f) {
		std::unique_lock _ul { m_mtx };
		if (!m_pool)
			throw Exception ("You should invoke Init method first");
		//
		using TRet = decltype (f ());
		if constexpr (std::is_void<TRet>::value) {
			GetMainContext ().post (std::forward<F> (f));
		} else if constexpr (std::is_same<TRet, Task<void>>::value) {
			asio::co_spawn (GetMainContext (), std::forward<F> (f), asio::detached);
		} else {
			static_assert (std::is_void<TRet>::value || std::is_same<TRet, Task<void>>::value, "Unsupported returns type");
		}
	}

	template<typename F, typename... Args>
	static void RunAsync (F &&f, Args... args) { return RunAsync (std::bind (f, args...)); }
	template<typename F, typename... Args>
	static void RunMainAsync (F &&f, Args... args) { return RunMainAsync (std::bind (f, args...)); }

	static Task<void> Delay (TimeSpan _dt) {
		asio::steady_timer timer (co_await asio::this_coro::executor);
		timer.expires_after (_dt);
		co_await timer.async_wait (UseAwaitable);
	}

	static void Init (size_t _thread_num = 0) {
		::srand ((unsigned int) ::time (NULL));
		std::unique_lock _ul { m_mtx };
		if (m_pool)
			throw Exception ("You should only invoke Init method once");
		m_pool = std::make_shared<IoCtxPool> (_thread_num);
	}

	static void Stop () {
		std::unique_lock _ul { m_mtx };
		if (!m_pool)
			throw Exception ("You should invoke Init method first");
		m_run = false;
		m_pool->Stop ();
	}

	static void Run () {
		std::unique_lock _ul { m_mtx };
		if (!m_pool)
			throw Exception ("You should invoke Init method first");
		m_run = true;
		_ul.unlock ();
		m_pool->Run ();
	}

	static size_t NumWorks() {
		return 	m_pool->NumWorks();
	}

	static IoContext &GetContext () {
		std::unique_lock _ul { m_mtx };
		if (!m_pool)
			Init ();
		return m_pool->GetContext ();
	}
	static IoContext &GetMainContext () {
		std::unique_lock _ul { m_mtx };
		if (!m_pool)
			Init ();
		return m_pool->GetMainContext ();
	}

private:
	inline static std::shared_ptr<IoCtxPool> m_pool = nullptr;
	inline static std::recursive_mutex m_mtx {};
	inline static bool m_run = false;
};

struct AsyncTimer {
	AsyncTimer () { }
	~AsyncTimer () { Cancel (); }

	Task<bool> WaitTimeoutAsync (TimeSpan _elapse) {
		co_return !co_await m_mtx.Lock (_elapse);
	}

	template<typename F>
	void WaitCallback (TimeSpan _elapse, F _cb) {
		if (!m_mtx.IsLocked ())
			m_mtx.LockSync ();
		Tasks::RunAsync ([this] (TimeSpan _elapse, F _cb) -> Task<void> {
			bool _lock = co_await m_mtx.Lock (_elapse);
			if (!_lock) {
				using TRet = typename std::decay<decltype (_cb ())>;
				if constexpr (std::is_same<TRet, void>::value) {
					_cb ();
				} else if constexpr (std::is_same<TRet, Task<void>>::value) {
					co_await _cb ();
				} else {
					static_assert (std::is_void<TRet>::value || std::is_same<TRet, Task<void>>::value, "Unsupported returns type");
				}
			}
		}, _elapse, _cb);
	}

	void Cancel () {
		if (m_mtx.IsLocked ())
			m_mtx.Unlock ();
	}

private:
	AsyncMutex m_mtx {};
};
}



#endif //__FV_COMMON_HPP__
