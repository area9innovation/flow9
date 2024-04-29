#ifndef __FV_CONN_HPP__
#define __FV_CONN_HPP__



#include <memory>
#include <string>
#include <vector>

#include "common.hpp"
#include "structs.hpp"
#include "req_res.hpp"



namespace fv {
struct IConn2 {
	std::string m_host = "", m_port = "";

	IConn2 () = default;
	virtual ~IConn2 () = default;
	virtual bool IsConnect () = 0;
	virtual Task<void> Send (char *_data, size_t _size) = 0;
	virtual void Cancel () = 0;

	Task<char> ReadChar ();
	Task<std::string> ReadLine ();
	Task<std::string> ReadCount (size_t _count);
	Task<std::vector<uint8_t>> ReadCountVec (size_t _count);
	Task<std::string> ReadSome ();

protected:
	virtual Task<size_t> RecvImpl (char *_data, size_t _size) = 0;
	std::string TmpData = "";
};



struct IConn: public IConn2 {
	virtual Task<void> Connect (std::string _host, std::string _port) = 0;
	virtual Task<void> Reconnect () = 0;
};



struct TcpConn: public IConn {
	std::shared_ptr<Tcp::socket> Socket;

	virtual ~TcpConn () { Cancel (); }
	Task<void> Connect (std::string _host, std::string _port) override;
	Task<void> Reconnect () override;
	bool IsConnect () override { return Socket->is_open (); }
	Task<void> Send (char *_data, size_t _size) override;
	void Cancel () override;

protected:
	Task<size_t> RecvImpl (char *_data, size_t _size) override;
};



struct TcpConn2: public IConn2 {
	Tcp::socket Socket;
	int64_t Id = -1;

	TcpConn2 (Tcp::socket _sock);

	virtual ~TcpConn2 () { Cancel (); }
	bool IsConnect () override { return Socket.is_open (); }
	Task<void> Send (char *_data, size_t _size) override;
	void Cancel () override;

protected:
	Task<size_t> RecvImpl (char *_data, size_t _size) override;
};



struct SslConn: public IConn {
	Ssl::context SslCtx { Config::SslClientVer };
	std::shared_ptr<Ssl::stream<Tcp::socket>> SslSocket;

	virtual ~SslConn () { Cancel (); }
	Task<void> Connect (std::string _host, std::string _port) override;
	Task<void> Reconnect () override;
	bool IsConnect () override { return SslSocket && SslSocket->next_layer ().is_open (); }
	Task<void> Send (char *_data, size_t _size) override;
	void Cancel () override;

protected:
	Task<size_t> RecvImpl (char *_data, size_t _size) override;
};



struct SslConn2: public IConn2 {
	Ssl::stream<Tcp::socket> SslSocket;
	int64_t Id = -1;

	SslConn2 (Ssl::stream<Tcp::socket> _sock);

	virtual ~SslConn2 () { Cancel (); }
	bool IsConnect () override { return SslSocket.next_layer ().is_open (); }
	Task<void> Send (char *_data, size_t _size) override;
	void Cancel () override;

protected:
	Task<size_t> RecvImpl (char *_data, size_t _size) override;
};



struct WsConn: public std::enable_shared_from_this<WsConn> {
	std::shared_ptr<IConn2> Parent;
	bool IsClient = true;
	std::atomic_bool Run { true };

	WsConn (std::shared_ptr<IConn2> _parent, bool _is_client);
	void Init ();
	bool IsConnect () { return Parent && Parent->IsConnect (); }
	Task<void> SendText (char *_data, size_t _size) { co_await _Send (_data, _size, WsType::Text); }
	Task<void> SendBinary (char *_data, size_t _size) { co_await _Send (_data, _size, WsType::Binary); }
	Task<void> Close () { Run.store (false); co_await _Send (nullptr, 0, WsType::Close); Parent = nullptr; }
	Task<std::tuple<std::string, WsType>> Recv ();

private:
	Task<void> _Send (char *_data, size_t _size, WsType _type);
};

Task<std::shared_ptr<IConn>> Connect (std::string _url);
template<TOption ..._Ops>
inline Task<std::shared_ptr<WsConn>> ConnectWS (std::string _url, _Ops ..._ops);
}



#endif //__FV_CONN_HPP__
