#ifndef __FV_REQ_RES_HPP__
#define __FV_REQ_RES_HPP__



#include <chrono>
#include <memory>
#include <string>
#include <unordered_map>
#include <variant>
#include <vector>

#include "common.hpp"
#include "structs.hpp"



namespace fv {
struct IConn;
struct IConn2;
struct WsConn;

struct Request {
	Request () {}
	Request (std::string _url, MethodType _method): Url (_url), Method (_method) {}

	TimeSpan Timeout = std::chrono::seconds (0);
	std::string Server = "";
	//
	std::string Url = "";
	MethodType Method = MethodType::Get;
	std::string Schema = "";
	std::string UrlPath = "";
	std::string Content = "";
	std::vector<url_kv> QueryItems;
	std::vector<std::variant<body_kv, body_file>> ContentItems;
	CaseInsensitiveMap Headers = DefaultHeaders ();
	std::unordered_map<std::string, std::string> Cookies;

	static Task<Request> GetFromConn (std::shared_ptr<IConn2> _conn, uint16_t _listen_port);
	static CaseInsensitiveMap DefaultHeaders () { return m_def_headers; }
	static void SetDefaultHeader (std::string _key, std::string _value) { m_def_headers [_key] = _value; }

	std::string Serilize (std::string _host, std::string _port, std::string _path);
	bool IsWebsocket ();
	Task<std::shared_ptr<WsConn>> UpgradeWebsocket ();
	bool IsUpgraded () { return Upgrade; }

private:
	bool _content_raw_contains_files ();
	std::shared_ptr<IConn2> Conn;
	bool Upgrade = false;

	inline static CaseInsensitiveMap m_def_headers { { "Accept", "*/*" }, { "Accept-Encoding", "gzip" }, { "Accept-Language", "zh-CN,zh,q=0.9" }, { "Pragma", "no-cache" }, { "Cache-Control", "no-cache" }, { "Connection", "keep-alive" }, { "User-Agent", version } };
};



struct Response {
	int HttpCode = -1;
	std::string Content = "";
	CaseInsensitiveMap Headers;

	static Task<Response> GetFromConn (std::shared_ptr<IConn> _conn);
	static Response Empty () { return Response {}; }
	static Response FromNotFound ();
	static Response FromText (std::string _text);
	static Response FromUpgradeWebsocket (Request &_r);

	std::string Serilize ();

private:
	static void InitDefaultHeaders (CaseInsensitiveMap &_map);
};
}



#endif //__FV_REQ_RES_HPP__
