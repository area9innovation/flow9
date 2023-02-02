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
#include <unordered_map>
#include <mutex>
#include <atomic>
#include <thread>
#include <tuple>
#include <any>
#include <typeindex>
#include <typeinfo>
#endif

// C++ runtime for flow

namespace flow {

inline void fail(const std::string& msg) { throw std::runtime_error(msg); }

enum TypeFx {
	VOID = 0, // special void type - technically it is nullptr_t
	INT = 1,   BOOL = 2, DOUBLE = 3, STRING = 4, NATIVE = 5, // primary types
	ARRAY = 6, REF = 7,  FUNC = 8,   STRUCT = 9,             // complex types
	// These types can't be met in runtime, but are used in RTTI markup
	UNKNOWN = -1, FLOW = -2, PARAMETER = -3
};

// Types with id values < 9 are from TypeFx, others are structs. 

using TypeId = int32_t;

// Flow internally uses utf-16 string format

using string = std::u16string;

// Runtime type information: structs

struct FieldDef {
	string name;
	TypeId type;
};

struct StructDef {
	string name;
	TypeId type;
	std::vector<FieldDef> args;
};

struct RTTI {
	// List of names for the types in TypeFx
	static const string type_names[];
	// Sequence of all struct definitions
	static std::vector<StructDef> struct_defs;
	static const string& typeName(TypeId id) {
		if (id < 0) return type_names[0]; else
		if (id < 9) return type_names[id + 1]; else
		if (id - 9 < struct_defs.size()) {
			return struct_defs.at(id - 9).name;
		} else {
			return type_names[0];
		}
	}
	static const StructDef& structDef(TypeId id) {
		if (id - 9 + 1 < struct_defs.size()) {
			return struct_defs.at(id - 8);
		} else {
			// Special struct def - undefined.
			return struct_defs.at(0);
		}
	}
	static int structField(TypeId id, const string& field) {
		int i = 0;
		for (auto& arg : struct_defs.at(id).args) {
			if (arg.name == field) break;
			i += 1;
		}
		return i;
	}
};

// Basic types

using Void = nullptr_t;
const Void void_value = nullptr;

// Scalar types
using Int = int32_t;
using Bool = bool;
using Double = double;

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

// Forward declaration of all types

struct Flow;
struct String;
struct Native;
template<TypeId Id, typename... Fs> struct Str;
template<typename T> struct Vec;
template<typename T> struct Ref;
template<typename R, typename... As> struct Fun;

// Predicate for compile-time type resolution

template<TypeId Id, typename T> struct is_type { enum { result = false }; };
template<> struct is_type<TypeFx::VOID, Void> { enum { result = true }; };
template<> struct is_type<TypeFx::INT, Int> { enum { result = true }; };
template<> struct is_type<TypeFx::BOOL, Bool> { enum { result = true }; };
template<> struct is_type<TypeFx::DOUBLE, Double> { enum { result = true }; };
template<> struct is_type<TypeFx::STRING, String*> { enum { result = true }; };
template<> struct is_type<TypeFx::NATIVE, Native*> { enum { result = true }; };
template<typename T> struct is_type<TypeFx::ARRAY, Vec<T>*> { enum { result = true }; };
template<typename T> struct is_type<TypeFx::REF, Ref<T>*> { enum { result = true }; };
template<typename R, typename... As> struct is_type<TypeFx::FUNC, Fun<R, As...>*> { enum { result = true }; };
template<TypeId Id, typename... Fs> struct is_type<Id, Str<Id, Fs...>*> { enum { result = true }; };
template<TypeId Id, typename T> constexpr bool is_type_v = is_type<Id, T>::result;

template<typename T> struct is_struct { enum { result = false }; };
template<TypeId Id, typename... Fs> struct is_struct<Str<Id, Fs...>*> { enum { result = true }; };
template<typename T> constexpr bool is_struct_v = is_struct<T>::result;

template<typename T> constexpr bool is_flow_ancestor_v = std::is_base_of_v<Flow, std::remove_pointer<T>>;

template<typename T1, typename T2> T2 cast(T1 x);
template<typename T> Int compare(T v1, T v2);
template<typename T> inline Bool equal(T v1, T v2) { return compare(v1, v2) == 0; }
template<typename T> inline String* toString(T v);
template<typename T> inline void toString(T v, string& str);

template<typename T> inline void rc(T x, Int d) {
	if constexpr (std::is_pointer_v<T>) { x->rc_ += d; if (x->rc_ == 0) delete x; }
}

template<typename T> inline T incRc(T x) {
	if constexpr (std::is_pointer_v<T>) { ++x->rc_; } return x;
}

template<typename T, typename V> inline T decRc(V y, T x) {
	if constexpr (std::is_pointer_v<T>) { if (--x->rc_ == 0) delete x; } return y;
}

// Dynamic wrapper for all values 

struct Flow {
	Flow(): rc_(1) {}
	virtual ~Flow() {}
	virtual TypeId typeId() const = 0;
	virtual Int size() const { return 0; }
	virtual Flow* getFlow(Int i) { fail("invalid flow value getter"); return nullptr; }
	virtual void setFlow(Int i, Flow* v) { fail("invalid flow value setter"); }
	virtual Flow* callFlow(Flow*...) { fail("invalid flow value getter"); return nullptr; }
	template<typename T> inline T get() { return dynamic_cast<T>(this); }
	Int rc_;
};

struct FVoid : public Flow { virtual TypeId typeId() const override { return TypeFx::VOID; } };
struct FInt : public Flow { FInt(Int v): val(v) {} virtual TypeId typeId() const override { return TypeFx::INT; } Int val; };
struct FBool : public Flow { FBool(Bool v): val(v) {} virtual TypeId typeId() const override { return TypeFx::BOOL; } Bool val; };
struct FDouble : public Flow { FDouble(Double v): val(v) {} virtual TypeId typeId() const override { return TypeFx::DOUBLE; } Double val; };

template<> inline Void Flow::get<Void>() { return void_value; }
template<> inline Int Flow::get<Int>() { return dynamic_cast<FInt*>(this)->val; }
template<> inline Bool Flow::get<Bool>() { return dynamic_cast<FBool*>(this)->val; }
template<> inline Double Flow::get<Double>() { return dynamic_cast<FDouble*>(this)->val; }

struct String : public Flow {
	enum { TYPE = TypeFx::STRING };
	String(): str() { }
	String(const std::string& s): str(std2string(s)) { }
	String(const string& s): str(s) { }
	String(string&& s): str(std::move(s)) { }
	String(const char16_t* s): str(s) { }
	String(const char16_t* s, Int len): str(s, len) { }
	String(char16_t c): str(1, c) { }
	String(const std::vector<char16_t>& codes): str(codes.data(), codes.size()) { }
	//String(String* s): str(s->str) { }

	String(const String& s): str(s.str) { }
	String(String&& s): str(std::move(s.str)) { }

	template<typename... As>
	static String* make(As... as) { return new String(as...); }

	TypeId typeId() const override { return TypeFx::STRING; }
	std::string toStd() const { return string2std(str); }

	String& operator = (const String& s) { str = s.str; return *this; }
	String& operator = (String&& s) { str = s.str; return *this; }

	string str;
};

inline String* concatStrings(String* s1, String* s2) {
	string ret;
	ret.reserve(s1->str.size() + s2->str.size());
	ret += s1->str;
	ret += s2->str;
	return new String(ret);
}

struct Native : public Flow {
	enum { TYPE = TypeFx::NATIVE };
	constexpr static TypeId typeId_() { return TypeFx::NATIVE; }
	template<typename T>
	Native(T v): val(v) { if constexpr (is_flow_ancestor_v<T>) rc(v, +1); }
	~Native() override {
		try {
			rc(std::any_cast<Flow*>(val), -1);
		} catch(const std::bad_any_cast& e) { }
	}
	TypeId typeId() const override { return TypeFx::NATIVE; }
	template<typename T> 
	T get() {
		try {
			rc(std::any_cast<Flow*>(val), -1);
		} catch(const std::bad_any_cast& e) { 
			fail("incorrect type in native");
		}
	}
private:
	std::any val;
};

// Any particular struct

template<TypeId Id, typename... Fs>
struct Str : public Flow {
	enum { TYPE = Id, SIZE = sizeof...(Fs) };
	using Fields = std::tuple<Fs...>;
	Str(Fs... fs): fields(fs...) { rcFields<0>(+1); }
	~Str() override { rcFields<0>(-1); }

	template<Int i>
	void rcFields(Int delta) {
		if constexpr(i < SIZE) {
			rc(std::get<i>(fields), delta);
			rcFields<i + 1>(delta);
		}
	}

	static Str* make(Fs... fs) { return new Str(fs...); }

	TypeId typeId() const override { return TYPE; }
	Int size() const override { return sizeof...(Fs); }

	Flow* getFlow(Int i) override {
		return getFlow_<0>(i);
	}
	template<Int i>
	Flow* getFlow_(Int j) {
		if constexpr(i == SIZE) {
			fail("illegal access of field by index");
			return nullptr;
		} else {
			if (i == j) return cast<std::tuple_element_t<i, Fields>, Flow*>(get<i>()); else
			return getFlow_<i + 1>(j);
		}
	}
	void setFlow(Int i, Flow* v) override {
		setFlow_<0>(i, v);
	}
	template<Int i>
	void setFlow_(Int j, Flow* v) {
		if constexpr(i == SIZE) fail("illegal access of field by index"); else {
			if (i == j) set<i>(cast<Flow*, std::tuple_element_t<i, Fields>>(v));
			else setFlow_<i + 1>(j, v);
		}
	}

	Flow* getFlow(String* f) {
		return getFlow(RTTI::structField(Id, f->str)); 
	}
	void setFlow(String* f, Flow* v) {
		setFlow(RTTI::structField(Id, f->str), v);
	}

	template<Int i>
	typename std::tuple_element_t<i, Fields> get() {
		std::tuple_element_t<i, Fields> x = std::get<i>(fields);
		rc(x, +1);
		return x;
	}
	template<Int i>
	void set(typename std::tuple_element_t<i, Fields> v) {
		rc(std::get<i>(fields), -1);
		std::get<i>(fields) = v;
		rc(std::get<i>(fields), +1);
	}
	Int compare_(Str* s) const { return compare_<0>(s); }
	template<Int i>
	Int compare_(Str* s) const {
		if constexpr(i == SIZE) return 0; else {
			Int c = compare<std::tuple_element_t<i, Fields>>(
				std::get<i>(fields), std::get<i>(s->fields)
			);
			if (c != 0) return c;
			compare_<i + 1>(s);
		}
	}

	void toStringStr(string& str) const { 
		str.append(RTTI::typeName(TYPE));
		str.append(u"(");
		toStringArgs<0>(str);
		str.append(u")");
	}
	template<Int i>
	void toStringArgs(string& str) const {
		if constexpr(i < SIZE) {
			if (i > 0) {
				str.append(u", ");
			}
			toString(std::get<i>(fields), str);
			toStringArgs<i + 1>(str);
		}
	}
private:
	Fields fields;
};

template<typename T> 
struct Vec : public Flow {
	enum { TYPE = TypeFx::ARRAY };
	using ElType = T;
	using const_iterator = typename std::vector<T>::const_iterator;
	using iterator = typename std::vector<T>::iterator;

	Vec(): vect() { }
	Vec(std::size_t s): vect() { vect.reserve(s); }
	Vec(std::initializer_list<T>&& il): vect(std::move(il)) { rcVect(+1); }
	Vec(const std::vector<T>& v): vect(v) { rcVect(+1); }
	Vec(std::vector<T>&& v): vect(std::move(v)) { rcVect(+1); }
	Vec(Vec&& a): vect(std::move(a.vect)) { }
	Vec(const Vec& a): vect(a.vect) { rcVect(+1); }
	~Vec() override { rcVect(-1); }
	void rcVect(Int delta) { for (T x : vect) rc(x, delta); }

	Vec& operator = (const Vec& a) {
		rcVect(-1);
		vect.operator=(a.vect);
		rcVect(+1);
		return *this;
	}
	Vec& operator = (Vec&& a) {
		rcVect(-1);
		vect.operator=(std::move(a.vect));
		return *this;
	}
	template<typename... As>
	static Vec* make(As... as) { return new Vec(as...); }
	static Vec* make(std::initializer_list<T>&& il) { return new Vec(std::move(il)); }

	TypeId typeId() const override { return TYPE; }

	// std::vector interface
	const_iterator begin() const { return vect.begin(); }
	const_iterator end() const { return vect.end(); }
	iterator begin() { return vect.begin(); }
	iterator end(){ return vect.end(); }

	// general interface
	Int size() const { 
		return static_cast<Int>(vect.size()); 
	}
	Flow* getFlow(Int i) override { return cast<ElType, Flow*>(get(i)); }
	void setFlow(Int i, Flow* v) override { set(i, cast<Flow*, ElType>(v)); }
	void push_back(ElType x) {
		rc(x, +1);
		vect.push_back(x);
	}

	ElType get(Int i) {
		ElType x = vect.at(i);
		rc(x, +1);
		return x; 
	}
	void set(Int i, ElType x) { 
		rc(vect[i], -1);
		vect[i] = x;
		rc(vect[i], +1);
	}
private:
	std::vector<ElType> vect;
};

template<typename T> 
struct Ref : public Flow {
	enum { TYPE = TypeFx::REF };
	using RefType = T;
	Ref() { }
	Ref(T r): val(r) { rc(val, +1); }
	Ref(const Ref& r): val(r.val) { rc(val, +1); }
	Ref(Ref&& r): val(std::move(r.val)) { }
	~Ref() override { rc(val, -1); }

	Ref& operator = (Ref&& r) {
		rc(val, -1);
		val = std::move(r.val);
		return *this;
	}
	Ref& operator = (const Ref& r) { 
		rc(val, -1);
		val = r.val;
		rc(val, +1); 
		return *this;
	}

	template<typename... As>
	static Ref* make(As... as) { return new Ref(as...); }

	TypeId typeId() const override { return TypeFx::REF; }

	Flow* getFlow(Int i) override { return cast<RefType, Flow*>(get()); }
	void setFlow(Int i, Flow* v) override { set(cast<Flow*, RefType>(v)); }

	// T-specific getter/setter
	T get() {
		rc(val, +1);
		return val; 
	}
	void set(T v) { 
		rc(val, -1);
		val = v;
		rc(val, +1);
	}
private:
	T val;
};

template<typename R, typename... As> 
struct Fun : public Flow, public std::function<R(As...)> {
	enum { TYPE = TypeFx::FUNC, ARITY = sizeof...(As) };
	using RetType = R;
	using Args = std::tuple<As...>;
	using Fn = std::function<R(As...)>;

	Fun() {}
	Fun(Fn&& f): Fn(std::move(f)) { }
	Fun(const Fn& f): Fn(f) { }

	Fun(Fn&& f, Vec<Flow*>&& cl): Fn(std::move(f)), closure(std::move(cl)) { }
	Fun(const Fn& f, const Vec<Flow*>& cl): Fn(f), closure(cl) { }
	Fun(const Fun& f): Fn(f), closure(f.closure) { }
	Fun(Fun&& f): Fn(std::move(f)), closure(std::move(f.closure)) { }

	template<typename... As1>
	static Fun* make(As1... as) { return new Fun(as...); }

	TypeId typeId() const override { return TYPE; }

	inline R call(As... as) const { return Fn::operator()(as...); }
	/*inline R call(Args as) const {
		return [as]<std::size_t... I>(std::index_sequence<I...>)
			{ return call(std::get<I>(as)...); }
			(std::make_index_sequence<ARITY>{});
	}*/
	Flow* callFlow(Flow* as...) override { 
		return cast<R, Flow*>(Fn::operator()(cast<Flow*, As>(as)...)); 
	}
private:
	Vec<Flow*> closure;
};

// Cast templates: from any type to any

template<typename T1, typename T2>
inline T2 cast(T1 x) {
	if constexpr (std::is_same_v<T1, T2>) {
		return x;
	} else if constexpr (std::is_same_v<T2, Void>) {
		if constexpr (std::is_same_v<T1, Void>) { return void_value; }
	} else {
		T2 ret;
		if constexpr (std::is_same_v<T2, Flow*>) {
			if constexpr (std::is_same_v<T1, Bool>) { ret = new FBool(x); }
			else if constexpr (std::is_same_v<T1, Int>) { ret = new FInt(x); }
			else if constexpr (std::is_same_v<T1, Double>) { ret = new FDouble(x); }
			else if constexpr (std::is_same_v<T1, Void>) { ret = new FVoid(); }
			else if constexpr (std::is_same_v<T1, Native*>) {
				try {
					ret = std::any_cast<Flow*>(x->val);
				} catch(const std::bad_any_cast& e) {
					ret = x;
				}
			}
			else if constexpr (std::is_pointer_v<T1>) ret = x;
		}
		else if constexpr (std::is_same_v<T2, Int>) {
			if constexpr (std::is_same_v<T1, Bool>) { ret = bool2int(x); }
			else if constexpr (std::is_same_v<T1, Double>) { ret = double2int(x); }
			else if constexpr (std::is_same_v<T1, String*>) { ret = string2int(x); }
			else if constexpr (std::is_same_v<T1, Flow*>) {
				switch (x->typeId()) {
					case TypeFx::INT:    ret = x->template get<Int>();
					case TypeFx::BOOL:   ret = bool2int(x->template get<Bool>());
					case TypeFx::DOUBLE: ret = double2int(x->template get<Double>());
					case TypeFx::STRING: ret = string2int(x->template get<String*>()->str);
					default:             fail("invalid conversion to int");
				}
			}
			else if constexpr (std::is_same_v<T1, Native*>) {
				try {
					ret = std::any_cast<Int>(x->val);
				} catch(const std::bad_any_cast& e) {
					fail("invalid conversion to int");
				}
			}
		}
		else if constexpr (std::is_same_v<T2, Bool>) {
			if constexpr (std::is_same_v<T1, Int>) { ret = int2bool(x); }
			else if constexpr (std::is_same_v<T1, Double>) { ret = double2bool(x); }
			else if constexpr (std::is_same_v<T1, String*>) { ret = string2bool(x); }
			else if constexpr (std::is_same_v<T1, Flow*>) {
				switch (x->typeId()) {
					case TypeFx::INT:    ret = int2bool(x->template get<Int>());
					case TypeFx::BOOL:   ret = x->template get<Bool>();
					case TypeFx::DOUBLE: ret = double2bool(x->template get<Double>());
					case TypeFx::STRING: ret = string2bool(x->template get<String*>()->str);
					default:             fail("invalid conversion to bool");
				}
			}
			else if constexpr (std::is_same_v<T1, Native*>) {
				try {
					ret = std::any_cast<Bool>(x->val);
				} catch(const std::bad_any_cast& e) {
					fail("invalid conversion to bool");
				}
			}
		}
		else if constexpr (std::is_same_v<T2, Double>) {
			if constexpr (std::is_same_v<T1, Int>) { ret = int2double(x); }
			else if constexpr (std::is_same_v<T1, Bool>) { ret = bool2double(x); }
			else if constexpr (std::is_same_v<T1, String*>) { ret = string2double(x); }
			else if constexpr (std::is_same_v<T1, Flow*>) {
				switch (x->typeId()) {
					case TypeFx::INT:    ret = int2double(x->template get<Int>());
					case TypeFx::BOOL:   ret = bool2double(x->template get<Bool>());
					case TypeFx::DOUBLE: ret = x->template get<Double>();
					case TypeFx::STRING: ret = string2double(x->template get<String*>()->str);
					default:             fail("invalid conversion to double");
				}
			}
			else if constexpr (std::is_same_v<T1, Native*>) {
				try {
					ret = std::any_cast<Double>(x->val);
				} catch(const std::bad_any_cast& e) {
					fail("invalid conversion to double");
				}
			}
		}
		else if constexpr (std::is_same_v<T2, String*>) {
			if constexpr (std::is_same_v<T1, Int>) { ret = int2string(x); }
			else if constexpr (std::is_same_v<T1, Bool>) { ret = bool2string(x); }
			else if constexpr (std::is_same_v<T1, Double>) { ret = double2string(x); }
			else ret = flow2string(x);
		}
		else if constexpr (std::is_same_v<T2, Native*>) {
			if constexpr (std::is_same_v<T1, Flow*>) {
				ret = x;
			} else {
				ret = new Native(x);
			}
		}
		else if constexpr (std::is_pointer_v<T2>) {
			using V2 = std::remove_pointer<T2>::type;
			if constexpr (is_type_v<TypeFx::ARRAY, T2>) {
				if constexpr (std::is_same_v<T1, Flow*>) {
					ret = new V2(x->size());
					for (Int i = 0; i < x->size(); ++ i) {
						ret->push_back(cast<Flow*, typename V2::ElType>(x->getFlow(i)));
					}
				} else {
					using V1 = std::remove_pointer<T1>::type;
					ret = new V2(x->size());
					for (Int i = 0; i < x->size(); ++ i) {
						ret->push_back(cast<typename V1::ElType, typename V2::ElType>(x->get(i)));
					}
				}
			}
			else if constexpr (is_type_v<TypeFx::REF, T2>) {
				if constexpr (std::is_same_v<T1, Flow*>) {
					ret = new V2(cast<Flow*, typename V2::RefType>(x->getFlow(0)));
				} else {
					using V1 = std::remove_pointer<T1>::type;
					T2 ret = new V2(x->size());
					ret = new V2(cast<typename V1::RefType, typename V2::RefType>(x->get()));
				}
			}
			else if constexpr (is_type_v<TypeFx::FUNC, T2>) {
				if constexpr (std::is_same_v<T1, Flow*>) {
					ret = new V2([x](auto... as) mutable {
						return cast<Flow*, typename V2::RetType>(
							x->callFlow(cast<typename V2::ArgTypes, Flow*>(as)...)
						); 
					});
				} else {
					using V1 = std::remove_pointer<T1>::type;
					ret = new V2([x](auto... as) mutable {
						return cast<typename V1::RetType, typename V2::RetType>(
							x->call(cast<typename V2::ArgTypes, typename V1::ArgTypes>(as)...)
						); 
					});
				}
			}
			else if constexpr (is_struct_v<V2>) {
				if constexpr (std::is_same_v<T1, Flow*>) {
					using V2_Fields = typename V2::Fields;
					ret = [x]<std::size_t... I>(std::index_sequence<I...>) { 
						return new V2(
							cast<Flow*, std::tuple_element_t<I, V2_Fields>>(x->get(I))...
						);
					}
					(std::make_index_sequence<V2::SIZE>{});
				} else {
					using V1 = std::remove_pointer<T1>::type;
					using V1_Fields = typename V1::Fields;
					using V2_Fields = typename V2::Fields;
					ret = [x]<std::size_t... I>(std::index_sequence<I...>) { 
						return new V2(
							cast<std::tuple_element_t<I, V1_Fields>, std::tuple_element_t<I, V2_Fields>>(std::get<I>(x->fields))...
						);
					}
					(std::make_index_sequence<V2::SIZE>{});
				}
			} else {
				fail("unknown type");
			}
		}
		//rc(x, -1);
		return ret;
	}
}

// General comparison functions

Int compareFlow(Flow* v1, Flow* v2);

template<typename T>
inline Int compare(T v1, T v2) {
	if (std::is_same_v<T, Void>) return 0;
	else if constexpr (std::is_scalar_v<T> || std::is_same_v<T, void*>) return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0);
	else if constexpr (std::is_same_v<T, Flow*>) return compareFlow(v1, v2);
	else if constexpr (is_type_v<TypeFx::ARRAY, T>) {
		Int c1 = compare<Int>(v1->size(), v2->size());
		if (c1 != 0) {
			return c1;
		} else {
			for (std::size_t i = 0; i < v1->vect.size(); ++ i) {
				Int c2 = compare<typename T::ElType>(v1->get(i), v2->get(i));
				if (c2 != 0) {
					return c2;
				}
			}
			return 0;
		}
	}
	else if constexpr (is_type_v<TypeFx::REF, T>) {
		return compare<typename T::RefType>(v1->get(), v2->get()); 
	}
	else if constexpr (is_type_v<TypeFx::FUNC, T> || is_type_v<TypeFx::NATIVE, T>) {
		return compare<void*>(v1, v2); 
	}
	else if constexpr (is_struct_v<T>) {
		if (!v1) return -1; else
		if (!v2) return 1; else {
			return v1->compare(v2);
		}
	}
	else {
		fail("unknown type");
	}
}

// Convert any value to string

String* flow2string(Flow* f);

template<typename T>
inline String* toString(T v) {
	string str;
	toString(v, str);
	return new String(str);
}

void appendEscaped(String* x, string& str);

template<typename T>
inline void toString(T v, string& str) {
	if (std::is_same_v<T, Void>) str.append(u"{}");
	else if constexpr (std::is_same_v<T, Int>) str.append(int2string(v));
	else if constexpr (std::is_same_v<T, Bool>) str.append(bool2string(v));
	else if constexpr (std::is_same_v<T, Double>) str.append(int2string(v));
	else if constexpr (std::is_same_v<T, String*>) appendEscaped(v, str);
	else if constexpr (std::is_same_v<T, Flow*>) str.append(flow2string(v));
	else if constexpr (is_type_v<TypeFx::ARRAY, T>) {
		str.append(u"[");
		bool first = true;
		for (Int i = 0; i < v->size(); ++i) {
			if (!first) {
				str.append(u", ");
			}
			toString(v->get(i), str);
			first = false;
		}
		str.append(u"]");
	}
	else if constexpr (is_type_v<TypeFx::REF, T>) {
		str.append(u"ref ");
		toString(v->get(), str);
	}
	else if constexpr (is_type_v<TypeFx::FUNC, T>) {
		str.append(u"<function>");
	}
	else if constexpr (is_type_v<TypeFx::NATIVE, T>) {
		str.append(u"<native>");
	}
	else if constexpr (is_struct_v<T>) {
		v->toStringStr(str);
	}
}

template<typename T> inline void show_rc(const char* lab, T x) {
	if constexpr (std::is_pointer_v<T>) {
		String* s = toString(x);
		std::cout << lab << " " << s->toStd() << "->rc = " << x->rc_ << std::endl;
	}
}


}
