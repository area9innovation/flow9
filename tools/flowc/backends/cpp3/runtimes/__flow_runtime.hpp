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

template<typename T>
struct Ptr {
	Ptr(): ptr(nullptr) { }
	Ptr(T* p): ptr(p) { inc(); }
	~Ptr() { dec(); }
	Ptr(Ptr&& p): ptr(p.ptr) { p.ptr = nullptr; }
	Ptr(const Ptr& p): ptr(p.ptr) { inc(); }
	template<typename T1>
	Ptr(Ptr<T1>&& p): ptr(static_cast<T*>(p.ptr)) { p.ptr = nullptr; }
	template<typename T1>
	Ptr(const Ptr<T1>& p): ptr(static_cast<T*>(p.ptr)) { inc(); }

	template<typename T1>
	Ptr& operator = (T1* p1) { 
		if (T* p = dynamic_cast<T*>(p1)) {
			dec(); ptr = p;
		} else {
			std::cerr << "illegal pointer assignment" << std::endl;
			exit(1);
		}
		return *this;
	}
	Ptr& operator = (Ptr&& p) { dec(); ptr = p.ptr; p.ptr = nullptr; return *this; }
	Ptr& operator = (const Ptr& p) { dec(); ptr = p.ptr; inc(); return *this; }
	void inc() { if (ptr) { ptr->inc(); } }
	void dec() { if (ptr) { if (ptr->dec()) { ptr = nullptr; } } }

	T& operator *() { return *ptr; }
	T* operator ->() { return ptr; }
	T* get() { return ptr; }
	T& operator *() const { return *ptr; }
	T* operator ->() const { return ptr; }
	T* get() const { return ptr; }
	operator bool() const { return ptr; }
	bool isSameObj(const Ptr& p) const { return ptr == p.ptr; }

	template<typename... As>
	static Ptr<T> make(As... as) { return Ptr(new T(as...)); }
	template<typename T1> Ptr<T1> statCast() const { return Ptr<T1>(static_cast<T1*>(ptr)); }
	template<typename T1> Ptr<T1> dynCast() const { return Ptr<T1>(dynamic_cast<T1*>(ptr)); }
	template<typename T1> Ptr<T1> reintCast() const { return Ptr<T1>(reinterpret_cast<T1*>(ptr)); }

	mutable T* ptr;
};

enum Type {
	INT = 0,   BOOL = 1, DOUBLE = 2, STRING = 3, NATIVE = 4, // scalar types
	ARRAY = 5, REF = 6,  FUNC = 7,   STRUCT = 8              // complex types
};

using Void = void;

// Scalar types
using Int = int32_t;
using Bool = bool;
using Double = double;
using string = std::u16string;

// Base class for object classes, 
// at the same time general dynamic type, which may be any other

struct Flow;

// Flow wrappers to scalar types

struct FInt;
struct FBool;
struct FDouble;

// Non-polymorphic non-scalar types

struct String;
struct Native;

// Abstract compound types

struct AStr;
struct AArr;
struct ARef;
struct AFun;

// Specific polymiphic types for particular type parameters

template<typename T> struct Str;
template<typename T> struct Arr;
template<typename T> struct Ref;
template<typename R, typename... As> struct Fun;

struct Flow {
	Flow(): refs(0), mortal(true) { }
	Flow(const Flow& f) = delete;
	virtual ~Flow() { }
	virtual Int type() const = 0;

	Int toInt();
	Bool toBool();
	Double toDouble();
	String* toString();
	Native* toNative();
	AStr* toAStr();
	AArr* toAArr();
	ARef* toARef();
	AFun* toAFun();

	template<typename T> T* toStr();
	template<typename T> Arr<T>* toArr();
	template<typename T> Ref<T>* toRef();
	template<typename R, typename... As> Fun<R, As...>* toFun();

	bool isSameObj(Flow* f);

	void inc() { ++ refs; }
	//bool dec() { if (refs > 0) { -- refs; } if (mortal && refs == 0) { delete this; return true; } else { return false; } }
	bool dec() { 
		if (mortal) {
			if (refs > 0) { -- refs; } 
			if (refs == 0) { 
				delete this;
				return true;
			} else {
				return false;
			} 
		}
	}

	//std::atomic<std::size_t> refs = 0;
	std::size_t refs;
	bool mortal;
};

template<typename T> T* setMortal(T* x) { x->mortal = true; return x; }

struct FInt : public Flow {
	FInt(Int v): val(v) { }
	Int type() const override { return Type::INT; }
	Int val;
};
struct FBool : public Flow {
	FBool(Bool v): val(v) { }
	Int type() const override { return Type::BOOL; }
	Bool val;
}; 
struct FDouble : public Flow {
	FDouble(Double v): val(v) { }
	Int type() const override { return Type::DOUBLE; }
	Double val;
};

struct String : public Flow {
	String(): str() { }
	String(const std::string& s);
	String(const string& s): str(s) { }
	String(string&& s): str(std::move(s)) { }
	String(const char16_t* s): str(s) { }
	String(const char16_t* s, Int len): str(s, len) { }
	String(char16_t c): str(1, c) { }
	String(const std::vector<char16_t>& codes): str(codes.data(), codes.size()) { }
	String(const String& s): str(s.str) { }
	String(const String* s): str(s->str) { }
	Int type() const override { return Type::STRING; }
	std::string toStd() const;

	String* concat(String* s) {
		String* ret = new String();
		ret->str.reserve(str.size() + s->str.size());
		ret->str += str;
		ret->str += s->str;
		if (s->refs == 0) delete s;
		return ret;
	}

	string str;
};
struct Native : public Flow {
	Native(void* n, std::function<void(void*)> r): nat(n), release(r) { }
	~Native() override { release(nat); }
	Int type() const override { return Type::NATIVE; }
	template<typename T> T* cast() { return reinterpret_cast<T*>(nat); }

	void* nat;
	std::function<void(void*)> release;
};

struct AStr : public Flow {
	virtual String* name() const = 0;
	virtual Int size() const = 0;
	virtual Flow* getFlow(Int i) = 0;
	virtual Flow* getFlow(String* name) = 0;
	virtual void setFlow(Int i, Flow* val) = 0;
	virtual void setFlow(String* name, Flow* val) = 0;
};

struct AArr : public Flow {
	Int type() const override { return Type::ARRAY; }
	virtual Int size() const = 0;
	virtual Flow* getFlow(Int i) = 0;
	virtual void setFlow(Int i, Flow* val) = 0;
};

struct ARef : public Flow {
	Int type() const override { return Type::REF; }
	virtual Flow* getFlow() = 0;
	virtual void setFlow(Flow*) = 0;
};

struct AFun : public Flow {
	Int type() const override { return Type::FUNC; }
	virtual Int arity() const = 0;
	virtual Flow* callFlow() const = 0;
	virtual Flow* callFlow(Flow* args...) const = 0;
};

inline Int Flow::toInt() { return dynamic_cast<FInt*>(this)->val; }
inline Bool Flow::toBool() { return dynamic_cast<FBool*>(this)->val; }
inline Double Flow::toDouble() { return dynamic_cast<FDouble*>(this)->val; }
inline String* Flow::toString() { return dynamic_cast<String*>(this); }
inline Native* Flow::toNative() { return dynamic_cast<Native*>(this); }
inline AStr* Flow::toAStr() { return dynamic_cast<AStr*>(this); }
inline AArr* Flow::toAArr() { return dynamic_cast<AArr*>(this); }
inline ARef* Flow::toARef() { return dynamic_cast<ARef*>(this); }
inline AFun* Flow::toAFun() { return dynamic_cast<AFun*>(this); }


template<typename T> struct Traits { 
	typedef Ptr<T> LVal;
	typedef T*     RVal;
	static RVal getter(LVal s) { return s.ptr; }
	static void setter(LVal& s, RVal x) { s = x; }
	static void setter(RVal& s, RVal x) { s = x; }
	static void setMortal(RVal s, bool m) { s->mortal = m; }
	static void dispose(RVal s) { delete s; }
};
template<> struct Traits<Int>      { 
	typedef Int    LVal;
	typedef Int    RVal;
	static RVal getter(LVal s) { return s; }
	static void setter(LVal& s, RVal x) { s = x; }
	static void setMortal(RVal s, bool m) { }
	static void dispose(RVal s) { }
};
template<> struct Traits<Bool>     {
	typedef Bool   LVal;
	typedef Bool   RVal;
	static RVal getter(LVal s) { return s; }
	static void setter(LVal& s, RVal x) { s = x; }
	static void setMortal(RVal s, bool m) { }
	static void dispose(RVal s) { }
};
template<> struct Traits<Double> { 
	typedef Double LVal;
	typedef Double RVal;
	static RVal getter(LVal s) { return s; }
	static void setter(LVal& s, RVal x) { s = x; }
	static void setMortal(RVal s, bool m) { }
	static void dispose(RVal s) { }
};
template<> struct Traits<Void> {
	typedef Void   LVal;
	typedef Void   RVal;
};
template<typename T> struct Traits<Str<T>> {
	typedef Ptr<T> LVal; 
	typedef T* RVal;
	static RVal getter(LVal s) { return s.ptr; }
	static void setter(LVal& s, RVal x) { s = x; }
	static void setter(RVal& s, RVal x) { s = x; }
	static void setMortal(RVal s, bool m) { s->mortal = m; }
	static void dispose(RVal s) { delete s; }
};
template<typename T> struct Traits<Ptr<T>> {
	typedef Ptr<T> LVal; typedef T* RVal;
	static RVal getter(LVal s) { return s.ptr; }
	static void setter(LVal& s, RVal x) { s = x; }
	static void setter(RVal& s, RVal x) { s = x; }
	static void setMortal(RVal s, bool m) { s->mortal = m; }
	static void dispose(RVal s) { delete s; }
};
template<typename T> struct Traits<T*> { 
	//static void fail() { static_assert(false, "raw pointer as a traits type"); }
}; // Must fail


template<typename T> inline typename Traits<T>::RVal setImmortal(typename Traits<T>::RVal x) { x->mortal = false; return x; }
template<> inline Int setImmortal<Int>(Int x) { return x; }
template<> inline Bool setImmortal<Bool>(Bool x) { return x; }
template<> inline Double setImmortal<Double>(Double x) { return x; }

template<typename T> inline typename Traits<T>::RVal setMortal(typename Traits<T>::RVal x) { x->mortal = true; return x; }
template<> inline Int setMortal<Int>(Int x) { return x; }
template<> inline Bool setMortal<Bool>(Bool x) { return x; }
template<> inline Double setMortal<Double>(Double x) { return x; }


template<typename T1> struct Cast { 
	template<typename T2> struct To   { static typename Traits<T2>::RVal conv(typename Traits<T1>::RVal x); };
	template<typename T2> struct From { static typename Traits<T1>::RVal conv(typename Traits<T2>::RVal x); };
};

template<typename T> struct Compare;
template<typename T> struct Equal { bool operator() (T v1, T v2) const { return Compare<T>::cmp(v1, v2) == 0; } };
template<> struct Compare<Bool> { static Int cmp(Bool v1, Bool v2) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); } };
template<> struct Compare<Int> { static Int cmp(Int v1, Int v2) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); } };
template<> struct Compare<Double> { static Int cmp(Double v1, Double v2) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); } };
template<> struct Compare<void*> { static Int cmp(void* v1, void* v2) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); } };
template<> struct Compare<String> { static Int cmp(String* v1, String* v2) { return v1->str.compare(v2->str); } };
template<> struct Compare<Native> { static Int cmp(Native* v1, Native* v2) { return Compare<void*>::cmp(v1->nat, v2->nat); } };

template<typename T> 
struct Arr : public AArr {
	typedef typename Traits<T>::LVal LVal;
	typedef typename Traits<T>::RVal RVal;
	typedef std::vector<LVal> Vect;

	struct const_iterator {
		const_iterator(typename Vect::const_iterator i): iter(i) { }
		const_iterator& operator ++() { ++iter; return *this; }
		bool operator == (const const_iterator& i) const { return iter == i.iter; }
		bool operator != (const const_iterator& i) const { return iter != i.iter; }
		RVal operator*() const { return Traits<T>::getter(*iter); }
		typename Vect::const_iterator iter;
	};
	struct iterator {
		iterator(typename Vect::iterator i): iter(i) { }
		iterator& operator ++() { ++iter; return *this; }
		bool operator == (const iterator& i) const { return iter == i.iter; }
		bool operator != (const iterator& i) const { return iter != i.iter; }
		RVal operator*() { return Traits<T>::getter(*iter); }
		typename Vect::iterator iter;
	};

	Arr(): vect() { }
	Arr(std::size_t s): vect() { vect.reserve(s); }
	Arr(std::initializer_list<RVal> il): vect(il.size()) { 
		std::size_t i = 0;
		for (RVal x : il) {
			vect[i++] = x;
		}
	}
	Arr(const Vect& v): vect(v) { }
	Arr(Vect&& v): vect(std::move(v)) { }
	Arr(Arr&& a): vect(std::move(a.vect)) { }
	Arr(const Arr& a): vect(a.vect) { }

	Arr& operator = (const Arr& a) { vect.operator=(a.vect); return *this; }
	Arr& operator = (Arr&& a) { vect.operator=(std::move(a.vect)); return *this; }

	// AArr interface
	Int size() const override { return static_cast<Int>(vect.size()); }
	Flow* getFlow(Int i) override;
	void setFlow(Int i, Flow* v) override;

	// std::vector interface
	const_iterator begin() const { return vect.begin(); }
	const_iterator end() const { return vect.end(); }
	iterator begin() { return vect.begin(); }
	iterator end(){ return vect.end(); }
	void push_back(RVal x) { vect.push_back(x); }

	// general interface
	RVal get(Int i) { return Traits<T>::getter(vect.at(i)); }
	void set(Int i, RVal x) { Traits<T>::setter(vect[i], x); }

	Int compare(Arr* a);

	Vect vect;
};

template<typename T> 
struct Ref : public ARef {
	typedef typename Traits<T>::RVal RVal;
	typedef typename Traits<T>::LVal LVal;
	Ref() { }
	Ref(RVal r): val(r) { }
	Ref(const Ref& r): val(r.val) { }
	Ref(Ref&& r): val(std::move(r.val)) { }

	Ref& operator = (Ref&& r) { val = std::move(r.val); return *this; }
	Ref& operator = (const Ref& r) { val = r.val; return *this; }

	// ARef interface
	Flow* getFlow() override { return Cast<T>::template To<Flow>::conv(get()); }
	void setFlow(Flow* r) override { set(Cast<Flow>::template To<T>::conv(r)); }

	// T-specific getter/setter
	RVal get() { return Traits<T>::getter(val); }
	void set(RVal v) { Traits<T>::setter(val, v); }

	Int compare(Ref* r) { return Compare<T>::cmp(val, r->val); }

	mutable LVal val;
};

struct Closure {
	Closure() { }
	Closure(std::initializer_list<Flow*> cl): closure(cl.size()) {
		std::size_t i = 0;
		for (Flow* x : cl) {
			closure[i++] = x;
		}
	}
	Closure(const Closure& cl): closure(cl.closure) { }
	Closure(Closure&& cl): closure(std::move(cl.closure)) { } 

	std::vector<Ptr<Flow>> closure;
};

template<typename R, typename... As> 
struct Fun : public AFun {
	typedef typename Traits<R>::RVal RVal;
	typedef typename std::function<RVal(typename Traits<As>::RVal...)> Fn;
	enum { ARITY = sizeof...(As) };
	Fun() {}
	Fun(Fn&& f): fn(std::move(f)) { }
	Fun(Fn&& f, Closure&& cl): fn(std::move(f)), closure(std::move(cl)) { }
	Fun(const Fun& f): fn(f.fn), closure(fn.closure) { }
	Fun(Fun&& f): fn(std::move(f.fn)), closure(std::move(fn.closure)) { }

	// AFun interface
	Int arity() const override { return ARITY; }
	Flow* callFlow() const override {
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
	Flow* callFlow(Flow* as...) const override {
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
	RVal operator()(typename Traits<As>::RVal... as) const { 
		if constexpr (std::is_same_v<RVal, Void>) {
			call(as...); 
		} else {
			return call(as...); 
		}
	}
	virtual RVal call(typename Traits<As>::RVal... as) const { 
		if constexpr (std::is_same_v<RVal, Void>) {
			fn(as...); 
		} else {
			return fn(as...); 
		}
	}

	Fn fn;
	Closure closure;
};

inline Int double2int(Double x) { return (x >= 0.0) ? static_cast<Int>(x + 0.5) : static_cast<Int>(x - 0.5); }
inline Int string2int(String* x) { if (x->str.size() == 0) return 0; else { try { return std::stoi(x->toStd()); } catch (std::exception& e) { return 0; } } }
inline Double string2double(String* x) { if (x->str.size() == 0) return 0.0; else { try { return std::stod(x->toStd()); } catch (std::exception& e) { return 0.0; } } }
inline String* int2string(Int x) { return new String(std::to_string(x)); }
String* double2string(Double x);
inline String* bool2string(Bool x) { return x ? new String(u"true") : new String(u"false"); }

const char* type2s(Int type);

void flow2string(Flow* v, String* os);

inline String* flow2string(Flow* f) { String* os = new String(); flow2string(f, os); return os; }

template<typename T> T* Flow::toStr() { 
	if (T* t = dynamic_cast<T*>(this)) {
		return t;
	} else {
		return T::fromAStr(toAStr());
	}
}
template<typename T> Arr<T>* Flow::toArr() { 
	if (Arr<T>* t = dynamic_cast<Arr<T>*>(this)) {
		return t;
	} else {
		AArr* a = toAArr();
		Arr<T>* ret = new Arr<T>(a->size());
		for (Int i = 0; i < a->size(); ++ i) {
			ret->push_back(Cast<Flow>::To<T>::conv(a->getFlow(i)));
		}
		return ret;
	}
}
template<typename T> Ref<T>* Flow::toRef() { 
	if (Ref<T>* t = dynamic_cast<Ref<T>*>(this)) {
		return t;
	} else {
		// TODO: fix this!
		return new Ref<T>(Cast<Flow>::To<T>::conv(toARef()->getFlow()));
	} 
}
template<typename R, typename... As> Fun<R, As...>* Flow::toFun() {
	if (Fun<R, As...>* t = dynamic_cast<Fun<R, As...>*>(this)) {
		return t;
	} else {
		AFun* f = toAFun();
		if constexpr (Fun<R, As...>::ARITY == 0) {
			if constexpr (std::is_same_v<R, Void>) {
				return new Fun<R, As...>([f]() mutable { 
					f->callFlow();
				});
			} else {
				return new Fun<R, As...>([f]() mutable { 
					return Cast<Flow>::template To<R>::conv(f->callFlow()); 
				});
			}
		} else {
			if constexpr (std::is_same_v<R, Void>) {
				return new Fun<R, As...>([f](typename Traits<As>::RVal... as) mutable { 
					f->callFlow(Cast<As>::template To<Flow>::conv(as)...);
				});
			} else {
				return new Fun<R, As...>([f](typename Traits<As>::RVal... as) mutable { 
					return Cast<Flow>::template To<R>::conv(f->callFlow(Cast<As>::template To<Flow>::conv(as)...)); 
				});
			}
		}
	}
}

template<typename T> struct BiCast {
	template<typename> struct From { static constexpr bool is_available() { return false; } }; 
	template<typename> struct To { static constexpr bool is_available() { return false; } }; 
};

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
template<> struct BiCast<Native> {
	template<typename> struct From { static constexpr bool is_available() { return false; } }; 
	template<typename> struct To { static constexpr bool is_available() { return false; } }; 
};
template<> struct BiCast<Flow> {
	template<typename> struct From { static constexpr bool is_available() { return false; } }; 
	template<typename> struct To { static constexpr bool is_available() { return false; } }; 
};
template<> struct BiCast<AStr> {
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
template<typename T> struct BiCast<Str<T>> { 
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
template<> struct BiCast<Int>::To<String> { static String* conv(Int x) { return int2string(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Int>::From<String> { static Int conv(String* x) { return string2int(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Int>::To<Flow> { static Flow* conv(Int x) { return new FInt(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Int>::From<Flow> { static Int conv(Flow* x) { 
	switch (x->type()) {
		case Type::INT:    return x->toInt();
		case Type::BOOL:   return x->toBool() ? 1 : 0;
		case Type::DOUBLE: return double2int(x->toDouble());
		case Type::STRING: return string2int(x->toString());
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
template<> struct BiCast<Bool>::To<String> { static String* conv(Bool x) { return bool2string(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Bool>::From<String> { static Bool conv(String* x) { return x->str == u"true"; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Bool>::To<Flow> { static Flow* conv(Bool x) { return new FBool(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Bool>::From<Flow> { static Bool conv(Flow* f) { 
	switch (f->type()) {
		case Type::INT:    return f->toInt() != 0;
		case Type::BOOL:   return f->toBool();
		case Type::DOUBLE: return f->toDouble() != 0.0;
		case Type::STRING: return f->toString()->str == u"true";
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
template<> struct BiCast<Double>::To<String> { static String* conv(Double x) { return double2string(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Double>::From<String> { static Double conv(String* x) { return string2double(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Double>::To<Flow> { static Flow* conv(Double x) { return new FDouble(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Double>::From<Flow> { static Double conv(Flow* f) { 
	switch (f->type()) {
		case Type::INT:    return f->toInt();
		case Type::BOOL:   return f->toBool() ? 1.0 : 0.0;
		case Type::DOUBLE: return f->toDouble();
		case Type::STRING: return string2double(f->toString());
		default:           return 0.0;
	}
} static constexpr bool is_available() { return true; } };

// BiCast<String>

template<> struct BiCast<String>::To<Int> { static Int conv(String* x) { return string2int(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::From<Int> { static String* conv(Int x) { return int2string(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::To<Bool> { static Bool conv(String* x) { return x->str == u"true"; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::From<Bool> { static String* conv(Bool x) { return new String(x ? u"true" : u"false"); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::To<Double> { static Double conv(String* x) { return string2double(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::From<Double> { static String* conv(Double x) { return double2string(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::To<String> { static String* conv(String* x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::From<String> { static String* conv(String* x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::To<Flow> { static Flow* conv(String* x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<String>::From<Flow> { static String* conv(Flow* x) { if (x->type() == Type::STRING) return x->toString(); else return flow2string(x); } static constexpr bool is_available() { return true; } };

// BiCast<Native>

template<> struct BiCast<Native>::To<Native> { static Native* conv(Native* x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Native>::From<Native> { static Native* conv(Native* x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Native>::To<Flow> { static Flow* conv(Native* x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Native>::From<Flow> { static Native* conv(Flow* x) { return x->toNative(); } static constexpr bool is_available() { return true; } };

// BiCast<Flow>

template<> struct BiCast<Flow>::To<Int> { static Int conv(Flow* x) { 
	switch (x->type()) {
		case Type::INT:    return x->toInt();
		case Type::BOOL:   return x->toBool() ? 1 : 0;
		case Type::DOUBLE: return double2int(x->toDouble());
		case Type::STRING: return string2int(x->toString());
		default:           return 0;
	}
} static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<Int> { static Flow* conv(Int x) { return new FInt(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::To<Bool> { static Bool conv(Flow* f) { 
	switch (f->type()) {
		case Type::INT:    return f->toInt() != 0;
		case Type::BOOL:   return f->toBool();
		case Type::DOUBLE: return f->toDouble() != 0.0;
		case Type::STRING: return f->toString()->str == u"true";
		default:           return false;
	}
} static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<Bool> { static Flow* conv(Bool x) { return new FBool(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::To<Double> { static Double conv(Flow* f) { 
	switch (f->type()) {
		case Type::INT:    return f->toInt();
		case Type::BOOL:   return f->toBool() ? 1.0 : 0.0;
		case Type::DOUBLE: return f->toDouble();
		case Type::STRING: return string2double(f->toString());
		default:           return 0.0;
	}
} static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<Double> { static Flow*   conv(Double d)  { return new FDouble(d); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::To<String>   { static String* conv(Flow* x)   { if (x->type() == Type::STRING) return x->toString(); else return flow2string(x); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<String> { static Flow*   conv(String* x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::To<Native>   { static Native* conv(Flow* x)   { return x->toNative(); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<Native> { static Flow*   conv(Native* x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::To<Flow>     { static Flow*   conv(Flow* x)   { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<Flow>   { static Flow*   conv(Flow* x)   { return x; } static constexpr bool is_available() { return true; } };

template<> struct BiCast<Flow>::To<AStr>   { static AStr* conv(Flow* x) { return x->toAStr(); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<AStr> { static Flow* conv(AStr* x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::To<AArr>   { static AArr* conv(Flow* x) { return x->toAArr(); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<AArr> { static Flow* conv(AArr* x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::To<ARef>   { static ARef* conv(Flow* x) { return x->toARef(); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<ARef> { static Flow* conv(ARef* x) { return x; } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::To<AFun>   { static AFun* conv(Flow* x) { return x->toAFun(); } static constexpr bool is_available() { return true; } };
template<> struct BiCast<Flow>::From<AFun> { static Flow* conv(AFun* x) { return x; } static constexpr bool is_available() { return true; } };


template<> template<typename R, typename... As> struct BiCast<Flow>::To<Fun<R, As...>>   { static Fun<R, As...>* conv(Flow* x) { return x->toFun<R, As...>(); } static constexpr bool is_available() { return true; } };
template<> template<typename R, typename... As> struct BiCast<Flow>::From<Fun<R, As...>> { static Flow* conv(Fun<R, As...>* x) { return x; } static constexpr bool is_available() { return true; } };
template<> template<typename T> struct BiCast<Flow>::To<Str<T>>   { static T* conv(Flow* x) { return x->toStr<T>(); } static constexpr bool is_available() { return true; } };
template<> template<typename T> struct BiCast<Flow>::From<Str<T>> { static Flow* conv(T* x) { return static_cast<Flow*>(x); } static constexpr bool is_available() { return true; } };
template<> template<typename T> struct BiCast<Flow>::To<Arr<T>>   { static Arr<T>* conv(Flow* x) { return x->toArr<T>(); } static constexpr bool is_available() { return true; } };
template<> template<typename T> struct BiCast<Flow>::From<Arr<T>> { static Flow* conv(Arr<T>* x) { return static_cast<Flow*>(x); } static constexpr bool is_available() { return true; } };
template<> template<typename T> struct BiCast<Flow>::To<Ref<T>>   { static Ref<T>* conv(Flow* x) { return x->toRef<T>(); } static constexpr bool is_available() { return true; } };
template<> template<typename T> struct BiCast<Flow>::From<Ref<T>> { static Flow* conv(Ref<T>* x) { return static_cast<Flow*>(x); } static constexpr bool is_available() { return true; } };

// BiCast<Str<T>>

template<typename T> template<typename T1> struct BiCast<Str<T>>::To<Str<T1>> {
	static constexpr bool is_available() { return true; }
	static T1* conv(T* x) { return T1::fromAStr(x->toAStr()); } 
};
template<typename T> template<typename T1> struct BiCast<Str<T>>::From<Str<T1>> {
	static constexpr bool is_available() { return true; }
	static T* conv(T1* x) { return T::fromAStr(x->toAStr()); }
};

// BiCast<AStr>

template<> template<typename T> struct BiCast<AStr>::To<Str<T>> {
	static constexpr bool is_available() { return true; }
	static T* conv(AStr* x) { 
		if (T* s = dynamic_cast<T*>(x)) {
			return s;
		} else {
			return T::fromAStr(x); 
		}
	} 
};
template<> template<typename T> struct BiCast<AStr>::From<Str<T>> {
	static constexpr bool is_available() { return true; }
	static AStr* conv(T* x) { return static_cast<AStr*>(x); } 
};

// BiCast<Arr<T>>

template<typename T> template<typename T1> struct BiCast<Arr<T>>::To<Arr<T1>> {
	static constexpr bool is_available() { return true; }
	static Arr<T1>* conv(Arr<T>* x) { return x->template toArr<T1>(); } 
};
template<typename T> template<typename T1> struct BiCast<Arr<T>>::From<Arr<T1>> {
	static constexpr bool is_available() { return true; }
	static Arr<T>* conv(Arr<T1>* x) { return x->template toArr<T>(); } 
};


// BiCast<Ref<T>>

template<typename T> template<typename T1> struct BiCast<Ref<T>>::To<Ref<T1>> {
	static constexpr bool is_available() { return true; }
	static Ref<T1>* conv(Ref<T>* x) { return x->template toRef<T1>(); } 
};
template<typename T> template<typename T1> struct BiCast<Ref<T>>::From<Ref<T1>> {
	static constexpr bool is_available() { return true; }
	static Ref<T>* conv(Ref<T1>* x) { return x->template toRef<T>(); }
};

// BiCast<Fun<R, As...>>

template<typename R, typename... As> 
template<typename R1, typename... As1> 
struct BiCast<Fun<R, As...>>::To<Fun<R1, As1...>> {
	static constexpr bool is_available() { return true; }
	static Fun<R1, As1...>* conv(Fun<R, As...>* x) { return x->template toFun<R1, As1...>(); } 
};
template<typename R, typename... As> 
template<typename R1, typename... As1> 
struct BiCast<Fun<R, As...>>::From<Fun<R1, As1...>> {
	static constexpr bool is_available() { return true; }
	static Fun<R, As...>* conv(Fun<R1, As1...>* x) { return x->template toFun<R, As...>(); } 
};

template<typename T1> 
template<typename T2> 
typename Traits<T2>::RVal Cast<T1>::To<T2>::conv(typename Traits<T1>::RVal x) {
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
typename Traits<T1>::RVal Cast<T1>::From<T2>::conv(typename Traits<T2>::RVal x) {
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
inline Flow* Arr<T>::getFlow(Int i) { 
	return Cast<T>::template To<Flow>::conv(get(i)); 
}

template<typename T>
inline void Arr<T>::setFlow(Int i, Flow* v) {
	set(i, Cast<Flow>::template To<T>::conv(v));
}

template<typename T>
Int Arr<T>::compare(Arr* a) { 
	Int c1 = Compare<Int>::cmp(vect.size(), a->vect.size());
	if (c1 != 0) {
		return c1;
	} else {
		for (std::size_t i = 0; i < vect.size(); ++ i) {
			Int c2 = Compare<T>::cmp(get(i), a->get(i));
			if (c2 != 0) {
				return c2;
			}
		}
		return 0;
	}
}

Int compareFlow(Flow* v1, Flow* v2);

template<> struct Compare<Flow> {
	static Int cmp(Flow* v1, Flow* v2) { return compareFlow(v1, v2); }
};

template<typename T>
struct Compare<Arr<T>> {
	static Int cmp(Arr<T>* v1, Arr<T>* v2) { return v1->compare(v2); }
};

template<typename T>
struct Compare<Ref<T>> {
	static Int cmp(Ref<T>* v1, Ref<T>* v2) { return v1->compare(v2); }
};

template<typename T>
struct Compare<Str<T>> {
	static Int cmp(T* v1, T* v2) { 
		if (!v1) return -1; else
		if (!v2) return 1; else
		return v1->compare(v2); 
	}
};

template<>
struct Compare<AStr> {
	static Int cmp(AStr* v1, AStr* v2) { 
		if (!v1) return -1; else
		if (!v2) return 1; else
		return compareFlow(v1, v2); 
	}
};

template<typename R, typename... As>
struct Compare<Fun<R, As...>> {
	static Int cmp(Fun<R, As...>* v1, Fun<R, As...>* v2) { return Compare<void*>::cmp(v1, v2); }
};

struct FieldDef {
	string name;
	string type;
	bool isMutable;
};

struct StructDef {
	typedef std::function<Flow*(Arr<Flow>*)> Constructor;
	Int id;
	Constructor make;
	std::vector<FieldDef> fields;
};

template<typename T> struct Refs { 
	static void dec(typename Traits<T>::RVal x) { x->dec(); } 
	static void inc(typename Traits<T>::RVal x) { x->inc(); } 
};
template<> struct Refs<Int> { static void dec(Int x) { } static void inc(Int x) { } };
template<> struct Refs<Bool> { static void dec(Bool x) { } static void inc(Int x) { } };
template<> struct Refs<Double> { static void dec(Double x) { } static void inc(Int x) { } };

}
