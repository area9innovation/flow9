#include <locale>
#include <sstream>
#include <iomanip>
#include <algorithm>
#include "flow_union.hpp"
#include "flow_array.hpp"
#include "flow_string.hpp"
#include "flow_function.hpp"
// math
#include <cmath>

template <typename A>
std::shared_ptr<A> makeFlowRef(A value) {
  return std::make_shared<A>(value);
}

// string

_FlowString* flow_substring(_FlowString* s, int32_t start, int32_t length) {
	if (s->_counter == 1) {
		s->value.erase(0, start).resize(length);
		//s->value = s->value.substr(start, length);
		return s;
	} else {
		_FlowString* res = new _FlowString(s->value.substr(start, length));
		drop(s);
		return res;
	}
}

int32_t flow_strlen(_FlowString* s) {
	auto res = s->value.size();
	drop(s);
	return static_cast<int32_t>(res);
}

int32_t flow_getCharCodeAt(_FlowString* s, int32_t i) {
	int32_t res = s->value.at(i);
	drop(s);
	return res;
}

// TODO. u16 instead of string
_FlowString* flow_d2s(double v) {
	return new _FlowString(std::to_string(v));
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

// for structs ( Struct1 == Struct2). (Struct1 == Struct1) is overloaded inside the struct
template <typename A, typename B>
bool operator==(const A& lhs, const B& rhs) {
	return lhs._id == rhs._id;
}
// compare by names
template <typename A, typename B>
bool operator<(const A& lhs, const B& rhs) {
	return demangle(typeid(lhs).name()) < demangle(typeid(rhs).name());
}
// compare by names
template <typename A, typename B>
bool operator>(const A& lhs, const B& rhs) {
	return demangle(typeid(lhs).name()) > demangle(typeid(rhs).name());
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

template <typename T>
std::ostream& operator<<(std::ostream& os, const _FlowArray<T>& a) {
	os << "[";
	for (std::size_t i = 0; i < a.value.size(); ++i) {
		flow_print2(a.value[i]);
		os << ",";
	}
	os << "]";
	return os;
}

template <typename A, typename B>
bool areValuesEqual(const A& v1, const B& v2) {
	return v1 == v2;
}

template <typename A, typename B>
bool areValuesEqual(A* v1, B* v2) {
	return (*v1) == (*v2);
}

// for println
template <typename A>
bool flow_isArray(A* v) {
	drop(v);
	return false;
}

template <typename A>
bool flow_isArray(A v) {
	return false;
}

template <typename A>
bool flow_isArray(_FlowArray<A>* v) {
	drop(v);
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
// TODO ?
template <typename A, typename B>
bool flow_isSameObj(const std::vector<A>& v1, const std::vector<B>& v2) {
	return &v1 == &v2;
}

// simple types
//template <typename A>
//void flow_println2(A&& v) {
//	flow_print2(v);
//	std::cout << std::endl;
//}
template <typename A>
void flow_println3(A v) {
	flow_print2(v);
	std::cout << std::endl;
}
// print with drop
template <typename A>
void flow_println3(A* v) {
	if (v == nullptr) {
		std::cout << "NULL Pointer " << std::endl;
	} else {
		flow_print2(*v);
		std::cout << std::endl;
		drop(v);
	}
}

template <typename A>
void flow_println2(A v) {
	flow_println3(v);
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
B flow_fold(_FlowArray<A*>* arr, const B initVal, _FlowFunction<B, B,A*>* flow_fn) {
	return flow_fold_memory(arr, initVal, flow_fn);
}

template <typename A, typename B>
B* flow_fold(_FlowArray<A*>* arr, B* initVal, _FlowFunction<B*, B*,A*>* flow_fn) {
	return flow_fold_memory(arr, initVal, flow_fn);
}

template <typename A, typename B>
B flow_fold_memory(_FlowArray<A*>* arr, const B initVal, _FlowFunction<B, B,A*>* flow_fn) {
	B _res = initVal;
	bool unusedItem = false; // free in the loop
	for (std::size_t i = 0; i != arr->value.size(); ++i) {
		unusedItem = arr->value[i]->_counter == 1;
		if ((arr->value.size() - i) > 1) flow_fn->dupFields();
		_res = (*flow_fn)(_res, unusedItem ? arr->value[i] : dup(arr->value[i]));
		if (unusedItem) arr->value[i] = nullptr;
	}
	drop(flow_fn);
	drop(arr);
	return _res;
}
// TODO: delete ? ---------------------------------------------------------------------------
template <typename A, typename B>
B flow_fold(_FlowArray<A*>* arr, const B initVal, const std::function<B(B, A*)> & flow_fn) {
  return flow_fold_memory(arr, initVal, flow_fn);
}

template <typename A, typename B>
B* flow_fold(_FlowArray<A*>* arr, B* initVal, const std::function<B* (B*, A*)>& flow_fn) {
	return flow_fold_memory(arr, initVal, flow_fn);
}

template <typename A, typename B>
B flow_fold_memory(_FlowArray<A*>* arr, const B initVal, const std::function<B(B, A*)>& flow_fn) {
	B _res = initVal;
	bool unusedItem = false; // free in the loop
	for (std::size_t i = 0; i != arr->value.size(); ++i) {
		unusedItem = arr->value[i]->_counter == 1;
		_res = flow_fn(_res, unusedItem ? arr->value[i] : dup(arr->value[i]));
		if (unusedItem) arr->value[i] = nullptr;
	}
	drop(arr);
	return _res;
}
// ---------------------------------------------------------------------------------------------
// 
// simple types
template <typename A, typename B>
B flow_fold(_FlowArray<A>* arr, const B flow_b, const std::function<B(B, A)>& flow_fn) {
	B _res = flow_b;
	for (std::size_t i = 0; i != arr->value.size(); ++i) {
		_res = flow_fn(_res, arr->value[i]);
	}
	drop(arr);
	return _res;
}

_FlowArray<int32_t>* flow_enumFromTo(int32_t start, int32_t end) {
	if (end < start) {
		return new _FlowArray<int32_t>{};
	} else {
		int32_t len = end - start + 1;
		_FlowArray<int32_t>* res = new _FlowArray<int32_t>{};
		res->value.resize(end - start + 1);
		for (int32_t i = start; i <= end; i++) {
			res->value[i - start] = i;
		}
		return res;
	}
}


// map(array)

// simple types
template <typename A, typename B>
_FlowArray<B>* flow_map(_FlowArray<A>* arr, _FlowFunction<B,A>* flow_fn) {
	return flow_map_memory(arr, flow_fn);
}

// struct to simple
template <typename A, typename B>
_FlowArray<B>* flow_map(_FlowArray<A*>* arr, _FlowFunction<B,A*>* flow_fn) {
	_FlowArray<B>* res = new _FlowArray<B>{};
	res->value.reserve(arr->value.size());
	bool lastUse = arr->_counter == 1;

	for (std::size_t i = 0; i != arr->value.size(); ++i) {
		if ((arr->value.size() - i) > 1) flow_fn->dupFields();
		res->value.push_back((*flow_fn)(lastUse ? arr->value[i] : dup(arr->value[i])));
		if (lastUse) arr->value[i] = nullptr;
	}
	drop(flow_fn);
	drop(arr);

	return res;
}

// simple to struct
template <typename A, typename B>
_FlowArray<B*>* flow_map(_FlowArray<A>* arr, _FlowFunction<B*,A>* flow_fn) {
	_FlowArray<B*>* res = new _FlowArray<B*>{};
	res->value.reserve(arr->value.size());

	for (std::size_t i = 0; i != arr->value.size(); ++i) {
		if ((arr->value.size() - i) > 1) flow_fn->dupFields();
		res->value.push_back((*flow_fn)(arr->value[i]));
	}
	drop(flow_fn);
	drop(arr);

	return res;
}

template <typename A, typename B>
_FlowArray<B*>* flow_map(_FlowArray<A*>* arr, _FlowFunction<B*,A*>* flow_fn) {
	return flow_map_memory(arr, flow_fn);
}

template <typename A, typename B>
_FlowArray<B>* flow_map_memory(_FlowArray<A>* arr, _FlowFunction<B,A>* flow_fn) {
	_FlowArray<B>* res = new _FlowArray<B>{};
	res->value.reserve(arr->value.size());
	if (arr->_counter == 1) {
		for (std::size_t i = 0; i != arr->value.size(); ++i) {
			if ((arr->value.size() - i) > 1) flow_fn->dupFields();
			res->value.push_back((*flow_fn)(arr->value[i]));
			arr->value[i] = nullptr;
		}
		drop(flow_fn);
		drop(arr);
		return res;
	}
	else {
		for (std::size_t i = 0; i != arr->value.size(); ++i) {
			if ((arr->value.size() - i) > 1) flow_fn->dupFields();
			res->value.push_back((*flow_fn)(dup(arr->value[i])));
		}
		drop(flow_fn);
		drop(arr);
		return res;
	}
}

template <typename A>
_FlowArray<A>* flow_map_memory(_FlowArray<A>* arr, _FlowFunction<A, A>* flow_fn) {
	if (arr->_counter == 1) {
		for (std::size_t i = 0; i != arr->value.size(); ++i) {
			if ((arr->value.size() - i) > 1) flow_fn->dupFields();
			arr->value[i] = (*flow_fn)(arr->value[i]);
		}
		drop(flow_fn);
		return arr;
	}
	else {
		_FlowArray<A>* res = new _FlowArray<A>{};
		res->value.reserve(arr->value.size());
		for (std::size_t i = 0; i != arr->value.size(); ++i) {
			if ((arr->value.size() - i) > 1) flow_fn->dupFields();
			res->value.push_back((*flow_fn)(dup(arr->value[i])));
		}
		drop(flow_fn);
		drop(arr);
		return res;
	}
}

// TODO: delete ? ---------------------------------------------------------------------------
// simple types
template <typename A, typename B>
_FlowArray<B>* flow_map(_FlowArray<A>* arr, const std::function<B(A)>& flow_fn) {
	return flow_map_memory(arr, flow_fn);
}

// struct to simple
template <typename A, typename B>
_FlowArray<B>* flow_map(_FlowArray<A*>* arr, const std::function<B(A*)>& flow_fn) {
	_FlowArray<B>* res = new _FlowArray<B>{};
	res->value.reserve(arr->value.size());
	bool lastUse = arr->_counter == 1;

	for (std::size_t i = 0; i != arr->value.size(); ++i) {
		res->value.push_back(flow_fn(lastUse ? arr->value[i] : dup(arr->value[i])));
		if (lastUse) arr->value[i] = nullptr;
	}
	drop(arr);

	return res;
}

// simple to struct
template <typename A, typename B>
_FlowArray<B*>* flow_map(_FlowArray<A>* arr, const std::function<B*(A)>& flow_fn) {
	_FlowArray<B*>* res = new _FlowArray<B*>{};
	res->value.reserve(arr->value.size());

	for (std::size_t i = 0; i != arr->value.size(); ++i) {
		res->value.push_back(flow_fn(arr->value[i]));
	}
	drop(arr);

	return res;
}

template <typename A, typename B>
_FlowArray<B*>* flow_map(_FlowArray<A*>* arr, const std::function<B*(A*)>& flow_fn) {
	return flow_map_memory(arr, flow_fn);
}

template <typename A, typename B>
_FlowArray<B>* flow_map_memory(_FlowArray<A>* arr, const std::function<B(A)>& flow_fn) {
	if (arr->_counter == 1) {
		for (std::size_t i = 0; i != arr->value.size(); ++i) {
			arr->value[i] = flow_fn(arr->value[i]);
		}
		return arr;
	}
	else {
		_FlowArray<B>* res = new _FlowArray<B>{};
		res->value.reserve(arr->value.size());
		for (std::size_t i = 0; i != arr->value.size(); ++i) {
			res->value.push_back(flow_fn(dup(arr->value[i])));
		}
		drop(arr);
		return res;
	}
}
// _______________---------------------------------------------------------------------------
// 

// simple types
template <typename A>
_FlowArray<A>* flow_filter(_FlowArray<A>* arr, _FlowFunction<bool, A>* flow_fn) {
	return flow_filter_memory(arr, flow_fn);
}

template <typename A>
_FlowArray<A*>* flow_filter(_FlowArray<A*>* arr, _FlowFunction<bool, A*>* flow_fn) {
	return flow_filter_memory(arr, flow_fn);
}
template <typename A>
_FlowArray<A>* flow_filter_memory(_FlowArray<A>* arr, _FlowFunction<bool, A>* flow_test) {
	if (arr->_counter == 1) {
		auto i = arr->value.size();
		auto it = std::remove_if(
			arr->value.begin(),
			arr->value.end(),
			[&flow_test, &i](auto& item) {
				i--;
				if (i > 0) flow_test->dupFields();
				bool unused = !(*flow_test)(dup(item));
				if (unused) { drop(item); }
				return unused;
			}
		);
		drop(flow_test);
		arr->value.erase(it);
		return arr;
	}
	else {
		_FlowArray<A>* res = new _FlowArray<A>{};
		for (std::size_t i = 0; i != arr->value.size(); ++i) {
			if ((arr->value.size() - i) > 1) flow_test->dupFields();
			if ((*flow_test)(dup(arr->value[i]))) res->value.push_back(dup(arr->value[i]));
		}
		drop(flow_test);
		drop(arr);
		return res;
	}
}
// TODO: delete ? ---------------------------------------------------------------------------
// simple types
template <typename A>
_FlowArray<A>* flow_filter(_FlowArray<A>* arr, const std::function<bool(A)>& flow_fn) {
	return flow_filter_memory(arr, flow_fn);
}

template <typename A>
_FlowArray<A*>* flow_filter(_FlowArray<A*>* arr, const std::function<bool(A*)>& flow_fn) {
	return flow_filter_memory(arr, flow_fn);
}
template <typename A>
_FlowArray<A>* flow_filter_memory(_FlowArray<A>* arr, const std::function<bool(A)>& flow_test) {
	if (arr->_counter == 1) {
		arr->value.erase(std::remove_if(
			arr->value.begin(),
			arr->value.end(),
			[&flow_test](auto& item) { 
				bool unused = !flow_test(dup(item));
				if (unused) { drop(item); }
				return unused;
			}
		));
		return arr;
	}
	else {
		_FlowArray<A>* res = new _FlowArray<A>{};
		for (std::size_t i = 0; i != arr->value.size(); ++i) {
			if (flow_test(dup(arr->value[i]))) res->value.push_back(dup(arr->value[i]));
		}
		drop(arr);
		return res;
	}
}
// ------------------------------------------------------------------------------------------

template <typename A>
_FlowArray<A>* flow_concat(_FlowArray<A>* arr1, _FlowArray<A>* arr2) {
	if (arr1->_counter == 1) {
		arr1->value.reserve(arr1->value.size() + arr2->value.size());
		arr2->dupFields();
		arr1->value.insert(arr1->value.end(), arr2->value.cbegin(), arr2->value.cend());
		drop(arr2);
		return arr1;
	}
	else if (arr2->_counter == 1) {
		arr2->value.reserve(arr1->value.size() + arr2->value.size());
		arr1->dupFields();
		arr2->value.insert(arr2->value.end(), arr1->value.cbegin(), arr1->value.cend());
		drop(arr1);
		return arr2;
	}
	else {
		_FlowArray<A>* res = new _FlowArray<A>{};
		res->value.reserve(arr1->value.size() + arr2->value.size());
		arr1->dupFields();
		res->value.insert(res->value.end(), arr1->value.cbegin(), arr1->value.cend());
		drop(arr1);
		arr2->dupFields();
		res->value.insert(res->value.end(), arr2->value.cbegin(), arr2->value.cend());
		drop(arr2);
		return res;
	}
}

template <typename A>
int32_t flow_length(_FlowArray<A>* arr) {
  auto res = arr->value.size();
  drop(arr);
  return static_cast<int32_t>(res);
}

template <typename A>
_FlowArray<A*>* flow_replace(_FlowArray<A*>* arr, int32_t i, A* value) {
	return flow_replace_memory(arr, i, value);
}

// simple types
template <typename A>
_FlowArray<A>* flow_replace(_FlowArray<A>* arr, int32_t i, A value) {
	return flow_replace_memory(arr, i, value);
}

template <typename A>
_FlowArray<A>* flow_replace_memory(_FlowArray<A>* arr, int32_t i, A value) {
	auto len = arr->value.size();
	// push
	if (i >= len || i < 0) {
		// reuse
		if (arr->_counter == 1) {
			arr->value.push_back(value);
			return arr;
		}
		// new allocation
		else {
			_FlowArray<A>* res = new _FlowArray<A>{};
			arr->dupFields();
			std::copy(arr->value.begin(), arr->value.end(), std::back_inserter(res->value));
			drop(arr);
			res->value.push_back(value);
			return res;
		}
	}
	// replace
	else {
		// reuse
		if (arr->_counter == 1) {
			drop(arr->value[i]);
			arr->value[i] = value;
			return arr;
		}
		// new allocation
		else {
			_FlowArray<A>* res = new _FlowArray<A>{};
			res->value.reserve(len);
			for (int j = 0; j < len; j++) {
				if (i == j) {
					res->value.push_back(value);
				}
				else {
					res->value.push_back(dup(arr->value[j]));
				}
			}
			drop(arr);
			return res;
		}
	}
}

template <typename A>
void flow_iter(_FlowArray<A*>* arr, _FlowFunction<void, A*>* flow_fn) {
	bool unusedItem;
	for (std::size_t i = 0; i != arr->value.size(); ++i) {
		unusedItem = arr->value[i]->_counter == 1;
		if ((arr->value.size() - i) > 1) flow_fn->dupFields();
		(*flow_fn)(unusedItem ? arr->value[i] : dup(arr->value[i]));
		if (unusedItem) arr->value[i] = nullptr;
	}
	drop(flow_fn);
	drop(arr);
}
template <typename A>
void flow_iter(_FlowArray<A>* arr, _FlowFunction<void,A>* flow_fn) {
	for (std::size_t i = 0; i != arr->value.size(); ++i) {
		if ((arr->value.size() - i) > 1) flow_fn->dupFields();
		(*flow_fn)(arr->value[i]);
	}
	drop(flow_fn);
	drop(arr);
}
// TODO: delete ? ---------------------------------------------------------------------------
template <typename A>
void flow_iter(_FlowArray<A*>* arr, const std::function<void(A*)> & flow_fn) {
	bool unusedItem;
	for (std::size_t i = 0; i != arr->value.size(); ++i) {
		unusedItem = arr->value[i]->_counter == 1;
		flow_fn(unusedItem ? arr->value[i] : dup(arr->value[i]));
		if (unusedItem) arr->value[i] = nullptr;
	}
	drop(arr);
}
template <typename A>
void flow_iter(_FlowArray<A>* arr, const std::function<void(A)>& flow_fn) {
	for (std::size_t i = 0; i != arr->value.size(); ++i) {
		flow_fn(arr->value[i]);
	}
	drop(arr);
}
// ----------------------------------------------------------------------------------------
// for println2
template <typename A>
void flow_iter(_FlowArray<A>* arr, void (*flow_fn)(A)) {
	for (std::size_t i = 0; i != arr->value.size(); ++i) {
		flow_fn(arr->value[i]);
	}
	drop(arr);
}
template <typename A>
void flow_iter(_FlowArray<A*>* arr, void (*flow_fn)(A*)) {
	bool unusedItem;
	for (std::size_t i = 0; i != arr->value.size(); ++i) {
		unusedItem = arr->value[i]->_counter == 1;
		flow_fn(unusedItem ? arr->value[i] : dup(arr->value[i]));
		if (unusedItem) arr->value[i] = nullptr;
	}
	drop(arr);
}

template <typename A>
void flow_iteri(_FlowArray<A*>* arr, const std::function<void(int32_t, A*)>& flow_fn) {
	bool unusedItem;
	for (std::size_t i = 0; i != arr->value.size(); ++i) {
		unusedItem = arr->value[i]->_counter == 1;
		flow_fn(i, unusedItem ? arr->value[i] : dup(arr->value[i]));
		if (unusedItem) arr->value[i] = nullptr;
	}
	drop(arr);
}
template <typename A>
void flow_iteri(_FlowArray<A>* arr, const std::function<void(int32_t, A)>& flow_fn) {
	for (std::size_t i = 0; i != arr->value.size(); ++i) {
		flow_fn(i, arr->value[i]);
	}
	drop(arr);
}

template <typename A>
int32_t flow_iteriUntil(_FlowArray<A*>* arr, const std::function<bool(int32_t, A*)>& flow_fn) {
	bool unusedItem;
	bool found = false;
	std::size_t i = 0;
	while (i < arr->value.size() && !found) {
		unusedItem = arr->value[i]->_counter == 1;
		found = flow_fn(i, unusedItem ? arr->value[i] : dup(arr->value[i]));
		if (unusedItem) arr->value[i] = nullptr;
		if (!found) i++;
	}
	drop(arr);
	return i;
}
template <typename A>
int32_t flow_iteriUntil(_FlowArray<A>* arr, const std::function<bool(int32_t, A)>& flow_fn) {
	bool found = false;
	std::size_t i = 0;
	while (i < arr->value.size() && !found) {
		found = flow_fn(i, arr->value[i]);
		if (!found) i++;
	}
	drop(arr);
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
