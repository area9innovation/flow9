// strings
#include <codecvt>
#include <string>
#include <locale>
// math
#include <cmath>

// common

void flow_quit(int32_t code) {
	// TODO
	exit(code);
}

template <typename A>
void flow_println2(A d) {
	std::cout << d << std::endl;
}

void flow_println2(std::u16string d) {
	std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> codecvt;
	std::cout << codecvt.to_bytes(d) << std::endl;
}

// math

double flow_log(double v) {
	return std::log(v);
}

double flow_exp(double v) {
	return std::exp(v);
}

// string

std::u16string flow_substring(std::u16string s, int32_t start, int32_t length) {
	return s.substr(start, length);
}

int32_t flow_strlen(std::u16string s) {
	return s.size();
}

int32_t flow_getCharCodeAt(std::u16string s, int32_t i) {
	return s.at(i);
}

// array

template <typename A, typename B> B
flow_fold(const std::vector<A> flow_a, const B flow_b, const std::function<B(B, A)> & flow_fn) {
  B _res = flow_b;
  for (std::size_t i = 0; i != flow_a.size(); ++i) {
    _res = flow_fn(_res, flow_a[i]);
  }
  return _res;
}

std::vector<int32_t> flow_enumFromTo(int32_t start, int32_t end) {
	if (end < start) {
		std::vector<int> res;
		return res;
	} else {
		int32_t len = end - start + 1;
		std::vector<int> res(len);
		std::generate(res.begin(), res.end(), [i = start] () mutable { return i++; });
		return res;
	}
}

template <typename A, typename B>
std::vector<B> flow_map(const std::vector<A> flow_a, const std::function<B(A)> & flow_fn) {
  std::vector<int> res(flow_a.size());
  for (std::size_t i = 0; i != flow_a.size(); ++i) {
    res[i] = flow_fn(flow_a[i]);
  }
  return res;
}

template <typename A>
std::vector<A> flow_filter(const std::vector<A> flow_a, const std::function<bool(A)> & flow_test) {
  std::vector<int> res;
  std::copy_if (flow_a.begin(), flow_a.end(), std::back_inserter(res), flow_test);
  return res;
}

template <typename A>
std::vector<A> flow_concat(const std::vector<A> flow_a, const std::vector<A> flow_b) {
  std::vector<A> res;
  res.reserve(flow_a.size() + flow_b.size());
  res.insert(res.end(), flow_a.cbegin(), flow_a.cend());
  res.insert(res.end(), flow_b.cbegin(), flow_b.cend());
  return res;
}


// flowstruct
template <typename A, typename ...Args2>
bool flow_isSameStructType(A struct1, std::variant<Args2...> struct2) {
	unsigned int id2 = std::visit([&](auto&& x) {return x._id;}, struct2);
	return struct1._id == id2;
}

template <typename ...Args1, typename B>
bool flow_isSameStructType(std::variant<Args1...> struct1, B struct2) {
	unsigned int id1 = std::visit([&](auto&& x) {return x._id;}, struct1);
	return id1 == struct2._id;
}

template <typename ...Args1, typename ...Args2>
bool flow_isSameStructType(std::variant<Args1...> struct1, std::variant<Args2...> struct2) {
	unsigned int id1 = std::visit([&](auto&& x) {return x._id;}, struct1);
	unsigned int id2 = std::visit([&](auto&& x) {return x._id;}, struct2);
	return id1 == id2;
}

template <typename A, typename B>
bool flow_isSameStructType(A struct1, B struct2) {
	return struct1._id == struct2._id;
}

template <typename A, typename ...B> A _extractStructVal(std::variant<B...> v) { return std::get<A>(v); }
template <typename A> A _extractStructVal(A v) { return v; }

template <typename A, typename B>
B flow_extractStruct(const std::vector<A> flow_a, B flow_b) {
  auto item = std::find_if(flow_a.begin(), flow_a.end(), [flow_b](A v){ return flow_isSameStructType(v, flow_b); });
  if (item == flow_a.end()) {
    return flow_b;
  } else {
    return _extractStructVal<B>(*item);
  }
}
