#pragma once
// Cpp3 runtime
#include <string>
#include <vector>
#include <cassert>
#include <functional>
#include <algorithm>
#include <sstream>
#include <memory>
#include <variant>
#include <iostream>
#include <codecvt>
#include <locale>
#include <cmath>

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

using utf16_to_utf8 = std::wstring_convert<std::codecvt_utf8_utf16<char16_t>,char16_t>;

inline std::string toStdString(String s) { utf16_to_utf8 conv; return conv.to_bytes(*s); }
inline string fromStdString(const std::string& s) { utf16_to_utf8 conv; return conv.from_bytes(s); }

const String empty_string = String(new string());

inline String makeString() { return empty_string; }
inline String makeString(const char16_t* s) { return String(new string(s)); }
inline String makeString(String s) { return String(new string(*s)); }
inline String makeString(const string& s) { return String(new string(s)); }
inline String makeString(char16_t ch) { return String(new string(1, ch)); }
inline String makeString(const std::string& s) { return String(new string(fromStdString(s))); }
inline String makeString(const char16_t* s, Int len) { return String(new string(s, len)); }

const String string_true = makeString("true");
const String string_false = makeString("false");
const String string_1 = makeString("1");
const String string_0 = makeString("0");

template<typename T> struct ToFlow;
template<typename T> struct FromFlow;
template<typename T> struct Compare;
template<typename T> struct Equal {
	bool operator() (T v1, T v2) const {
		return Compare<T>::cmp(v1, v2) == 0;
	}
};

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

// Abstract compound types

struct AStruct;
struct Union;
struct AArray;
struct AReference;
struct AFunction;

// Dynamic type
struct Flow;

// Special uninterpreted type
struct Native;

void flow2string(Flow v, std::ostream& os, bool init = true);

template<typename T> struct Str;
template<typename T> struct Arr;
template<typename T> struct Ref;
template<typename T> struct Nat;
template<typename R, typename... As> struct Fun;

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
	const T& operator *() const { return str.operator*(); }
	const T* operator ->() const { return str.operator->(); }
	const T* get() const { return str.get(); }
	bool isSameObj(Str<T> s) const { return str.get() == s.str.get(); }
	Str& operator = (const Str& s) { str.operator=(s.str); return *this; }
	Str& operator = (Str&& s) { str.operator=(std::move(s.str)); return *this;}
	template<typename T1>
	Str<T1> cast() {
		return std::reinterpret_pointer_cast<T1>(str);
	}

	Ptr<T> str;
};

struct Union {
	Union(): un() {}
	template<typename T>
	Union(Str<T> s): un(std::static_pointer_cast<AStruct>(s.str)) { }
	Union(Ptr<AStruct> s): un(s) { }
	Union(const Union& u): un(u.un) { }
	Union(Union&& u): un(std::move(u.un)) { }
	AStruct& operator *() { return un.operator*(); }
	AStruct* operator ->() { return un.operator->(); }
	AStruct* get() { return un.get(); }
	const AStruct& operator *() const { return un.operator*(); }
	const AStruct* operator ->() const { return un.operator->(); }
	const AStruct* get() const { return un.get(); }
	bool isSameObj(Union u) const { return un.get() == u.un.get(); }
	Union& operator = (const Union& u) { un.operator=(u.un); return *this; }
	Union& operator = (Union&& u) { un.operator=(std::move(u.un)); return *this; }
	template<typename T1>
	Str<T1> cast() {
		return std::dynamic_pointer_cast<T1>(un);
	}

	Ptr<AStruct> un;
};

struct Flow {
	typedef std::variant<
		Int, Bool, Double, String, 
		Ptr<AStruct>, Ptr<AArray>, Ptr<AReference>, Ptr<AFunction>,
		Ptr<Native>
	> Variant;
	Flow(): val() { }
	Flow(Int i): val(i) { }
	Flow(Bool b): val(b) { }
	Flow(Double d): val(d) { }
	Flow(String s): val(s) { }
	Flow(Ptr<AStruct> s): val(s) { }
	Flow(Ptr<AArray> a): val(a) { }
	Flow(Ptr<AReference> r): val(r) { }
	Flow(Ptr<AFunction> f): val(f) { }
	Flow(Ptr<Native> n): val(n) { }
	Flow(const Union& u): val(u.un) { }
	Flow(Union&& u): val(std::move(u.un)) { }
	template<typename T> Flow(Str<T> s);
	template<typename T> Flow(Ref<T> r);
	template<typename T> Flow(Arr<T> a);
	template<typename T> Flow(Nat<T> n);
	template<typename R, typename... As> Flow(Fun<R, As...> f);

	Variant val;

	Int toInt() { return std::get<Int>(val); }
	Bool toBool() { return std::get<Bool>(val); }
	Double toDouble() { return std::get<Double>(val); }
	String toString() { return std::get<String>(val); }
	Ptr<AStruct> toStruct() { return std::get<Ptr<AStruct>>(val); }
	Ptr<AArray> toArray() { return std::get<Ptr<AArray>>(val); }
	Ptr<AReference> toReference() { return std::get<Ptr<AReference>>(val); }
	Ptr<AFunction> toFunction() { return std::get<Ptr<AFunction>>(val); }
	Ptr<Native> toNative() { return std::get<Ptr<Native>>(val); }

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
			default:           return Type::NATIVE;
		} 
	}
	bool isSameObj(Flow f) { 
		if (type() != f.type()) {
			return false;
		} else {
			switch (type()) {
				case Type::INT:    return toInt() == f.toInt();
				case Type::BOOL:   return toBool() == f.toBool();
				case Type::DOUBLE: return toDouble() == f.toDouble();
				case Type::STRING: return *toString() == *f.toString();
				case Type::STRUCT: return toStruct().get() == f.toStruct().get();
				case Type::ARRAY:  return toArray().get() == f.toArray().get();
				case Type::REF:    return toReference().get() == f.toReference().get();
				case Type::FUNC:   return toFunction().get() == f.toFunction().get();
				case Type::NATIVE: return toNative().get() == f.toNative().get();
				default:           return false;
			}
		}
	}
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
	str = std::dynamic_pointer_cast<T>(std::get<Ptr<AStruct>>(f.val));
}

struct AStruct {
	virtual Int id() const = 0;
	virtual String name() const = 0;
	virtual Int size() const = 0;
	virtual std::vector<Flow> fields() = 0;
	virtual Flow field(String name) = 0;
	virtual void setField(String name, Flow val) = 0;
	virtual Int compare(const AStruct&) const = 0;
};

struct AArray {
	virtual Int size() const = 0;
	virtual std::vector<Flow> elements() = 0;
	virtual Flow element(Int i) = 0;
};

struct AReference {
	virtual Flow reference() = 0;
};

struct AFunction { 
	virtual Flow call(std::vector<Flow> args) = 0;
};

struct Native { 
	virtual Void* get() = 0;
};

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
	return std::static_pointer_cast<AStruct>(from.str);
}

template<typename T> 
struct Arr : public AArray {
	typedef std::vector<T> Vect;
	Arr(): arr(new Vect()) { }
	Arr(std::size_t s): arr(new Vect()) { arr->reserve(s); }
	Arr(std::initializer_list<T> il): arr(new Vect(il)) { }
	Arr(const Arr& a): arr(a.arr) { }
	Arr(Arr&& a): arr(std::move(a.arr)) { }
	Arr(const Vect& v): arr(new Vect(v)) { }
	Arr(Vect* v): arr(v) { }
	Arr(Ptr<Vect>&& v): arr(std::move(v)) { }
	Arr& operator = (Arr&& a) { arr = std::move(a.arr); return *this; }
	Arr& operator = (const Arr& a) { arr = a.arr; return *this; }
	Int size() const override { return static_cast<Int>(arr->size()); }
	std::vector<Flow> elements() override {
		std::vector<Flow> ret;
		ret.reserve(arr->size());
		for (T x : *arr) {
			ret.push_back(ToFlow<T>::conv(x));
		}
		return ret;
	}
	Flow element(Int i) override {
		return ToFlow<T>::conv(arr->at(i));
	}
	Int compare(Arr a) const { 
		Int c1 = Compare<Int>::cmp(arr->size(), a.arr->size());
		if (c1 != 0) {
			return c1;
		} else {
			for (std::size_t i = 0; i < arr->size(); ++ i) {
				Int c2 = Compare<T>::cmp(arr->at(i), a.arr->at(i));
				if (c2 != 0) {
					return c2;
				}
			}
			return 0;
		}
	}
	bool isSameObj(Arr a) const { return arr.get() == a.arr.get(); }
	template<typename T1>
	Arr<T1> cast() {
		return std::reinterpret_pointer_cast<typename Arr<T1>::Vect>(arr);
	}

	Ptr<Vect> arr;
};

template<typename T> 
struct Ref : public AReference {
	Ref() { }
	Ref(const T& r): ref(std::make_shared<T>(r)) { }
	Ref(T&& r): ref(std::make_shared<T>(r)) { }
	Ref(const Ref& r): ref(r.ref) { }
	Ref(Ptr<T>&& r): ref(std::move(r)) { }
	Ref(Ref&& r): ref(std::move(r.ref)) { }
	Ref& operator = (Ref&& r) { ref = std::move(r.ref); return *this; }
	Ref& operator = (const Ref& r) { ref = r.ref; return *this; }
	Flow reference() override { return ToFlow<T>::conv(*ref); }
	Int compare(Ref r) const { return Compare<T>::cmp(*ref, *r.ref); }
	bool isSameObj(Ref r) const { return ref.get() == r.ref.get(); }
	template<typename T1>
	Ref<T1> cast() {
		return std::reinterpret_pointer_cast<T1>(ref);
	}
	Ptr<T> ref;
};

template<typename R, typename... As> 
struct Fun : public AFunction {
	typedef std::function<R(As...)> Fn;
	Fun() {}
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
	bool isSameObj(Fun f) const { return fn.get() == f.fn.get(); }
	template<std::size_t... S>
	Flow call(const std::vector<Flow>& vec, std::index_sequence<S...>) {
		//return fn->operator()(FromFlow<As[S]...>::conv(vec.at(S)...));
		return Flow(0);
	}
	Flow call(std::vector<Flow> args) override {
		static const Int arity = sizeof...(As);
		if (arity == args.size()) {
			return call(args, std::make_index_sequence<arity>());
		} else {
			assert(false && "function arity mismatch");
			return Flow();
		}
	}
	template<typename R1, typename... As1> 
	Fun<R1, As1...> cast() {
		return std::reinterpret_pointer_cast<typename Fun<R1, As1...>::Fn>(fn);
	}

	Ptr<Fn> fn;
};

template<typename N>
struct Nat : public Native {
	Nat() {}
	Nat(N* n): nat(n) { }
	Nat(const Nat& n): nat(n.nat) { }
	Nat(const Ptr<N>& n): nat(n) { }
	Nat(Ptr<N>&& n): nat(std::move(n)) { }
	Nat(Nat&& n): nat(std::move(n.nat)) { }
	Nat& operator = (Nat&& n) { nat = std::move(n.nat); return *this; }
	Nat& operator = (const Nat& n) { nat = n.nat; return *this; }
	Int compare(Nat n) const { return Compare<void*>::cmp(nat.get(), n.nat.get()); }
	bool isSameObj(Nat n) const { return nat.get() == n.nut.get(); }
	Void* get() override { return nat.get(); }
	template<typename N1>
	Nat<N1> cast() {
		return std::reinterpret_pointer_cast<N1>(nat);
	}

	Ptr<N> nat;
};

template<typename T> Flow::Flow(Str<T> s): val(std::static_pointer_cast<AStruct>(s.str)) { }
template<typename T> Flow::Flow(Ref<T> r): val(std::make_shared<Ref<T>>(r)) { }
template<typename T> Flow::Flow(Arr<T> a): val(std::make_shared<Arr<T>>(a)) { }
template<typename T> Flow::Flow(Nat<T> n): val(std::make_shared<Nat<T>>(n)) { }
template<typename R, typename... As> Flow::Flow(Fun<R, As...> f): val(std::make_shared<Fun<R, As...>>(f)) { }

inline void flow2string(Flow v, std::ostream& os, bool init) {
	switch (v.type()) {
		case Type::INT:    os << std::get<Int>(v.val); break;
		case Type::BOOL:   os << (std::get<Bool>(v.val) ? "true" : "false"); break;
		case Type::DOUBLE: os << std::get<Double>(v.val); break;
		case Type::STRING: {
			if (!init) {
				os << "\"";
			}
			os << toStdString(std::get<String>(v.val));
			if (!init) {
				os << "\""; 
			}
			break;
		}
		case Type::STRUCT: {
			Ptr<AStruct> s = std::get<Ptr<AStruct>>(v.val);
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
			Ptr<AArray> a = std::get<Ptr<AArray>>(v.val);
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
			flow2string(std::get<Ptr<AReference>>(v.val)->reference(), os, false);
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

inline String flow2string(Flow f) {
	std::ostringstream os;
	flow2string(f, os, true);
	return makeString(os.str());
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
	static Flow conv(Arr<T> a) { return Ptr<AArray>(new Arr<T>(a)); }
};
template<typename T> struct ToFlow<Str<T>> {
	static Flow conv(Str<T> s) { return std::static_pointer_cast<AStruct>(s.str); }
};
template<typename T> struct ToFlow<Ref<T>> {
	static Flow conv(Ref<T> r) { return Ptr<AReference>(new Ref<T>(r)); }
};
template<typename R, typename... As> struct ToFlow<Fun<R, As...>> {
	static Flow conv(Fun<R, As...> f) { return Ptr<AFunction>(new Fun<R, As...>(f)); }
};
template<typename T> struct ToFlow<Nat<T>> {
	static Flow conv(Nat<T> n) { return Ptr<Native>(new Nat<T>(n)); }
};


template<> struct FromFlow<Int> {
	static Int conv(Flow f) { 
		switch (f.type()) {
			case Type::INT:    return f.toInt();
			case Type::BOOL:   return f.toBool() ? 1 : 0;
			case Type::DOUBLE: return round(f.toDouble());
			case Type::STRING: return std::stoi(toStdString(f.toString()));
			default:           return 0;
		}
	}
};
template<> struct FromFlow<Bool> {
	static Bool conv(Flow f) { 
		switch (f.type()) {
			case Type::INT:    return f.toInt() != 0;
			case Type::BOOL:   return f.toBool();
			case Type::DOUBLE: return f.toDouble() != 0.0;
			case Type::STRING: {
				std::string s = toStdString(f.toString());
				return s == "1" || s == "true" || s == "True";
			}
			default: return 0;
		}
	}
};
template<> struct FromFlow<Double> {
	static Double conv(Flow f) { 
		return f.toDouble();
		switch (f.type()) {
			case Type::INT:    return f.toInt();
			case Type::BOOL:   return f.toBool() ? 1.0 : 0.0;
			case Type::DOUBLE: return f.toDouble();
			case Type::STRING: return std::stod(toStdString(f.toString()));
			default:           return 0.0;
		}
	}
};
template<> struct FromFlow<String> {
	static String conv(Flow f) { return flow2string(f); }
};
template<> struct FromFlow<Flow> {
	static Flow conv(Flow f) { return f; }
};
template<> struct FromFlow<Union> {
	static Union conv(Flow f) { return f.toStruct(); }
};
template<typename T> struct FromFlow<Arr<T>> {
	static Arr<T> conv(Flow f) { 
		return std::dynamic_pointer_cast<typename Arr<T>::Vect>(f.toArray());
	}
};

template<> struct FromFlow<Arr<Flow>> {
	static Arr<Flow> conv(Flow f) { 
		return f.toArray()->elements();
	}
};
template<> struct FromFlow<Arr<Arr<Flow>>> {
	static Arr<Arr<Flow>> conv(Flow f) { 
		Arr<Flow> arrays = f.toArray()->elements();
		Arr<Arr<Flow>> ret(arrays.size());
		for (Flow x : *arrays.arr) {
			ret.arr->push_back(FromFlow<Arr<Flow>>::conv(x));
		}
		return ret;
	}
};

template<typename T> struct FromFlow<Str<T>> {
	static Str<T> conv(Flow f) { return dynamic_pointer_cast<T>(f.toStruct()); }
};
template<typename T> struct FromFlow<Ref<T>> {
	static Ref<T> conv(Flow f) { return *dynamic_pointer_cast<Ref<T>>(f.toReference()); }
};
template<typename R, typename... As> struct FromFlow<Fun<R, As...>> {
	static Fun<R, As...> conv(Flow f) { return *dynamic_pointer_cast<Fun<R, As...>>(f.toFunction()); }
};
template<typename T> struct FromFlow<Nat<T>> {
	static Nat<T> conv(Flow f) { return *dynamic_pointer_cast<Nat<T>>(f.toNative()); }
};

//template<typename From, typename To> struct Cast;

/*
enum Type {
	INT, BOOL, DOUBLE, STRING, 
	STRUCT, ARRAY, REF, FUNC, 
	NATIVE
};
*/
template<typename From> struct Cast;
template<> struct Cast<Int> { template<typename _To> struct To; };
template<> struct Cast<Bool> { template<typename _To> struct To; };
template<> struct Cast<Double> { template<typename _To> struct To; };
template<> struct Cast<String> { template<typename _To> struct To; };
template<> struct Cast<Flow> { template<typename _To> struct To; };
template<> struct Cast<Union> { template<typename _To> struct To; };
template<typename T> struct Cast<Str<T>> { template<typename _To> struct To; };
template<typename T> struct Cast<Arr<T>> { template<typename _To> struct To; };
template<typename T> struct Cast<Ref<T>> { template<typename _To> struct To; };
template<typename T> struct Cast<Nat<T>> { template<typename _To> struct To; };
template<typename R, typename... As> struct Cast<Fun<R, As...>> { template<typename _To> struct To; };

template<> struct Cast<Int>::To<Int> { Int conv(Int x) { return x; } };
template<> struct Cast<Int>::To<Bool> { Bool conv(Int x) { return x == 0 ? false : true; } };
template<> struct Cast<Int>::To<Double> { Double conv(Int x) { return x; } };
template<> struct Cast<Int>::To<String> { String conv(Int x) { return makeString(std::to_string(x)); } };
template<> struct Cast<Int>::To<Flow> { Flow conv(Int x) { return x; } };

template<> struct Cast<Bool>::To<Int> { Int conv(Bool x) { return x ? 1 : 0; } };
template<> struct Cast<Bool>::To<Bool> { Bool conv(Bool x) { return x; } };
template<> struct Cast<Bool>::To<Double> { Double conv(Bool x) { return x; } };
template<> struct Cast<Bool>::To<String> { String conv(Bool x) { return makeString(std::to_string(x)); } };
template<> struct Cast<Bool>::To<Flow> { Flow conv(Bool x) { return x; } };

template<> struct Cast<Double>::To<Int> { Int conv(Double x) { return x; } };
template<> struct Cast<Double>::To<Bool> { Bool conv(Double x) { return x; } };
template<> struct Cast<Double>::To<Double> { Double conv(Double x) { return x; } };
template<> struct Cast<Double>::To<String> { String conv(Double x) { return makeString(std::to_string(x)); } };
template<> struct Cast<Double>::To<Flow> { Flow conv(Bool x) { return x; } };

template<> struct Cast<String>::To<Int> { Int conv(String x) { return std::stoi(toStdString(x)); } };
template<> struct Cast<String>::To<Bool> { Bool conv(String x) { return *x == *string_true || *x == *string_1; } };
template<> struct Cast<String>::To<Double> { Double conv(String x) { return std::stod(toStdString(x)); } };
template<> struct Cast<String>::To<String> { String conv(String x) { return x; } };
template<> struct Cast<String>::To<Flow> { Flow conv(Bool x) { return x; } };

template<> struct Cast<Flow>::To<Int> { Int conv(Flow x) { return x.toInt(); } };
template<> struct Cast<Flow>::To<Bool> { Bool conv(Flow x) { return x.toBool(); } };
template<> struct Cast<Flow>::To<Double> { Double conv(Flow x) { return x.toDouble(); } };
template<> struct Cast<Flow>::To<String> { String conv(Flow x) { return x.toString(); } };
template<> struct Cast<Flow>::To<Ptr<AStruct>> { Ptr<AStruct> conv(Flow x) { return x.toStruct(); } };
template<> struct Cast<Flow>::To<Ptr<AArray>> { Ptr<AArray> conv(Flow x) { return x.toArray(); } };
template<> struct Cast<Flow>::To<Ptr<AReference>> { Ptr<AReference> conv(Flow x) { return x.toReference(); } };
template<> struct Cast<Flow>::To<Ptr<AFunction>> { Ptr<AFunction> conv(Flow x) { return x.toFunction(); } };
template<> struct Cast<Flow>::To<Ptr<Native>> { Ptr<Native> conv(Flow x) { return x.toNative(); } };

template<typename T> struct Cast<Flow>::To<Str<T>> {
	Str<T> conv(Flow x) { 
		return std::dynamic_pointer_cast<typename Str<T>::Name>(x.toStruct()); 
	} 
};
template<> struct Cast<Flow>::To<Union> {
	Union conv(Flow x) { 
		return x.toStruct(); 
	} 
};
template<typename T> struct Cast<Flow>::To<Arr<T>> { 
	Arr<T> conv(Flow x) {
		return *std::dynamic_pointer_cast<Arr<T>>(x.toArray()); 
	} 
};
template<typename T> struct Cast<Flow>::To<Ref<T>> { 
	Ref<T> conv(Flow x) { 
		return *std::dynamic_pointer_cast<Ref<T>>(x.toReference()); 
	} 
};
template<typename R, typename... As> struct Cast<Flow>::To<Fun<R, As...>> { 
	Fun<R, As...> conv(Flow x) { 
		return *std::dynamic_pointer_cast<Fun<R, As...>>(x.toFunction());
	} 
};

template<typename T> struct Cast<Flow>::To<Nat<T>> { 
	Nat<T> conv(Flow x) { 
		return *std::dynamic_pointer_cast<Nat<T>>(x.toNative()); 
	} 
};

//template<> struct Cast<Int>::To<Flow> { Flow conv(Int x) { return x; } };
//template<> struct Cast<Bool>::To<Flow> { Flow conv(Bool x) { return x; } };
//template<> struct Cast<Double>::To<Flow> { Flow conv(Double x) { return x; } };
//template<> struct Cast<String>::To<Flow> { Flow conv(String x) { return x; } };
//template<> struct Cast<Ptr<AStruct>>::To<Flow> { Flow conv(Ptr<AStruct> x) { return x; } };
//template<> struct Cast<Ptr<AArray>>::To<Flow> { Flow conv(Ptr<AArray> x) { return x; } };
//template<> struct Cast<Ptr<AReference>>::To<Flow> { Flow conv(Ptr<AReference> x) { return x; } };
//template<> struct Cast<Ptr<AFunction>>::To<Flow> { Flow conv(Ptr<AFunction> x) { return x; } };
//template<> struct Cast<Ptr<Native>>::To<Flow> { Flow conv(Ptr<Native> x) { return x; } };

/*
template<typename T> struct Cast<Str<T>>::To<Flow> {
	Flow conv(Str<T> x) { 
		return std::static_pointer_cast<AStruct>(x.str); 
	} 
};
*/

/*
template<> struct Cast<Union>::To<Flow> {
	Flow conv(Union x) { 
		return x.un; 
	} 
};
template<typename T> struct Cast<Arr<T>>::To<Flow> { 
	Flow conv(Arr<T> x) {
		return Ptr<AArray>(new Arr<T>(x));
	} 
};
template<typename T> struct Cast<Ref<T>>::To<Flow> { 
	Flow conv(Ref<T> x) { 
		return Ptr<AReference>(new Ref<T>(x));
	} 
};
template<typename R, typename... As> struct Cast<Fun<R, As...>>::To<Flow> { 
	Flow conv(Fun<R, As...> x) { 
		return Ptr<AFunction>(new Fun<R, As...>(x));
	} 
};

template<typename T> struct Cast<Nat<T>>::To<Flow> { 
	Flow conv(Nat<T> x) { 
		return Ptr<Native>(new Nat<T>(x));
	} 
};

//template<typename T> struct Cast<Ptr<AStruct>>::To<Str<T>> { Str<T> conv(Ptr<AStruct> x) { return std::dynamic_pointer_cast<T>(x); } };
template<typename T> struct Cast<Union>::To<Str<T>> { Str<T> conv(Union x) { return std::dynamic_pointer_cast<T>(x.un); } };
//template<typename T> struct Cast<Str<T>>::To<Ptr<AStruct>> { Ptr<AStruct> conv(Str<T> x) { return std::static_pointer_cast<AStruct>(x.str); } };
template<typename T> struct Cast<Str<T>>::To<Union> { Union conv(Str<T> x) { return std::static_pointer_cast<AStruct>(x.str); } };
template<typename T1, typename T2> struct Cast<Str<T1>>::To<Str<T2>> { Ptr<T2> conv(Str<T1> x) { return std::reinterpret_pointer_cast<T2>(x.str); } };


template<typename T1, typename T2> struct Cast<Arr<T1>>::To<Arr<T2>> { Arr<T2> conv(Arr<T1> x) { return x.template cast<T2>(); } };
template<typename T1, typename T2> struct Cast<Ref<T1>>::To<Ref<T2>> { Ref<T2> conv(Ref<T1> x) { return x.template cast<T2>(); } };
template<typename T1, typename T2> struct Cast<Nat<T1>>::To<Nat<T2>> { Nat<T2> conv(Nat<T1> x) { return x.template cast<T2>(); } };

*/

template<typename> struct is_struct : std::false_type {};
template<typename T> struct is_struct<Str<T>> : std::true_type {};

/*
template<typename S1, typename S2> struct Cast<S1, S1> { 
	S2 conv(S1 x) { return std::reinterpret_pointer_cast<typename S2::element_type>(x); } 
};
template<typename S> struct Cast<Union, S> { 
	S conv(Union x) { return std::dynamic_pointer_cast<typename S::element_type>(x); } 
};

template<typename S> struct Cast<S, Union> { 
	Union conv(S x) { return std::static_pointer_cast<AStruct>(x); } 
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

inline Int compareFlow(Flow v1, Flow v2) {
	if (v1.type() != v2.type()) {
		return Compare<Int>::cmp(v1.type(), v2.type());
	} else {
		switch (v1.type()) {
			case Type::INT:    return Compare<Int>::cmp(std::get<Int>(v1.val), std::get<Int>(v2.val));
			case Type::BOOL:   return Compare<Bool>::cmp(std::get<Bool>(v1.val), std::get<Bool>(v2.val));
			case Type::DOUBLE: return Compare<Double>::cmp(std::get<Double>(v1.val), std::get<Double>(v2.val));
			case Type::STRING: return std::get<String>(v1.val)->compare(*std::get<String>(v2.val));
			case Type::STRUCT: {
				Ptr<AStruct> s1 = std::get<Ptr<AStruct>>(v1.val);
				Ptr<AStruct> s2 = std::get<Ptr<AStruct>>(v2.val);
				Int c1 = s1->name()->compare(*s2->name());
				if (c1 != 0) {
					return c1;
				} else {
					std::vector<Flow> fs1 = s1->fields();
					std::vector<Flow> fs2 = s2->fields();
					for (std::size_t i = 0; i < fs1.size(); ++ i) {
						Int c2 = compareFlow(fs1.at(i), fs2.at(i));
						if (c2 != 0) {
							return c2;
						}
					}
					return 0;
				}
			}
			case Type::ARRAY: {
				Ptr<AArray> a1 = std::get<Ptr<AArray>>(v1.val);
				Ptr<AArray> a2 = std::get<Ptr<AArray>>(v2.val);
				Int c1 = Compare<Int>::cmp(a1->size(), a2->size());
				if (c1 != 0) {
					return c1;
				} else {
					std::vector<Flow> es1 = a1->elements();
					std::vector<Flow> es2 = a2->elements();
					for (std::size_t i = 0; i < es1.size(); ++ i) {
						Int c2 = compareFlow(es1.at(i), es2.at(i));
						if (c2 != 0) {
							return c2;
						}
					}
					return 0;
				}
			}
			case Type::REF: {
				Ptr<AReference> r1 = std::get<Ptr<AReference>>(v1.val);
				Ptr<AReference> r2 = std::get<Ptr<AReference>>(v2.val);
				return compareFlow(r1->reference(), r2->reference());
			}
			case Type::FUNC: {
				Ptr<AFunction> f1 = std::get<Ptr<AFunction>>(v1.val);
				Ptr<AFunction> f2 = std::get<Ptr<AFunction>>(v2.val);
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

}
