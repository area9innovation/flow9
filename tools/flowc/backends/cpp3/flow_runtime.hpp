#pragma once
// Cpp3 runtime
#include <map>
#include <string>
#include <vector>
#include <cassert>
#include <functional>
#include <algorithm>
#include <sstream>
#include <fstream>
#include <memory>
#include <cstdlib>
#include <variant>
#include <iostream>
#include <cmath>
#include <codecvt>
#include <locale>
#include <ctime>
#include <chrono>
#include <sys/time.h>
#include <filesystem>
#include <system_error>
#include <unordered_map>
#include <concepts>
//#include <stacktrace>

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

// Unions for conversion from Double/Int to 16-bit chars and back

struct Two16Chars {
	Two16Chars(char16_t v0, char16_t v1): c0(v0), c1(v1) {}
	char16_t c0;
	char16_t c1;
};

union IntOrChars {
	Two16Chars chars;
	Int int_;
	IntOrChars(Int i): int_(i) { }
	IntOrChars(char16_t i0, char16_t i1): chars(i0, i1) { }
};
struct Four16Chars {
	Four16Chars(char16_t v0, char16_t v1, char16_t v2, char16_t v3): c0(v0), c1(v1), c2(v2), c3(v3) {}
	char16_t c0;
	char16_t c1;
	char16_t c2;
	char16_t c3;
};

union DoubleOrChars {
	Four16Chars chars;
	Double double_;
	DoubleOrChars(Double d): double_(d) { }
	DoubleOrChars(char16_t i0, char16_t i1, char16_t i2, char16_t i3): chars(i0, i1, i2, i3) { }
};

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
inline String makeString(const char16_t* s, Int len) { return String(new string(s, len)); }

String string_true = makeString("true");
String string_false = makeString("false");
String string_1 = makeString("1");
String string_0 = makeString("0");

template<typename T> struct ToFlow;
template<typename T> struct FromFlow;
template<typename T> struct Compare;

template<> struct Compare<Bool> {
	static Int cmp(Bool v1, Bool v2) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); }
};

template<> struct Compare<int> {
	static Int cmp(int v1, int v2) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); }
};

template<> struct Compare<Double> {
	static Int cmp(Double v1, Double v2) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0);  }
};

template<> struct Compare<void*> {
	static Int cmp(void* v1, void* v2) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0);  }
};

template<> struct Compare<String> {
	static Int cmp(String v1, String v2) { return v1->compare(*v2); }
};

// Compound types

struct Struct;
struct Union;
struct Array;
struct Reference;
struct Function;

// Special uninterpreted type
struct Native;

template<typename T> struct Str;

struct Flow {
	typedef std::variant<
		Int, Bool, Double, String, 
		Ptr<Struct>, Ptr<Array>, Ptr<Reference>, Ptr<Function>,
		Ptr<Native>
	> Variant;
	Flow(): val() { }
	Flow(Int i): val(i) { }
	Flow(Bool b): val(b) { }
	Flow(Double d): val(d) { }
	Flow(String s): val(s) { }
	Flow(Ptr<Struct> s): val(s) { }
	Flow(Ptr<Array> a): val(a) { }
	Flow(Ptr<Reference> r): val(r) { }
	Flow(Ptr<Function> f): val(f) { }
	Flow(Ptr<Native> n): val(n) { }

	template<typename T>
	Flow(Str<T> s);

	Variant val;

	Type type() const { 
		switch (val.index()) {
			case Type::INT:    return Type::INT;
			case Type::BOOL:   return Type::BOOL;
			case Type::DOUBLE: return Type::DOUBLE;
			case Type::STRING: return Type::STRING;
			case Type::STRUCT: return Type::STRUCT;
			case Type::ARRAY:  return Type::ARRAY;
			case Type::REF:    return Type::REF;
			case Type::FUNC:   return Type::FUNC;
			case Type::NATIVE: return Type::NATIVE;
			default: return Type::NATIVE;
		} 
	}
};

void flow2string(Flow v, std::ostream& os, bool init = true);

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
struct Str {
	typedef T Name;
	Str(): str() { }
	Str(T* s): str(s) { }
	Str(Ptr<T> s): str(s) { }
	Str(const Union& u);
	Str(const Flow& f);
	Str(const Str& s): str(s.str) { }
	Str(Str&& s): str(std::move(s.str)) { }
	T& operator *() { return str.operator*(); }
	T* operator ->() { return str.operator->(); }
	T* get() { return str.get(); }
	Str& operator = (const Str& s) { str.operator=(s.str); return *this; }
	Str& operator = (Str&& s) { str.operator=(std::move(s.str)); return *this;}

	Ptr<T> str;
};

struct Union {
	Union(): un() {}
	template<typename T>
	Union(Str<T> s): un(std::static_pointer_cast<Struct>(s.str)) { }
	Union(Ptr<Struct> s): un(s) { }
	Union(const Union& u): un(u.un) { }
	Union(Union&& u): un(std::move(u.un)) { }
	Struct& operator *() { return un.operator*(); }
	Struct* operator ->() { return un.operator->(); }
	Struct* get() { return un.get(); }
	Union& operator = (const Union& u) { un.operator=(u.un); return *this; }
	Union& operator = (Union&& u) { un.operator=(std::move(u.un)); return *this; }

	Ptr<Struct> un;
};

template<typename T>
Str<T>::Str(const Union& u): str(std::dynamic_pointer_cast<T>(u.un)) { }
template<typename T>
Str<T>::Str(const Flow& f) {
	if (f.type() != Type::STRUCT) {
		std::cerr << "struct construction from not a struct ";
		flow2string(f, std::cerr, false);
		std::cerr << std::endl;
	}
	str = std::dynamic_pointer_cast<T>(std::get<Ptr<Struct>>(f.val));
}

template<typename T>
Flow::Flow(Str<T> s): val(std::static_pointer_cast<Struct>(s.str)) { }

template<typename From, typename To>
Str<typename To::Name> struct2struct(Str<typename From::Name> from) {
	return std::reinterpret_pointer_cast<typename To::Name>(from.str);
}

template<typename To>
Str<typename To::Name> union2struct(Union from) {
	return std::dynamic_pointer_cast<typename To::Name>(from.un);
}

template<typename From>
Union struct2union(Str<typename From::Name> from) {
	return std::static_pointer_cast<Struct>(from.str);
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
	Arr& operator = (const Arr& a) { arr = a.arr; return *this; }
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
		Int c1 = Compare<Int>::cmp(arr->size(), a.arr->size());
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
	Ref(const T& r): ref(std::make_shared<T>(r)) { }
	Ref(T&& r): ref(std::make_shared<T>(r)) { }
	Ref(const Ref& r): ref(r.ref) { }
	Ref(Ref&& r): ref(std::move(r.ref)) { }
	Ref& operator = (Ref&& r) { ref = std::move(r.ref); return *this; }
	Ref& operator = (const Ref& r) { ref = r.ref; return *this; }
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
	Fun& operator = (const Fun& f) { fn = f.fn; return *this; }
	R operator()(As... as) const { return fn->operator()(as...); }
	Int compare(Fun f) const { return Compare<void*>::cmp(fn.get(), f.fn.get()); }
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
	Int compare(Nat n) const { return Compare<void*>::cmp(nat.get(), n.nat.get()); }
	template<typename N1>
	Nat<N1> cast() const {
		return std::reinterpret_pointer_cast<N1>(nat);
	}

	Ptr<N> nat;
};

void flow2string(Flow v, std::ostream& os, bool init) {
	switch (v.type()) {
		case Type::INT:    os << std::get<Int>(v.val); break;
		case Type::BOOL:   os << (std::get<Bool>(v.val) ? "true" : "false"); break;
		case Type::DOUBLE: os << std::get<Double>(v.val); break;
		case Type::STRING: {
			if (!init) os << "\"";
			os << toStdString(std::get<String>(v.val));
			if (!init) os << "\""; break;
		}
		case Type::STRUCT: {
			Ptr<Struct> s = std::get<Ptr<Struct>>(v.val);
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
			Ptr<Array> a = std::get<Ptr<Array>>(v.val);
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
			flow2string(std::get<Ptr<Reference>>(v.val)->reference(), os, false);
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
	static Flow conv(Union u) { return Flow(u.un); }
};
template<typename T> struct ToFlow<Arr<T>> {
	static Flow conv(Arr<T> a) { return Ptr<Array>(new Arr<T>(a)); }
};
template<typename T> struct ToFlow<Str<T>> {
	static Flow conv(Str<T> s) { return std::static_pointer_cast<Struct>(s.str); }
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
	static Int conv(Flow f) { return std::get<Int>(f.val); }
};
template<> struct FromFlow<Bool> {
	static Bool conv(Flow f) { return std::get<Bool>(f.val); }
};
template<> struct FromFlow<Double> {
	static Double conv(Flow f) { return std::get<Double>(f.val); }
};
template<> struct FromFlow<String> {
	static String conv(Flow f) { return std::get<String>(f.val); }
};
template<> struct FromFlow<Flow> {
	static Flow conv(Flow f) { return f; }
};
template<> struct FromFlow<Union> {
	static Union conv(Flow f) { return std::get<Ptr<Struct>>(f.val); }
};
template<typename T> struct FromFlow<Arr<T>> {
	static Arr<T> conv(Flow f) { 
		return std::dynamic_pointer_cast<typename Arr<T>::Vect>(std::get<Ptr<Array>>(f.val));
	}
};

template<> struct FromFlow<Arr<Flow>> {
	static Arr<Flow> conv(Flow f) { 
		return std::get<Ptr<Array>>(f.val)->elements();
	}
};
template<> struct FromFlow<Arr<Arr<Flow>>> {
	static Arr<Arr<Flow>> conv(Flow f) { 
		Arr<Flow> arrays = std::get<Ptr<Array>>(f.val)->elements();
		Arr<Arr<Flow>> ret(arrays.size());
		for (Flow x : *arrays.arr) {
			ret.arr->push_back(FromFlow<Arr<Flow>>::conv(x));
		}
		return ret;
	}
};

template<typename T> struct FromFlow<Str<T>> {
	static Str<T> conv(Flow f) { return dynamic_cast<Str<T>&>(*std::get<Ptr<Struct>>(f.val)); }
};
template<typename T> struct FromFlow<Ref<T>> {
	static Ref<T> conv(Flow f) { return dynamic_cast<Ref<T>&>(*std::get<Ptr<Reference>>(f.val)); }
};
template<typename R, typename... As> struct FromFlow<Fun<R, As...>> {
	static Fun<R, As...>& conv(Flow f) { return static_cast<Fun<R, As...>&>(*std::get<Ptr<Function>>(f.val)); }
};
template<typename T> struct FromFlow<Nat<T>> {
	static Nat<T> conv(Flow n) { return dynamic_cast<Nat<T>&>(*std::get<Ptr<Native>>(n.val)); }
};

template<typename From, typename To> struct Cast;

/*
enum Type {
	INT, BOOL, DOUBLE, STRING, 
	STRUCT, ARRAY, REF, FUNC, 
	NATIVE
};
*/

template<> struct Cast<Int, Int> { Int conv(Int x) { return x; } };
template<> struct Cast<Int, Bool> { Bool conv(Int x) { return x == 0 ? false : true; } };
template<> struct Cast<Int, Double> { Double conv(Int x) { return x; } };
template<> struct Cast<Int, String> { String conv(Int x) { return makeString(std::to_string(x)); } };

template<> struct Cast<Bool, Int> { Int conv(Bool x) { return x ? 1 : 0; } };
template<> struct Cast<Bool, Bool> { Bool conv(Bool x) { return x; } };
template<> struct Cast<Bool, Double> { Double conv(Bool x) { return x; } };
template<> struct Cast<Bool, String> { String conv(Bool x) { return makeString(std::to_string(x)); } };

template<> struct Cast<Double, Int> { Int conv(Double x) { return x; } };
template<> struct Cast<Double, Bool> { Bool conv(Double x) { return x; } };
template<> struct Cast<Double, Double> { Double conv(Double x) { return x; } };
template<> struct Cast<Double, String> { String conv(Double x) { return makeString(std::to_string(x)); } };

template<> struct Cast<String, Int> { Int conv(String x) { return std::stoi(toStdString(x)); } };
template<> struct Cast<String, Bool> { Bool conv(String x) { return *x == *string_true || *x == *string_1; } };
template<> struct Cast<String, Double> { Double conv(String x) { return std::stod(toStdString(x)); } };
template<> struct Cast<String, String> { String conv(String x) { return x; } };

template<typename> struct is_struct : std::false_type {};
template<typename T> struct is_struct<Arr<T>> : std::true_type {};

/*
template<typename S1, typename S2> struct Cast<S1, S1> { 
	S2 conv(S1 x) { return std::reinterpret_pointer_cast<typename S2::element_type>(x); } 
};
template<typename S> struct Cast<Union, S> { 
	S conv(Union x) { return std::dynamic_pointer_cast<typename S::element_type>(x); } 
};

template<typename S> struct Cast<S, Union> { 
	Union conv(S x) { return std::static_pointer_cast<Struct>(x); } 
};



template<typename T1, typename T2> struct Cast<is_array(T1), is_array(T2)> { 
	T2 conv(T1 x) { return std::static_pointer_cast<typename T2::Vect>(x); } 
};
*/


Int compareFlow(Flow v1, Flow v2);

template<> struct Compare<Flow> {
	static Int cmp(Flow v1, Flow v2) { return compareFlow(v1, v2); }
};

template<> struct Compare<Union> {
	static Int cmp(Union v1, Union v2) { return v1.un->compare(*v2.un); }
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
	static Int cmp(Fun<R, As...> v1, Fun<R, As...> v2) { return Compare<void*>::cmp(v1.fn.get(), v2.fn.get()); }
};

template<typename T>
struct Compare<Nat<T>> {
	static Int cmp(Nat<T> v1, Nat<T> v2) { return Compare<void*>::cmp(v1.nat.get(), v2.nat.get()); }
};

Int compareFlow(Flow v1, Flow v2) {
	if (v1.type() != v2.type()) {
		return Compare<Int>::cmp(v1.type(), v2.type());
	} else {
		switch (v1.type()) {
			case Type::INT:    return Compare<Int>::cmp(std::get<Int>(v1.val), std::get<Int>(v2.val));
			case Type::BOOL:   return Compare<Bool>::cmp(std::get<Bool>(v1.val), std::get<Bool>(v2.val));
			case Type::DOUBLE: return Compare<Double>::cmp(std::get<Double>(v1.val), std::get<Double>(v2.val));
			case Type::STRING: return std::get<String>(v1.val)->compare(*std::get<String>(v2.val));
			case Type::STRUCT: {
				Ptr<Struct> s1 = std::get<Ptr<Struct>>(v1.val);
				Ptr<Struct> s2 = std::get<Ptr<Struct>>(v2.val);
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
				Ptr<Array> a1 = std::get<Ptr<Array>>(v1.val);
				Ptr<Array> a2 = std::get<Ptr<Array>>(v2.val);
				Int c1 = Compare<Int>::cmp(a1->size(), a2->size());
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
				Ptr<Reference> r1 = std::get<Ptr<Reference>>(v1.val);
				Ptr<Reference> r2 = std::get<Ptr<Reference>>(v2.val);
				return compareFlow(r1->reference(), r2->reference());
			}
			case Type::FUNC: {
				Ptr<Function> f1 = std::get<Ptr<Function>>(v1.val);
				Ptr<Function> f2 = std::get<Ptr<Function>>(v2.val);
				return Compare<void*>::cmp(f1.get(), f2.get());
			}
			case Type::NATIVE: {
				Ptr<Native> n1 = std::get<Ptr<Native>>(v1.val);
				Ptr<Native> n2 = std::get<Ptr<Native>>(v2.val);
				return Compare<void*>::cmp(n1.get(), n2.get());
			}
			default: {
				std::cerr << "illegal type: " << v1.type() << std::endl;
				assert(false);
				return 0;
			}
		}
	}
}


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
