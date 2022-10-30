// Common includes, which are used by runtime

#ifndef FLOW_RUNTIME_HEADER
#include <string>
#include <vector>
#include <functional>
#include <algorithm>
#include <sstream>
#include <memory>
#include <variant>
#include <iostream>
#include <iomanip>
#include <type_traits>
#endif

// C++ runtime for flow

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

std::string toStdString(String str);
string fromStdString(const std::string& s);

inline String makeString() { return std::make_shared<string>(); }
inline String makeString(const char16_t* s) { return std::make_shared<string>(s); }
inline String makeString(String s) { return std::make_shared<string>(*s); }
inline String makeString(const string& s) { return std::make_shared<string>(s); }
inline String makeString(string&& s) { return std::make_shared<string>(std::move(s)); }
inline String makeString(char16_t ch) { return std::make_shared<string>(1, ch); }
inline String makeString(const std::string& s) { return std::make_shared<string>(fromStdString(s)); }
inline String makeString(const char16_t* s, Int len) { return std::make_shared<string>(s, len); }
inline String makeString(const std::vector<char16_t>& codes) { return std::make_shared<string>(codes.data(), codes.size()); }

const String string_true = makeString(u"true");
const String string_false = makeString(u"false");
const String string_1 = makeString(u"1");
const String string_0 = makeString(u"0");

inline Int double2int(Double x) { return (x >= 0.0) ? static_cast<Int>(x + 0.5) : static_cast<Int>(x - 0.5); }
inline Int string2int(String x) { if (x->size() == 0) return 0; else { try { return std::stoi(toStdString(x)); } catch (std::exception& e) { return 0; } } }
inline Double string2double(String x) { if (x->size() == 0) return 0.0; else { try { return std::stod(toStdString(x)); } catch (std::exception& e) { return 0.0; } } }
inline String int2string(Int x) { return makeString(std::to_string(x)); }
String double2string(Double x);
inline String bool2string(Bool x) { return x ? string_true : string_false; }


const char* type2s(Int type);

template<typename T> struct ToFlow;
template<typename T> struct FromFlow;
template<typename T> struct Compare;
template<typename T> struct Equal {
	bool operator() (T v1, T v2) const { return Compare<T>::cmp(v1, v2) == 0; }
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

void flow2string(Flow v, String os);

template<typename T> struct Str;
template<typename T> struct Arr;
template<typename T> struct Ref;
template<typename R, typename... As> struct Fun;

template<typename T> struct Array;
template<typename T> struct Reference;
template<typename R, typename... As> struct Function;


template<typename> struct BiCast;

template<typename T1> struct Cast { 
	template<typename T2> struct To { static T2 conv(T1 x); };
	template<typename T2> struct From { static T1 conv(T2 x); };
};

template<typename T> 
struct Arr {
	Arr(): arr() { }
	Arr(std::initializer_list<T> il): arr(std::move(std::make_shared<Array<T>>(il))) { }
	Arr(Ptr<Array<T>>&& a): arr(std::move(a)) { }
	Arr(const Arr& a): arr(a.arr) { }
	Arr(Arr&& a): arr(std::move(a.arr)) { }
	Arr(std::size_t s): arr(std::move(std::make_shared<Array<T>>(s))) { }
	static Arr makeEmpty() { return Arr(std::make_shared<Array<T>>(0)); }

	Array<T>& operator *() { return arr.operator*(); }
	Array<T>* operator ->() { return arr.operator->(); }
	Array<T>* get() { return arr.get(); }
	const Array<T>& operator *() const { return arr.operator*(); }
	const Array<T>* operator ->() const { return arr.operator->(); }
	const Array<T>* get() const { return arr.get(); }

	Arr& operator = (Arr&& a) { arr = std::move(a.arr); return *this; }
	Arr& operator = (const Arr& a) { arr = a.arr; return *this; }
	bool isSameObj(Arr a) const { return arr.get() == a.arr.get(); }

	Ptr<Array<T>> arr;
};

template<typename T> 
struct Ref {
	Ref() { }
	Ref(const T& r): ref(std::make_shared<Reference<T>>(r)) { }
	Ref(const Ref& r): ref(r.ref) { }
	Ref(Ptr<Reference<T>>&& r): ref(std::move(r)) { }
	Ref(Ref&& r): ref(std::move(r.ref)) { }

	Reference<T>& operator *() { return ref.operator*(); }
	Reference<T>* operator ->() { return ref.operator->(); }
	Reference<T>* get() { return ref.get(); }
	const Reference<T>& operator *() const { return ref.operator*(); }
	const Reference<T>* operator ->() const { return ref.operator->(); }
	const Reference<T>* get() const { return ref.get(); }

	Ref& operator = (Ref&& r) { ref = std::move(r.ref); return *this; }
	Ref& operator = (const Ref& r) { ref = r.ref; return *this; }

	bool isSameObj(Ref r) const { return ref.get() == r.ref.get(); }

	Ptr<Reference<T>> ref;
};

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

	Ptr<T> str;
};

template<typename R, typename... As> 
struct Fun {
	typedef std::function<R(As...)> Fn;
	Fun() {}
	Fun(const Fn& f): fn(std::make_shared<Function<R, As...>>(f)) { }
	Fun(Fn&& f): fn(std::make_shared<Function<R, As...>>(f)) { }
	Fun(Ptr<Function<R, As...>>&& f): fn(std::move(f)) { }
	Fun(const Ptr<Function<R, As...>>& f): fn(f) { }
	Fun(const Fun& f): fn(f.fn) { }
	Fun(Fun&& f): fn(std::move(f.fn)) { }

	Function<R, As...>& operator *() { return fn.operator*(); }
	Function<R, As...>* operator ->() { return fn.operator->(); }
	Function<R, As...>* get() { return fn.get(); }
	const Function<R, As...>& operator *() const { return fn.operator*(); }
	const Function<R, As...>* operator ->() const { return fn.operator->(); }
	const Function<R, As...>* get() const { return fn.get(); }

	Fun& operator = (Fun&& f) { fn = std::move(f.fn); return *this; }
	Fun& operator = (const Fun& f) { fn = f.fn; return *this; }
	R operator()(As... as) const { return fn->operator()(as...); }
	Int compare(Fun f) const { return Compare<void*>::cmp(fn.get(), f.fn.get()); }
	bool isSameObj(Fun f) const { return fn.get() == f.fn.get(); }

	Ptr<Function<R, As...>> fn;
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

	Ptr<AStruct> un;
};

struct Flow {
	typedef std::variant<
		Int, Bool, Double, String,
		Ptr<AStruct>, Ptr<AArray>, Ptr<AReference>, Ptr<AFunction>, 
		Ptr<Void>
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
	Flow(Ptr<Void> n): val(n) { }
	Flow(const Union& u): val(u.un) { }
	Flow(Union&& u): val(std::move(u.un)) { }
	template<typename T> Flow(Str<T> s);
	template<typename T> Flow(Ref<T> r);
	template<typename T> Flow(Arr<T> a);
	template<typename R, typename... As> Flow(Fun<R, As...> f);
	template<typename T> Flow(Ptr<T> n): val(std::static_pointer_cast<Void>(n)) { }

	Variant val;

	Int toInt() const {
		try { 
			return std::get<Int>(val); 
		} catch (std::bad_variant_access& err) {
			std::cerr << "failed to get Int (" << Type::INT << "), in fact: " << type2s(val.index()) << std::endl;
			throw err;
		}
	}
	Bool toBool() const { 
		try {
			return std::get<Bool>(val); 
		} catch (std::bad_variant_access& err) {
			std::cerr << "failed to get Bool(" << Type::BOOL << "), in fact: " << type2s(val.index()) << std::endl;
			throw err;
		}
	}
	Double toDouble() const { 
		try {
			return std::get<Double>(val); 
		} catch (std::bad_variant_access& err) {
			std::cerr << "failed to get Double(" << Type::DOUBLE << "), index: " << type2s(val.index()) << std::endl;
			throw err;
		}
	}
	String toString() const { 
		try {
			return std::get<String>(val); 
		} catch (std::bad_variant_access& err) {
			std::cerr << "failed to get String(" << Type::STRING << ") , index: " << type2s(val.index()) << std::endl;
			throw err;
		}
	}
	Ptr<AStruct> toStruct() const { 
		try {
			return std::get<Ptr<AStruct>>(val); 
		} catch (std::bad_variant_access& err) {
			std::cerr << "failed to get Struct(" << Type::STRUCT << ") , index: " << type2s(val.index()) << std::endl;
			throw err;
		}
	}
	Ptr<AArray> toArray() const { 
		try {
			return std::get<Ptr<AArray>>(val); 
		} catch (std::bad_variant_access& err) {
			std::cerr << "failed to get Array(" << Type::ARRAY << ") , index: " << type2s(val.index()) << std::endl;
			throw err;
		}
	}
	Ptr<AReference> toReference() const { 
		try {
			return std::get<Ptr<AReference>>(val); 
		} catch (std::bad_variant_access& err) {
			std::cerr << "failed to get Reference(" << Type::REF << ") , index: " << type2s(val.index()) << std::endl;
			throw err;
		}
	}
	Ptr<AFunction> toFunction() const { 
		try{
			return std::get<Ptr<AFunction>>(val); 
		} catch (std::bad_variant_access& err) {
			std::cerr << "failed to get Function(" << Type::FUNC << ") , index: " << type2s(val.index()) << std::endl;
			throw err;
		}
	}
	template<typename T>
	Ptr<T> toNative() const { 
		try{
			return std::reinterpret_pointer_cast<T>(std::get<Ptr<Void>>(val)); 
		} catch (std::bad_variant_access& err) {
			std::cerr << "failed to get Native(" << Type::NATIVE << ") , index: " <<type2s(val.index()) << std::endl;
			throw err;
		}
	}

	Type type() const;
	bool isSameObj(Flow f) const;
};

inline String flow2string(Flow f) { String os = makeString(); flow2string(f, os); return os; }
struct AStruct {
	virtual Int id() const = 0;
	virtual String name() const = 0;
	virtual Int size() const = 0;
	virtual Arr<Flow> fields() const = 0;
	virtual Flow field(String name) const = 0;
	virtual void setField(String name, Flow val) const = 0;
	virtual Int compare(const AStruct&) const = 0;
};

struct AArray {
	virtual Int size() const = 0;
	virtual Arr<Flow> elements() const = 0;
	virtual Flow element(Int i) const = 0;
};

struct AReference {
	virtual Flow reference() const = 0;
	virtual void set(Flow) const = 0;
};

struct AFunction {
	virtual Int arity() const = 0;
	virtual Flow call(Flow args...) const = 0;
};

template<typename T>
Str<T>::Str(const Union& u) { 
	if (u->id() == T::ID) {
		str = std::dynamic_pointer_cast<T>(u.un);
	}
}

template<typename T> 
struct Array : public AArray {
	typedef std::vector<T> Vect;
	typedef typename Vect::const_iterator const_iterator;
	typedef typename Vect::iterator iterator;

	Array(): vect() { }
	Array(std::size_t s): vect() { vect.reserve(s); }
	Array(std::initializer_list<T> il): vect(il) { }
	Array(const Array& a): vect(a.vect) { }
	Array(const Vect& v): vect(v) { }
	Array(Vect&& v): vect(std::move(v)) { }
	virtual ~Array() {}
	Ptr<Array> copy() { return std::make_shared<Array>(vect); }

	Array& operator = (const Array& a) { vect.operator=(a.vect); return *this; }
	Array& operator = (Array&& a) { vect.operator=(std::move(a.vect)); return *this; }

	Int size() const override { return static_cast<Int>(vect.size()); }
	Arr<Flow> elements() const override;
	Flow element(Int i) const override;
	Int compare(Array a) const;

	const_iterator begin() const { return vect.begin(); }
	const_iterator end() const { return vect.end(); }
	iterator begin() { return vect.begin(); }
	iterator end(){ return vect.end(); }
	void push_back(T x) { vect.push_back(x); }

	template<typename T1> Arr<T1> cast() const;

	Vect vect;
};

template<typename T> 
struct Reference : public AReference {
	Reference() { }
	Reference(const T& r): val(std::make_shared<T>(r)) { }
	Reference(T&& r): val(std::move(r)) { }
	Reference(const Reference& r): val(r.val) { }
	Reference(Reference&& r): val(std::move(r.val)) { }
	Reference& operator = (Reference&& r) { val = std::move(r.val); return *this; }
	Reference& operator = (const Reference& r) { val = r.val; return *this; }
	Flow reference() const override { return Cast<T>::template To<Flow>::conv(*val); }
	void set(Flow r) const override { *val = Cast<Flow>::template To<T>::conv(r); }
	Int compare(Reference r) const { return Compare<T>::cmp(*val, *r.val); }

	template<typename T1> Ref<T1> cast() const;

	mutable Ptr<T> val;
};

template<typename R, typename... As> 
struct Function : public AFunction {
	typedef std::function<R(As...)> Fn;
	enum { ARITY = sizeof...(As) };
	Function() {}
	Function(Fn&& f): fn(std::move(f)) { }
	Function(const Fn& f): fn(f) { }
	Function(const Function& f): fn(f.fn) { }
	Function(Function&& f): fn(std::move(f.fn)) { }
	R operator()(As... as) const { return call(as...); }
	virtual R call(As... as) const { return fn.operator()(as...); }
	Int arity() const override { return ARITY; }
	Flow call(Flow as...) const override {
		if constexpr (std::is_same_v<R, Void>) {
			fn.operator()(Cast<Flow>::template To<As>::conv(as)...);
			return Flow();
		} else {
			return Cast<R>::template To<Flow>::conv(fn.operator()(Cast<Flow>::template To<As>::conv(as)...));
		}
	}
	template<typename R1, typename... As1> 
	Fun<R1, As1...> cast() const {
		if constexpr (std::is_same_v<R, R1> && std::conjunction_v<std::is_same<As, As1>...>) {
			return Fun(fn);
		} else if constexpr (std::is_same_v<R, Void>) {
			std::function<R1(As1...)> ret = [this](As1... as) { 
				fn.operator()(Cast<As1>::template To<As>::conv(as)...);
				return R1();
			};
			return Fun<R1, As1...>(ret);
		} else if constexpr (std::is_same_v<R1, Void>) {
			std::function<R1(As1...)> ret = [this](As1... as) { 
				fn.operator()(Cast<As1>::template To<As>::conv(as)...);
			};
			return Fun<R1, As1...>(ret);
		} else {
			std::function<R1(As1...)> ret = [this](As1... as) { 
				return Cast<R>::template To<R1>::conv(fn.operator()(Cast<As1>::template To<As>::conv(as)...)); 
			};
			return Fun<R1, As1...>(ret);
		}
	}

	Fn fn;
};


template<typename T> Flow::Flow(Str<T> s): val(std::static_pointer_cast<AStruct>(s.str)) { }
template<typename T> Flow::Flow(Ref<T> r): val(std::static_pointer_cast<AReference>(r.ref)) { }
template<typename T> Flow::Flow(Arr<T> a): val(std::static_pointer_cast<AArray>(a.arr)) { }
template<typename R, typename... As> Flow::Flow(Fun<R, As...> f): val(std::static_pointer_cast<AFunction>(std::make_shared<Fun<R, As...>>(f))) { }

template<> struct BiCast<Int> {
	template<typename> struct From { static constexpr bool is_available() { return false; } }; 
	template<typename> struct To { static constexpr bool is_available() { return false; } }; 
};
template<> struct BiCast<Bool> {
	template<typename> struct From { static constexpr bool is_available() { return false; } }; 
	template<typename> struct To { static constexpr bool is_available() { return false; } }; 
};
template<> struct BiCast<Double> {
	template<typename> struct From { static constexpr bool is_available() { return false; } }; 
	template<typename> struct To { static constexpr bool is_available() { return false; } }; 
};
template<> struct BiCast<String> {
	template<typename> struct From { static constexpr bool is_available() { return false; } }; 
	template<typename> struct To { static constexpr bool is_available() { return false; } }; 
};
template<> struct BiCast<Flow> {
	template<typename> struct From { static constexpr bool is_available() { return false; } }; 
	template<typename> struct To { static constexpr bool is_available() { return false; } }; 
};
template<> struct BiCast<Union> {
	template<typename> struct From { static constexpr bool is_available() { return false; } }; 
	template<typename> struct To { static constexpr bool is_available() { return false; } }; 
};
template<typename T> struct BiCast<Str<T>> { 
	template<typename> struct From { static constexpr bool is_available() { return false; } }; 
	template<typename> struct To { static constexpr bool is_available() { return false; } }; 
};
template<typename T> struct BiCast<Arr<T>> { 
	template<typename> struct From { static constexpr bool is_available() { return false; } }; 
	template<typename> struct To { static constexpr bool is_available() { return false; } }; 
};
template<typename T> struct BiCast<Ref<T>> { 
	template<typename> struct From { static constexpr bool is_available() { return false; } }; 
	template<typename> struct To { static constexpr bool is_available() { return false; } }; 
};
template<typename R, typename... As> struct BiCast<Fun<R, As...>> { 
	template<typename> struct From { static constexpr bool is_available() { return false; } };
	template<typename> struct To { static constexpr bool is_available() { return false; } };
};

// BiCast<Int>

template<> struct BiCast<Int>::From<Int> { static Int conv(Int x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Int>::To<Int> { static Int conv(Int x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Int>::From<Bool> { static Int conv(Bool x) { return x ? 1 : 0; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Int>::To<Bool> { static Bool conv(Int x) { return x == 0 ? false : true; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Int>::To<Double> { static Double conv(Int x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Int>::From<Double> { static Int conv(Double x) { return double2int(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Int>::To<String> { static String conv(Int x) { return int2string(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Int>::From<String> { static Int conv(String x) { return string2int(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Int>::To<Flow> { static Flow conv(Int x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Int>::From<Flow> { static Int conv(Flow x) { 
	switch (x.type()) {
		case Type::INT:    return x.toInt();
		case Type::BOOL:   return x.toBool() ? 1 : 0;
		case Type::DOUBLE: return double2int(x.toDouble());
		case Type::STRING: return string2int(x.toString());
		default:           return 0;
	}
} static constexpr bool is_available() { return true; } };

// BiCast<Bool>

template<> struct BiCast<Bool>::To<Int> { static Int conv(Bool x) { return x ? 1 : 0; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Bool>::From<Int> { static Bool conv(Int x) { return x == 0 ? false : true; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Bool>::To<Bool> { static Bool conv(Bool x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Bool>::From<Bool> { static Bool conv(Bool x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Bool>::To<Double> { static Double conv(Bool x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Bool>::From<Double> { static Bool conv(Double x) { return x == 0.0 ? false : true; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Bool>::To<String> { static String conv(Bool x) { return bool2string(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Bool>::From<String> { static Bool conv(String x) { return *x == *string_true; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Bool>::To<Flow> { static Flow conv(Bool x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Bool>::From<Flow> { static Bool conv(Flow f) { 
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
} static constexpr bool is_available() { return true; } };

// BiCast<Double>

template<> struct BiCast<Double>::To<Int> { static Int conv(Double x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Double>::From<Int> { static Double conv(Int x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Double>::To<Bool> { static Bool conv(Double x) { return x != 0.0; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Double>::From<Bool> { static Bool conv(Double x) { return x ? 1.0 : 0.0; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Double>::To<Double> { static Double conv(Double x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Double>::From<Double> { static Double conv(Double x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Double>::To<String> { static String conv(Double x) { return double2string(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Double>::From<String> { static Double conv(String x) { return string2double(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Double>::To<Flow> { static Flow conv(Double x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Double>::From<Flow> { static Double conv(Flow f) { 
	switch (f.type()) {
		case Type::INT:    return f.toInt();
		case Type::BOOL:   return f.toBool() ? 1.0 : 0.0;
		case Type::DOUBLE: return f.toDouble();
		case Type::STRING: return string2double(f.toString());
		default:           return 0.0;
	}
} static constexpr bool is_available() { return true; } };

// BiCast<String>

template<> struct BiCast<String>::To<Int> { static Int conv(String x) { return string2int(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::From<Int> { static String conv(Int x) { return int2string(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::To<Bool> { static Bool conv(String x) { return *x == *string_true || *x == *string_1; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::From<Bool> { static String conv(Bool x) { return x ? string_true : string_false; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::To<Double> { static Double conv(String x) { return string2double(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::From<Double> { static String conv(Double x) { return double2string(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::To<String> { static String conv(String x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::From<String> { static String conv(String x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::To<Flow> { static Flow conv(String x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::From<Flow> { static String conv(Flow x) { if (x.type() == Type::STRING) return x.toString(); else return flow2string(x); } static constexpr bool is_available() { return true; } };

// BiCast<Flow>

template<> struct BiCast<Flow>::To<Int> { static Int conv(Flow x) { 
	switch (x.type()) {
		case Type::INT:    return x.toInt();
		case Type::BOOL:   return x.toBool() ? 1 : 0;
		case Type::DOUBLE: return double2int(x.toDouble());
		case Type::STRING: return string2int(x.toString());
		default:           return 0;
	}
} static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<Int> { static Flow conv(Int x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::To<Bool> { static Bool conv(Flow f) { 
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
} static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<Bool> { static Flow conv(Bool x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::To<Double> { static Double conv(Flow f) { 
	switch (f.type()) {
		case Type::INT:    return f.toInt();
		case Type::BOOL:   return f.toBool() ? 1.0 : 0.0;
		case Type::DOUBLE: return f.toDouble();
		case Type::STRING: return string2double(f.toString());
		default:           return 0.0;
	}
} static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<Double> { static Flow conv(Double d) { return d; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::To<String> { static String conv(Flow x) { if (x.type() == Type::STRING) return x.toString(); else return flow2string(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<String> { static Flow conv(String x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::To<Flow> { static Flow conv(Flow x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<Flow> { static Flow conv(Flow x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::To<Union> { static Union conv(Flow x) { return x.toStruct(); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<Union> { static Flow conv(Union x) { return x.un; } static constexpr bool is_available() { return true; } };

template<> template<typename R, typename... As> struct BiCast<Flow>::To<Fun<R, As...>> {
	static constexpr bool is_available() { return true; }
	static Fun<R, As...> conv(Flow x) { 
		Fun<R, As...> r = std::dynamic_pointer_cast<Function<R, As...>>(x.toFunction());
		if (r.get() != nullptr) {
			return r;
		} else {
			return r->template cast<R, As...>();
		}
	} 
};
template<> template<typename R, typename... As> struct BiCast<Flow>::From<Fun<R, As...>> {
	static constexpr bool is_available() { return true; }
	static Flow conv(Fun<R, As...> x) { return std::static_pointer_cast<AFunction>(x.fn); } 
};

template<> template<typename T> struct BiCast<Flow>::To<Str<T>> {
	static constexpr bool is_available() { return true; }
	static Str<T> conv(Flow x) { 
		Str<T> r = std::dynamic_pointer_cast<T>(x.toStruct());
		if (r.get() != nullptr) {
			return r;
		} else {
			if constexpr (T::SIZE == 0) {
				return std::make_shared<T>();
			} else {
				return std::make_shared<T>(x.toStruct());
			}
		}
	} 
};
template<> template<typename T> struct BiCast<Flow>::From<Str<T>> {
	static constexpr bool is_available() { return true; }
	static Flow conv(Str<T> x) { return std::static_pointer_cast<AStruct>(x.str); } 
};

template<> template<typename T> struct BiCast<Flow>::To<Arr<T>> {
	static constexpr bool is_available() { return true; }
	static Arr<T> conv(Flow x) { 
		Arr<T> r = std::dynamic_pointer_cast<Array<T>>(x.toArray());
		if (r.get() != nullptr) {
			return r;
		} else {
			Arr<Flow> elems = x.toArray()->elements();
			Arr<T> ret(elems->size());
			for (Flow x : elems->vect) {
				ret->vect.push_back(Cast<Flow>::template To<T>::conv(x));
			}
			return ret;
		}
	} 
};
template<> template<typename T> struct BiCast<Flow>::From<Arr<T>> {
	static constexpr bool is_available() { return true; }
	static Flow conv(Arr<T> x) { return std::static_pointer_cast<AArray>(x.arr); } 
};

template<> template<typename T> struct BiCast<Flow>::To<Ref<T>> {
	static constexpr bool is_available() { return true; }
	static Ref<T> conv(Flow x) { 
		Ref<T> r = std::dynamic_pointer_cast<Reference<T>>(x.toReference());
		if (r.get() != nullptr) {
			return r;
		} else {
			return Ref<T>(Cast<Flow>::template To<T>::conv(x.toReference()->reference()));
		}
	} 
};
template<> template<typename T> struct BiCast<Flow>::From<Ref<T>> {
	static constexpr bool is_available() { return true; }
	static Flow conv(Ref<T> x) { return std::static_pointer_cast<AReference>(x.ref); } 
};

// BiCast<Union>

template<> template<typename T> struct BiCast<Union>::To<Str<T>> {
	static constexpr bool is_available() { return true; }
	static Str<T> conv(Union x) { 
		Str<T> r = std::dynamic_pointer_cast<T>(x.un);
		if (r.get() != nullptr) {
			return r;
		} else {
			return std::make_shared<T>(x.un);
		}
	} 
};
template<> template<typename T> struct BiCast<Union>::From<Str<T>> {
	static constexpr bool is_available() { return true; }
	static Union conv(Str<T> x) { return std::static_pointer_cast<AStruct>(x.str); } 
	
};

// BiCast<Str<T>>

template<typename T> template<typename T1> struct BiCast<Str<T>>::To<Str<T1>> {
	static constexpr bool is_available() { return true; }
	static Str<T1> conv(Str<T> x) { 
		if constexpr (std::is_same_v<T, T1>) {
			return x;
		} else {
			return x->template cast<T1>(); 
		}
	} 
};
template<typename T> template<typename T1> struct BiCast<Str<T>>::From<Str<T1>> {
	static constexpr bool is_available() { return true; }
	static Str<T> conv(Str<T1> x) {
		if constexpr (std::is_same_v<T, T1>) {
			return x;
		} else {
			return x->template cast<T>();
		}
	} 
};


// BiCast<Arr<T>>

template<typename T> template<typename T1> struct BiCast<Arr<T>>::To<Arr<T1>> {
	static constexpr bool is_available() { return true; }
	static Arr<T1> conv(Arr<T> x) {
		if constexpr (std::is_same_v<T, T1>) {
			return x;
		} else {
			return x->template cast<T1>();
		}
	} 
};
template<typename T> template<typename T1> struct BiCast<Arr<T>>::From<Arr<T1>> {
	static constexpr bool is_available() { return true; }
	static Arr<T> conv(Arr<T1> x) {
		if constexpr (std::is_same_v<T, T1>) {
			return x;
		} else {
			return x->template cast<T>();
		}
	} 
};


// BiCast<Ref<T>>

template<typename T> template<typename T1> struct BiCast<Ref<T>>::To<Ref<T1>> {
	static constexpr bool is_available() { return true; }
	static Ref<T1> conv(Ref<T> x) {
		if constexpr (std::is_same_v<T, T1>) {
			return x;
		} else {
			return Ref<T1>(Cast<T>::template To<T1>::conv(*x.ref->val));
		}
	} 
};
template<typename T> template<typename T1> struct BiCast<Ref<T>>::From<Ref<T1>> {
	static constexpr bool is_available() { return true; }
	static Ref<T> conv(Ref<T1> x) {
		if constexpr (std::is_same_v<T, T1>) {
			return x;
		} else {
			return Ref<T>(Cast<T1>::template To<T>::conv(*x.ref->val));
		}
	} 
};

// BiCast<Fun<R, As...>>

template<typename R, typename... As> 
template<typename R1, typename... As1> 
struct BiCast<Fun<R, As...>>::To<Fun<R1, As1...>> {
	static constexpr bool is_available() { return true; }
	static Fun<R1, As1...> conv(Fun<R, As...> x) { 
		if constexpr (std::is_same_v<R, R1> && std::conjunction_v<std::is_same<As, As1>...>) {
			return x;
		} else {
			return x->template cast<R1, As1...>(); 
		}
	} 
};
template<typename R, typename... As> 
template<typename R1, typename... As1> 
struct BiCast<Fun<R, As...>>::From<Fun<R1, As1...>> {
	static constexpr bool is_available() { return true; }
	static Fun<R, As...> conv(Fun<R1, As1...> x) { 
		if constexpr (std::is_same_v<R, R1> && std::conjunction_v<std::is_same<As, As1>...>) {
			return x;
		} else {
			return x->template cast<R, As...>(); 
		}
	} 
};

template<typename T1> 
template<typename T2> 
T2 Cast<T1>::To<T2>::conv(T1 x) {
	if constexpr (std::is_same_v<T1, T2>) {
		return x;
	} else if constexpr (BiCast<T1>::template To<T2>::is_available()) {
		typedef typename BiCast<T1>::template To<T2> Conv;
		return Conv::conv(x);
	} else {
		typedef typename BiCast<T2>::template From<T1> Conv;
		return Conv::conv(x);
	}
}

template<typename T1> 
template<typename T2> 
T1 Cast<T1>::From<T2>::conv(T2 x) {
	if constexpr (std::is_same_v<T1, T2>) {
		return x;
	} else if constexpr (BiCast<T1>::template To<T2>::is_available()) {
		typedef typename BiCast<T1>::template From<T2> Conv;
		return Conv::conv(x);
	} else {
		typedef typename BiCast<T2>::template To<T1> Conv;
		return Conv::conv(x);
	}
}

template<typename T>
Arr<Flow> Array<T>::elements() const {
	Arr<Flow> ret(vect.size());
	for (T x : vect) {
		ret->vect.push_back(Cast<T>::template To<Flow>::conv(x));
	}
	return ret;
}
template<typename T>
Flow Array<T>::element(Int i) const {
	if constexpr (std::is_same_v<T, Flow>) {
		return vect.at(i);
	} else {
		return Cast<T>::template To<Flow>::conv(vect.at(i));
	}
}
template<typename T>
Int Array<T>::compare(Array a) const { 
	Int c1 = Compare<Int>::cmp(vect.size(), a.vect.size());
	if (c1 != 0) {
		return c1;
	} else {
		for (std::size_t i = 0; i < vect.size(); ++ i) {
			Int c2 = Compare<T>::cmp(vect.at(i), a.vect.at(i));
			if (c2 != 0) {
				return c2;
			}
		}
		return 0;
	}
}

template<typename T>
template<typename T1>
Arr<T1> Array<T>::cast() const {
	if constexpr (std::is_same_v<T, T1>) {
        return Arr<T1>(this);
    } else {
		Arr<T1> ret = Arr<T1>(vect.size());
		for (T x : vect) {
			ret->vect.push_back(Cast<T>::template To<T1>::conv(x));
		}
		return ret;
	}
}

Int compareFlow(Flow v1, Flow v2);

template<> struct Compare<Flow> {
	static Int cmp(Flow v1, Flow v2) { return compareFlow(v1, v2); }
};

template<> struct Compare<Union> {
	static Int cmp(Union v1, Union v2) { return v1.un->compare(*v2.un); }
};
template<typename T>
struct Compare<Arr<T>> {
	static Int cmp(Arr<T> v1, Arr<T> v2) { return v1->compare(*v2); }
};

template<typename T>
struct Compare<Ref<T>> {
	static Int cmp(Ref<T> v1, Ref<T> v2) { return v1->compare(*v2); }
};

template<typename T>
struct Compare<Str<T>> {
	static Int cmp(Str<T> v1, Str<T> v2) { 
		if (v1.get() == nullptr) return -1; else
		if (v2.get() == nullptr) return 1; else
		return v1->compare(*v2); 
	}
};

template<typename R, typename... As>
struct Compare<Fun<R, As...>> {
	static Int cmp(Fun<R, As...> v1, Fun<R, As...> v2) { return Compare<void*>::cmp(v1.fn.get(), v2.fn.get()); }
};

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

}
