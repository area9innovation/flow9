#pragma once


#include "flow_string.hpp"
#include "flow_object.hpp"
#include "flow_array.hpp"
#include "flow_ref.hpp"
#include "flow_t.hpp"
#include "binaryserializer.hpp"

#ifdef FLOW_ENABLE_CONCURRENCY
	#include "concurrency.hpp"
#endif

#include <vector>
#include <map>
#include <cmath>
#include <numeric>
#include <fstream>
#include <iostream>
#include <sstream>
#include <functional>
#include <algorithm>
#include <locale>
#include <chrono>
#include <codecvt>

#include "flow_rendersupport.hpp"

#ifdef FLOWC_RUNTIME_INCLUDE_MD5
	// Include path to flow/QtByteRunner/core/
	#include "md5.h"
	#include "md5.cpp"
#endif

#ifdef FLOWC_RUNTIME_INCLUDE_FILESYSTEM
	#include <experimental/filesystem>
#endif

namespace flow {
	
	template <typename T>
	using array_t = array<ptr_type_t<T>>;
	
} // namespace flow

template <typename T>
void fcPrintln(flow::fparam<T> v) {
	fcPrintln<flow::string>(toString(v));
}

template <>
void fcPrintln<flow::string>(const flow::string& s) {
	std::wcout << static_cast<std::wstring>(s) << std::endl;
}

template <typename T>
FLOW_INLINE int elemIndex(const flow::array_t<T>& v, const flow::ptr_type_t<T> elem, const int illegal) {
	for (size_t i = 0; i < static_cast<size_t>(v.size()); i++) {
		if (v[i] == elem) {
			return i;
		}
	}
	return illegal;
}

template <typename T1, typename T2>
FLOW_INLINE flow::array_t<T2> map(const flow::array_t<T1>& v, const std::function<flow::ptr_type_t<T2>(flow::fparam<T1>)> f) {
	std::vector<flow::ptr_type_t<T2>> vv;
	vv.reserve(v.size());
	std::transform(v.cbegin(), v.cend(), std::back_inserter(vv), f);
	return vv;
}

template <typename T, typename TT, typename F>
FLOW_INLINE flow::array_t<TT> mapi(const flow::array_t<T>& v, F f) {
	std::vector<flow::ptr_type_t<TT>> vv;
	vv.reserve(v.size());
	for (size_t i = 0; i < v.size(); i++) {
		vv.push_back(f(i, v[i]));
	}
	return vv;
}

template<typename T>
FLOW_ALWAYS_INLINE int length(const flow::array_t<T>& v) {
	return v.size();
}

template <typename T>
flow::array_t<T> subrange(const flow::array_t<T>& v, int index, int length) {
	std::vector<flow::ptr_type_t<T>> vv;
	if (index < 0 || length < 1) return vv;
	vv.reserve(std::min<int>(length, v.size() - index));
	std::copy_n(v.cbegin() + index, std::min<int>(length, v.size() - index), std::back_inserter(vv));
	return vv;
}

template <typename T>
flow::array_t<T> concat(const flow::array_t<T>& v1, const flow::array_t<T>& v2) {
	std::vector<flow::ptr_type_t<T>> vv;
	vv.reserve(v1.size() + v2.size());
	vv.insert(vv.end(), v1.cbegin(), v1.cend());
	vv.insert(vv.end(), v2.cbegin(), v2.cend());
	return vv;
}

FLOW_INLINE flow::array<int> enumFromTo(int start, int end) {
	std::vector<int> v;
	if (start > end) return v;
	v.resize(end - start  + 1);
	for (int i = start; i <= end; i++) {
		v[i-start] = i;
	}
	return v;
}

template <typename T, typename TT, typename F>
FLOW_ALWAYS_INLINE flow::ptr_type_t<TT> fold(const flow::array_t<T>& xs, const flow::ptr_type_t<TT> init, F f) {
	// return std::accumulate(xs.cbegin(), xs.cend(), init, f);
	flow::ptr_type_t<TT> acc = init;
	for (int i = 0; i < xs.size(); i++) {
		acc = f(acc, xs[i]);
	}
	return acc;
}

template <typename T, typename TT, typename F>
FLOW_ALWAYS_INLINE flow::ptr_type_t<TT> foldi(const flow::array_t<T>& xs, const flow::ptr_type_t<TT> init, F f) {
 	flow::ptr_type_t<TT> init2 = init;
	for (int i = 0; i < xs.size(); i++) {
		init2 = f(i, init2, xs[i]);
	}
	return init2;
}

// TODO: optimize this!
template <typename T, typename F>
flow::array_t<T> filter(const flow::array_t<T>& a, F test) {
	std::vector<flow::ptr_type_t<T>> v;
	std::copy_if(a.cbegin(), a.cend(), std::back_inserter(v), test);
	return v;
}

template <typename T, typename F>
void iteri(const flow::array_t<T>& a, F fn) {
	for (size_t i = 0; i < a.size(); i++) {
		fn(i, a[i]);
	}
}

template <typename T, typename F>
void iter(const flow::array_t<T>& a, F fn) {
	std::for_each(a.cbegin(), a.cend(), std::move(fn));
}

template <typename T, typename F>
bool exists(const flow::array_t<T>& a, F fn) {
	return std::find_if(a.cbegin(), a.cend(), std::move(fn)) != a.cend();
}

uint64_t g_replace_tsc = 0;

template <typename T>
flow::array_t<T> replace(const flow::array_t<T>& a, int i, flow::ptr_type_t<T> elem) {
	tsc_holder holder(g_replace_tsc);
	if (a.size() == 0) {
		if (i == 0) {
			return std::vector<flow::ptr_type_t<T>>({ elem });
		} else {
			return a;
		}
	}
	if (i == a.size()) {
		std::vector<flow::ptr_type_t<T>> v;
		v.reserve(a.size() + 1);
		const flow::ptr_type_t<T>* begin = &(*(a.vec_))[0];
		for (int i = 0; i < a.size(); i++) {
			v.push_back(begin[i]);
		}
		v.push_back(elem);
		return v;
	} else {
		std::vector<flow::ptr_type_t<T>> v = *(a.vec_);
		if (i >= 0 && i < static_cast<int>(v.size())) {
			v[i] = elem;
		}
		return v;
	}
}

template <typename T, typename F>
size_t iteriUntil(const flow::array_t<T>& a, F fn) {
	for (size_t i = 0; i < a.size(); i++) {
		if (fn(i, a[i])) return i;
	}
	return a.size();
}

flow::array<int> s2a(const std::wstring& s) {
	std::vector<int> v(s.size());
	std::transform(s.cbegin(), s.cend(), v.begin(), [] (auto x) { return static_cast<int>(x); });
	return v;
}

flow::array<int> s2a(const flow::string& s) {
	return s2a(std::wstring(s));
}

flow::string toUpperCase(const flow::string& str) {
	std::wstring s;
	std::transform(str.cbegin(), str.cend(), std::back_inserter(s), ::toupper);
	return s;
}

flow::string toLowerCase(const flow::string& str) {
	std::wstring s;
	std::transform(str.cbegin(), str.cend(), std::back_inserter(s), ::tolower);
	return s;
}

int getCharCodeAt(const flow::string& s, int i) {
	return (i >= 0 && i < static_cast<int>(s.size())) ? (int)s[i] : -1;
}

flow::string fromCharCode(int code) {
	std::wstring s(L" ");
	s[0] = code;
	return s;
}

FLOW_INLINE int strlen(const flow::string& str) {
	return str.size();
}

int clipLenToRange(int start, int len, int size) {
	int end = start + len;
	if (end > size || end < 0) {
		len = size - start;
	}
	return len;
}

flow::string substring(const flow::string& str, int start, int len) {
	int strlen = str.size();
	if (len < 0) {
	  if (start < 0) {
		len = 0;
	  } else {
		int smartLen1 = len + start;
		if (smartLen1 >= 0) {
		  len = 0;
		} else {
		  int smartLen2 = smartLen1 + strlen;
		  if (smartLen2 <= 0) {
			len = 0;
		  } else {
			len = smartLen2;
		  }
		}
	  }
	}
	if (start < 0) {
	  int smartStart = start + strlen;
	  if (smartStart > 0) {
		start = smartStart;
	  } else {
		start = 0;
	  }
	} else if (start >= strlen) {
	  len = 0;
	}

	if (len < 1) return flow::string(L"");

	len = clipLenToRange(start, len, strlen);
	return str.substr(start, start + len);
}

int strIndexOf(const flow::string& str, const flow::string& substr) {
	auto pos = str.find(substr);
	return (pos == flow::string::npos) ? -1 : pos;
}

int strRangeIndexOf(const flow::string& str, const flow::string& substr, int start, int end) {
	
	// TODO: rewrite the whole function using std::search() later
	if (start + substr.size() == end && start >= 0 && end <= str.size()) {
		for (int i = start; i < end; i++) {
			if (str[i] != substr[i-start])
				return -1;
		}
		return start;
	}
	
  if (start < 0)
	start = 0;

  if (end >= static_cast<int>(str.size())) {
    size_t f1 = str.find(substr, start);
    if (f1 == flow::string::npos) {
      return -1;
    } else {
      return (int)f1;
    }
  }

  end -= substr.size() - 1;

  size_t fnd = str.find(substr, start);
  if (fnd != flow::string::npos && static_cast<int>(fnd) <= end - 1)
	return static_cast<int>(fnd);

  return -1;
}

void dump_tsc_counters();

void quit(const int code) {
	dump_tsc_counters();
	std::exit(code);
}

void fail(const flow::string& msg) {
	std::wcout << static_cast<std::wstring>(msg) << std::endl;
	quit(255);
}

flow::string getTargetName () {
	return flow::string(L"cpp,native");
}

flow::string hostCall(flow::string name, flow::array<flow::string> args) {
	// temporary stub. TODO: implement it when needed
	return flow::string();
}

namespace flow {
	const flow::string str_quote = flow::string(L"\"");
}

flow::string toString(flow::string s) { 
	// TODO: fix it!
	return flow::str_quote + s + flow::str_quote; 
}

flow::string toString(bool b) {
	return b ? flow::string(L"true") : flow::string(L"false");
}

flow::string toString(const int i) { 
	return flow::string(std::to_wstring(i)); 
}

flow::string toString(double d) { 
	return flow::string(std::to_wstring(d)); 
}

template <typename T>
flow::string toString(std::function<T>) {
	return flow::string(L"function");
}

flow::string toString(const flow::flow_t& f);

template <typename T>
flow::string toString(const flow::array<T>& a) {
	flow::string s(L"[");
	for (int i = 0; i < length<T>(a); i++) {
		if (i > 0) s = s + flow::string(L", ");
		s = s + toString(a[i]);
	}
	s = s + flow::string(L"]");
	return s;
}

template <typename T>
flow::string toString(const flow::ref<T>& r) {
	return flow::string(L"ref ") + toString(*r);
}

template <typename T, typename = flow::is_struct_type_t<T>>
flow::string toString(const flow::ptr<T>& p) {
	return p->toString();
}

template <typename T, typename = flow::is_union_type_t<T>>
flow::string toString(const T& u) {
	return u.ptr_.ptr_->toString();
}

flow::string toString(const native&) {
	return flow::string(L"native");
}

flow::string toString(const flow::flow_t& f) {
	switch (f.value_.index()) {
		case flow::flow_t::is_struct:
			return f.get_object_ref().ptr_->toString();
		case flow::flow_t::is_array_of_flow_t:
			return toString(f.get_array());
		case flow::flow_t::is_int:
			return toString(f.get_int());
		case flow::flow_t::is_double:
			return toString(f.get_double());
		case flow::flow_t::is_string:
			return toString(f.get_string());
		default:
			FLOW_UNREACHABLE();
	}
}

namespace flow {
	flow::string toString2(const flow::flow_t& f) {
		::toString(f);
	}
}

flow::string loaderUrl() {
	return flow::string();
}

std::wstring s2ws_impl(const std::string& str)
{
	using convert_typeX = std::codecvt_utf8<wchar_t>;
	std::wstring_convert<convert_typeX, wchar_t> converterX;

	return converterX.from_bytes(str);
}

flow::string s2ws(const std::string& str)
{
	return flow::string(s2ws_impl(str));
}

std::string ws2s(const flow::string& wstr)
{
	using convert_typeX = std::codecvt_utf8<wchar_t>;
	std::wstring_convert<convert_typeX, wchar_t> converterX;

	return converterX.to_bytes(std::wstring(wstr));
}

flow::array<int> string2utf8(const flow::string& str) {
	std::string u = ws2s(str);
	std::vector<int> v(u.size());
	std::transform(u.cbegin(), u.cend(), v.begin(), [] (wchar_t c) { return static_cast<uint8_t>(c); });
	return v;
}

bool setFileContent(const flow::string& filename, const flow::string& content) {
	// TODO: Wrap with exception handler or error protection
	std::wofstream file;
	file.open(ws2s(filename).c_str());
	file.imbue(std::locale(file.getloc(), new std::codecvt_utf8<wchar_t>));
	file << static_cast<std::wstring>(content);
	file.close();
	return true;	
}

bool setFileContentUTF16(const flow::string& filename, const flow::string& content) {
	FLOW_ASSERT(false);
	return false;
}

double number2double(const flow::flow_t& f) {
	switch (f.index()) {
		case flow::flow_t::is_int:		return f.get_int();
		case flow::flow_t::is_double:	return f.get_double();
		default:	FLOW_ABORT
	}
}

int dayOfWeek1(int, int, int) {
	FLOW_ABORT
}

bool isArray(const flow::flow_t& f) {
	return f.index() == flow::flow_t::is_array_of_flow_t;
}

#ifdef FLOWC_RUNTIME_INCLUDE_FILESYSTEM

double fileModified(const flow::string& filename) {
	namespace fs = std::experimental::filesystem;
	std::error_code err;
	fs::file_time_type t = fs::last_write_time(ws2s(filename), err);
	if (err.value() == 0) {
		std::time_t tt = std::chrono::system_clock::to_time_t(t);
		return std::chrono::milliseconds(tt).count() * 1000.0;
	} else {
		// file does not exist
		return 0.0;
	}
}

bool isDirectory(const flow::string& filename) {
	namespace fs = std::experimental::filesystem;
	return fs::is_directory(ws2s(filename));
}

flow::string createDirectory(const flow::string& filename) {
	namespace fs = std::experimental::filesystem;
	return flow::string(fs::create_directory(ws2s(filename)) ? L"" : L"Failed");
}

flow::string deleteDirectory(const flow::string& filename) {
	namespace fs = std::experimental::filesystem;
	return flow::string(fs::remove(ws2s(filename)) ? L"" : L"Failed");
}

double fileSize(const flow::string& filename) {
	namespace fs = std::experimental::filesystem;
	fs::path p{ws2s(filename)};
	p = fs::canonical(p);
	return (double)fs::file_size(p);
}

bool setFileContentBytes(const flow::string& filename, const flow::string& content) {
	FLOW_ASSERT(false); // TODO not implemented
	return false;
}


#endif // FLOWC_RUNTIME_INCLUDE_FILESYSTEM


flow::string deleteFile(const flow::string& filename) {
	std::remove(ws2s(filename).c_str());
	return flow::string(L"");
}

bool fileExists(const flow::string& filename)
{
	std::wifstream infile(ws2s(filename).c_str());
	return infile.good();
}

flow::string getFileContent(const flow::string& filename)
{
	if (fileExists(filename)) {
		std::wifstream wif(ws2s(filename).c_str());
		wif.imbue(std::locale(wif.getloc(), new std::codecvt_utf8<wchar_t>));
		std::wstringstream wss;
		wss << wif.rdbuf();
		return flow::string(wss.str());
	} else {
		return flow::string(L"");
	}
}

template <typename T, typename = flow::is_struct_type_t<T>>
bool isSameStructType(const flow::ptr<T>& left, const flow::flow_t& right) {
	return left.ref_.ptr_->obj_id_ == right.get_struct_type();
}

template <typename T>
constexpr bool isSameStructType(const flow::ptr<T>& left, const flow::ptr<T>& right) {
	return true;
}

template <typename T1, typename T2>
constexpr bool isSameStructType(const T1& left, const T2& right) {
	return false;
}

FLOW_INLINE int bitShl(int a, int n)		{ return a << n;	}
FLOW_INLINE int bitUshr(int a, int n)	{ return ((unsigned int)a) >> n;	}
FLOW_INLINE int bitOr(int a, int b)		{ return a | b;		}
FLOW_INLINE int bitAnd(int a, int b)		{ return a & b;		}
FLOW_INLINE int bitXor(int a, int b)		{ return a ^ b;		}
FLOW_INLINE int bitNot(int a)			{ return ~a;		}

double timestamp() {
	std::chrono::duration<double, std::milli> ms = std::chrono::system_clock::now().time_since_epoch();
	return ms.count();
}

std::wstring toBinary(const double d) {
	// This is an significantly simplified version of toBinary,
	// which only converts double to string representation.
	// Correct value of converted data is ONLY in positions 3-6,
	// other values are zeroed.
	// This version is only intended to be used with double2bytes
	// (in bytecode.flow).
	std::wstring a;
	for (int i = 0; i < 3; i++) {
		a.push_back(0);
	}
	const int *pdata = (const int*)&d;
	a.push_back(static_cast<wchar_t>(pdata[0] & 0xFFFF));
	a.push_back(static_cast<wchar_t>((pdata[0] >> 16) & 0xFFFF));
	a.push_back(static_cast<wchar_t>(pdata[1] & 0xFFFF));
	a.push_back(static_cast<wchar_t>((pdata[1] >> 16) & 0xFFFF));
	a.push_back(0);
	return a;
}

template <typename T>
flow::string toBinary(const flow::ptr<T>& value) {
	flow::BinarySerializer serializer;
    serializer.serialize(value);
	return serializer.output();
}

// using flow::flow_t;

int stringbytes2int(const flow::string& s) {
	FLOW_ASSERT(s.size() == 2);
	flow::string::char_t buf[2] = {s[0], s[1]};
	return *(int*)buf;
}

double stringbytes2double(const flow::string& s) {
	FLOW_ASSERT(s.size() == 4);
	flow::string::char_t buf[4] = {s[0], s[1], s[2], s[3]};
	return *(double*)buf;
}

double string2time(const flow::string& s) {
	// not implemented!
	// FLOW_ASSERT(false);
	return 0.0;
}

flow::string time2string(double t) {
	// not implemented!
	// FLOW_ASSERT(false);
	return flow::string(L"");
}

namespace flow {
	double mod_double(double a, double b) {
		FLOW_ASSERT(a >= 0 && b > 0);
		return a - int(a/b)*b;
	}
	
	template <typename T>
	flow::string structname(const T&) {
		FLOW_ABORT
	}
	
	int get_struct_type(const flow::flow_t& f) {
		return f.id_();
	}
	
}

#ifdef FLOWC_RUNTIME_INCLUDE_MD5
flow::string md5(const flow::string& str) {
	return s2ws(md5(ws2s(str)));
}
#endif // FLOWC_RUNTIME_INCLUDE_MD5

char **stored_argv;
int stored_argc;

flow::array<flow::array<flow::string>> getAllUrlParametersArray() {
	if (stored_argc == 1) {
		return flow::array<flow::array<flow::string>>();
	} else {
		flow::array<flow::array<flow::string>>::vector_t params;
		for (int i = 1; i < stored_argc; i++) {
			flow::string st = s2ws(std::string(stored_argv[i]));
			size_t pos = st.find(flow::string(L"="));
			flow::array<flow::string>::vector_t v;
			if (pos == flow::string::npos) {
				v.push_back(st);
				v.push_back(flow::empty_string);
			} else {
				v.push_back(st.substr(0, pos));
				v.push_back(st.substr(pos + 1, flow::string::npos));
			}
			params.push_back(std::move(v));
		}
		return std::move(params);
	}
}

#ifdef FLOWC_RUNTIME_INCLUDE_FILESYSTEM
	namespace fs = std::experimental::filesystem;
	fs::path application_path;

flow::string resolveRelativePath(const flow::string& path) {
	fs::path resolved = std::wstring(path);
	return flow::string(fs::canonical(resolved).wstring());
}

flow::string getApplicationPath() {
	return application_path.wstring();
}

flow::array<flow::string> getApplicationArguments() {
	if (stored_argc == 1) {
		return flow::array<flow::string>();
	} else {
		flow::array<flow::string>::vector_t params;
		for (int i = 1; i < stored_argc; i++) {
			flow::string st = s2ws(std::string(stored_argv[i]));
			params.push_back(std::move(st));
		}
		return std::move(params);
	}
}

std::vector<flow::string> readDirectory(const flow::string& path) {
	std::vector<flow::string> res;
	for (auto& p : fs::directory_iterator(fs::path(std::wstring(path)))) {
		res.push_back(p.path().filename().wstring());
	}
	// std::filesystem's directory_iterator does not include those two guys
	// into the list, so add them manually.
	res.push_back(flow::string(L".."));
	res.push_back(flow::string(L"."));
	return res;
}
#endif

template <typename T, typename = flow::is_struct_type_t<T>>
FLOW_INLINE bool isSameObj(const flow::ptr_type_t<T>& o1, const flow::ptr_type_t<T>& o2) {
	return o1.ref_.is_same(o2.ref_);
}

template <typename T, typename = flow::is_union_type_t<T>>
FLOW_INLINE bool isSameObj(const T& o1, const T& o2) {
	return o1.ptr_.is_same(o2.ptr_);
}

template <typename T, typename = std::enable_if_t<std::is_same_v<T, flow::string>>>
FLOW_INLINE bool isSameObj(const T& s1, const flow::string& s2) {
	return s1.cbegin() == s2.cbegin();
}

namespace flow {
	std::map<flow::string, std::function<flow::object_ref(const flow::array<flow::flow_t>&)>> struct_creators;
}

flow::flow_t makeStructValue(const flow::string& structname, const flow::array_t<flow::flow_t>& args, const flow::flow_t& default_value) {
	auto it = flow::struct_creators.find(structname);
	if (it != flow::struct_creators.end()) {
		return flow::flow_t((it->second)(args));
	} else {
		return default_value;
	}
}

void printCallstack() {
	// Not implemented
	FLOW_ASSERT(false);
}

template <typename T>
flow::ptr_type_t<T> fail0(const flow::string& msg) {
	fcPrintln<flow::string>(msg);
	std::abort();
}

void startProcess(
	const flow::string& command, 
	flow::array<flow::string> args,
	const flow::string& currentWorkingDirectory, 
	const flow::string& _stdin, 
	std::function<void(int, const flow::string&, const flow::string&)> onExit
) {
	FLOW_ASSERT(false); // not implemented
}

namespace flow {
	
	#ifdef FLOW_ENABLE_CONCURRENCY
	
	int deep_copy(const int i) {
		return i;
	}
	
	bool deep_copy(const bool b) {
		return b;
	}
	
	double deep_copy(const double x) {
		return x;
	}
	
	flow::string deep_copy(const flow::string& str) {
		if (str.ptr_->is_concurrent_object_) {
			// TODO: copy pointer for long strings later if needed...
			if (str.ptr_->copy_ == nullptr) {
				auto new_str = flow::string(str.cbegin(), str.cend());
				str.ptr_->copy_ = (void*)new_str.ptr_.get();
				return new_str;
			} else {
				return (string_base*)str.ptr_->copy_;
			}
		} else {
			return str;
		}
	}
	
	template <typename T>
	flow::array<T> deep_copy(const flow::array<T>& arr) {
		// TODO: use copy_ later 
		std::vector<T> v;
		v.reserve(arr.size());
		for (int i = 0; i < arr.size(); i++) {
			v.push_back(deep_copy(arr[i]));
		}
		return v;
	}
	
	template <typename T>
	flow::ref<T> deep_copy(const flow::ref<T>& ref) {
		if (ref.ptr_->is_concurrent_object_) {
			if (ref.ptr_->copy_ == nullptr) {
				auto new_ref = flow::make_ref<T>(deep_copy(*ref));
				ref.ptr_->copy_ = (void*)new_ref.ptr_.get();
				return new_ref;
			} else {
				return *(ref_holder<T>*)ref.ptr_->copy_;
			}
		} else {
			return ref;
		}
	}
	
	template <typename T>
	std::function<T> deep_copy(const std::function<T>& f) {
		FLOW_ABORT
	}
	
	native deep_copy(const native& n) {
		FLOW_ABORT
	}
	
	template <typename T, typename = is_struct_type_t<T>>
	flow::ptr<T> deep_copy(const flow::ptr<T>& ptr) {
		const object* obj = ptr.ref_.ptr_.get();
		if (obj->is_concurrent_object_) {
			return object_ref(obj->deep_copy());
		} else {
			return ptr;
		}
	}
	
	template <typename T, typename = is_union_type_t<T>>
	T deep_copy(const T& u) {
		// ? if (obj->is_concurrent_object_)
		return object_ref(u.ptr_.ptr_->deep_copy());
	}
	
	#else // FLOW_ENABLE_CONCURRENCY
	
	template <typename T>
	T deep_copy(const T&) {
		FLOW_ABORT
	}
	
	#endif
	
} // namespace flow

uint64_t g_deep_copy_tsc = 0;

#ifdef FLOW_ENABLE_CONCURRENCY

std::unique_ptr<flow::threads_pool> g_threads_pool;
std::atomic_flag g_threads_pool_spin = ATOMIC_FLAG_INIT;

void on_concurrent_thread_start(int tid) {
	// FLOW_PRN("on_concurrent_thread_start" << tid);
	flow::g_local_thread_mem_pools = &flow::concurrent_mem_pools_managers[tid];
}

template <typename T> 
flow::array<flow::ptr_type_t<T>> concurrent(const bool fine, const flow::array<std::function<flow::ptr_type_t<T>()>>& tasks) {
	
	if (!g_threads_pool) {
		g_threads_pool.reset(new flow::threads_pool(on_concurrent_thread_start));
	}
	
	std::vector<std::function<void()>> tasks2;
	tasks2.reserve(tasks.size());
	
	std::vector<flow::ptr_type_t<T>>* results = new std::vector<flow::ptr_type_t<T>>();
	results->reserve(tasks.size());
	// TODO: release results?
	
	std::vector<int> indices(tasks.size());
	
	for (int i = 0; i < tasks.size(); i++) {
		tasks2.push_back([i, &results, &indices, &tasks] () {
			// FLOW_PRN("flow::g_local_thread_mem_pools == " << flow::g_local_thread_mem_pools);
			auto r = tasks[i]();
			flow::spin_lock_guard lock(g_threads_pool_spin);
			indices[i] = results->size();
			results->push_back(r);
			// FLOW_PRN("task " << i << " finished");
		});
	}
	
	g_threads_pool->run(tasks2);
	
	flow::threads_pool::concurrency_enabled = false;
	
	std::vector<flow::ptr_type_t<T>> results2;
	results2.reserve(tasks.size());
	{
		tsc_holder holder(g_deep_copy_tsc);
		for (int i = 0; i < tasks.size(); i++) {
			results2.push_back(flow::deep_copy((*results)[indices[i]]));
		}
	}

	// g_threads_pool->clear_memory();
	// TODO: release results instead...

	return results2;
}

#else // FLOW_ENABLE_CONCURRENCY

template <typename T1> 
flow::array<flow::ptr_type_t<T1>> sequential(const bool fine, const flow::array<std::function<flow::ptr_type_t<T1>()>>& tasks);

template <typename T> 
flow::array<flow::ptr_type_t<T>> concurrent(const bool fine, const flow::array<std::function<flow::ptr_type_t<T>()>>& tasks) {
	return sequential<T>(fine, tasks);
}

#endif // FLOW_ENABLE_CONCURRENCY


using flow::flow_t;

void makeHttpRequest(const flow::string& url, const bool postMethod, const flow::array<flow::array<flow::string>>& headers,
const flow::array<flow::array<flow::string>>& params, const std::function<void(flow::string)>& onData, 
const std::function<void(flow::string)>& onError, const std::function<void(int)>& onStatus) { FLOW_ABORT }

void httpCustomRequestNative(const flow::string& url, 
const flow::string& method, const flow::array<flow::array<flow::string>>& headers, 
const flow::array<flow::array<flow::string>>& parameters, const flow::string& data, const std::function<void(int, flow::string, 
flow::array<flow::array<flow::string>>)>& onResponse, bool async) { FLOW_ABORT }

double flow_random() { FLOW_ABORT }

void fcPrintln2(const flow::string& s) {
	fcPrintln<flow::string>(s);
}

// native setClipboard : io (text: string) -> void = Native.setClipboard;
void setClipboard(const flow::string& text) { FLOW_ABORT }

// native getGlobalClipboard : io () -> string = Native.getClipboard;
const flow::string getGlobalClipboard() { FLOW_ABORT }

