#ifndef __FV_TCP_SERVER_HPP___
#define __FV_TCP_SERVER_HPP___



#include <atomic>
#include <functional>
#include <memory>
#include <mutex>
#include <unordered_set>

#include "common.hpp"
#include "conn.hpp"



namespace fv {
struct TcpServer {
	void SetOnConnect (std::function<Task<void> (std::shared_ptr<IConn2>)> _on_connect) { OnConnect = _on_connect; }
	void RegisterClient (int64_t _id, std::shared_ptr<IConn2> _conn) { std::unique_lock _ul { Mutex }; Clients [_id] = _conn; }
	void UnregisterClient (int64_t _id, std::shared_ptr<IConn2> _conn) {
		std::unique_lock _ul { Mutex };
		if (Clients [_id].get () == _conn.get ())
			Clients.erase (_id);
	}
	Task<bool> SendData (int64_t _id, char *_data, size_t _size) {
		try {
			std::unique_lock _ul { Mutex };
			if (Clients.contains (_id)) {
				auto _conn = Clients [_id];
				_ul.unlock ();
				co_await _conn->Send (_data, _size);
				co_return true;
			}
		} catch (...) {
		}
		co_return false;
	}
	Task<size_t> BroadcastData (char *_data, size_t _size) {
		std::unique_lock _ul { Mutex };
		std::unordered_set<std::shared_ptr<IConn2>> _conns;
		for (auto [_key, _val] : Clients)
			_conns.emplace (_val);
		_ul.unlock ();
		size_t _count = 0;
		for (auto _conn : _conns) {
			try {
				co_await _conn->Send (_data, _size);
				_count++;
			} catch (...) {
			}
		}
		co_return _count;
	}
	Task<void> Run (std::string _ip, uint16_t _port) {
		if (IsRun.load ())
			co_return;
		IsRun.store (true);
		auto _executor = co_await asio::this_coro::executor;
		Tcp::endpoint _ep { asio::ip::address::from_string (_ip), _port };
		Acceptor = std::make_unique<Tcp::acceptor> (_executor, _ep, true);
		try {
			int c = 0;
			for (; IsRun.load ();) {
				std::cout << "TcpServer cycle " << c++ << " ..." << std::endl;
				std::shared_ptr<IConn2> _conn = std::shared_ptr<IConn2> ((IConn2 *) new TcpConn2 (co_await Acceptor->async_accept (UseAwaitable)));
				Tasks::RunAsync ([this, _conn] () -> Task<void> {
					co_await OnConnect (_conn);
				});
				std::cout << "TcpServer cycle " << c << " IS OVER " << std::endl;
			}
			std::cout << "TcpServer for quited... " << std::endl;
		} catch (std::exception e) {
			std::cout << "TcpServer EXCEPTION: " << e.what() << std::endl;
		}
		std::cout << "TcpServer::Run quited... " << std::endl;
		co_return;
	}
	Task<void> Run (uint16_t _port) {
		co_await Run ("0.0.0.0", _port);
		std::cout << "TcpServer::Run quited (0)... " << std::endl;
	}
	void Stop () {
		std::cout << "TcpServer going to: IsRun.store (false);" << std::endl;
		IsRun.store (false);
		std::cout << "TcpServer is stopped" << std::endl;
		if (Acceptor) {
			std::cout << "TcpServer is doing: Acceptor->cancel ()" << std::endl;
			Acceptor->cancel ();
			std::cout << "TcpServer: Acceptor->cancel () is done" << std::endl;
		}
	}

private:
	std::unique_ptr<Tcp::acceptor> Acceptor;
	std::function<Task<void> (std::shared_ptr<IConn2>)> OnConnect;
	std::unordered_map<int64_t, std::shared_ptr<IConn2>> Clients;
	std::mutex Mutex;
	std::atomic_bool IsRun { false };
};



struct HttpServer {
	void OnBefore (std::function<Task<std::optional<fv::Response>> (fv::Request &)> _cb) { m_before = _cb; }
	void SetHttpHandler (std::string _path, std::function<Task<fv::Response> (fv::Request &)> _cb) { m_map_proc [_path] = _cb; }
	void SetHttpHandler1 (std::string _path, std::function<Task<void> (Request &, std::function<Task<void> (Response&)>)> _cb) { m_map_proc1 [_path] = _cb; }
	void OnUnhandled (std::function<Task<fv::Response> (fv::Request &)> _cb) { m_unhandled_proc = _cb; }
	void OnAfter (std::function<Task<void> (fv::Request &, fv::Response &)> _cb) { m_after = _cb; }

	Task<void> Run (uint16_t _port) {
		m_tcpserver.SetOnConnect ([this, _port] (std::shared_ptr<IConn2> _conn) -> Task<void> {
			while (true) {
				Request _req = co_await Request::GetFromConn (_conn, _port);
				if (m_before) {
					std::optional<Response> _ores = co_await m_before (_req);
					if (_ores.has_value ()) {
						if (m_after)
							co_await m_after (_req, _ores.value ());
						std::string _str_res = _ores.value ().Serilize ();
						co_await _conn->Send (_str_res.data (), _str_res.size ());
						continue;
					}
				}
				auto proc1 = [this, &_req, &_conn](Response& _res1) -> Task<void> {
					if (_res1.HttpCode == -1) {
						try {
							_res1 = co_await m_unhandled_proc (_req);
						} catch (...) {
						}
					}
					if (_res1.HttpCode == -1)
						_res1 = Response::FromNotFound ();
					if (m_after)
						co_await m_after (_req, _res1);
					std::string _str_res = _res1.Serilize ();
					co_await _conn->Send (_str_res.data (), _str_res.size ());
				};
				if (m_map_proc1.contains (_req.UrlPath)) {
					try {
						co_await m_map_proc1 [_req.UrlPath] (_req, proc1);
					} catch (...) {
					}
				} else {
					Response _res {};
					if (m_map_proc.contains (_req.UrlPath)) {
						try {
							_res = co_await m_map_proc [_req.UrlPath] (_req);
						} catch (...) {
						}
					}
					if (_res.HttpCode == -1) {
						try {
							_res = co_await m_unhandled_proc (_req);
						} catch (...) {
						}
					}
					if (_req.IsUpgraded ())
						break;
					if (_res.HttpCode == -1)
						_res = Response::FromNotFound ();
					if (m_after)
						co_await m_after (_req, _res);
					std::string _str_res = _res.Serilize ();
					co_await _conn->Send (_str_res.data (), _str_res.size ());
				}
			}
		});
		co_await m_tcpserver.Run (_port);
		std::cout << "HttpServer::Run quited (0)... " << std::endl;
	}

	void Stop () {
		std::cout << "HttpServer going to: m_tcpserver.Stop ();" << std::endl;
		m_tcpserver.Stop (); 
		std::cout << "HttpServer m_tcpserver.Stop (); IS DONE" << std::endl;
	}

private:
	TcpServer m_tcpserver {};
	std::function<Task<std::optional<Response>> (Request &)> m_before;
	std::unordered_map<std::string, std::function<Task<Response> (Request &)>> m_map_proc;
	std::unordered_map<std::string,
		std::function<Task<void> (Request &, std::function<Task<void> (Response&)>)>
	> m_map_proc1;
	std::function<Task<Response> (Request &)> m_unhandled_proc = [] (Request &) -> Task<Response> { co_return Response::FromNotFound (); };
	std::function<Task<void> (Request &, Response &)> m_after;
};
}



#endif //__FV_TCP_SERVER_HPP___
