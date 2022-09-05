#pragma once
// Cpp3 runtime
#include <map>
#include <string>
#include <vector>
#include <cassert>
#include <functional>
#include <sstream>
#include <compare>
#include <memory>
#include <cstdlib>
#include <variant>
#include <iostream>
#include <cmath>
#include <codecvt>
#include <locale>
#include <ctime>

namespace flow {

template<typename T> using Ptr = std::shared_ptr<T>;

enum Type {
	INT, BOOL, DOUBLE, STRING, 
	STRUCT, ARRAY, REF, FUNC, 
	NATIVE
};

using Void = void;

// Scalar types
using Int = int32_t;
using Bool = bool;
using Double = double;
using string = std::u16string;
using String = Ptr<string>;

std::wstring_convert<std::codecvt_utf8_utf16<char16_t>,char16_t> utf16_to_utf8;

inline std::string toStdString(String s) { return utf16_to_utf8.to_bytes(*s); }
inline string fromStdString(const std::string& s) { return utf16_to_utf8.from_bytes(s); }

String empty_string = String(new string());

inline String makeString() { return empty_string; }
inline String makeString(const char16_t* s) { return String(new string(s)); }
inline String makeString(String s) { return String(new string(*s)); }
inline String makeString(const string& s) { return String(new string(s)); }
inline String makeString(char16_t ch) { return String(new string(1, ch)); }
inline String makeString(const std::string& s) { return String(new string(fromStdString(s))); }


// Compound types
struct Struct;
struct Array;
struct Reference;
struct Function;

// Special uninterpreted type
struct Native;

using Flow = std::variant<
	Int, Bool, Double, String, 
	Ptr<Struct>, Ptr<Array>, Ptr<Reference>, Ptr<Function>,
	Ptr<Native>
>;

template<typename T> struct ToFlow;
template<typename T> struct FromFlow;

struct Struct {
	virtual Int id() const = 0;
	virtual String name() const = 0;
	virtual Int size() const = 0;
	virtual std::vector<Flow> fields() = 0;
};

struct Array { 
	virtual Int size() const = 0;
	virtual std::vector<Flow> elements() = 0;
};

struct Reference {
	virtual Flow reference() = 0;
};

struct Function {
};

struct Native {
	virtual String name() const = 0;
	virtual String toString() const = 0;
};

template<typename T> 
struct Str : public Struct {
	Str(T* s): str(s) { }
	Str(const Str& s): str(s.str) { }
	Str(Str&& s): str(std::move(s.str)) { }
	Str& operator = (Str&& s) { str = std::move(s.str); return *this; }
	Int id() const override { return str->id(); }
	String name() const override { return str->name(); }
	Int size() const override { return str->size(); }
	std::vector<Flow> fields() override { return str->fields(); }

	Ptr<T> str;
};

template<typename T> 
struct Arr : public Array {
	typedef std::vector<T> Vect;
	Arr(): arr(new Vect()) { }
	Arr(Int s): arr(new Vect()) { arr->reserve(s); }
	Arr(std::initializer_list<T> il): arr(new Vect(il)) { }
	Arr(const Arr& a): arr(a.arr) { }
	Arr(Arr&& a): arr(std::move(a.arr)) { }
	Arr(Vect* v): arr(v) { }
	Arr& operator = (Arr&& a) { arr = std::move(a.arr); return *this; }
	Int size() const override { return arr->size(); }
	std::vector<Flow> elements() override {
		std::vector<Flow> ret;
		ret.reserve(arr->size());
		for (T x : *arr) {
			ret.push_back(ToFlow<T>::conv(x));
		}
		return ret;
	};
	Arr<T> clone() const {
		Arr<T> ret(arr->size());
		for (T x : *arr) {
			ret.arr->push_back(x);
		}
		return ret;
	}

	Ptr<Vect> arr;
};

template<typename T> 
struct Ref : public Reference {
	Ref(T&& r): ref(std::make_shared<T>(r)) { }
	Ref(const Ref& r): ref(r.ref) { }
	Ref(Ref&& r): ref(std::move(r.ref)) { }
	Ref& operator = (Ref&& r) { ref = std::move(r.ref); return *this; }
	Flow reference() override { return ToFlow<T>::conv(*ref); }

	Ptr<T> ref;
};

template<typename R, typename... As> 
struct Fun : public Function {
	typedef std::function<R(As...)> Fn;
	Fun(Fn&& f): fn(std::make_shared<Fn>(f)) { }
	Fun(const Fun& f): fn(f.fn) { }
	Fun(Fun&& f): fn(std::move(f.fn)) { }
	Fun& operator = (Fun&& f) { fn = std::move(f.fn); return *this; }
	R operator()(As... as) const { return fn->operator()(as...); }

	Ptr<Fn> fn;
};

struct Nat : public Native {
	Nat(void* n): nat(n) { }
	Nat(const Nat& n): nat(n.nat) { }
	Nat(Nat&& n): nat(std::move(n.nat)) { }
	Nat& operator = (Nat&& n) { nat = std::move(n.nat); return *this; }

	void* nat;
};

void flow2string(Flow v, std::ostream& os, bool init = true) {
	switch (v.index()) {
		case Type::INT:    os << std::get<Int>(v); break;
		case Type::BOOL:   os << (std::get<Bool>(v) ? "true" : "false"); break;
		case Type::DOUBLE: os << std::get<Double>(v); break;
		case Type::STRING: {
			if (!init) os << "\"";
			os << toStdString(std::get<String>(v));
			if (!init) os << "\""; break;
		}
		case Type::STRUCT: {
			Ptr<Struct> s = std::get<Ptr<Struct>>(v);
			os << s->name() << "(";
			for (Flow f : s->fields()) {
				flow2string(f, os, false);
			}
			os << ")";
			break;
		}
		case Type::ARRAY: {
			Ptr<Array> a = std::get<Ptr<Array>>(v);
			os << "[";
			bool first = true;
			for (Flow e : a->elements()) {
				if (!first) {
					os << ", ";
				}
				flow2string(e, os, false);
				first = false;
			}
			os << "]";
			break;
		}
		case Type::REF: {
			os << "ref ";
			flow2string(std::get<Ptr<Reference>>(v)->reference(), os, false);
			break;
		}
		case Type::FUNC:   os << "<func>"; break;
		case Type::NATIVE: {
			os << toStdString(std::get<Ptr<Native>>(v)->toString());
			break;
		}
	}
}

template<typename T> struct ToFlow;
//{ 
//	static Flow conv(T t); 
//};
template<> struct ToFlow<Int> {
	static Flow conv(Int i) { return Flow(i); }
};
template<> struct ToFlow<Bool> {
	static Flow conv(Bool b) { return Flow(b); }
};
template<> struct ToFlow<Double> {
	static Flow conv(Double d) { return Flow(d); }
};
template<> struct ToFlow<String> {
	static Flow conv(String s) { return Flow(s); }
};
template<> struct ToFlow<Flow> {
	static Flow conv(Flow f) { return f; }
};
template<typename T> struct ToFlow<Arr<T>> {
	static Flow conv(Arr<T> a) { return Ptr<Array>(new Arr<T>(a)); }
};
template<typename T> struct ToFlow<Str<T>> {
	static Flow conv(Str<T> s) { return Ptr<Struct>(new Str<T>(s)); }
};
template<typename T> struct ToFlow<Ref<T>> {
	static Flow conv(Ref<T> r) { return Ptr<Reference>(new Ref<T>(r)); }
};
template<typename R, typename... As > struct ToFlow<Fun<R, As...>> {
	static Flow conv(Fun<R, As...> f) { return Ptr<Function>(new Fun<R, As...>(f)); }
};

template<typename T> struct FromFlow;
//{ 
//	static T conv(Flow f); 
//};
template<> struct FromFlow<Int> {
	static Int conv(Flow f) { return std::get<Int>(f); }
};
template<> struct FromFlow<Bool> {
	static Bool conv(Flow f) { return std::get<Bool>(f); }
};
template<> struct FromFlow<Double> {
	static Double conv(Flow f) { return std::get<Double>(f); }
};
template<> struct FromFlow<String> {
	static String conv(Flow f) { return std::get<String>(f); }
};
template<> struct FromFlow<Flow> {
	static Flow conv(Flow f) { return f; }
};
template<typename T> struct FromFlow<Arr<T>> {
	static Arr<T> conv(Flow f) { return dynamic_cast<Arr<T>&>(*std::get<Ptr<Array>>(f)); }
};
template<typename T> struct FromFlow<Str<T>> {
	static Str<T> conv(Flow f) { return dynamic_cast<Str<T>&>(*std::get<Ptr<Struct>>(f)); }
};
template<typename T> struct FromFlow<Ref<T>> {
	static Ref<T> conv(Flow f) { return dynamic_cast<Ref<T>&>(*std::get<Ptr<Reference>>(f)); }
};
template<typename R, typename... As > struct FromFlow<Fun<R, As...>> {
	static Fun<R, As...>& conv(Flow f) { return static_cast<Fun<R, As...>&>(*std::get<Ptr<Function>>(f)); }
};

std::map<string, string> command_args;
int exit_code = 0;
std::string date_time_format("%Y-%m-%d %H:%M:%S");

struct FieldDef {
	string name;
	string type;
	bool isMutable;
};

struct StructDef {
	typedef std::function<Flow(Arr<Flow>)> Constructor;
	Int id;
	Constructor make;
	std::vector<FieldDef> fields;
};

std::map<string, StructDef> struct_defs;

}
