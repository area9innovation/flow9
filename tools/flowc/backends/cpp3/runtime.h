#pragma once
#include <functional>
#include <variant>
#include <string>
#include <sstream>
#include <ostream>
#include <iostream>
#include <memory>

namespace flowc {


template <typename T>
std::shared_ptr<T> makeRef(T value) {
  return std::make_shared<T>(value);
}

template <typename T>
std::shared_ptr<T> copyValue(T value) {
  return std::make_shared<T>(value);
}

enum class RuntimeType {
	VOID, BOOL, INT, DOUBLE, STRING, NATIVE, 
	ARRAY, REF, FUNC, NAME
};

template<class T> RuntimeType runtimeType();

template<> RuntimeType runtimeType<void>() { return RuntimeType::VOID; }
template<> RuntimeType runtimeType<bool>() { return RuntimeType::BOOL; }
template<> RuntimeType runtimeType<int>() { return RuntimeType::INT; }
template<> RuntimeType runtimeType<double>() { return RuntimeType::DOUBLE; }
template<> RuntimeType runtimeType<std::string>() { return RuntimeType::STRING; }
//template<class T> RuntimeType runtimeType<std::vector<T>>() { return RuntimeType::ARRAY; }

template<class T> T* copyScalar(T v);

template<> bool* copyScalar<bool>(bool v) { return new bool({v}); }
template<> int* copyScalar<int>(int v) { return new int({v}); }
template<> double* copyScalar<double>(double v) { return new double({v}); }
template<> std::string* copyScalar<std::string>(std::string s) { return new std::string(s); }

template<class T, class F> std::shared_ptr<T> copyValue(F v) { return std::make_shared<bool>(v); }
//template<> std::shared_ptr<bool> copyValue<bool>(bool v) { return std::make_shared<bool>(v); }
//template<> int* copyScalar<int>(int v) { return new int({v}); }
//template<> double* copyScalar<double>(double v) { return new double({v}); }
//template<> std::string* copyScalar<std::string>(std::string s) { return new std::string(s); }

template<class T, class F>
inline typename std::enable_if<std::is_same<F, std::vector<T>>::value, std::shared_ptr<std::vector<T>>>::type
copyValue(F v) {
	return new std::vector(v);
}

template<class T> std::vector<T>* copyArray(std::vector<T> v) { return new std::vector(v); }

//template<class R, class ... AS>
//std::function<R(AS...)>& funcRef(std::function<R(AS...)> fn) {
//	R(&ret)(AS);
//}


struct FlowVal {
	void* data;
	RuntimeType type;
};


/*struct RuntimeType {
	virtual 
};*/

std::string toString(const FlowVal& val) {
	std::ostringstream os;
	switch (val.type) {
		case RuntimeType::VOID:{
			os << "{}";
			break;
		}
		case RuntimeType::BOOL: {
			os << *reinterpret_cast<int*>(val.data);
			break;
		}
		case RuntimeType::INT: {
			os << *reinterpret_cast<int*>(val.data);
			break;
		}
		case RuntimeType::DOUBLE: {
			os << *reinterpret_cast<double*>(val.data);
			break;
		}
		case RuntimeType::STRING: {
			os << *reinterpret_cast<std::string*>(val.data);
			break;
		}
		case RuntimeType::ARRAY: {
			const std::vector<FlowVal>& arr = *reinterpret_cast<const std::vector<FlowVal>*>(val.data);
			os << "["; for (auto v : arr) os << toString(v); os << "[";
			break;
		}
		case RuntimeType::REF: {
			const FlowVal* ref = *reinterpret_cast<const FlowVal**>(val.data);
			os << toString(*ref);
			break;
		}
		case RuntimeType::NAME: {
			//const FlowVal* val = *reinterpret_cast<FlowVal**>(val.data);
			os << "TODO: NAME";
			break;
		}
		default: {
			break;
		}
	}
	return os.str();
}

// Natives:

void println2(const FlowVal& val) {
	std::cout << toString(val) << std::endl;
}

template<class T_1, class T_2>
T_2 extractStruct(std::vector<T_1> a, T_2 s) {
	// Just a stub
	return s;
}

 void quit(int code) {
	 std::exit(code);
 }

 std::string i2s(int x) {
	 std::ostringstream os;
	 os << x;
	 return os.str();
 }

}
