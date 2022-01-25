#include <locale>
#include <sstream>
#include <iomanip>
#include <algorithm>
#include "flow_union.hpp"
#include "flow_array.hpp"
#include "flow_string.hpp"
// math
#include <cmath>

template <typename A>
std::shared_ptr<A> makeFlowRef(A value) {
  return std::make_shared<A>(value);
}

// string

_FlowString* flow_substring(_FlowString* s, int32_t start, int32_t length) {
	return new _FlowString((*s).value.substr(start, length));
}

int32_t flow_strlen(_FlowString* s) {
	return static_cast<int>((*s).value.size());
}

int32_t flow_getCharCodeAt(_FlowString* s, int32_t i) {
	return (*s).value.at(i);
}

// precision = 20!
_FlowString* flow_d2s(double v) {
	std::stringstream stream;
	stream << std::fixed << std::setprecision(20) << v;
	return new _FlowString(stream.str());
}

// common
template <typename T, typename TT>
T flow_cast(const TT& val) {
	//std::cout<< "Casting from '" << demangle(typeid(val).name()) << "' to '" << demangle(typeid(T).name()) << "' ..." << std::endl;
	return T(reinterpret_cast<const T&>(val));
}

// TODO: delete ?
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
template <typename T, typename ...TT>
T flow_cast_variant(_FlowUnion<TT...>* val) {
	//std::cout<< "Casting VARIANT from '" << demangle(typeid(val).name()) << "' to '" << demangle(typeid(T).name()) << "' ..." << std::endl;
	if (const T* pval = std::get_if<T>(val)) {
		return *pval;
	}
	else {
		/*std::cout<< "ERROR casting from '" << demangle(typeid(val).name()) << "' to '" << demangle(typeid(T).name()) << "'" << std::endl;
		T res;
		return res;*/
		throw std::invalid_argument("variant type is not equal '" + demangle(typeid(T).name()) + "' [" + demangle(typeid(val).name()) + "]");
	}
}

// compare unions by address
template <typename ...Args1, typename ...Args2>
bool operator==(const _FlowUnion<Args1...>& struct1, const _FlowUnion<Args2...>& struct2) {
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
	std::cout << v;
}

template <typename A>
void flow_print2(A* v) {
	if (v == nullptr) {
		std::cout << "NULL Pointer " << std::endl;
	} else {
		flow_print2(*v);
	}
}

template <typename A>
void flow_print2(std::shared_ptr<A> v) {
	std::cout << "ref " << *v;
}


void flow_print2(_FlowString* d) {
	std::cout << d->toString();
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

template <typename ...T>
void flow_print2(_FlowUnion<T...>* v) {
	(*v).visit([](auto&& x) { flow_print2(x); });
}

template <typename A, typename B>
bool areValuesEqual(const std::vector<A>& v1, const std::vector<B>& v2) {
	return v1.size() == v2.size() && std::equal(v1.begin(), v1.end(), v2.begin());
}

template <typename A, typename B>
bool areValuesEqual(const A& v1, const B& v2) {
	return v1 == v2;
}

template <typename A>
bool flow_isArray(A v) {
	return false;
}

template <typename A>
bool flow_isArray(_FlowArray<A>* v) {
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

// print with drop
template <typename A>
void flow_println2(A&& v) {
	flow_print2(v);
	std::cout << std::endl;
	drop(v);
}
// print with drop
template <typename A>
void flow_println2(A* v) {
	if (v == nullptr) {
		std::cout << "NULL Pointer " << std::endl;
	} else {
		flow_print2(*v);
		std::cout << std::endl;
		drop(v);
	}
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
bool flow_isSameStructType(A* struct1, B* struct2) {
	bool res = (*struct1)._id == (*struct2)._id;
	drop(struct1);
	drop(struct2);
	return res;
}

template <typename A, typename ...B>
bool flow_isSameStructType(A* struct1, _FlowUnion<B...>* struct2) {
	unsigned int id1 = (*struct1)._id;
	drop(struct1);
	unsigned int id2 = (*struct2).visit([&](auto&& x) { return (*x)._id; });
	drop(struct2);
	return id1 == id2;
}

template <typename ...A, typename B>
bool flow_isSameStructType(_FlowUnion<A...>* struct1, B* struct2) {
	unsigned int id2 = (*struct2)._id;
	drop(struct2);
	unsigned int id1 = (*struct1).visit([&](auto&& x) { return (*x)._id; });
	drop(struct1);
	return id1 == id2;
}

template <typename ...A, typename ...B>
bool flow_isSameStructType(_FlowUnion<A...>* struct1, _FlowUnion<B...>* struct2) {
	unsigned int id1 = (*struct1).visit([&](auto&& x) { return (*x)._id; });
	drop(struct1);
	unsigned int id2 = (*struct2).visit([&](auto&& x) { return (*x)._id; });
	drop(struct2);
	return id1 == id2;
}

template <typename A, typename B>
B* flow_extractStruct(_FlowArray<A*>* vect, B* valType) {
	B* res = nullptr;
	for (auto i = 0; i != (*vect).value.size(); i++) {
		if (flow_isSameStructType(dup((*vect).value[i]), dup(valType))) {
			res = dup(_extractStructVal<B>((*vect).value[i]));
			break;
		}
	}
	if (res == nullptr) {
		drop(vect);
		return reuse(valType);
	}
	else {
		drop(valType);
		drop(vect);
		return res;
	}
}

template <typename A, typename ...B> A* _extractStructVal(_FlowUnion<B*...>* v) { return std::get<A*>(*v); }
template <typename A> A* _extractStructVal(A* v) { return v; }

template <typename A, typename ...B> A _extractStructVal(_FlowUnion<B...> v) { return std::get<A>(v); }
template <typename A> A _extractStructVal(A v) { return v; }

template <typename A>
_FlowString flow_getStructName(A st) {
	return _FlowString(demangle(typeid(st).name()));
}
