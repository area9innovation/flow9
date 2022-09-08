#pragma once
// Cpp3 runtime
#include <map>
#include <string>
#include <vector>
#include <cassert>
#include <functional>
#include <algorithm>
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

template<typename O>
Int order2int(O x) { return (x < 0) ? 1 : ((x > 0) ? 1 : 0); }

// Compound types

struct Struct;
struct Array;
struct Reference;
struct Function;

// Special uninterpreted type
struct Native;

using Union = Ptr<Struct>;

using Flow = std::variant<
	Int, Bool, Double, String, 
	Ptr<Struct>, Ptr<Array>, Ptr<Reference>, Ptr<Function>,
	Ptr<Native>
>;

template<typename T> struct ToFlow;
template<typename T> struct FromFlow;
template<typename T> struct Compare;

struct Struct {
	virtual Int id() const = 0;
	virtual String name() const = 0;
	virtual Int size() const = 0;
	virtual std::vector<Flow> fields() = 0;
	virtual Int compare(const Struct&) const = 0;
};

struct Array {
	virtual Int size() const = 0;
	virtual std::vector<Flow> elements() = 0;
};

struct Reference {
	virtual Flow reference() = 0;
};

struct Function { };

struct Native { };

template<typename T> 
using Str = Ptr<T>;

template<typename From, typename To>
Str<To> struct2struct(Str<From> from) {
	return std::reinterpret_pointer_cast<To>(from);
}

template<typename To>
Str<To> union2struct(Union from) {
	return std::dynamic_pointer_cast<To>(from);
}

template<typename From>
Union struct2union(Str<From> from) {
	return std::static_pointer_cast<Struct>(from);
}

template<typename T> 
struct Arr : public Array {
	typedef std::vector<T> Vect;
	Arr(): arr(new Vect()) { }
	Arr(Int s): arr(new Vect()) { arr->reserve(s); }
	Arr(std::initializer_list<T> il): arr(new Vect(il)) { }
	Arr(const Arr& a): arr(a.arr) { }
	Arr(Arr&& a): arr(std::move(a.arr)) { }
	Arr(const Vect& v): arr(new Vect(v)) { }
	Arr(Vect* v): arr(v) { }
	Arr(Ptr<Vect>&& v): arr(std::move(v)) { }
	Arr& operator = (Arr&& a) { arr = std::move(a.arr); return *this; }
	Int size() const override { return arr->size(); }
	std::vector<Flow> elements() override {
		std::vector<Flow> ret;
		ret.reserve(arr->size());
		for (T x : *arr) {
			ret.push_back(ToFlow<T>::conv(x));
		}
		return ret;
	}
	Int compare(Arr a) const { 
		Int c1 = order2int(arr->size() <=> a.arr->size());
		if (c1 != 0) {
			return c1;
		} else {
			for (Int i = 0; i < arr->size(); ++ i) {
				Int c2 = Compare<T>::cmp(arr->at(i), a.arr->at(i));
				if (c2 != 0) {
					return c2;
				}
			}
			return 0;
		}
	}
	template<typename T1>
	Arr<T1> cast() const {
		return std::reinterpret_pointer_cast<typename Arr<T1>::Vect>(arr);
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
	Int compare(Ref r) const { return Compare<T>::cmp(*ref, *r.ref); }
	template<typename T1>
	Ref<T1> cast() const {
		return std::reinterpret_pointer_cast<T1>(ref);
	}
	Ptr<T> ref;
};

template<typename R, typename... As> 
struct Fun : public Function {
	typedef std::function<R(As...)> Fn;
	//Fun(const Fn& f): fn(std::make_shared(f)) { }
	Fun(Fn&& f): fn(std::make_shared<Fn>(f)) { }
	Fun(Fn* f): fn(f) { }
	Fun(Ptr<Fn>&& f): fn(std::move(f)) { }
	Fun(const Fn& f): fn(std::make_shared<Fn>(f)) { }
	Fun(const Fun& f): fn(f.fn) { }
	Fun(Fun&& f): fn(std::move(f.fn)) { }
	Fun& operator = (Fun&& f) { fn = std::move(f.fn); return *this; }
	R operator()(As... as) const { return fn->operator()(as...); }
	Int compare(Fun f) const { return order2int(fn.get() <=> f.fn.get()); }
	template<typename R1, typename... As1> 
	Fun<R1, As1...> cast() const {
		return std::reinterpret_pointer_cast<typename Fun<R1, As1...>::Fn>(fn);
	}

	Ptr<Fn> fn;
};

template<typename N>
struct Nat : public Native {
	Nat(N* n): nat(n) { }
	Nat(const Nat& n): nat(n.nat) { }
	Nat(Nat&& n): nat(std::move(n.nat)) { }
	Nat& operator = (Nat&& n) { nat = std::move(n.nat); return *this; }
	Int compare(Nat n) const { return order2int(nat.get() <=> n.nat.get()); }
	template<typename N1>
	Nat<N1> cast() const {
		return std::reinterpret_pointer_cast<N1>(nat);
	}

	Ptr<N> nat;
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
			os << toStdString(s->name()) << "(";
			bool first = true;
			for (Flow f : s->fields()) {
				if (!first) {
					os << ", ";
				}
				flow2string(f, os, false);
				first = false;
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
		case Type::FUNC: {
			os << "<func>"; 
			break;
		}
		case Type::NATIVE: {
			os << "<native>";
			break;
		}
	}
}

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
template<> struct ToFlow<Union> {
	static Flow conv(Union u) { return Flow(u); }
};
template<typename T> struct ToFlow<Arr<T>> {
	static Flow conv(Arr<T> a) { return Ptr<Array>(new Arr<T>(a)); }
};
template<typename T> struct ToFlow<Str<T>> {
	static Flow conv(Str<T> s) { return s; }
};
template<typename T> struct ToFlow<Ref<T>> {
	static Flow conv(Ref<T> r) { return Ptr<Reference>(new Ref<T>(r)); }
};
template<typename R, typename... As> struct ToFlow<Fun<R, As...>> {
	static Flow conv(Fun<R, As...> f) { return Ptr<Function>(new Fun<R, As...>(f)); }
};
template<typename T> struct ToFlow<Nat<T>> {
	static Flow conv(Nat<T> n) { return Ptr<Native>(new Nat<T>(n)); }
};


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
template<> struct FromFlow<Union> {
	static Union conv(Flow f) { return std::get<Union>(f); }
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
template<typename R, typename... As> struct FromFlow<Fun<R, As...>> {
	static Fun<R, As...>& conv(Flow f) { return static_cast<Fun<R, As...>&>(*std::get<Ptr<Function>>(f)); }
};
template<typename T> struct FromFlow<Nat<T>> {
	static Nat<T> conv(Flow n) { return dynamic_cast<Nat<T>&>(*std::get<Ptr<Native>>(n)); }
};

Int compareFlow(Flow v1, Flow v2) {
	if (v1.index() != v2.index()) {
		return order2int(v1.index() <=> v2.index());
	} else {
		switch (v1.index()) {
			case Type::INT:    return order2int(std::get<Int>(v1) <=> std::get<Int>(v2));
			case Type::BOOL:   return order2int(std::get<Bool>(v1) <=> std::get<Bool>(v2));
			case Type::DOUBLE: return order2int(std::get<Double>(v1) <=> std::get<Double>(v2));
			case Type::STRING: return std::get<String>(v1)->compare(*std::get<String>(v2));
			case Type::STRUCT: {
				Ptr<Struct> s1 = std::get<Ptr<Struct>>(v1);
				Ptr<Struct> s2 = std::get<Ptr<Struct>>(v2);
				Int c1 = s1->name()->compare(*s2->name());
				if (c1 != 0) {
					return c1;
				} else {
					std::vector<Flow> fs1 = s1->fields();
					std::vector<Flow> fs2 = s2->fields();
					for (Int i = 0; i < fs1.size(); ++ i) {
						Int c2 = compareFlow(fs1.at(i), fs2.at(i));
						if (c2 != 0) {
							return c2;
						}
					}
					return 0;
				}
			}
			case Type::ARRAY: {
				Ptr<Array> a1 = std::get<Ptr<Array>>(v1);
				Ptr<Array> a2 = std::get<Ptr<Array>>(v2);
				Int c1 = order2int(a1->size() <=> a2->size());
				if (c1 != 0) {
					return c1;
				} else {
					std::vector<Flow> es1 = a1->elements();
					std::vector<Flow> es2 = a2->elements();
					for (Int i = 0; i < es1.size(); ++ i) {
						Int c2 = compareFlow(es1.at(i), es2.at(i));
						if (c2 != 0) {
							return c2;
						}
					}
					return 0;
				}
			}
			case Type::REF: {
				Ptr<Reference> r1 = std::get<Ptr<Reference>>(v1);
				Ptr<Reference> r2 = std::get<Ptr<Reference>>(v2);
				return compareFlow(r1->reference(), r2->reference());
			}
			case Type::FUNC: {
				Ptr<Function> f1 = std::get<Ptr<Function>>(v1);
				Ptr<Function> f2 = std::get<Ptr<Function>>(v2);
				return order2int(f1.get() <=> f2.get());
			}
			case Type::NATIVE: {
				Ptr<Native> n1 = std::get<Ptr<Native>>(v1);
				Ptr<Native> n2 = std::get<Ptr<Native>>(v2);
				return order2int(n1.get() <=> n2.get());
			}
			default: {
				std::cerr << "illegal type: " << v1.index() << std::endl;
				assert(false);
				return 0;
			}
		}
	}
}

template<> struct Compare<Int> {
	static Int cmp(Int v1, Int v2) { return order2int(v1 <=> v2); }
};

template<> struct Compare<Bool> {
	static Int cmp(Bool v1, Bool v2) { return order2int(v1 <=> v2); }
};

template<> struct Compare<Double> {
	static Int cmp(Double v1, Double v2) { return order2int(v1 <=> v2); }
};

template<> struct Compare<String> {
	static Int cmp(String v1, String v2) { return v1->compare(*v2); }
};

template<> struct Compare<Flow> {
	static Int cmp(Flow v1, Flow v2) { return compareFlow(v1, v2); }
};

template<> struct Compare<Union> {
	static Int cmp(Union v1, Union v2) { return v1->compare(*v2); }
};

template<typename T>
struct Compare<Arr<T>> {
	static Int cmp(Arr<T> v1, Arr<T> v2) { return v1.compare(v2); }
};

template<typename T>
struct Compare<Ref<T>> {
	static Int cmp(Ref<T> v1, Ref<T> v2) { return v1.compare(v2); }
};

template<typename T>
struct Compare<Str<T>> {
	static Int cmp(Str<T> v1, Str<T> v2) { return v1->compare(*v2); }
};

template<typename R, typename... As>
struct Compare<Fun<R, As...>> {
	static Int cmp(Fun<R, As...> v1, Fun<R, As...> v2) { return order2int(v1.fn.get() <=> v2.fn.get()); }
};

template<typename T>
struct Compare<Nat<T>> {
	static Int cmp(Nat<T> v1, Nat<T> v2) { return order2int(v1.nat.get() <=> v2.nat.get()); }
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
