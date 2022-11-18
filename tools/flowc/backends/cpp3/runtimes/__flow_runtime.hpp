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
#include <map>
#include <mutex>
#include <atomic>
#include <thread>
#endif

// C++ runtime for flow

namespace flow {

// Reference counting pointer. Essential for memory managing.
template<typename T>
struct Ptr {
	Ptr(): ptr(nullptr) { }
	Ptr(const T* p): ptr(p) { inc(); }
	~Ptr() { dec(); }
	Ptr(Ptr&& p): ptr(p.ptr) { p.ptr = nullptr; }
	Ptr(const Ptr& p): ptr(p.ptr) { inc(); }
	template<typename T1>
	Ptr(Ptr<T1>&& p): ptr(static_cast<const T*>(p.ptr)) { p.ptr = nullptr; }
	template<typename T1>
	Ptr(const Ptr<T1>& p): ptr(static_cast<const T*>(p.ptr)) { inc(); }

	template<typename T1>
	Ptr& operator = (const T1* p1) { dec(); ptr = static_cast<const T*>(p1); inc(); return *this; }
	template<typename T1>
	Ptr& operator = (Ptr<T1> p1) { dec(); ptr = static_cast<const T*>(p1.ptr); inc(); return *this; }

	Ptr& operator = (Ptr&& p) { dec(); ptr = p.ptr; p.ptr = nullptr; return *this; }
	Ptr& operator = (const Ptr& p) { dec(); ptr = p.ptr; inc(); return *this; }

	const T& operator *() { return *ptr; }
	const T* operator ->() { return ptr; }
	const T* get() { return ptr; }
	const T& operator *() const { return *ptr; }
	const T* operator ->() const { return ptr; }
	const T* get() const { return ptr; }
	operator bool() const { return ptr; }
	bool isSameObj(const Ptr& p) const { return ptr == p.ptr; }

	template<typename... As>
	static Ptr<T> make(As... as) { return new T(std::move(as)...); }
	template<typename T1>
	static Ptr<T> make(std::initializer_list<T1> il) { return new T(std::move(il)); }
	template<typename T1> Ptr<T1> statCast() const { return Ptr<T1>(static_cast<const T1*>(ptr)); }
	template<typename T1> Ptr<T1> dynCast() const { return Ptr<T1>(dynamic_cast<const T1*>(ptr)); }
	template<typename T1> Ptr<T1> reintCast() const { return Ptr<T1>(reinterpret_cast<const T1*>(ptr)); }

	void inc() const { ptr->incRefs(); }
	void dec() const { if (ptr) ptr->decRefs(); }

	const T* ptr;
};

enum Type {
	INT = 0,   BOOL = 1, DOUBLE = 2, STRING = 3, NATIVE = 4, // scalar types
	ARRAY = 5, REF = 6,  FUNC = 7,   STRUCT = 8,             // complex types
	UNKNOWN = -1
};

using Void = void;

// Scalar types
using Int = int32_t;
using Bool = bool;
using Double = double;
using string = std::u16string;

const char* type2s(Int type);

// String conversions

std::string string2std(const string& str);
string std2string(const std::string& s);

// Basic scalar type conversions

inline Double int2double(Int x) { return x; }
inline Bool int2bool(Int x) { return x != 0; }
inline string int2string(Int x) { return std2string(std::to_string(x)); }

inline Int double2int(Double x) { return (x >= 0.0) ? static_cast<Int>(x + 0.5) : static_cast<Int>(x - 0.5); }
inline Bool double2bool(Double x) { return x != 0.0; }
string double2string(Double x);

inline Int bool2int(Bool x) { return x ? 1 : 0; }
inline Double bool2double(Bool x) { return x ? 1.0 : 0.0; }
inline string bool2string(Bool x) { return x ? u"true" : u"false"; }

inline Int string2int(const string& s) { if (s.size() == 0) { return 0; } else { try { return std::stoi(string2std(s)); } catch (std::exception& e) { return 0; } } }
inline Double string2double(const string& s) { if (s.size() == 0) { return 0.0; } else { try { return std::stod(string2std(s)); } catch (std::exception& e) { return 0.0; } } }	
inline Bool string2bool(const string& s) { return s != u"false"; }

// Base class for object classes, 
// at the same time general dynamic type, which may be any other

struct AFlow;
using Flow = Ptr<AFlow>;

// Flow wrappers to scalar types

struct FInt;
struct FBool;
struct FDouble;

// Non-polymorphic non-scalar types

struct VString;
struct VNative;

using String = Ptr<VString>;
using Native = Ptr<VNative>;

// Abstract compound types

struct AStr;
struct AVec;
struct ARef;
struct AFun;

using PStr = Ptr<AStr>;
using PVec = Ptr<AVec>;
using PRef = Ptr<ARef>;
using PFun = Ptr<AFun>;

using Union = PStr;

// Specific polymiphic types for particular type parameters

template<typename T> struct Vector;
template<typename T> struct Reference;
template<typename R, typename... As> struct Function;

// Reference-counting Pointers to compound types. Are passed all-around as variables/values.

template<typename T> using Str = Ptr<T>;
template<typename T> using Vec = Ptr<Vector<T>>;
template<typename T> using Ref = Ptr<Reference<T>>;
template<typename R, typename... As> using Fun = Ptr<Function<R, As...>>;

struct AFlow {
	enum { TYPE = Type::UNKNOWN };
	AFlow(): refs(0) { }
	AFlow(const AFlow& f) = delete;
	virtual ~AFlow() { }
	virtual Int type() const = 0;

	// Direct getters - don't do any conversion
	Int getInt() const;
	Bool getBool() const;
	Double getDouble() const;
	String getString() const;
	Native getNative() const;
	PStr getAStr() const;
	PVec getAVec() const;
	PRef getARef() const;
	PFun getAFun() const;

	// Indirect getters - may perform conversions
	Int toInt() const;
	Bool toBool() const;
	Double toDouble() const;
	String toString() const;
	Native toNative() const;
	PStr toAStr() const;
	PVec toAVec() const;
	PRef toARef() const;
	PFun toAFun() const;

	template<typename T> Str<T> toStr() const;
	template<typename T> Vec<T> toVec() const;
	template<typename T> Ref<T> toRef() const;
	template<typename R, typename... As> Fun<R, As...> toFun() const;

	bool isSameObj(Flow f) const;

	void incRefs() const { ++ refs; }
	bool decRefs() const { -- refs; if (refs == 0) { delete this; return true; } else { return false; } }

	mutable std::size_t refs;
};

struct FInt : public AFlow {
	enum { TYPE = Type::INT };
	FInt(Int v): val(v) { }
	Int type() const override { return Type::INT; }
	const Int val;
};
struct FBool : public AFlow {
	enum { TYPE = Type::BOOL };
	FBool(Bool v): val(v) { }
	Int type() const override { return Type::BOOL; }
	const Bool val;
}; 
struct FDouble : public AFlow {
	enum { TYPE = Type::DOUBLE };
	FDouble(Double v): val(v) { }
	Int type() const override { return Type::DOUBLE; }
	const Double val;
};

struct VString : public AFlow {
	enum { TYPE = Type::STRING };
	VString(): str() { }
	VString(const std::string& s): str(std2string(s)) { }
	VString(const string& s): str(s) { }
	VString(string&& s): str(std::move(s)) { }
	VString(const char16_t* s): str(s) { }
	VString(const char16_t* s, Int len): str(s, len) { }
	VString(char16_t c): str(1, c) { }
	VString(const std::vector<char16_t>& codes): str(codes.data(), codes.size()) { }
	VString(const VString& s): str(s.str) { }
	VString(Ptr<VString> s): str(s->str) { }
	Int type() const override { return Type::STRING; }
	std::string toStd() const { return string2std(str); }

	string str;
};

inline String concatStrings(String s1, String s2) {
	string ret;
	ret.reserve(s1->str.size() + s2->str.size());
	ret += s1->str;
	ret += s2->str;
	return String::make(ret);
}

struct VNative : public AFlow {
	enum { TYPE = Type::NATIVE };
	VNative(void* n, std::function<void(void*)> r): nat(n), release(r) { }
	~VNative() override { release(nat); }
	Int type() const override { return Type::NATIVE; }
	template<typename T> T* cast() const { return reinterpret_cast<T*>(nat); }

	mutable void* nat;
	std::function<void(void*)> release;
};

struct AStr : public AFlow {
	// Type is specified in ancestor classes
	virtual String name() const = 0;
	virtual Int size() const = 0;
	// Get field by index
	virtual Flow getFlowField(Int i) const = 0;
	// Get field bu name
	virtual Flow getFlowField(String name) const = 0;
	// Mutable fields ! therefore const qualifier is kept.
	virtual void setFlowField(Int i, Flow val) const = 0;
	virtual void setFlowField(String name, Flow val) const = 0;
};

struct AVec : public AFlow {
	enum { TYPE = Type::ARRAY };
	Int type() const override { return Type::ARRAY; }
	virtual Int size() const = 0;
	virtual Flow getFlowItem(Int i) const = 0;
	virtual void setFlowItem(Int i, Flow val) = 0;
};

struct ARef : public AFlow {
	enum { TYPE = Type::REF };
	Int type() const override { return Type::REF; }
	virtual Flow getFlowRef() const = 0;
	// Reference is mutable by design, therefore const qualifier is kept.
	virtual void setFlowRef(Flow r) const = 0;
};

struct AFun : public AFlow {
	enum { TYPE = Type::FUNC };
	Int type() const override { return Type::FUNC; }
	virtual Int arity() const = 0;
	// Special case of zero-ary function is added because c varargs don't admit zero arg
	virtual Flow callFlowArgs() const = 0;
	virtual Flow callFlowArgs(Flow args...) const = 0;
};

void flow2string(Flow v, string& os);
inline String flow2string(Flow f) { string os; flow2string(f, os); return String::make(os); }

inline Int AFlow::getInt() const { return static_cast<const FInt*>(this)->val; }
inline Bool AFlow::getBool() const { return static_cast<const FBool*>(this)->val; }
inline Double AFlow::getDouble() const { return static_cast<const FDouble*>(this)->val; }
inline String AFlow::getString() const { return static_cast<const VString*>(this); }
inline Native AFlow::getNative() const { return static_cast<const VNative*>(this); }
inline PStr AFlow::getAStr() const { return static_cast<const AStr*>(this); }
inline PVec AFlow::getAVec() const { return static_cast<const AVec*>(this); }
inline PRef AFlow::getARef() const { return static_cast<const ARef*>(this); }
inline PFun AFlow::getAFun() const { return static_cast<const AFun*>(this); }

inline Int AFlow::toInt() const { 
	switch (type()) {
		case Type::INT:    return getInt();
		case Type::BOOL:   return int2bool(getBool());
		case Type::DOUBLE: return double2int(getDouble());
		case Type::STRING: return string2int(getString()->str);
		default:           return 0;
	}
}
inline Bool AFlow::toBool() const { 
	switch (type()) {
		case Type::INT:    return int2bool(getInt());
		case Type::BOOL:   return getBool();
		case Type::DOUBLE: return double2bool(getDouble());
		case Type::STRING: return string2bool(getString()->str);
		default:           return false;
	}
}
inline Double AFlow::toDouble() const { 
	switch (type()) {
		case Type::INT:    return int2double(getInt());
		case Type::BOOL:   return bool2double(getBool());
		case Type::DOUBLE: return getDouble();
		case Type::STRING: return string2double(getString()->str);
		default:           return 0.0;
	}
}
inline String AFlow::toString() const {
	if (type() == Type::STRING) {
		return getString();
	} else {
		return flow2string(this);
	}
}
inline Native AFlow::toNative() const { return getNative(); }
inline PStr AFlow::toAStr() const { return getAStr(); }
inline PVec AFlow::toAVec() const { return getAVec(); }
inline PRef AFlow::toARef() const { return getARef(); }
inline PFun AFlow::toAFun() const { return getAFun(); }

template<typename T1> struct Cast { 
	template<typename T2> struct To   { static T2 conv(T1 x); };
	template<typename T2> struct From { static T1 conv(T2 x); };
};

template<typename T> struct Compare;
template<typename T> struct Equal { bool operator() (T v1, T v2) const { return Compare<T>::cmp(v1, v2) == 0; } };
template<> struct Compare<Bool> { static Int cmp(Bool v1, Bool v2) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); } };
template<> struct Compare<Int> { static Int cmp(Int v1, Int v2) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); } };
template<> struct Compare<Double> { static Int cmp(Double v1, Double v2) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); } };
template<> struct Compare<void*> { static Int cmp(void* v1, void* v2) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); } };
template<> struct Compare<const void*> { static Int cmp(const void* v1, const void* v2) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); } };
template<> struct Compare<String> { static Int cmp(String v1, String v2) { return v1->str.compare(v2->str); } };
template<> struct Compare<Native> { static Int cmp(Native v1, Native v2) { return Compare<void*>::cmp(v1->nat, v2->nat); } };

template<typename T> 
struct Vector : public AVec {
	typedef std::vector<T> Vect;
	typedef typename Vect::const_iterator const_iterator;
	typedef typename Vect::iterator iterator;

	Vector(): vect() { }
	Vector(std::size_t s): vect() { vect.reserve(s); }
	Vector(std::initializer_list<T> il): vect(il) { }
	Vector(const Vect& v): vect(v) { }
	Vector(Vect&& v): vect(std::move(v)) { }
	Vector(Vector&& a): vect(std::move(a.vect)) { }
	Vector(const Vector& a): vect(a.vect) { }

	Vector& operator = (const Vector& a) { vect.operator=(a.vect); return *this; }
	Vector& operator = (Vector&& a) { vect.operator=(std::move(a.vect)); return *this; }

	// AVec interface
	Int size() const override { return static_cast<Int>(vect.size()); }
	Flow getFlowItem(Int i) const override { return Cast<T>::template To<Flow>::conv(getItem(i)); }
	void setFlowItem(Int i, Flow x) override { setItem(i, Cast<Flow>::template To<T>::conv(x)); }

	// std::vector interface
	const_iterator begin() const { return vect.begin(); }
	const_iterator end() const { return vect.end(); }
	iterator begin() { return vect.begin(); }
	iterator end(){ return vect.end(); }
	void push_back(T x) { vect.push_back(x); }

	// general interface
	T getItem(Int i) const { return vect.at(i); }
	void setItem(Int i, T x) { vect[i] = x; }

	Int compare(Vec<T> a) const;

	Vect vect;
};

template<typename T>
Vec<T> concatVecs(Vec<T> v1, Vec<T> v2) {
	std::vector<T> ret;
	ret.reserve(v1->size() + v2->size());
	for(T x : *v1) ret.push_back(x);
	for(T x : *v2) ret.push_back(x);
	return Vec<T>::make(std::move(ret));
}

template<typename T> 
struct Reference : public ARef {
	Reference() { }
	Reference(T r): val(r) { }
	Reference(const Reference& r): val(r.val) { }
	Reference(Reference&& r): val(std::move(r.val)) { }

	Reference& operator = (Reference&& r) { val = std::move(r.val); return *this; }
	Reference& operator = (const Reference& r) { val = r.val; return *this; }

	// ARef interface
	Flow getFlowRef() const override { return Cast<T>::template To<Flow>::conv(getRef()); }
	void setFlowRef(Flow r) const override { setRef(Cast<Flow>::template To<T>::conv(r)); }

	// T-specific getter/setter
	T getRef() const { return val; }
	void setRef(T v) const { val = v; }

	Int compare(Ref<T> r) const { return Compare<T>::cmp(val, r->val); }

	mutable T val;
};

struct Closure {
	Closure() { }
	Closure(std::initializer_list<Flow> cl): closure(cl) { }
	Closure(const Closure& cl): closure(cl.closure) { }
	Closure(Closure&& cl): closure(std::move(cl.closure)) { } 
	std::vector<Flow> closure;
};

template<typename R, typename... As> 
struct Function : public AFun {
	typedef std::function<R(As...)> Fn;
	enum { ARITY = sizeof...(As) };
	Function() {}
	Function(Fn&& f): fn(std::move(f)) { }
	Function(Fn&& f, Closure&& cl): fn(std::move(f)), closure(std::move(cl)) { }
	Function(const Fn& f): fn(f) { }
	Function(const Fn& f, const Closure& cl): fn(f), closure(cl) { }
	Function(const Function& f): fn(f.fn), closure(fn.closure) { }
	Function(Function&& f): fn(std::move(f.fn)), closure(std::move(fn.closure)) { }

	// AFun interface
	Int arity() const override { return ARITY; }
	Flow callFlowArgs() const override {
		if constexpr (ARITY == 0) {
			if constexpr (std::is_same_v<R, Void>) {
				fn();
				return nullptr;
			} else {
				return Cast<R>::template To<Flow>::conv(fn());
			}
		} else {
			std::cerr << "arity mismatch: actual " << ARITY << " while used as: " << 0 << std::endl;
			exit(1);
			return nullptr;
		}
	}
	Flow callFlowArgs(Flow as...) const override {
		if constexpr (std::is_same_v<R, Void>) {
			fn(Cast<Flow>::template To<As>::conv(as)...);
			return nullptr;
		} else {
			return Cast<R>::template To<Flow>::conv(
				fn(Cast<Flow>::template To<As>::conv(as)...)
			);
		}
	}

	// R, As... direct interface
	R operator()(As... as) const { 
		if constexpr (std::is_same_v<R, Void>) {
			call(as...); 
		} else {
			return call(as...); 
		}
	}
	virtual R call(As... as) const { 
		if constexpr (std::is_same_v<R, Void>) {
			fn(as...); 
		} else {
			return fn(as...); 
		}
	}

	Fn fn;
	Closure closure;
};

template<typename T> Str<T> AFlow::toStr() const { 
	if (const T* t = dynamic_cast<const T*>(this)) {
		return t;
	} else {
		return T::fromAStr(toAStr());
	}
}
template<typename T> Vec<T> AFlow::toVec() const {   
	if (const Vector<T>* t = dynamic_cast<const Vector<T>*>(this)) {
		return t;
	} else {
		PVec a = toAVec();
		std::vector<T> ret;
		ret.reserve(a->size());
		for (Int i = 0; i < a->size(); ++ i) {
			ret.push_back(Cast<Flow>::To<T>::conv(a->getFlowItem(i)));
		}
		return Vec<T>::make(std::move(ret));
	}
}
template<typename T> Ref<T> AFlow::toRef() const { 
	if (const Reference<T>* t = dynamic_cast<const Reference<T>*>(this)) {
		return t;
	} else {
		// TODO: fix this!
		return Ref<T>::make(Cast<Flow>::To<T>::conv(toARef()->getFlowRef()));
	}
}
template<typename R, typename... As> Fun<R, As...> AFlow::toFun() const {
	if (const Function<R, As...>* t = dynamic_cast<const Function<R, As...>*>(this)) {
		return t;
	} else {
		PFun f = toAFun();
		if constexpr (Function<R, As...>::ARITY == 0) {
			if constexpr (std::is_same_v<R, Void>) {
				return Fun<R, As...>::make([f]() mutable { 
					f->callFlowArgs();
				});
			} else {
				return Fun<R, As...>::make([f]() mutable { 
					return Cast<Flow>::template To<R>::conv(f->callFlowArgs()); 
				});
			}
		} else {
			if constexpr (std::is_same_v<R, Void>) {
				return Fun<R, As...>::make([f](As... as) mutable { 
					f->callFlowArgs(Cast<As>::template To<Flow>::conv(as)...);
				});
			} else {
				return Fun<R, As...>::make([f](As... as) mutable { 
					return Cast<Flow>::template To<R>::conv(f->callFlowArgs(Cast<As>::template To<Flow>::conv(as)...)); 
				});
			}
		}
	}
}

// Default cast fillers: all are not available. Available ones will be set by partial specialization

template<typename T> struct BiCast { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<> struct BiCast<Int> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<> struct BiCast<Bool> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<> struct BiCast<Double> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<> struct BiCast<String> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<> struct BiCast<Native> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<> struct BiCast<Flow> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<> struct BiCast<Union> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<typename T> struct BiCast<Vec<T>> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<typename T> struct BiCast<Ref<T>> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<typename R, typename... As> struct BiCast<Fun<R, As...>> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<typename T> struct BiCast<Str<T>> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };

// BiCast<Int>

template<> struct BiCast<Int>::From<Bool> { static Int conv(Bool x) { return bool2int(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Int>::To<Bool> { static Bool conv(Int x) { return int2bool(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Int>::To<Double> { static Double conv(Int x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Int>::From<Double> { static Int conv(Double x) { return double2int(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Int>::To<String> { static String conv(Int x) { return String::make(int2string(x)); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Int>::From<String> { static Int conv(String x) { return string2int(x->str); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Int>::To<Flow> { static Flow conv(Int x) { return Ptr<FInt>::make(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Int>::From<Flow> { static Int conv(Flow x) { return x->toInt(); } static constexpr bool is_available() { return true; } };

// BiCast<Bool>

template<> struct BiCast<Bool>::To<Int> { static Int conv(Bool x) { return bool2int(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Bool>::From<Int> { static Bool conv(Int x) { return int2bool(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Bool>::To<Double> { static Double conv(Bool x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Bool>::From<Double> { static Bool conv(Double x) { return double2bool(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Bool>::To<String> { static String conv(Bool x) { return String::make(bool2string(x)); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Bool>::From<String> { static Bool conv(String x) { return string2bool(x->str); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Bool>::To<Flow> { static Flow conv(Bool x) { return Ptr<FBool>::make(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Bool>::From<Flow> { static Bool conv(Flow f) { return f->toBool(); } static constexpr bool is_available() { return true; } };

// BiCast<Double>

template<> struct BiCast<Double>::To<Int> { static Int conv(Double x) { return double2int(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Double>::From<Int> { static Double conv(Int x) { return int2double(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Double>::To<Bool> { static Bool conv(Double x) { return double2bool(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Double>::From<Bool> { static Double conv(Bool x) { return bool2double(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Double>::To<String> { static String conv(Double x) { return String::make(double2string(x)); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Double>::From<String> { static Double conv(String x) { return string2double(x->str); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Double>::To<Flow> { static Flow conv(Double x) { return Ptr<FDouble>::make(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Double>::From<Flow> { static Double conv(Flow f) { return f->toDouble(); } static constexpr bool is_available() { return true; } };

// BiCast<String>

template<> struct BiCast<String>::To<Int> { static Int conv(String x) { return string2int(x->str); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::From<Int> { static String conv(Int x) { return String::make(int2string(x)); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::To<Bool> { static Bool conv(String x) { return string2bool(x->str); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::From<Bool> { static String conv(Bool x) { return String::make(bool2string(x)); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::To<Double> { static Double conv(String x) { return string2double(x->str); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::From<Double> { static String conv(Double x) { return String::make(double2string(x)); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::To<Flow> { static Flow conv(String x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::From<Flow> { static String conv(Flow x) { return x->toString(); } static constexpr bool is_available() { return true; } };

// BiCast<Native>

template<> struct BiCast<Native>::To<Flow> { static Flow conv(Native x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Native>::From<Flow> { static Native conv(Flow x) { return x->toNative(); } static constexpr bool is_available() { return true; } };

// BiCast<Flow>

template<> struct BiCast<Flow>::To<Int>      { static Int conv(Flow x) { return x->toInt(); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<Int>    { static Flow conv(Int x) { return Ptr<FInt>::make(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::To<Bool>     { static Bool conv(Flow x) { return x->toBool(); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<Bool>   { static Flow conv(Bool x) { return Ptr<FBool>::make(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::To<Double>   { static Double conv(Flow x) { return x->toDouble(); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<Double> { static Flow   conv(Double d)  { return Ptr<FDouble>::make(d); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::To<String>   { static String conv(Flow x)   { return x->toString(); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<String> { static Flow   conv(String x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::To<Native>   { static Native conv(Flow x)   { return x->toNative(); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<Native> { static Flow   conv(Native x) { return x; } static constexpr bool is_available() { return true; } };

template<> struct BiCast<Flow>::To<Union>   { static Union conv(Flow x) { return x->toAStr(); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<Union> { static Flow conv(Union x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::To<AVec>   { static PVec conv(Flow x) { return x->toAVec(); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<AVec> { static Flow conv(PVec x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::To<ARef>   { static PRef conv(Flow x) { return x->toARef(); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<ARef> { static Flow conv(PRef x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::To<AFun>   { static PFun conv(Flow x) { return x->toAFun(); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<AFun> { static Flow conv(PFun x) { return x; } static constexpr bool is_available() { return true; } };

template<> template<typename R, typename... As> struct BiCast<Flow>::To<Fun<R, As...>>   { static Fun<R, As...> conv(Flow x) { return x->toFun<R, As...>(); } static constexpr bool is_available() { return true; } };
template<> template<typename R, typename... As> struct BiCast<Flow>::From<Fun<R, As...>> { static Flow conv(Fun<R, As...> x) { return x; } static constexpr bool is_available() { return true; } };
template<> template<typename T> struct BiCast<Flow>::To<Str<T>>   { static Str<T> conv(Flow x) { return x->toStr<T>(); } static constexpr bool is_available() { return true; } };
template<> template<typename T> struct BiCast<Flow>::From<Str<T>> { static Flow conv(Str<T> x) { return x; } static constexpr bool is_available() { return true; } };
template<> template<typename T> struct BiCast<Flow>::To<Vec<T>>   { static Vec<T> conv(Flow x) { return x->toVec<T>(); } static constexpr bool is_available() { return true; } };
template<> template<typename T> struct BiCast<Flow>::From<Vec<T>> { static Flow conv(Vec<T> x) { return x; } static constexpr bool is_available() { return true; } };
template<> template<typename T> struct BiCast<Flow>::To<Ref<T>>   { static Ref<T> conv(Flow x) { return x->toRef<T>(); } static constexpr bool is_available() { return true; } };
template<> template<typename T> struct BiCast<Flow>::From<Ref<T>> { static Flow conv(Ref<T> x) { return x; } static constexpr bool is_available() { return true; } };

// BiCast<Str<T>>

template<typename T> template<typename T1> struct BiCast<Str<T>>::To<Str<T1>> { static Str<T1> conv(Str<T> x) { return T1::fromAStr(x.ptr); } static constexpr bool is_available() { return static_cast<int>(T1::TYPE) == static_cast<int>(Type::STRUCT); } };
template<typename T> template<typename T1> struct BiCast<Str<T>>::From<Str<T1>> { static Str<T> conv(Str<T1> x) { return T::fromAStr(x.ptr); } static constexpr bool is_available() { return static_cast<int>(T::TYPE) == static_cast<int>(Type::STRUCT);  } };

// BiCast<Union>

template<> template<typename T> struct BiCast<Union>::To<Str<T>> {
	static constexpr bool is_available() { return static_cast<int>(T::TYPE) == static_cast<int>(Type::STRUCT); }
	static Str<T> conv(Union x) { 
		if (const T* s = dynamic_cast<const T*>(x.ptr)) {
			return s;
		} else {
			return T::fromAStr(x); 
		}
	} 
};
template<> template<typename T> struct BiCast<Union>::From<Str<T>> {
	static constexpr bool is_available() { return true; }
	static Union conv(Str<T> x) { return x; } 
};

// BiCast<Vec<T>>

template<typename T> template<typename T1> struct BiCast<Vec<T>>::To<Vec<T1>> {
	static constexpr bool is_available() { return true; }
	static Vec<T1> conv(Vec<T> x) { return x->template toVec<T1>(); } 
};
template<typename T> template<typename T1> struct BiCast<Vec<T>>::From<Vec<T1>> {
	static constexpr bool is_available() { return true; }
	static Vec<T> conv(Vec<T1> x) { return x->template toVec<T>(); } 
};


// BiCast<Ref<T>>

template<typename T> template<typename T1> struct BiCast<Ref<T>>::To<Ref<T1>> {
	static constexpr bool is_available() { return true; }
	static Ref<T1> conv(Ref<T> x) { return x->template toRef<T1>(); } 
};
template<typename T> template<typename T1> struct BiCast<Ref<T>>::From<Ref<T1>> {
	static constexpr bool is_available() { return true; }
	static Ref<T> conv(Ref<T1> x) { return x->template toRef<T>(); }
};

// BiCast<Fun<R, As...>>

template<typename R, typename... As> 
template<typename R1, typename... As1> 
struct BiCast<Fun<R, As...>>::To<Fun<R1, As1...>> {
	static constexpr bool is_available() { return true; }
	static Fun<R1, As1...> conv(Fun<R, As...> x) { return x->template toFun<R1, As1...>(); } 
};
template<typename R, typename... As> 
template<typename R1, typename... As1> 
struct BiCast<Fun<R, As...>>::From<Fun<R1, As1...>> {
	static constexpr bool is_available() { return true; }
	static Fun<R, As...> conv(Fun<R1, As1...> x) { return x->template toFun<R, As...>(); } 
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
Int Vector<T>::compare(Vec<T> a) const { 
	Int c1 = Compare<Int>::cmp(vect.size(), a->vect.size());
	if (c1 != 0) {
		return c1;
	} else {
		for (std::size_t i = 0; i < vect.size(); ++ i) {
			Int c2 = Compare<T>::cmp(getItem(i), a->getItem(i));
			if (c2 != 0) {
				return c2;
			}
		}
		return 0;
	}
}

Int compareFlow(Flow v1, Flow v2);

template<> struct Compare<Flow> {
	static Int cmp(Flow v1, Flow v2) { return compareFlow(v1, v2); }
};

template<typename T>
struct Compare<Vec<T>> {
	static Int cmp(Vec<T> v1, Vec<T> v2) { return v1->compare(v2); }
};

template<typename T>
struct Compare<Ref<T>> {
	static Int cmp(Ref<T> v1, Ref<T> v2) { return v1->compare(v2); }
};

template<typename T>
struct Compare<Str<T>> {
	static Int cmp(Str<T> v1, Str<T> v2) { 
		if (!v1) return -1; else
		if (!v2) return 1; else
		return v1->compare(v2); 
	}
};

template<>
struct Compare<Union> {
	static Int cmp(Union v1, Union v2) { 
		if (!v1) return -1; else
		if (!v2) return 1; else
		return compareFlow(v1, v2); 
	}
};

template<typename R, typename... As>
struct Compare<Fun<R, As...>> {
	static Int cmp(Fun<R, As...> v1, Fun<R, As...> v2) { return Compare<const void*>::cmp(v1.ptr, v2.ptr); }
};

struct FieldDef {
	string name;
	string type;
	bool isMutable;
};

struct StructDef {
	typedef std::function<Flow(Vec<Flow>)> Constructor;
	Int id;
	Constructor make;
	std::vector<FieldDef> fields;
};

}
