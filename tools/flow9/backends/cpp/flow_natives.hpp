// strings
#include <codecvt>
#include <string>
#include <locale>
#include <sstream>
#include <iomanip>
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

template <typename A>
std::shared_ptr<A> makeFlowRef(A value) {
  return std::make_shared<A>(value);
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

// precision = 20!
std::u16string flow_d2s(double v) {
	std::stringstream stream;
	stream << std::fixed << std::setprecision(20) << v;
	std::string s = stream.str();

	std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> codecvt;
	return codecvt.from_bytes(s);
}

// common
template <typename T, typename TT>
T flow_cast(const TT& val) {
	//std::cout<< "Casting from '" << demangle(typeid(val).name()) << "' to '" << demangle(typeid(T).name()) << "' ..." << std::endl;
	return T(reinterpret_cast<const T&>(val));
}

template <typename T, typename ...TT>
T flow_cast_variant(std::variant<TT...> val) {
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

void flow_quit(int32_t code) {
	// TODO
	exit(code);
}

template <typename A>
void flow_print2(A&& v) {
	drop(v);
	std::cout << v;
}

template <typename A>
void flow_print2(std::shared_ptr<A> v) {
	std::cout << "ref " << *v;
}


void flow_print2(std::u16string d) {
	std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> codecvt;
	std::cout << codecvt.to_bytes(d);
}

void flow_print2(const bool d) {
	std::cout << (d ? "true" : "false");
}

void flow_print2(const int d) {
	std::cout << d;
}

void flow_print2(const double d) {
	flow_print2(flow_d2s(d));
}

template <typename ...Args>
void flow_print2(const std::variant<Args...> v) {
	std::visit([](auto&& x) { flow_print2(x); }, v);
}

template <typename A>
void flow_print2(const std::vector<A>& v) {
	int32_t lastInd = v.size() - 1;

    flow_print2("[");
    for (std::size_t i = 0; i < v.size(); ++i) {
    	flow_print2(v[i]);
    	if (i != lastInd) flow_print2(", ");
	}
	flow_print2("]");
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
    	flow_print2(v[i]);
    	if (i != size) os << ", ";
	}
	os << "]";
    return os;
}

template <typename A>
void flow_println2(A&& v) {
	flow_print2(v);
	std::cout << std::endl;
}

template <typename A>
bool flow_isArray(A v) {
	return false;
}

template <typename A>
bool flow_isArray(const std::vector<A>& v) {
	return true;
}

template <typename A, typename B>
bool flow_isSameObj(const A& v1, const B& v2) {
	if (typeid(v2) == typeid(v2)) {
		return v1 == v2;
	} else {
		return false;
	}
}

template <typename A, typename B>
bool flow_isSameObj(const std::vector<A>& v1, const std::vector<B>& v2) {
	return &v1 == &v2;
}

// memory
// TODO

// variables
/*template <typename T>
T dup(T& a) {
	return a;
}*/

template <typename T>
T* drop(T& a) {
	a._counter -= 1;
	if (a._counter < 1) {
		std::cout<<"FREE:: &=" << &a <<"; counter = "<< a._counter <<std::endl;
		a.~T();
		return nullptr;
	} else {
		return &a;
	}
}

// TODO
// memory leak (?)
// use std::unique_ptr
template <typename T>
T& reuse(T& a) {
	T* tmp;
	std::cout<<"REUSE:: from &=" << &a <<" to &="<< tmp <<std::endl;
	tmp = &a;
	drop<T>(a);
	return *tmp;
	// does not transfer ownership
	// does not work as expected because it does not break the link to the variable.
	/*std::cout<<"REUSE:: &=" << &a << std::endl;
	a._counter = 1;
	return a;*/
}

// TODO: recursive DUP // v1 = struct1(struct2(...)) (??)
template <typename T>
T& dup(T& a) {
	a._counter += 1;
	//std::cout<<"DUP:: cnt after: "<< a._counter << "; &=" << &a <<std::endl;
	return a;
}

// TODO: vector (array)

int32_t dup(int32_t a) {
	std::cout<<"DUP:: int value "<< a <<std::endl;
	return a;
}

int32_t drop(int32_t a) {
	std::cout<<"DROP:: int value "<< a <<std::endl;
	return a;
}

int32_t reuse(int32_t a) {
	std::cout<<"REUSE:: int value "<< a <<std::endl;
	return a;
}

std::u16string dup(std::u16string a) {
	std::cout<<"DUP:: string value ";flow_print2(a); std::cout <<std::endl;
	return a;
}

std::u16string drop(std::u16string a) {
	std::cout<<"DROP:: string value ";flow_print2(a); std::cout <<std::endl;
	return a;
}

std::u16string reuse(std::u16string a) {
	std::cout<<"REUSE:: string value ";flow_print2(a); std::cout <<std::endl;
	return a;
}

bool dup(bool a) {
	std::cout<<"DUP:: bool value "<< a <<std::endl;
	return a;
}

bool drop(bool a) {
	std::cout<<"DROP:: bool value "<< a <<std::endl;
	return a;
}

bool reuse(bool a) {
	std::cout<<"REUSE:: bool value "<< a <<std::endl;
	return a;
}

double dup(double a) {
	std::cout<<"DUP:: double value "<< a <<std::endl;
	return a;
}

double drop(double a) {
	std::cout<<"DROP:: double value "<< a <<std::endl;
	return a;
}

double reuse(double a) {
	std::cout<<"REUSE:: double value "<< a <<std::endl;
	return a;
}

// math

double flow_log(double v) {
	return std::log(v);
}

double flow_exp(double v) {
	return std::exp(v);
}

int32_t flow_bitNot(int32_t v) {
	return ~v;
}

int32_t flow_bitAnd(int32_t a, int32_t b) {
	return a & b;
}

int32_t flow_bitOr(int32_t a, int32_t b) {
	return a | b;
}

int32_t flow_bitXor(int32_t a, int32_t b) {
	return a ^ b;
}

int32_t flow_bitShl(int32_t a, int32_t n) {
	return a << n;
}

int32_t flow_bitUshr(int32_t a, int32_t n) {
	return ((unsigned int)a) >> n;
}

int32_t flow_trunc(double v) {
	return (int32_t)v;
}

// array

template <typename A, typename B>
B flow_fold(const std::vector<A>& flow_a, const B flow_b, const std::function<B(B, A)> & flow_fn) {
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
std::vector<B> flow_map(const std::vector<A>& flow_a, const std::function<B(A)> & flow_fn) {
  // std::vector<B> res(flow_a.size());
  // for (std::size_t i = 0; i != flow_a.size(); ++i) {
  //   res[i] = flow_fn(flow_a[i]);
  // }
  //return res;
	std::vector<B> res;
	std::transform(flow_a.begin(), flow_a.end(), std::back_inserter(res), flow_fn);
	return res;
}

// TODO: fix cpp and uncomment this
/*std::vector<B> flow_map(const std::vector<A>& flow_a, const std::function<B(const A&)> & flow_fn) {
  std::vector<B> res(flow_a.size());
  for (std::size_t i = 0; i != flow_a.size(); ++i) {
    res[i] = flow_fn(flow_a[i]);
  }
  return res;
}
*/

template <typename A>
std::vector<A> flow_filter(const std::vector<A>& flow_a, const std::function<bool(A)> & flow_test) {
  std::vector<A> res;
  std::copy_if (flow_a.begin(), flow_a.end(), std::back_inserter(res), flow_test);
  return res;
}


template <typename A>
std::vector<A> flow_concat(const std::vector<A>& flow_a, const std::vector<A> flow_b) {
  std::vector<A> res;
  res.reserve(flow_a.size() + flow_b.size());
  res.insert(res.end(), flow_a.cbegin(), flow_a.cend());
  res.insert(res.end(), flow_b.cbegin(), flow_b.cend());
  return res;
}

template <typename A>
int32_t flow_length(const std::vector<A>& flow_a) {
  return flow_a.size();
}

template <typename A>
std::vector<A> flow_replace(const std::vector<A>& flow_a, int32_t i, A value) {
  auto len = flow_a.size();
  if (i >= len || i < 0) {
  	std::vector<A> res;
    std::copy(flow_a.begin(), flow_a.end(), std::back_inserter(res));
    res.push_back(value);
    return res;
  } else {
  	std::vector<A> res(len);
  	res[i] = value;
  	for (int j = 0; j < len; j++) {
		if (i != j) res[j] = flow_a[j];
	}
  	return res;
  }
}

template <typename A>
void flow_iter(const std::vector<A>& flow_a, const std::function<void(A)> & flow_fn) {
  std::for_each(flow_a.begin(), flow_a.end(), flow_fn);
}

template <typename A>
void flow_iter(const std::vector<A>& flow_a, void(*fn)(A) ) {
	for (std::size_t i = 0; i != flow_a.size(); ++i) {
		(*fn)(flow_a[i]);
	}
}

template <typename A>
void flow_iteri(const std::vector<A>& flow_a, const std::function<void(int32_t, A)> & flow_fn) {
	for (std::size_t i = 0; i != flow_a.size(); ++i) {
		flow_fn(i, flow_a[i]);
	}
}

template <typename A>
int flow_iteriUntil(const std::vector<A>& flow_a, const std::function<bool(int32_t, A)> & flow_fn) {
	int32_t i = 0;
	bool found = false;
	while (i < flow_a.size() && !found) {
		found = flow_fn(i, flow_a[i]);
		if (!found) i++;
	}
	return i;
}

// flowstruct
template <typename A, typename B>
bool flow_isSameStructType(A struct1, B struct2) {
	return struct1._id == struct2._id;
}

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

template <typename T> std::string type_name();

template <typename A>
std::u16string flow_getStructName(A st) {
	std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> codecvt;
	return codecvt.from_bytes(demangle(typeid(st).name()));
}
