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

#define PERCEUS_REFS

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

	//template<typename T1>
	//Ptr& operator = (const T1* p1) { is_smart = p1.is_smart; dec(); ptr = static_cast<const T*>(p1); inc(); return *this; }
	//template<typename T1>
	//Ptr& operator = (Ptr<T1> p1) { is_smart = p1.is_smart; dec(); ptr = static_cast<const T*>(p1.ptr); inc(); return *this; }

	Ptr& operator = (Ptr&& p) { dec(); ptr = p.ptr; p.ptr = nullptr; return *this; }
	Ptr& operator = (const Ptr& p) { dec(); ptr = p.ptr; inc(); return *this; }

	const T& operator *() { return *ptr; }
	const T* operator ->() { return ptr; }
	const T* get() { return ptr; }
	//const T* release() { dec(); const T* ret = ptr; ptr = nullptr; return ret; }

	const T& operator *() const { return *ptr; }
	const T* operator ->() const { return ptr; }
	const T* get() const { return ptr; }
	//const T* release() const { dec(); const T* ret = ptr; ptr = nullptr; return ret; }

	operator bool() const { return ptr; }
	bool isSameObj(const Ptr& p) const { return ptr == p.ptr; }

	template<typename... As>
	static Ptr<T> make(As... as) { return new T(std::move(as)...); }
	template<typename T1>
	static Ptr<T> make(std::initializer_list<T1> il) { return new T(std::move(il)); }

	inline void inc() const {
		#ifndef PERCEUS_REFS
		ptr->incRefs(); 
		#endif
	}
	inline void dec() const {
		#ifndef PERCEUS_REFS 
		if (ptr) ptr->decRefs(); 
		#endif
	}

	const T* ptr;
};

enum Type {
	VOID = 0, // special void type - technically it is nullptr_t
	INT = 1,   BOOL = 2, DOUBLE = 3, STRING = 4, NATIVE = 5, // primary types
	ARRAY = 6, REF = 7,  FUNC = 8,   STRUCT = 9,             // complex types
	UNKNOWN = -1
};

using Void = nullptr_t;
const Void void_value = nullptr;

// Scalar types
using Int = int32_t;
using Bool = bool;
using Double = double;
using string = std::u16string;

string type2s(Int type);

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


// Specific polymiphic types for particular type parameters

template<typename T> struct Vector;
template<typename T> struct Reference;
template<typename R, typename... As> struct Function;

// Reference-counting Pointers to compound types. Are passed all-around as variables/values.

template<typename T> using Str = Ptr<T>;
template<typename T> using Vec = Ptr<Vector<T>>;
template<typename T> using Ref = Ptr<Reference<T>>;
template<typename R, typename... As> using Fun = Ptr<Function<R, As...>>;

typedef uint32_t RefCount_t;

struct AFlow {
	enum { TYPE = Type::UNKNOWN };
	#ifdef PERCEUS_REFS
	AFlow(): refs(0) { }
	#else
	AFlow(): refs(0) { }
	#endif
	AFlow(const AFlow& f) = delete;
	virtual ~AFlow() { }
	virtual Int type() const = 0;

	// Direct getters - don't do any conversion
	Void getVoid() const;
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

	inline void incRefs() const { 
		++ refs; 
	}
	inline void decRefs() const { 
		if (-- refs == 0) {
			delete this; 
		}
	}
	inline void checkRefs() const {
		if (refs == 0) {
			delete this;
		}
	}

	//mutable std::atomic<uint32_t> refs;
	mutable RefCount_t refs;
};

template<typename T> struct IsScalar { enum { value = false }; };
template<> struct IsScalar<Int> { enum { value = true }; };
template<> struct IsScalar<Bool> { enum { value = true }; };
template<> struct IsScalar<Double> { enum { value = true }; };

struct FVoid : public AFlow {
	enum { TYPE = Type::VOID };
	FVoid() { }
	Int type() const override { return Type::VOID; }
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
	//if (s1->refs > 2) {
		string ret;
		ret.reserve(s1->str.size() + s2->str.size());
		ret += s1->str;
		ret += s2->str;
		s1->checkRefs();
		s2->checkRefs();
		return String::make(ret);
	/*} else {
		//std::cout << "Shortcut for concatStrings, s1->size()=" << s1->str.size() << ", s2->size()" << s2->str.size() << std::endl;
		const_cast<string&>(s1->str) += s2->str;
		return s1;
	}*/
}

struct VNative : public AFlow {
	enum { TYPE = Type::NATIVE };
	VNative(const AFlow* w): nat(const_cast<AFlow*>(w)), release([](void* x) { static_cast<AFlow*>(x)->decRefs(); }), is_wrapper(true) { w->incRefs(); }
	VNative(void* n, std::function<void(void*)> r): nat(n), release(r), is_wrapper(false) { }
	~VNative() override { release(nat); }
	Int type() const override { return Type::NATIVE; }
	template<typename T> T* cast() const { return static_cast<T*>(nat); }
	Flow toFlow() const { return is_wrapper ? static_cast<AFlow*>(nat) : this; }

	mutable void* nat;
	std::function<void(void*)> release;
	bool is_wrapper;
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

String flow2string(Flow f);

inline Void AFlow::getVoid() const { return void_value; }
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
inline Native AFlow::toNative() const { 
	if (type() == Type::NATIVE) {
		return getNative(); 
	} else {
		return Native::make(this);
	}
}
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
template<> struct Compare<Void> { static Int cmp(Void v1, Void v2) { return 0; } };
template<> struct Compare<Bool> { static Int cmp(Bool v1, Bool v2) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); } };
template<> struct Compare<Int> { static Int cmp(Int v1, Int v2) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); } };
template<> struct Compare<Double> { static Int cmp(Double v1, Double v2) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); } };
template<> struct Compare<void*> { static Int cmp(void* v1, void* v2) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); } };
template<> struct Compare<const void*> { static Int cmp(const void* v1, const void* v2) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); } };
template<> struct Compare<String> { static Int cmp(String v1, String v2) { Int ret = v1->str.compare(v2->str); v1->checkRefs(); v2->checkRefs(); return ret; } };
template<> struct Compare<Native> { static Int cmp(Native v1, Native v2) { Int ret = Compare<void*>::cmp(v1->nat, v2->nat); v1->checkRefs(); v2->checkRefs(); return ret; } };

template<typename T> struct RefCount { 
	static void inc(T x) { 
		#ifdef PERCEUS_REFS
		x->incRefs(); 
		#endif
	} 
	static void dec(T x) { 
		#ifdef PERCEUS_REFS
		x->decRefs(); 
		#endif
	}
	static bool check(T x) { 
		#ifdef PERCEUS_REFS
		x->checkRefs(); 
		#endif
	}
	static RefCount_t refs(T x) { 
		#ifdef PERCEUS_REFS
		x->refs; 
		#endif
	} 
};
template<> struct RefCount<Int> { static void inc(Int x) { } static void dec(Int x) { } static void check(Int x) { } static RefCount_t refs(Int x) { return 1; } };
template<> struct RefCount<Bool> { static void inc(Bool x) { } static void dec(Bool x) { } static void check(Bool x) { } static RefCount_t refs(Bool x) { return 1; }};
template<> struct RefCount<Double> { static void inc(Double x) { } static void dec(Double x) { } static void check(Double x) { } static RefCount_t refs(Double x) { return 1; }};

const uint32_t FNV_offset_basis = 0x811C9DC5;
const uint32_t FNV_prime = 16777619;

template<typename T> uint32_t hash(uint32_t h, T v);
template<> inline uint32_t hash(uint32_t h, Bool v) { 
	return (h ^ static_cast<uint8_t>(v)) * FNV_prime; 
}
template<> inline uint32_t hash(uint32_t h, Int v) {
	uint32_t v1 = static_cast<uint32_t>(v);
	h = (h ^ ( v1        & 0xFF)) * FNV_prime;
	h = (h ^ ((v1 >> 8)  & 0xFF)) * FNV_prime;
	h = (h ^ ((v1 >> 16) & 0xFF)) * FNV_prime;
	h = (h ^ ((v1 >> 24) & 0xFF)) * FNV_prime;
	return h;
}
template<> inline uint32_t hash(uint32_t h, uint64_t v1) { 
	h = (h ^ ( v1        & 0xFF)) * FNV_prime;
	h = (h ^ ((v1 >> 8)  & 0xFF)) * FNV_prime;
	h = (h ^ ((v1 >> 16) & 0xFF)) * FNV_prime;
	h = (h ^ ((v1 >> 24) & 0xFF)) * FNV_prime;
	h = (h ^ ((v1 >> 32) & 0xFF)) * FNV_prime;
	h = (h ^ ((v1 >> 40) & 0xFF)) * FNV_prime;
	h = (h ^ ((v1 >> 48) & 0xFF)) * FNV_prime;
	h = (h ^ ((v1 >> 56) & 0xFF)) * FNV_prime;
	return h;
}
template<> inline uint32_t hash(uint32_t h, Double v) { 
	return hash<uint64_t>(h, static_cast<uint64_t>(v));
}
template<> inline uint32_t hash(uint32_t h, void* v) { 
	return hash<uint64_t>(h, reinterpret_cast<uint64_t>(v));
}
template<> inline uint32_t hash(uint32_t h, const void* v) { 
	return hash<uint64_t>(h, reinterpret_cast<uint64_t>(v));
}
template<> inline uint32_t hash(uint32_t h, String v) {
	for (char16_t c : v->str) {
		h = (h ^ ( c       & 0xFF)) * FNV_prime;
		h = (h ^ ((c >> 8) & 0xFF)) * FNV_prime;
	}
	return h; 
}
template<> inline uint32_t hash(uint32_t h, Native n) { 
	return hash<uint64_t>(h, reinterpret_cast<uint64_t>(n->nat));
}
template<> uint32_t hash(uint32_t h, Flow n);

template<typename T> struct Hash { inline size_t operator() (T n) const { return hash(FNV_offset_basis, n); } };

template<typename T> 
struct Vector : public AVec {
	typedef std::vector<T> Vect;
	typedef typename Vect::const_iterator const_iterator;
	typedef typename Vect::iterator iterator;

	Vector(): vect() { }
	Vector(std::size_t s): vect() { vect.reserve(s); }
	Vector(std::initializer_list<T> il): vect(il) { for (T x : vect) RefCount<T>::inc(x); }
	Vector(const Vect& v): vect(v) { for (T x : vect) RefCount<T>::inc(x); }
	Vector(Vect&& v): vect(std::move(v)) { }
	Vector(Vector&& a): vect(std::move(a.vect)) { }
	Vector(const Vector& a): vect(a.vect) { for (T x : vect) RefCount<T>::inc(x); }
	~Vector() override { for (T x : vect) RefCount<T>::dec(x); }

	Vector& operator = (const Vector& a) {
		for (T x : vect) RefCount<T>::dec(x);
		vect.operator=(a.vect);
		for (T x : vect) RefCount<T>::inc(x);
		return *this;
	}
	Vector& operator = (Vector&& a) {
		for (T x : vect) RefCount<T>::dec(x); 
		vect.operator=(std::move(a.vect));
		return *this;
	}

	// AVec interface
	Int size() const override { return static_cast<Int>(vect.size()); }
	Flow getFlowItem(Int i) const override { return Cast<T>::template To<Flow>::conv(getItem(i)); }
	void setFlowItem(Int i, Flow x) override { setItem(i, Cast<Flow>::template To<T>::conv(x)); }

	// std::vector interface
	const_iterator begin() const { return vect.begin(); }
	const_iterator end() const { return vect.end(); }
	iterator begin() { return vect.begin(); }
	iterator end(){ return vect.end(); }
	void push_back(T x) { RefCount<T>::inc(x); vect.push_back(x); }

	// general interface
	T getItem(Int i) const { return vect.at(i); }
	void setItem(Int i, T x) { RefCount<T>::dec(vect[i]); vect[i] = x; RefCount<T>::inc(vect[i]); }

	Int compare(Vec<T> a) const;

	Vect vect;
};

/*
template<typename T>
const Vector<T>* concatVecs(const Vector<T>* v1, const Vector<T>* v2) {
	if (v1->refs > 1) {
		std::vector<T> ret;
		ret.reserve(v1->size() + v2->size());
		for(T x : *v1) ret.push_back(x);
		for(T x : *v2) ret.push_back(x);
		return new Vector<T>(std::move(ret));
	} else {
		//std::cout << "Shortcut for concatVecs, v1->size()=" << v1->vect.size() << ", v2->size()=" << v2->vect.size() << std::endl;
		std::vector<T>& ret = const_cast<std::vector<T>&>(v1->vect);
		for(T x : *v2) ret.push_back(x);
		//std::cout << "Resulting v1->size()=" << v1->vect.size() << ", ret.size()=" << ret.size() << std::endl;
		return v1;
	}
}*/
/*
template<typename T>
Vec<T> concatVecs1(Vec<T> v1, Vec<T> v2) {
	if (v1->refs > 2) {
		std::cout << "concatVecs, v1->refs=" << v1->refs << std::endl;
		std::vector<T> ret;
		ret.reserve(v1->size() + v2->size());
		for(T x : *v1) ret.push_back(x);
		for(T x : *v2) ret.push_back(x);
		return new Vector<T>(std::move(ret));
	} else {
		std::cout << "Shortcut for concatVecs, v1->size()=" << v1->vect.size() << ", v2->size()=" << v2->vect.size() << std::endl;
		std::vector<T>& ret = const_cast<std::vector<T>&>(v1->vect);
		for(T x : *v2) ret.push_back(x);
		std::cout << "Resulting v1->size()=" << v1->vect.size() << ", ret.size()=" << ret.size() << std::endl;
		return v1;
	}
}
*/
template<typename T> 
struct Reference : public ARef {
	Reference() { }
	Reference(T r): val(r) { RefCount<T>::inc(val); }
	Reference(const Reference& r): val(r.val) { RefCount<T>::inc(val); }
	Reference(Reference&& r): val(std::move(r.val)) { }
	~Reference() override { RefCount<T>::dec(val); }

	Reference& operator = (Reference&& r) {
		RefCount<T>::dec(val);
		val = std::move(r.val);
		return *this;
	}
	Reference& operator = (const Reference& r) { 
		RefCount<T>::dec(val);
		val = r.val; 
		RefCount<T>::inc(val);
		return *this;
	}

	// ARef interface
	Flow getFlowRef() const override { return Cast<T>::template To<Flow>::conv(getRef()); }
	void setFlowRef(Flow r) const override { setRef(Cast<Flow>::template To<T>::conv(r)); }

	// T-specific getter/setter
	T getRef() const { return val; }
	void setRef(T v) const { RefCount<T>::dec(val); val = v; RefCount<T>::inc(val); }

	Int compare(Ref<T> r) const { return Compare<T>::cmp(val, r->val); }

	mutable T val;
};

template<typename R, typename... As> 
struct Function : public AFun, public std::function<R(As...)> {
	typedef std::function<R(As...)> Fn;
	enum { ARITY = sizeof...(As) };
	Function() {}
	Function(Fn&& f): Fn(std::move(f)) { }
	Function(const Fn& f): Fn(f) { }

	Function(Fn&& f, Vector<Flow>&& cl): Fn(std::move(f)), closure(std::move(cl)) { }
	Function(const Fn& f, const Vector<Flow>& cl): Fn(f), closure(cl) { }
	Function(const Function& f): Fn(f), closure(f.closure) { }
	Function(Function&& f): Fn(std::move(f)), closure(std::move(f.closure)) { }

	// AFun interface
	Int arity() const override { return ARITY; }
	Flow callFlowArgs() const override {
		if constexpr (ARITY == 0) {
			return Cast<R>::template To<Flow>::conv(Fn::operator()());
		} else {
			std::cerr << "arity mismatch: actual " << ARITY << " while used as: " << 0 << std::endl;
			exit(1);
			return nullptr;
		}
	}
	Flow callFlowArgs(Flow as...) const override {
		return Cast<R>::template To<Flow>::conv(
			Fn::operator()(Cast<Flow>::template To<As>::conv(as)...)
		);
	}
	inline R call(As... as) const {
		return Fn::operator()(as...);
	}
	Vector<Flow> closure;
};

//using Union = PStr;

template<int... TS>
struct Union {
	Union(): un() { }
	Union(const PStr& u): un(u) { check(); }
	Union(PStr&& u): un(std::move(u)) { check(); }

	template<typename T>
	Union(const Str<T>& s): un(s) { check(); }
	template<typename T>
	Union(Str<T>&& s): un(std::move(s)) { check(); }

	Union(const Union& u): un(u.un) { }
	Union(Union&& u): un(std::move(u.un)) { }
	template<int... TS1>
	Union(const Union<TS1...>& u): un(u.un) { check(); }
	template<int... TS1>
	Union(Union<TS1...>&& u): un(std::move(u.un)) { check(); }

	void check() const {
		std::vector<Int> types = {TS...};
		Int tp = un->type();
		for (Int t: types) {
			if (t == tp) {
				return;
			}
		}
		std::cerr << "Type " << string2std(type2s(un->type())) << " is not contained in union of types:" << std::endl;
		for (Int t : types) {
			std::cerr << string2std(type2s(t)) << ", ";
		}
		std::cerr << std::endl;
		throw std::exception();
		exit(1);
	}
	Union& operator = (Union&& u) { un.operator = (std::move(u.un)); check(); return *this; }
	Union& operator = (const Union& u) { un.operator = (std::move(u.un)); check(); return *this; }

	const AStr& operator *() { return un.operator*(); }
	const AStr* operator ->() { return un.operator->(); }
	const AStr* get() { return un.get(); }

	const AStr& operator *() const { return un.operator*(); }
	const AStr* operator ->() const { return un.operator->(); }
	const AStr* get() const { return un.get(); }

	PStr un;
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
			return Fun<R, As...>::make([f]() mutable { 
				return Cast<Flow>::template To<R>::conv(f->callFlowArgs()); 
			});
		} else {
			return Fun<R, As...>::make([f](As... as) mutable { 
				return Cast<Flow>::template To<R>::conv(f->callFlowArgs(Cast<As>::template To<Flow>::conv(as)...)); 
			});
		}
	}
}

// Default cast fillers: all are not available. Available ones will be set by partial specialization

template<typename T> struct BiCast { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<> struct BiCast<Void> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<> struct BiCast<Int> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<> struct BiCast<Bool> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<> struct BiCast<Double> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<> struct BiCast<String> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<> struct BiCast<Native> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<> struct BiCast<Flow> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<int... TS> struct BiCast<Union<TS...>> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<typename T> struct BiCast<Vec<T>> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<typename T> struct BiCast<Ref<T>> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<typename R, typename... As> struct BiCast<Fun<R, As...>> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };
template<typename T> struct BiCast<Str<T>> { template<typename> struct From { static constexpr bool is_available() { return false; } }; template<typename> struct To { static constexpr bool is_available() { return false; } }; };

// BiCast<Void>

template<> struct BiCast<Void>::From<Flow> { static Void conv(Flow x) { return void_value; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<Void> { static Flow conv(Void x) { return Ptr<FVoid>::make(); } static constexpr bool is_available() { return true; } };

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

template<> struct BiCast<Native>::To<Flow> { static Flow conv(Native x) { return x->toFlow(); } static constexpr bool is_available() { return true; } };
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
template<> struct BiCast<Flow>::From<Native> { static Flow   conv(Native x) { return x->toFlow(); } static constexpr bool is_available() { return true; } };

template<> template<int... TS> struct BiCast<Flow>::To<Union<TS...>>   { static Union<TS...> conv(Flow x) { return x->toAStr(); } static constexpr bool is_available() { return true; } };
template<> template<int... TS> struct BiCast<Flow>::From<Union<TS...>> { static Flow conv(Union<TS...> x) { return x.get(); } static constexpr bool is_available() { return true; } };
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

// BiCast<Union<TS...>>

template<int... TS> template<typename T> struct BiCast<Union<TS...>>::To<Str<T>> {
	static constexpr bool is_available() { return static_cast<int>(T::TYPE) == static_cast<int>(Type::STRUCT); }
	static Str<T> conv(Union<TS...> x) { 
		if (const T* s = dynamic_cast<const T*>(x.get())) {
			return s;
		} else {
			return T::fromAStr(x.get()); 
		}
	} 
};
template<int... TS> template<typename T> struct BiCast<Union<TS...>>::From<Str<T>> {
	static constexpr bool is_available() { return true; }
	static Union<TS...> conv(Str<T> x) { return x; } 
};

template<int... TS> template<int... TS1> struct BiCast<Union<TS...>>::To<Union<TS1...>> {
	static constexpr bool is_available() { return true; }
	static Union<TS1...> conv(Union<TS...> x) { return x; } 
};

template<int... TS> template<int... TS1> struct BiCast<Union<TS...>>::From<Union<TS1...>> {
	static constexpr bool is_available() { return true; }
	static Union<TS...> conv(Union<TS1...> x) { return x; } 
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

template<int... TS>
struct Compare<Union<TS...>> {
	static Int cmp(Union<TS...> v1, Union<TS...> v2) { 
		if (!v1.get()) return -1; else
		if (!v2.get()) return 1; else
		return compareFlow(v1.get(), v2.get()); 
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

extern string struct_names[];
extern Int struct_count;

}
