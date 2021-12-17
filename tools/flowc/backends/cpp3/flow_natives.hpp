// strings
#include <codecvt>
#include <string>
#include <locale>
#include <sstream>
#include <iomanip>
#include <variant>
#include <functional>
#include <iostream>
// math
#include <cmath>
// getStructName
#ifdef __GNUG__
#include <cstdlib>
#include <memory>
#include <cxxabi.h>
std::string demangle(const char* name) {
    int status = -4; // some arbitrary value to eliminate the compiler warning
    // enable c++11 by passing the flag -std=c++11 to g++
    std::unique_ptr<char, void(*)(void*)> res {
        abi::__cxa_demangle(name, NULL, NULL, &status),
        std::free
    };
    return (status==0) ? res.get() : name ;
}
#else
// does nothing if not g++
std::string demangle(const char* name) {
    return name;
}
#endif

namespace flowc {

template <typename A>
std::shared_ptr<A> makeFlowRef(A value) {
  return std::make_shared<A>(value);
}

// string

std::u16string substring(std::u16string s, int32_t start, int32_t length) {
	return s.substr(start, length);
}

int32_t strlen(std::u16string s) {
	return s.size();
}

int32_t getCharCodeAt(std::u16string s, int32_t i) {
	return s.at(i);
}

std::u16string string2u16string(const std::string& s) {
	std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> codecvt;
	return codecvt.from_bytes(s);
}

// precision = 20!
std::u16string d2s(double v) {
	std::stringstream stream;
	stream << std::fixed << std::setprecision(20) << v;
	return string2u16string(stream.str());
}

 std::u16string i2s(int x) {
	std::ostringstream os;
	os << x;
	return string2u16string(os.str());
 }

// common
template <typename T, typename TT>
T cast(const TT& val) {
	//std::cout<< "Casting from '" << demangle(typeid(val).name()) << "' to '" << demangle(typeid(T).name()) << "' ..." << std::endl;
	return T(reinterpret_cast<const T&>(val));
}

template <typename T, typename ...TT>
T cast_variant(std::variant<TT...> val) {
	//std::cout<< "Casting VARIANT from '" << demangle(typeid(val).name()) << "' to '" << demangle(typeid(T).name()) << "' ..." << std::endl;
	if (const T* pval = std::get_if<T>(&val)) {
		return *pval; 
	} else  {
		/*std::cout<< "ERROR casting from '" << demangle(typeid(val).name()) << "' to '" << demangle(typeid(T).name()) << "'" << std::endl;
		T res;
		return res;*/
		throw std::invalid_argument("variant type is not equal '" + demangle(typeid(T).name()) + "' [" +  demangle(typeid(val).name()) + "]");
	}
}

// compare unions by address
template <typename ...Args1, typename ...Args2>
bool operator==(std::variant<Args1...>& struct1, std::variant<Args2...>& struct2) {
	return &struct1 == &struct2;
}
// for structs ( Struct1 == Struct2). (Struct1 == Struct1) is overloaded inside the struct
template <typename A, typename B>
bool operator==(const A& lhs, const B& rhs) {
	return lhs._id == rhs._id;
}

void quit(int32_t code) {
	// TODO
	exit(code);
}

template <typename A>
void print2(A v) {
	std::cout << v;
}

void print2(std::u16string d) {
	std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> codecvt;
	std::cout << codecvt.to_bytes(d);
}

void print2(const bool d) {
	std::cout << (d ? "true" : "false");
}

void print2(const int d) {
	std::cout << d;
}

void print2(const double d) {
	print2(d2s(d));
}

template <typename ...Args>
void print2(const std::variant<Args...> v) {
	std::visit([](auto&& x) { print2(x); }, v);
}

template <typename A>
void print2(const std::vector<A>& v) {
	int32_t lastInd = v.size() - 1;

    print2("[");
    for (std::size_t i = 0; i < v.size(); ++i) {
    	print2(v[i]);
    	if (i != lastInd) print2(", ");
	}
	print2("]");
}

template <typename A, typename B>
bool areValuesEqual(const std::vector<A>& v1, const std::vector<B>& v2) {
	return v1.size() == v2.size() && std::equal(v1.begin(), v1.end(), v2.begin());
}

template <typename A, typename B>
bool areValuesEqual(const A& v1, const B& v2) {
	return v1 == v2;
}

// for println
template <typename A>
std::ostream& operator<<(std::ostream& os, const std::vector<A>& v){
    auto size = v.size() - 1;
    os << "[";
    for (std::size_t i = 0; i <= size; ++i) {
    	print2(v[i]);
    	if (i != size) os << ", ";
	}
	os << "]";
    return os;
}

template <typename A>
void println2(A v) {
	print2(v);
	std::cout << std::endl;
}

template <typename A>
bool isArray(A v) {
	return false;
}

template <typename A>
bool isArray(const std::vector<A>& v) {
	return true;
}

template <typename A, typename B>
bool isSameObj(const A& v1, const B& v2) {
	if (typeid(v2) == typeid(v2)) {
		return v1 == v2;
	} else {
		return false;
	}
}

template <typename A, typename B>
bool isSameObj(const std::vector<A>& v1, const std::vector<B>& v2) {
	return &v1 == &v2;
}

// math

double log(double v) {
	return std::log(v);
}

double exp(double v) {
	return std::exp(v);
}

int32_t bitNot(int32_t v) {
	return ~v;
}

int32_t bitAnd(int32_t a, int32_t b) {
	return a & b;
}

int32_t bitOr(int32_t a, int32_t b) {
	return a | b;
}

int32_t bitXor(int32_t a, int32_t b) {
	return a ^ b;
}

int32_t bitShl(int32_t a, int32_t n) {
	return a << n;
}

int32_t bitUshr(int32_t a, int32_t n) {
	return ((unsigned int)a) >> n;
}

int32_t trunc(double v) {
	return (int32_t)v;
}

// array

template <typename A, typename B>
B fold(const std::vector<A>& a, const B b, const std::function<B(B, A)> & fn) {
  B _res = b;
  for (std::size_t i = 0; i != a.size(); ++i) {
    _res = fn(_res, a[i]);
  }
  return _res;
}

std::vector<int32_t> enumFromTo(int32_t start, int32_t end) {
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
std::vector<B> map(const std::vector<A>& a, const std::function<B(A)> & fn) {
  // std::vector<B> res(a.size());
  // for (std::size_t i = 0; i != a.size(); ++i) {
  //   res[i] = fn(a[i]);
  // }
  //return res;
	std::vector<B> res;
	std::transform(a.begin(), a.end(), std::back_inserter(res), fn);
	return res;
}

template <typename A>
std::vector<A> filter(const std::vector<A>& a, const std::function<bool(A)> & test) {
  std::vector<A> res;
  std::copy_if (a.begin(), a.end(), std::back_inserter(res), test);
  return res;
}


template <typename A>
std::vector<A> concat(const std::vector<A>& a, const std::vector<A> b) {
  std::vector<A> res;
  res.reserve(a.size() + b.size());
  res.insert(res.end(), a.cbegin(), a.cend());
  res.insert(res.end(), b.cbegin(), b.cend());
  return res;
}

template <typename A>
int32_t length(const std::vector<A>& a) {
  return a.size();
}

template <typename A>
std::vector<A> replace(const std::vector<A>& a, int32_t i, A value) {
  auto len = a.size();
  if (i >= len || i < 0) {
  	std::vector<A> res;
    std::copy(a.begin(), a.end(), std::back_inserter(res));
    res.push_back(value);
    return res;
  } else {
  	std::vector<A> res(len);
  	res[i] = value;
  	for (int j = 0; j < len; j++) {
		if (i != j) res[j] = a[j];
	}
  	return res;
  }
}

template <typename A>
void iter(const std::vector<A>& a, const std::function<void(A)> & fn) {
  std::for_each(a.begin(), a.end(), fn);
}

template <typename A>
void iter(const std::vector<A>& a, void(*fn)(A) ) {
	for (std::size_t i = 0; i != a.size(); ++i) {
		(*fn)(a[i]);
	}
}

template <typename A>
void iteri(const std::vector<A>& a, const std::function<void(int32_t, A)> & fn) {
	for (std::size_t i = 0; i != a.size(); ++i) {
		fn(i, a[i]);
	}
}

template <typename A>
int iteriUntil(const std::vector<A>& a, const std::function<bool(int32_t, A)> & fn) {
	int32_t i = 0;
	bool found = false;
	while (i < a.size() && !found) {
		found = fn(i, a[i]);
		if (!found) i++;
	}
	return i;
}

// flowstruct
template <typename A, typename B>
bool isSameStructType(A struct1, B struct2) {
	return struct1._id == struct2._id;
}

template <typename A, typename ...Args2>
bool isSameStructType(A struct1, std::variant<Args2...> struct2) {
	unsigned int id2 = std::visit([&](auto&& x) {return x._id;}, struct2);
	return struct1._id == id2;
}

template <typename ...Args1, typename B>
bool isSameStructType(std::variant<Args1...> struct1, B struct2) {
	unsigned int id1 = std::visit([&](auto&& x) {return x._id;}, struct1);
	return id1 == struct2._id;
}

template <typename ...Args1, typename ...Args2>
bool isSameStructType(std::variant<Args1...> struct1, std::variant<Args2...> struct2) {
	unsigned int id1 = std::visit([&](auto&& x) {return x._id;}, struct1);
	unsigned int id2 = std::visit([&](auto&& x) {return x._id;}, struct2);
	return id1 == id2;
}

template <typename A, typename ...B> A _extractStructVal(std::variant<B...> v) { return std::get<A>(v); }
template <typename A> A _extractStructVal(A v) { return v; }

template <typename A, typename B>
B extractStruct(const std::vector<A> a, B b) {
  auto item = std::find_if(a.begin(), a.end(), [b](A v){ return isSameStructType(v, b); });
  if (item == a.end()) {
    return b;
  } else {
    return _extractStructVal<B>(*item);
  }
}

template <typename T> std::string type_name();

template <typename A>
std::u16string getStructName(A st) {
	std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> codecvt;
	return codecvt.from_bytes(demangle(typeid(st).name()));
}

}

