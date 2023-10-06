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

//#define CONCURRENCY_ON
//#define ATOMIC_RC

namespace flow {

inline void fail(const std::string& msg) { throw std::runtime_error(msg); }

enum TypeFx {
	VOID = 0, // special void type - technically it is nullptr_t
	INT = 1,   BOOL = 2, DOUBLE = 3, STRING = 4, NATIVE = 5, // primary types
	ARRAY = 6, REF = 7,  FUNC = 8,   STRUCT = 9,             // complex types
	// These types can't be met in runtime, but are used in RTTI markup
	UNKNOWN = -1, FLOW = -2, PARAMETER = -3,
	STRUCT_TYPE_ID_OFFSET = STRUCT
};

// Types with id values < 9 are from TypeFx, others are structs. 

using TypeId = int32_t;
const TypeId structTypeIdOffset = TypeFx::STRUCT_TYPE_ID_OFFSET;

// Flow internally uses utf-16 string format

using string = std::u16string;

// String conversions

void copyString2std(const string& str, std::string& s);
void copyStd2string(const std::string& str, string& s);
void string2ostream(const string& str, std::ostream& os);
void istream2string(std::istream& is, string& str);
inline std::string string2std(const string& str) { std::string s; copyString2std(str, s); return s; }
inline string std2string(const std::string& str) { string s; copyStd2string(str, s); return s; }

// Basic types

using Void = nullptr_t;
const Void void_value = nullptr;

// Scalar types
using Int = int32_t;
using Bool = bool;
using Double = double;


// Basic scalar type conversions

inline Double int2double(Int x) { return x; }
inline Bool int2bool(Int x) { return x != 0; }
string int2string(Int x) noexcept;

inline Int double2int(Double x) { return (x >= 0.0) ? static_cast<Int>(x + 0.5) : static_cast<Int>(x - 0.5); }
inline Bool double2bool(Double x) { return x != 0.0; }
string double2string(Double x, bool persistent_dot = false);

inline Int bool2int(Bool x) { return x ? 1 : 0; }
inline Double bool2double(Bool x) { return x ? 1.0 : 0.0; }
inline string bool2string(Bool x) { return x ? u"true" : u"false"; }

inline Int string2int(const string& s) { if (s.size() == 0) { return 0; } else { try { return std::stoi(string2std(s)); } catch (std::exception& e) { return 0; } } }
inline Double string2double(const string& s) { if (s.size() == 0) { return 0.0; } else { try { return std::stod(string2std(s)); } catch (std::exception& e) { return 0.0; } } }
inline Bool string2bool(const string& s) { return s != u"false"; }

// Runtime type information: structs

struct FieldDef {
	string name;
	TypeId type;
};

struct Flow;
template<typename T>  struct Vec;

struct StructDef {
	string name;
	TypeId type;
	std::vector<FieldDef> args;
	std::function<Flow*(Vec<Flow*>*)> constructor;
};

struct RTTI {
	static const string& typeName(TypeId id) {
		if (id < 0) return type_names[0]; else
		if (id < structTypeIdOffset) return type_names[id + 1]; else
		if (id - structTypeIdOffset < static_cast<TypeId>(struct_defs.size())) {
			return struct_defs.at(id - structTypeIdOffset).name;
		} else {
			return type_names[0];
		}
	}
	static const StructDef& structDef(TypeId id) {
		if (id - structTypeIdOffset < static_cast<TypeId>(struct_defs.size())) {
			return struct_defs.at(id - structTypeIdOffset);
		} else {
			static StructDef undef;
			fail("undefined struct with type id: " + string2std(int2string(id)));
			return undef;
		}
	}
	static int structField(TypeId id, const string& field) {
		int i = 0;
		for (auto& arg : structDef(id).args) {
			if (arg.name == field) break;
			i += 1;
		}
		return i;
	}
	static TypeId structId(const string& struct_name) {
		auto x = struct_name_to_id.find(struct_name);
		if (x == struct_name_to_id.end()) {
			return -1;
		} else {
			return x->second;
		}
	}
	static void initStructMap() {
		for (int i = structTypeIdOffset; i < static_cast<TypeId>(struct_defs.size()) + structTypeIdOffset; ++i) {
			const StructDef& def = struct_defs.at(i - structTypeIdOffset);
			struct_name_to_id[def.name] = i;
		}
	}
private:
	// List of names for the types in TypeFx
	static const string type_names[];
	// Sequence of all struct definitions
	static std::vector<StructDef> struct_defs;
	// Maps a struct name to its id.
	static std::unordered_map<string, int32_t> struct_name_to_id;
};


// Forward declaration of all types

struct Flow;
struct String;
struct Native;
template<TypeId Id, typename... Fs> struct Str;
template<typename T> struct Vec;
template<typename T> struct Ref;
template<typename R, typename... As> struct Fun;

// Union is just a flow.
using Union = Flow;

// Predicate for compile-time type resolution

namespace traits {
	template<typename T> struct get_type_id { enum { result = TypeFx::UNKNOWN }; };
	template<> struct get_type_id<Void> { enum { result = TypeFx::VOID }; };
	template<> struct get_type_id<Int> { enum { result = TypeFx::INT }; };
	template<> struct get_type_id<Bool> { enum { result = TypeFx::BOOL }; };
	template<> struct get_type_id<Double> { enum { result = TypeFx::DOUBLE }; };
	template<> struct get_type_id<String> { enum { result = TypeFx::STRING }; };
	template<> struct get_type_id<Native> { enum { result = TypeFx::NATIVE }; };
	template<> struct get_type_id<Flow> { enum { result = TypeFx::FLOW }; };
	template<typename T> struct get_type_id<Vec<T>> { enum { result = TypeFx::ARRAY }; };
	template<typename T> struct get_type_id<Ref<T>> { enum { result = TypeFx::REF }; };
	template<typename R, typename... As> struct get_type_id<Fun<R, As...>> { enum { result = TypeFx::FUNC }; };
	template<TypeId Id, typename... Fs> struct get_type_id<Str<Id, Fs...>> { enum { result = Id }; };
}
template<typename T> constexpr TypeId get_type_id_v = traits::get_type_id<std::remove_pointer_t<T>>::result;
template<TypeId Id, typename T> constexpr bool is_type_v = get_type_id_v<T> == Id;
template<typename T> constexpr bool is_struct_v = get_type_id_v<T> >= TypeFx::STRUCT_TYPE_ID_OFFSET;
template<typename T> constexpr bool is_struct_or_union_v = is_struct_v<T> || std::is_same_v<Union, std::remove_pointer_t<T>>;
template<typename T> constexpr bool is_flow_ancestor_v = std::is_base_of_v<Flow, std::remove_pointer_t<T>>;
template<typename T> constexpr bool is_scalar_v =
	is_type_v<TypeFx::VOID, T> ||
	is_type_v<TypeFx::INT, T> ||
	is_type_v<TypeFx::BOOL, T> ||
	is_type_v<TypeFx::DOUBLE, T>;

extern std::mutex tmp_out_mutex;

template<typename T> inline void incRc(T x, Int d = 1) {
	if constexpr (is_flow_ancestor_v<T>) {
#ifdef CONCURRENCY_ON
	#ifdef ATOMIC_RC
		std::atomic_ref<long>(x->rc_).fetch_add(d);
	#else
		if (x->rc_ < 0) {
			std::atomic_ref<long>(x->rc_).fetch_sub(d);
		} else {
			x->rc_ += d;
		}
	#endif
#else
		x->rc_ += d;
#endif
	}
}

template<typename T> inline void decRc(T x) {
	if constexpr (is_flow_ancestor_v<T>) {
#ifdef CONCURRENCY_ON
	#ifdef ATOMIC_RC
		if (std::atomic_ref<long>(x->rc_).fetch_sub(1) == 1) {
			delete x;
		}
	#else
		if (x->rc_ < 0) {
			if (std::atomic_ref<long>(x->rc_).fetch_add(1) == -1) {
				delete x;
			}
		} else {
			x->rc_ -= 1;
			if (x->rc_ == 0) {
				delete x;
			}
		}
	#endif
#else
		x->rc_ -= 1;
		if (x->rc_ == 0) {
			delete x;
		} 
#endif
	}
}

template<typename T> inline T decRcReuse(T x) {
	if constexpr (is_flow_ancestor_v<T>) {
#ifdef CONCURRENCY_ON
	#ifdef ATOMIC_RC
		if (std::atomic_ref<long>(x->rc_).fetch_sub(1) == 1) {
			x->unbindChildren();
			return x;
		} else {
			return nullptr;
		}
	#else
		if (x->rc_ < 0) {
			if (std::atomic_ref<long>(x->rc_).fetch_add(1) == -1) {
				x->unbindChildren();
				return x;
			} else {
				return nullptr;
			}
		} else {
			x->rc_ -= 1;
			if (x->rc_ == 0) {
				x->unbindChildren();
				return x;
			} else {
				return nullptr;
			}
		}
	#endif
#else
		x->rc_ -= d;
		if (x->rc_ == 0) {
			x->unbindChildren();
			return x;
		} else {
			return nullptr;
		}
#endif
	}
}

template<typename T> inline void decRcFinish(T x) {
	if constexpr (is_flow_ancestor_v<T>) {
		delete x;
	}
}

template<typename T> inline bool unitRc(T x) {
	return x->rc_ == 1;
}

template<typename T, typename R> inline R decRcRet(T x, R ret) { decRc(x); return ret; }

template<typename T> inline T incRcRet(T x) { incRc(x); return x; }

/* 
	All access methods are divided into three groups:
	- get/set are a plain getters/setters, which don't affect any RCs
	- getRc1/setRc1 always return an object with properly incremented RCs (thus it may be used in RC-calls)
	- getRc/setRc are as getRc1/setRc1, but it also decrements the RC of `this` for an object (or argument, if is used in func)
*/

template<typename T1, typename T2> T2 castRc(T1 x);
template<typename T> Int compareRc(T v1, T v2);
template<typename T> Int compare(T v1, T v2);
template<typename T> inline Bool equalRc(T v1, T v2) { Int c = compareRc(v1, v2); return c == 0; }
template<typename T> inline Bool equal(T v1, T v2) { Int c = compare(v1, v2); return c == 0; }
template<typename T> inline String* toStringRc(T v);
template<typename T> inline String* toString(T v);
template<typename T> inline void toStringRc(T v, string& str);
template<typename T> inline void toString(T v, string& str);
template<typename T> inline T makeDefVal();
template<typename T> inline void assignRc(T& to, T what) {
	if constexpr (is_flow_ancestor_v<T>) {
		T old = to;
		to = what;
		if (old) {
			decRc(old);
		} 
	} else {
		to = what;
	}
}

// Dynamic wrapper for all values 

struct Flow {
	Flow(): rc_(1) {}
	virtual ~Flow() {}
	virtual TypeId typeId() const = 0;
	virtual Int size() const { return 0; }
	virtual TypeId componentTypeId(Int i) { fail("invalid flow value getter"); return TypeFx::UNKNOWN; }
	virtual void unbindChildren() { }
	virtual void makeShared() { rc_ = -rc_; }
	inline bool isShared() { return (rc_ < 0); }
	TypeId typeIdRc() const { return decRcRet(this, typeId()); }
	Int sizeRc() const { return decRcRet(this, size()); }
	
	// these methods decrement `this` RC
	virtual Flow* getFlowRc(Int i) { fail("invalid flow value getter"); return nullptr; }
	virtual void setFlowRc(Int i, Flow* v) { fail("invalid flow value setter"); }
	virtual Flow* getFlowRc(String* f) { fail("invalid flow value getter"); return nullptr; }
	virtual void setFlowRc(String* f, Flow* v) { fail("invalid flow value setter"); }
	virtual Flow* callFlowRc(std::vector<Flow*>) { fail("invalid flow value getter"); return nullptr; }

	// these methods do not affect `this` RC, but return results RC is incremented
	virtual Flow* getFlowRc1(Int i) { fail("invalid flow value getter"); return nullptr; }
	virtual void setFlowRc1(Int i, Flow* v) { fail("invalid flow value setter"); }
	virtual Flow* getFlowRc1(String* f) { fail("invalid flow value getter"); return nullptr; }
	virtual void setFlowRc1(String* f, Flow* v) { fail("invalid flow value setter"); }
	virtual Flow* callFlowRc1(std::vector<Flow*>) { fail("invalid flow value getter"); return nullptr; }

	// these methods do not change any RCs. NODE: only non-scalar components may be accessed this way,
	// attempt to apply this method to a scalar component will cause runtime error
	virtual Flow* getFlow(Int i) { fail("invalid flow value getter"); return nullptr; }
	virtual Flow* getFlow(const string& f) { fail("invalid flow value getter"); return nullptr; }

	template<typename T> inline T get() { return dynamic_cast<T>(this); }
	template<typename T> inline T getRc1() { return incRcRet(dynamic_cast<T>(this)); }
	template<typename T> inline T getRc() { return dynamic_cast<T>(this); }

	mutable long rc_;
};

struct FVoid : public Flow { TypeId typeId() const override { return TypeFx::VOID; } };
struct FInt : public Flow { FInt(Int v): val(v) {} TypeId typeId() const override { return TypeFx::INT; } Int val; };
struct FBool : public Flow { FBool(Bool v): val(v) {} TypeId typeId() const override { return TypeFx::BOOL; } Bool val; };
struct FDouble : public Flow { FDouble(Double v): val(v) {} TypeId typeId() const override { return TypeFx::DOUBLE; } Double val; };

template<> inline Void Flow::getRc<Void>() { return decRcRet(this, void_value); }
template<> inline Int Flow::getRc<Int>() { return decRcRet(this, dynamic_cast<FInt*>(this)->val); }
template<> inline Bool Flow::getRc<Bool>() { return decRcRet(this, dynamic_cast<FBool*>(this)->val); }
template<> inline Double Flow::getRc<Double>() { return decRcRet(this, dynamic_cast<FDouble*>(this)->val); }

template<> inline Void Flow::getRc1<Void>() { return void_value; }
template<> inline Int Flow::getRc1<Int>() { return dynamic_cast<FInt*>(this)->val; }
template<> inline Bool Flow::getRc1<Bool>() { return dynamic_cast<FBool*>(this)->val; }
template<> inline Double Flow::getRc1<Double>() { return dynamic_cast<FDouble*>(this)->val; }

template<> inline Void Flow::get<Void>() { return void_value; }
template<> inline Int Flow::get<Int>() { return dynamic_cast<FInt*>(this)->val; }
template<> inline Bool Flow::get<Bool>() { return dynamic_cast<FBool*>(this)->val; }
template<> inline Double Flow::get<Double>() { return dynamic_cast<FDouble*>(this)->val; }

const Int UNI_HALF_BASE = 0x10000;
const Int UNI_HALF_SHIFT = 10;
const Int UNI_HALF_MASK = 0x3FF;
const Int UNI_SUR_HIGH_START = 0xD800;
const Int UNI_SUR_HIGH_END = 0xDBFF;
const Int UNI_SUR_LOW_START = 0xDC00;
const Int UNI_SUR_LOW_END = 0xDFFF;

struct String : public Flow {
	enum { TYPE = TypeFx::STRING };
	String(): str() { }
	String(const std::string& s): str(std2string(s)) { }
	String(const string& s): str(s) { }
	String(string&& s): str(std::move(s)) { }
	String(const char16_t* s): str(s) { }
	String(const char16_t* s, Int len): str(s, len) { }
	String(char16_t c): str(1, c) { }
	String(Int c) { append(c); }
	String(std::initializer_list<char16_t>&& codes): str(std::move(codes)) { }

	String& operator = (String&& r) = delete;
	String& operator = (const String& r) = delete;

	template<typename... As>
	static String* make(As... as) { return new String(std::move(as)...); }
	static String* make(std::initializer_list<char16_t>&& codes) { return new String(std::move(codes)); }

	static String* makeOrReuse(String* s) {
		if (s == nullptr) {
			return new String();
		} else {
			s->str.clear();
			s->rc_ = 1;
			return s;
		}
	}
	static String* makeOrReuse(String* s, const std::string& x) {
		if (s == nullptr) {
			return new String(x);
		} else {
			s->str.clear();
			copyStd2string(x, s->str);
			s->rc_ = 1;
			return s;
		}
	}
	static String* makeOrReuse(String* s, std::initializer_list<char16_t>&& codes) {
		if (s == nullptr) {
			return new String(std::move(codes));
		} else {
			s->str = codes; 
			s->rc_ = 1;
			return s;
		}
	}

	TypeId typeId() const override { return TypeFx::STRING; }
	std::string toStd() const { return string2std(str); }
	void append(Int c) {
		if (c <= 0xFFFF) {
			str.append(1, static_cast<char16_t>(c));
		} else {
			c -= UNI_HALF_BASE;
			str.append(1, static_cast<char16_t>((c >> UNI_HALF_SHIFT) + UNI_SUR_HIGH_START));
      		str.append(1, static_cast<char16_t>((c & UNI_HALF_MASK) + UNI_SUR_LOW_START));
		}
	}

	string str;
};

inline String* concatStringsRc(String* s1, String* s2) {
	if (unitRc(s1)) {
		s1->str += s2->str;
		decRc(s2);
		return s1;
	} else {
		string ret;
		ret.reserve(s1->str.size() + s2->str.size());
		ret += s1->str;
		ret += s2->str;
		decRc(s1); decRc(s2);
		return new String(std::move(ret));
	}
}

struct Native : public Flow {
	enum { TYPE = TypeFx::NATIVE };
	enum Kind { SCALAR = 0, FLOW_PTR = 1, FOREIGN_PTR = 2 };
	template<typename T>
	Native(T v): cleanup([](){}), share([](){ }), val(v) {
		if constexpr (is_flow_ancestor_v<T>) {
			cleanup = [v]() { decRc(std::any_cast<Flow*>(v)); };
			share   = [v]() { std::any_cast<Flow*>(v)->makeShared(); };
		} else if constexpr (std::is_pointer_v<T>) {
			cleanup = [v]() { delete std::any_cast<T>(v); };
		}
	}
	template<typename T>
	Native(T v, std::function<void()>&& s): cleanup([](){}), share(std::move(s)), val(v) {
		if constexpr (is_flow_ancestor_v<T>) {
			cleanup = [v](){ decRc(std::any_cast<Flow*>(v)); };
		} else if constexpr (std::is_pointer_v<T>) {
			cleanup = [v](){ delete std::any_cast<T>(v); };
		}
	}
	~Native() override {
		cleanup();
	}
	Native& operator = (Native&& r) = delete;
	Native& operator = (const Native& r) = delete;

	TypeId typeId() const override { return TypeFx::NATIVE; }
	void makeShared() override {
		if (!isShared()) {
			Flow::makeShared();
		}
		share();
	}
	template<typename... As> static Native* make(As... as) { return new Native(as...); }
	template<typename T> bool castsTo() {
		try {
			std::any_cast<T>(val);
			return true;
		} catch(const std::bad_any_cast& e) {
			return false;
		}
	}
	template<typename T> inline T getRc() { return decRcRet(this, getRc1<T>()); }
	template<typename T> inline T getRc1() { return incRcRet(get<T>()); }
	template<typename T> inline T get() {
		try {
			return std::any_cast<T>(val);
		} catch(const std::bad_any_cast& e) { 
			fail("incorrect type in native");
		}
	}
private:
	std::function<void()> cleanup;
	std::function<void()> share;
	std::any val;
};

// Any particular struct

template<TypeId Id, typename... Fs>
struct Str : public Flow {
	enum { TYPE = Id, SIZE = sizeof...(Fs) };
	using Fields = std::tuple<Fs...>;
	Str(Fs... fs): fields(fs...) { }
	~Str() override { decRcFields<0>(); }

	template<typename S>
	static S make(Fs... fs) {
		return new std::remove_pointer_t<S>(std::move(fs)...);
	}
	template<typename S>
	static S makeOrReuse(S s, Fs... fs) {
		if (s == nullptr) {
			return new std::remove_pointer_t<S>(std::move(fs)...);
		} else {
			s->fields = std::tie(fs...);
			s->rc_ = 1;
			return s;
		}
	}

	Str& operator = (Str&& r) = delete;
	Str& operator = (const Str& r) = delete;

	// general interface
	TypeId typeId() const override { return TYPE; }
	Int size() const override { return sizeof...(Fs); }
	TypeId componentTypeId(Int i) override {
		return componentTypeId_<0>(i);
	}
	void unbindChildren() override { 
		decRcFields<0>();
		resetFields<0>();
	}
	void makeShared() override {
		if (!isShared()) {
			Flow::makeShared();
			makeSharedFields<0>();
		}
	}

	Flow* getFlowRc(Int i) override {
		return decRcRet(this, getFlowRc1(i));
	}
	void setFlowRc(Int i, Flow* v) override {
		setFlowRc1(i, v);
		decRc(this);
	}
	Flow* getFlowRc(String* f) override {
		int field_idx = RTTI::structField(Id, f->str);
		decRc(f);
		return getFlowRc(field_idx);
	}
	void setFlowRc(String* f, Flow* v) override {
		int field_idx = RTTI::structField(Id, f->str);
		decRc(f);
		setFlowRc(field_idx, v);
	}

	Flow* getFlowRc1(Int i) override {
		return getFlowRc1_<0>(i);
	}
	void setFlowRc1(Int i, Flow* v) override {
		setFlowRc1_<0>(i, v);
	}
	Flow* getFlowRc1(String* f) override {
		int field_idx = RTTI::structField(Id, f->str);
		decRc(f);
		return getFlowRc1(field_idx); 
	}
	void setFlowRc1(String* f, Flow* v) override {
		int field_idx = RTTI::structField(Id, f->str);
		decRc(f);
		setFlowRc1(field_idx, v);
	}

	Flow* getFlow(Int i) override {
		return getFlow_<0>(i);
	}
	Flow* getFlow(const string& f) override {
		int field_idx = RTTI::structField(Id, f);
		return getFlow(field_idx); 
	}

	// specific methods
	template<Int i>
	typename std::tuple_element_t<i, Fields> getRc() {
		std::tuple_element_t<i, Fields> f = getRc1<i>();
		decRc(this);
		return f;
	}
	template<Int i>
	void setRc(typename std::tuple_element_t<i, Fields> v) {
		setRc1<i>(v);
		decRc(this);
	}
	template<Int i>
	inline typename std::tuple_element_t<i, Fields> getRc1() {
		return incRcRet(get<i>());
	}
	template<Int i>
	inline void setRc1(typename std::tuple_element_t<i, Fields> v) {
		set<i>(v);
	}
	template<Int i>
	inline typename std::tuple_element_t<i, Fields> get() {
		return std::get<i>(fields);
	}
	template<Int i>
	inline void set(typename std::tuple_element_t<i, Fields> v) {
		assignRc<typename std::tuple_element_t<i, Fields>>(std::get<i>(fields), v);
	}

	Int compareRc(Str* s) {
		Int c = compareRc<0>(s);
		decRc(s);
		decRc(this);
		return c;
	}
	Int compare(Str* s) {
		return compare<0>(s);
	}
	void toStringStrRc(string& str) {
		str.append(RTTI::typeName(TYPE));
		str.append(u"(");
		toStringArgsRc<0>(str);
		str.append(u")");
	}
	void toStringStr(string& str) {
		str.append(RTTI::typeName(TYPE));
		str.append(u"(");
		toStringArgs<0>(str);
		str.append(u")");
	}

private:
	template<Int i>
	void incRcFields() {
		if constexpr(i < SIZE) {
			incRc(std::get<i>(fields));
			incRcFields<i + 1>();
		}
	}
	template<Int i>
	void decRcFields() {
		if constexpr(i < SIZE) {
			if constexpr (is_flow_ancestor_v<std::tuple_element_t<i, Fields>>) {
				if (std::tuple_element_t<i, Fields> v = std::get<i>(fields)) {
					decRc(v);
				}
			}
			decRcFields<i + 1>();
		}
	}
	template<Int i>
	void resetFields() {
		if constexpr(i < SIZE) {
			if constexpr (is_flow_ancestor_v<std::tuple_element_t<i, Fields>>) {
				std::get<i>(fields) = nullptr;
			}
			resetFields<i + 1>();
		}
	}
	template<Int i>
	void makeSharedFields() {
		if constexpr(i < SIZE) {
			if constexpr (is_flow_ancestor_v<std::tuple_element_t<i, Fields>>) {
				std::get<i>(fields)->makeShared();
			}
			makeSharedFields<i + 1>();
		}
	}
	template<Int i>
	Flow* getFlowRc1_(Int j) {
		if constexpr(i == SIZE) {
			fail("illegal access of field by index");
			return nullptr;
		} else {
			if (i == j) {
				return castRc<std::tuple_element_t<i, Fields>, Flow*>(getRc1<i>()); 
			} else {
				return getFlowRc1_<i + 1>(j);
			}
		}
	}
	template<Int i>
	void setFlowRc1_(Int j, Flow* v) {
		if constexpr(i == SIZE) {
			fail("illegal access of field by index");
		} else {
			if (i == j) {
				setRc1<i>(castRc<Flow*, std::tuple_element_t<i, Fields>>(v));
			} else {
				setFlowRc1_<i + 1>(j, v);
			}
		}
	}
	template<Int i>
	Flow* getFlow_(Int j) {
		if constexpr(i == SIZE) {
			fail("illegal access of field by index");
			return nullptr;
		} else {
			if (i == j) {
				if constexpr (is_flow_ancestor_v<std::tuple_element_t<i, Fields>>) {
					return get<i>(); 
				} else {
					fail("only flow ancestor fields may be accessed directly as Flow");
				}
			} else {
				return getFlow_<i + 1>(j);
			}
		}
	}
	template<Int i>
	TypeId componentTypeId_(Int j) {
		if constexpr(i == SIZE) return TypeFx::UNKNOWN; else {
			if (i == j) {
				return get_type_id_v<std::tuple_element_t<i, Fields>>;
			}
			return componentTypeId_<i + 1>(j);
		}
	}
	template<Int i>
	Int compareRc(Str* s) {
		if constexpr(i == SIZE) return 0; else {
			Int c = flow::compareRc<std::tuple_element_t<i, Fields>>(
				getRc1<i>(), s->getRc1<i>()
			);
			if (c != 0) return c;
			return compareRc<i + 1>(s);
		}
	}
	template<Int i>
	Int compare(Str* s) {
		if constexpr(i == SIZE) return 0; else {
			Int c = flow::compare<std::tuple_element_t<i, Fields>>(
				get<i>(), s->get<i>()
			);
			if (c != 0) return c;
			return compare<i + 1>(s);
		}
	}
	template<Int i>
	void toStringArgsRc(string& str) {
		if constexpr(i < SIZE) {
			if constexpr (i > 0) {
				str.append(u", ");
			}
			toStringRc(getRc1<i>(), str);
			toStringArgsRc<i + 1>(str);
		} else {
			decRc(this);
		}
	}
	template<Int i>
	void toStringArgs(string& str) {
		if constexpr(i < SIZE) {
			if constexpr (i > 0) {
				str.append(u", ");
			}
			toString(get<i>(), str);
			toStringArgs<i + 1>(str);
		}
	}
	Fields fields;
};

template<typename T> 
struct Vec : public Flow {
	enum { TYPE = TypeFx::ARRAY };
	using ElType = T;
	using const_iterator = typename std::vector<T>::const_iterator;
	using iterator = typename std::vector<T>::iterator;

	Vec(): vect() { }
	Vec(std::initializer_list<T>&& il): vect(std::move(il)) { }
	Vec(const std::initializer_list<T>& il): vect(il) { }
	Vec(Vec&& a): vect(std::move(a.vect)) { }
	Vec(const Vec& a): vect(a.vect) { incRcVec(); }
	Vec(std::vector<T>&& v): vect(std::move(v)) { }

	~Vec() override { decRcVec(); }
	inline void incRcVec() {
		if constexpr (is_flow_ancestor_v<T>) {
			for (T x : vect) {
				incRc(x);
			}
		}
	}
	inline void decRcVec() {
		if constexpr (is_flow_ancestor_v<T>) {
			for (T x : vect) {
				decRc(x);
			}
		}
	}

	Vec& operator = (Vec&& r) = delete;
	Vec& operator = (const Vec& r) = delete;

	template<typename... As>
	static Vec* make(As... as) { return new Vec(std::move(as)...); }
	static Vec* make(std::initializer_list<T>&& il) { return new Vec(std::move(il)); }

	static Vec* makeOrReuse(Vec* v) {
		if (v == nullptr) {
			return new Vec();
		} else {
			v->rc_ = 1;
			return v;
		}
	}
	static Vec* makeOrReuse(Vec* v, std::initializer_list<T>&& il) {
		if (v == nullptr) {
			return new Vec(std::move(il));
		} else {
			v->vect = il;
			/*v->vect.reserve(il.size());
			for (T x: il) {
				v->vect.push_back(x);
			}*/
			v->rc_ = 1;
			return v;
		}
	}

	void reserve(std::size_t s) { vect.reserve(s); }

	// std::vector interface
	const_iterator begin() const { return vect.begin(); }
	const_iterator end() const { return vect.end(); }
	iterator begin() { return vect.begin(); }
	iterator end(){ return vect.end(); }

	// general interface
	TypeId typeId() const override { return TYPE; }
	Int size() const override { 
		return static_cast<Int>(vect.size()); 
	}
	TypeId componentTypeId(Int i) override {
		return get_type_id_v<T>;
	}
	void unbindChildren() override {
		vect.clear();
	}
	void makeShared() override {
		if (!isShared()) {
			Flow::makeShared();
			if constexpr (is_flow_ancestor_v<T>) {
				for (T x : vect) {
					x->makeShared();
				}
			}
		}
	}

	Flow* getFlowRc(Int i) override { 
		return castRc<T, Flow*>(getRc(i));
	}
	void setFlowRc(Int i, Flow* v) override {
		setRc(i, castRc<Flow*, T>(v));
	}
	Flow* getFlowRc1(Int i) override { 
		return castRc<T, Flow*>(getRc1(i)); 
	}
	void setFlowRc1(Int i, Flow* v) override { 
		setRc1(i, castRc<Flow*, T>(v));
	}
	Flow* getFlow(Int i) override {
		if constexpr (is_flow_ancestor_v<T>) {
			return vect[i];
		} else {
			fail("only flow ancestor components may be accessed directly as Flow");
		}
	}

	// specific methods
	void pushBack(T x) {
		vect.push_back(x);
	}
	void pushBackRc(T x) {
		pushBack(x);
		decRc(this);
	}
	T getRc(Int i) {
		return decRcRet(this, getRc1(i));
	}
	void setRc(Int i, T x) {
		setRc1(i, x);
		decRc(this);
	}
	inline T getRc1(Int i) {
		return incRcRet(vect.at(i));
	}
	inline void setRc1(Int i, T x) {
		set(i, x);
	}
	inline T get(Int i) {
		return vect.at(i);
	}
	inline void set(Int i, ElType x) {
		//
		//assignRc<T>(vect[i], x);
		T old = vect[i];
		vect[i] = x;
		decRc(old);
	}
	void shrink() {
		vect.shrink_to_fit();
	}
	std::vector<T>& getVect() { return vect; }
private:
	std::vector<T> vect;
};

template<typename T> 
struct Ref : public Flow {
	enum { TYPE = TypeFx::REF };
	using RefType = T;
	Ref() { }
	Ref(T r): val(r) { }
	Ref(const Ref& r): val(r.val) { incRc(val); }
	Ref(Ref&& r): val(std::move(r.val)) { }
	~Ref() override { 
		if constexpr (is_flow_ancestor_v<T>) {
			if (val) {
				decRc(val);
			}
		}
	}

	Ref& operator = (Ref&& r) = delete;
	Ref& operator = (const Ref& r) = delete;

	template<typename... As>
	static Ref* make(As... as) { return new Ref(std::move(as)...); }
	template<typename A>
	static Ref* makeOrReuse(Ref* r, A a) {
		if (r == nullptr) {
			return new Ref(std::move(a));
		} else {
			r->val = a;
			r->rc_ = 1;
			return r;
		}
	}

	// general interface
	TypeId typeId() const override { return TypeFx::REF; }
	Int size() const override { return 1; }
	TypeId componentTypeId(Int i) override {
		return get_type_id_v<T>;
	}
	void unbindChildren() override {
		if constexpr (is_flow_ancestor_v<T>) {
			decRc(val);
			val = nullptr;
		}
	}
	void makeShared() override {
		if (!isShared()) {
			Flow::makeShared();
			if constexpr (is_flow_ancestor_v<T>) {
				val->makeShared();
			}
		}
	}

	Flow* getFlowRc(Int i) override { 
		return castRc<RefType, Flow*>(getRc()); 
	}
	void setFlowRc(Int i, Flow* v) override {
		setRc(castRc<Flow*, RefType>(v));
	}
	Flow* getFlowRc1(Int i) override { 
		return castRc<RefType, Flow*>(getRc1()); 
	}
	void setFlowRc1(Int i, Flow* v) override {
		setRc1(castRc<Flow*, RefType>(v));
	}
	Flow* getFlow(Int i) override {
		if constexpr (is_flow_ancestor_v<T>) {
			return val;
		} else {
			fail("only flow ancestor components may be accessed directly as Flow");
		}
	}

	// specific methods
	inline T getRc() {
		return decRcRet(this, getRc1());
	}
	inline void setRc(T v) {
		setRc1(v);
		decRc(this);
	}
	inline T getRc1() {
		return incRcRet(get());
	}
	inline void setRc1(T v) {
		set(v);
	}
	inline T get() {
		return val;
	}
	inline void set(T v) {
		assignRc<T>(val, v);
	}
	inline T& getVal() {
		return val;
	}
private:
	T val;
};

template<typename R, typename... As> 
struct Fun : public Flow {
	enum { TYPE = TypeFx::FUNC, ARITY = sizeof...(As) };
	using RetType = R;
	using Args = std::tuple<As...>;
	using Fn = std::function<R(As...)>;
	using Fn1 = std::function<R(Args)>;

	Fun() {}
	Fun(Fn&& f): fn(std::move(f)) { }
	Fun(const Fn& f): fn(f) { }
	Fun(const Fn1& f): fn(f) { }

	template<typename... Cs>
	Fun(Fn&& f, Cs... cl): fn(std::move(f)) {
		initClosure<Cs...>(cl...);
	}
	template<typename C1, typename... Cs>
	constexpr void initClosure(C1 c1, Cs... cl) {
		static_assert(is_flow_ancestor_v<C1> || is_scalar_v<C1>, "illegal type in closure");
		if constexpr (is_flow_ancestor_v<C1>) {
			closure.push_back(c1);
		}
		initClosure<Cs...>(cl...);
	}
	template<typename... Cs> constexpr void initClosure(Cs...) { }

	~Fun() {
		for (Flow* x: closure) {
			decRc(x);
		}
	}

	Fun(const Fun& f): fn(f), closure(f.closure) { }
	Fun(Fun&& f): fn(std::move(f)), closure(std::move(f.closure)) { }

	Fun& operator = (Fun&& r) = delete;
	Fun& operator = (const Fun& r) = delete;

	template<typename... As1>
	static Fun* make(As1... as) { return new Fun(std::move(as)...); }
	template<typename F, typename... Cs>
	static Fun* makeOrReuse(Fun* f, F fn, Cs... cl) {
		if (f == nullptr) {
			return new Fun(std::move(fn), std::move(cl)...);
		} else {
			f->fn = std::move(fn);
			f->initClosure<Cs...>(std::move(cl)...);
			f->rc_ = 1;
			return f;
		}
	}

	// general interface
	TypeId typeId() const override { return TYPE; }
	Int size() const override {
		return static_cast<Int>(closure.size());
	}
	void unbindChildren() override {
		closure.clear();
	}
	void makeShared() override {
		if (!isShared()) {
			Flow::makeShared();
			for (Flow* x: closure) {
				x->makeShared();
			}
		}
	}

	Flow* callFlowRc(std::vector<Flow*> as) override {
		if (ARITY == as.size()) {
			return [this, as]<std::size_t... I>(std::index_sequence<I...>) {
				return castRc<R, Flow*>(callRc(
					castRc<Flow*, std::tuple_element_t<I, Args>>(as.at(I))...
				));
			}
			(std::make_index_sequence<ARITY>{});
		} else {
			fail("wrong function arity");
			return void_value;
		}
	}
	Flow* callFlowRc1(std::vector<Flow*> as) override { 
		if (ARITY == as.size()) {
			return [this, as]<std::size_t... I>(std::index_sequence<I...>) { 
				return castRc<R, Flow*>(callRc1(
					castRc<Flow*, std::tuple_element_t<I, Args>>(as.at(I))...
				));
			}
			(std::make_index_sequence<ARITY>{});
		} else {
			fail("wrong function arity");
			return void_value;
		}
	}

	// specific methods
	inline R callRc(As... as) {
		return decRcRet(this, callRc1(as...));
	}
	inline R callRc1(As... as) {
		return call(as...);
	}
	virtual R call(As... as) {
		for (Flow* x: closure) {
			incRc(x);
		}
		return fn(as...);
	}

private:
	Fn fn;
	std::vector<Flow*> closure;
};

// This function is for debugging purposes only! Doesn't cleanp v!
template<typename T>
inline std::string toStdString(T v) {
	string str;
	toString(v, str);
	return string2std(str);
}

// Cast templates: from any type to any

template<typename T1, typename T2>
inline T2 castRc(T1 x) {
	if constexpr (std::is_same_v<T1, T2>) {
		return x;
	} 
	else if constexpr (std::is_same_v<T2, Void>) {
		if constexpr (std::is_same_v<T1, Void>) { return void_value; }
		else { decRc(x); return void_value; }
	} 
	else if constexpr (std::is_same_v<T2, Flow*>) {
		if constexpr (std::is_same_v<T1, Bool>) { return new FBool(x); }
			else if constexpr (std::is_same_v<T1, Int>) { return new FInt(x); }
			else if constexpr (std::is_same_v<T1, Double>) { return new FDouble(x); }
			else if constexpr (std::is_same_v<T1, Void>) { return new FVoid(); }
			else if constexpr (std::is_same_v<T1, Native*>) {
				if (x->template castsTo<Flow*>()) {
					return x->template getRc<Flow*>();
				} else {
					return x;
				}
			}
			else if constexpr (is_flow_ancestor_v<T1>) {
				return x; 
			}
	} 
	else if constexpr (std::is_same_v<T2, Int>) {
		if constexpr (std::is_same_v<T1, Bool>) { return bool2int(x); }
		else if constexpr (std::is_same_v<T1, Double>) { return double2int(x); }
		else if constexpr (std::is_same_v<T1, String*>) { return string2int(x); }
		else if constexpr (std::is_same_v<T1, Flow*>) {
			switch (x->typeId()) {
				case TypeFx::INT:    return x->template getRc<Int>();
				case TypeFx::BOOL:   return bool2int(x->template getRc<Bool>());
				case TypeFx::DOUBLE: return double2int(x->template getRc<Double>());
				case TypeFx::STRING: { Int ret = string2int(x->template get<String*>()->str); decRc(x); return ret; }
				default:             fail("invalid conversion to int");
			}
		}
		else if constexpr (std::is_same_v<T1, Native*>) {
			return x->template getRc<Int>();
		}
	}
	else if constexpr (std::is_same_v<T2, Bool>) {
		if constexpr (std::is_same_v<T1, Int>) { return int2bool(x); }
		else if constexpr (std::is_same_v<T1, Double>) { return double2bool(x); }
		else if constexpr (std::is_same_v<T1, String*>) { return string2bool(x); }
		else if constexpr (std::is_same_v<T1, Flow*>) {
			switch (x->typeId()) {
				case TypeFx::INT:    return int2bool(x->template getRc<Int>());
				case TypeFx::BOOL:   return x->template getRc<Bool>();
				case TypeFx::DOUBLE: return double2bool(x->template getRc<Double>());
				case TypeFx::STRING: { Bool ret = string2bool(x->template get<String*>()->str); decRc(x); return ret; }
				default:             fail("invalid conversion to bool");
			}
		}
		else if constexpr (std::is_same_v<T1, Native*>) {
			return x->template getRc<Bool>();
		}
	}
	else if constexpr (std::is_same_v<T2, Double>) {
		if constexpr (std::is_same_v<T1, Int>) { return int2double(x); }
		else if constexpr (std::is_same_v<T1, Bool>) { return bool2double(x); }
		else if constexpr (std::is_same_v<T1, String*>) { return string2double(x); }
		else if constexpr (std::is_same_v<T1, Flow*>) {
			switch (x->typeId()) {
				case TypeFx::INT:    return int2double(x->template getRc<Int>());
				case TypeFx::BOOL:   return bool2double(x->template getRc<Bool>());
				case TypeFx::DOUBLE: return x->template getRc<Double>();
				case TypeFx::STRING: { Double ret = string2double(x->template get<String*>()->str); decRc(x); return ret; }
				default:             fail("invalid conversion to double");
			}
		}
		else if constexpr (std::is_same_v<T1, Native*>) {
			return x->template getRc<Double>();
		}
	}
	else if constexpr (std::is_same_v<T2, String*>) {
		if constexpr (std::is_same_v<T1, Int>) { return String::make(int2string(x)); }
		else if constexpr (std::is_same_v<T1, Bool>) { return String::make(bool2string(x)); }
		else if constexpr (std::is_same_v<T1, Double>) { return String::make(double2string(x)); }
		else if constexpr (std::is_same_v<T1, Flow*>) {
			if (x->typeId() == TypeFx::STRING) {
				return x->template getRc<String*>();
			} else {
				return flow2stringRc(x);
			}
		} else {
			return flow2stringRc(x);
		}
	}
	else if constexpr (std::is_same_v<T2, Native*>) {
		return Native::make(x);
	}
	else if constexpr (is_type_v<TypeFx::ARRAY, T2>) {
		using V2 = std::remove_pointer<T2>::type;
		if constexpr (is_type_v<TypeFx::ARRAY, T1>) {
			T2 ret = V2::make();
			ret->reserve(x->size());
			using V1 = std::remove_pointer<T1>::type;
			for (auto e : *x) {
				incRc(e);
				ret->pushBack(castRc<typename V1::ElType, typename V2::ElType>(e));
			}
			decRc(x);
			return ret;
		} else if (T2 f = dynamic_cast<T2>(x)) {
			return f;
		} else {
			T2 ret = V2::make();
			ret->reserve(x->size());
			for (Int i = 0; i < x->size(); ++ i) {
				Flow* e = x->getFlowRc1(i);
				ret->pushBack(castRc<Flow*, typename V2::ElType>(e));
			}
			decRc(x);
			return ret;
		}
	}
	else if constexpr (is_type_v<TypeFx::REF, T2>) {
		using V2 = std::remove_pointer<T2>::type;
		if constexpr (is_type_v<TypeFx::REF, T1>) {
			using V1 = std::remove_pointer<T1>::type;
			return new V2(castRc<typename V1::RefType, typename V2::RefType>(x->getRc()));
		} else if (T2 f = dynamic_cast<T2>(x)) {
			return f;
		} else {
			return new V2(castRc<Flow*, typename V2::RefType>(x->getFlowRc(0)));
		}
	}
	else if constexpr (is_type_v<TypeFx::FUNC, T2>) {
		using V2 = std::remove_pointer<T2>::type;
		if constexpr (is_type_v<TypeFx::FUNC, T1>) {
			using V1 = std::remove_pointer<T1>::type;
			T2 ret = [x]<std::size_t... I>(std::index_sequence<I...>) constexpr { 
				return new V2([x](std::tuple_element_t<I, typename V2::Args>... as) mutable {
					return castRc<typename V1::RetType, typename V2::RetType>(x->callFlowRc(
						castRc<
							std::tuple_element_t<I, typename V2::Args>, 
							std::tuple_element_t<I, typename V1::Args>
						>(std::get<I>(as))...
					));
				}, {});
			}
			(std::make_index_sequence<V2::ARITY>{});
			decRc(x);
			return ret;
		} 
		else if (T2 f = dynamic_cast<T2>(x)) {
			return f;
		} else {
			T2 ret = [x]<std::size_t... I>(std::index_sequence<I...>) constexpr { 
				return new V2([x](std::tuple_element_t<I, typename V2::Args>... as) mutable {
					std::vector<Flow*> as_vect {castRc<std::tuple_element_t<I, typename V2::Args>, Flow*>(as)...};
					return castRc<Flow*, typename V2::RetType>(x->callFlowRc(as_vect));
				}, x);
			}
			(std::make_index_sequence<V2::ARITY>{});
			decRc(x);
			return ret;
		}
	}
	else if constexpr (is_struct_v<T2>) {
		using V2 = std::remove_pointer<T2>::type;
		if constexpr (is_struct_v<T1>) {
			using V1 = std::remove_pointer<T1>::type;
			using V1_Fields = typename V1::Fields;
			using V2_Fields = typename V2::Fields;
			T2 ret = [x]<std::size_t... I>(std::index_sequence<I...>) constexpr { 
				return new V2(
					castRc<
						std::tuple_element_t<I, V1_Fields>, 
						std::tuple_element_t<I, V2_Fields>
					>(x->template getRc1<I>())...
				);
			}
			(std::make_index_sequence<V2::SIZE>{});
			decRc(x);
			return ret;
		} else if (T2 f = dynamic_cast<T2>(x)) {
			return f;
		} else {
			using V2_Fields = typename V2::Fields;
			T2 ret = [x]<std::size_t... I>(std::index_sequence<I...>) constexpr { 
				return new V2(
					castRc<Flow*, std::tuple_element_t<I, V2_Fields>>(x->getFlowRc1(I))...
				);
			}
			(std::make_index_sequence<V2::SIZE>{});
			decRc(x);
			return ret;
		}
	}
}

// General comparison functions

Int flowCompare(Flow* v1, Flow* v2);

inline Int flowCompareRc(Flow* v1, Flow* v2) {
	Int c = flowCompare(v1, v2);
	decRc(v1); decRc(v2);
	return c;
}

template<typename T>
inline Int compareRc(T v1, T v2) {
	Int ret = compare(v1, v2);
	decRc(v1); decRc(v2);
	return ret;
}

template<typename T>
inline Int compare(T v1, T v2) {
	if constexpr (std::is_same_v<T, Void>) return true;
	else if constexpr (std::is_same_v<T, void*>) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); }
	else if constexpr (std::is_same_v<T, Int>) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); }
	else if constexpr (std::is_same_v<T, Bool>) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); }
	else if constexpr (std::is_same_v<T, Double>) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); }
	else if constexpr (std::is_same_v<T, Flow*>) { return flowCompare(v1, v2); }
	else if constexpr (std::is_same_v<T, String*>) { return v1->str.compare(v2->str); }
	else if constexpr (std::is_same_v<T, Native*>) { return compare<void*>(v1, v2); }
	else if constexpr (is_type_v<TypeFx::ARRAY, T>) {
		Int c1 = compare<Int>(v1->size(), v2->size());
		if (c1 != 0) {
			return c1;
		} else {
			for (Int i = 0; i < v1->size(); ++ i) {
				Int c2 = compare<typename std::remove_pointer<T>::type::ElType>(v1->get(i), v2->get(i));
				if (c2 != 0) {
					return c2;
				}
			}
			return 0;
		}
	}
	else if constexpr (is_type_v<TypeFx::REF, T>) {
		return compare<typename std::remove_pointer<T>::type::RefType>(v1->get(), v2->get());
	}
	else if constexpr (is_type_v<TypeFx::FUNC, T> || is_type_v<TypeFx::NATIVE, T>) {
		return compare<void*>(v1, v2);
	}
	else if constexpr (is_struct_v<T>) {
		if (v1 == void_value) {
			return -1;
		} else if (v2 == void_value) {
			return 1;
		} else {
			return v1->compare(v2);
		}
	} else {
		fail("illegal compare type");
		return false;
	}
}

// Convert any value to string

void flow2string(Flow* v, string& str);

inline String* flow2stringRc(Flow* f) {
	string os; 
	flow2string(f, os);
	decRc(f);
	return new String(os); 
}

template<typename T>
inline String* toStringRc(T v) {
	string str;
	toString(v, str);
	decRc(v);
	return String::make(str);
}

template<typename T>
inline String* toString(T v) {
	string str;
	toString(v, str);
	return String::make(str);
}

void appendEscaped(string& str, const string& x);

template<typename T>
inline void toString(T v, string& str) {
	if constexpr (std::is_same_v<T, Void>) { str.append(u"{}"); }
	else if constexpr (std::is_same_v<T, Int>) { str.append(int2string(v)); }
	else if constexpr (std::is_same_v<T, Bool>) { str.append(bool2string(v)); }
	else if constexpr (std::is_same_v<T, Double>) { str.append(double2string(v, true)); }
	else if constexpr (std::is_same_v<T, String*>) {
		str.append(u"\""); appendEscaped(str, v->str); str.append(u"\"");
	}
	else if constexpr (std::is_same_v<T, Flow*>) { flow2string(v, str); }
	else if constexpr (is_type_v<TypeFx::ARRAY, T>) {
		str.append(u"[");
		Int size = v->size();
		for (Int i = 0; i < size; ++i) {
			if (i > 0) {
				str.append(u", ");
			}
			toString(v->get(i), str);
		}
		str.append(u"]");
	}
	else if constexpr (is_type_v<TypeFx::REF, T>) {
		str.append(u"ref ");
		toString(v->get(), str);
	}
	else if constexpr (is_type_v<TypeFx::FUNC, T>) {
		decRc(v);
		str.append(u"<function>");
	}
	else if constexpr (is_type_v<TypeFx::NATIVE, T>) {
		decRc(v);
		str.append(u"<native>");
	}
	else if constexpr (is_struct_v<T>) {
		v->toStringStr(str);
	}
}

template<typename T>
inline T makeDefVal() {
	if constexpr (std::is_same_v<T, Void>) return void_value;
	else if constexpr (std::is_same_v<T, Int>) return 0;
	else if constexpr (std::is_same_v<T, Bool>) return false;
	else if constexpr (std::is_same_v<T, Double>) return 0.0;
	else if constexpr (std::is_same_v<T, String*>) return String::make();
	else if constexpr (std::is_same_v<T, Flow*>) return String::make();
	else if constexpr (is_type_v<TypeFx::ARRAY, T>) return T::make();
	else if constexpr (is_type_v<TypeFx::REF, T>) return T::make(makeDefVal<typename T::RefType>());
	else if constexpr (is_type_v<TypeFx::FUNC, T>) {
		using F = std::remove_pointer_t<T>;
		return []<std::size_t... I>(std::index_sequence<I...>) constexpr { 
			return F::make([](std::tuple_element_t<I, typename F::Args>... as) mutable {
				return makeDefVal<typename F::RetType>();
			}, {});
		}
		(std::make_index_sequence<F::ARITY>{});
	}
	else if constexpr (is_type_v<TypeFx::NATIVE, T>) return Native::make(String::make());
	else if constexpr (is_struct_v<T>) {
		using S = std::remove_pointer_t<T>;
		return []<std::size_t... I>(std::index_sequence<I...>) constexpr { 
			return S::make(makeDefVal<std::tuple_element_t<I, typename S::Fields>>()...);
		}
		(std::make_index_sequence<S::SIZE>{});
	}
}

template<typename T>
inline T makeDefInit() {
	if constexpr (std::is_same_v<T, Void>) return void_value;
	else if constexpr (std::is_same_v<T, Int>) return 0;
	else if constexpr (std::is_same_v<T, Bool>) return false;
	else if constexpr (std::is_same_v<T, Double>) return 0.0;
	else return nullptr;
}

void cleanupAtExit();

}
