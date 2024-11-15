#ifndef __FV_COMMON_FUNCS_HPP__
#define __FV_COMMON_FUNCS_HPP__



#include <algorithm>
#include <string>



namespace fv {
inline std::string _to_lower (std::string _s) { std::transform (_s.begin (), _s.end (), _s.begin (), ::tolower); return _s; }



inline std::string _trim (std::string _s) {
	size_t _start = 0, _stop = _s.size ();
	while (_start < _stop) {
		char _ch = _s [_start];
		if (_ch != ' ' && _ch != '\r')
			break;
		_start++;
	}
	while (_start < _stop) {
		char _ch = _s [_stop - 1];
		if (_ch != ' ' && _ch != '\r')
			break;
		_stop--;
	}
	return _s.substr (_start, _stop - _start);
};



inline std::string random_str (size_t _len) {
	static const std::string s_chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
	std::string _str = "";
	if (_len == 0 || _len == std::string::npos)
		return _str;
	_str.resize (_len);
	for (size_t i = 0; i < _len; ++i)
		_str [i] = s_chars [((size_t) ::rand ()) % s_chars.size ()];
	return _str;
}



inline std::string percent_encode (std::string_view data) {
	static const char *hex_char = "0123456789ABCDEF";
	std::string ret = "";
	for (size_t i = 0; i < data.size (); ++i) {
		char ch = data [i];
		if (isalnum ((unsigned char) ch) || ch == '-' || ch == '_' || ch == '.' || ch == '~') {
			ret += ch;
		} else if (ch == ' ') {
			ret += "+";
		} else {
			ret += '%';
			ret += hex_char [((unsigned char) ch) >> 4];
			ret += hex_char [((unsigned char) ch) % 16];
		}
	}
	return ret;
}



inline std::string base64_encode (std::string_view data) {
	static const std::string base64_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
	std::string ret;
	int i = 0, j = 0;
	unsigned char char_3 [3], char_4 [4];
	size_t in_len = data.size ();
	unsigned char *bytes_to_encode = (unsigned char *) &data [0];
	while (in_len--) {
		char_3 [i++] = *(bytes_to_encode++);
		if (i == 3) {
			char_4 [0] = (char_3 [0] & 0xfc) >> 2;
			char_4 [1] = ((char_3 [0] & 0x03) << 4) + ((char_3 [1] & 0xf0) >> 4);
			char_4 [2] = ((char_3 [1] & 0x0f) << 2) + ((char_3 [2] & 0xc0) >> 6);
			char_4 [3] = char_3 [2] & 0x3f;

			for (i = 0; i < 4; i++)
				ret += base64_chars [char_4 [i]];
			i = 0;
		}
	}
	if (i) {
		for (j = i; j < 3; j++)
			char_3 [j] = '\0';
		char_4 [0] = (char_3 [0] & 0xfc) >> 2;
		char_4 [1] = ((char_3 [0] & 0x03) << 4) + ((char_3 [1] & 0xf0) >> 4);
		char_4 [2] = ((char_3 [1] & 0x0f) << 2) + ((char_3 [2] & 0xc0) >> 6);
		for (j = 0; j < i + 1; j++)
			ret += base64_chars [char_4 [j]];
		while ((i++ < 3))
			ret += '=';
	}
	return ret;
}



inline std::tuple<std::string, std::string, std::string, std::string> _parse_url (std::string _url) {
	size_t _p = _url.find ('#');
	if (_p != std::string::npos)
		_url = _url.substr (0, _p);
	std::string _schema = "http";
	_p = _url.find ("://");
	if (_p != std::string::npos) {
		_schema = _to_lower (_url.substr (0, _p));
		_url = _url.substr (_p + 3);
	}
	//
	_p = _url.find ('/');
	std::string _path = "/";
	if (_p != std::string::npos) {
		_path = _url.substr (_p);
		_url = _url.substr (0, _p);
	}
	//
	_p = _url.find (':');
	std::string _host = "", _port = "";
	if (_p != std::string::npos) {
		_host = _url.substr (0, _p);
		_port = _url.substr (_p + 1);
	} else {
		_host = _url;
		if (_schema == "http" || _schema == "ws") {
			_port = "80";
		} else if (_schema == "https" || _schema == "wss") {
			_port = "443";
		} else {
			throw Exception ("Unknown Port");
		}
	}
	return { _schema, _host, _port, _path };
}
}



#endif //__FV_COMMON_FUNCS_HPP__
