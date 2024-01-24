#pragma once

#include "__flow_runtime_refcounter.hpp"

namespace flow {

/* 
	All access methods are divided into three groups:
	- get/set are a plain getters/setters, which don't affect any RCs
	- getRc1/setRc1 always return an object with properly incremented RCs (thus it may be used in RC-calls)
	- getRc/setRc are as getRc1/setRc1, but it also decrements the RC of `this` for an object (or argument, if is used in func)
*/

template<typename T1, typename T2> T2 castRc(T1 x);

Int flowCompare(Flow* v1, Flow* v2);
template<typename T> Int compare(T v1, T v2);
template<typename T> Int compareRc(T v1, T v2) { Int ret = compare(v1, v2); decRc(v1); decRc(v2); return ret; }
template<typename T> inline Bool equalRc(T v1, T v2) { Int c = compareRc(v1, v2); return c == 0; }
template<typename T> inline Bool equal(T v1, T v2) { Int c = compare(v1, v2); return c == 0; }

template<typename T> inline void toStringRc(T v, string& s) { append2string(s, v); decRc(v); }
template<typename T> inline void toString(T v, string& s) { append2string(s, v); }

template<typename S, typename T> inline S hash(T v);
template<typename S, typename T> inline S hashRc(T v) { S ret = hash(v); decRc(v); return ret; }

template<typename T> T clone(T v);

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

// This function is for debugging purposes only! Doesn't cleanp v!
template<typename T>
inline std::string toStdString(T v) {
	string s;
	append2string(s, v);
	return string2std(s);
}

template<typename S, typename T> struct Hash;
template<typename T> struct Equal { bool operator() (T v1, T v2) const { return equal(v1, v2); } };

// Dynamic wrapper for all values 

struct Flow: public RcBase {
	virtual ~Flow() { }

	virtual void append2string(string&) = 0;

	virtual TypeId typeId() const = 0;
	virtual Int componentSize() const { return 0; }
	virtual TypeId componentTypeId(Int i) { fail("invalid flow value getter"); return TypeFx::UNKNOWN; }
	inline TypeId typeIdRc() { return decRcRet(this, typeId()); }
	inline Int componentSizeRc() { return decRcRet(this, componentSize()); }
	
	// these methods decrement `this` RC
	inline Flow* getFlowRc(Int i) { return decRcRet(this, getFlowRc1(i)); }
	inline Bool getBoolRc(Int i) { return decRcRet(this, getBoolRc1(i)); }
	inline Int getIntRc(Int i) { return decRcRet(this, getIntRc1(i));  }
	inline Double getDoubleRc(Int i) { return decRcRet(this, getDoubleRc1(i)); }
	inline void setFlowRc(Int i, Flow* v) { setFlowRc1(i, v); decRc(this); }
	inline Flow* getFlowRc(String* f) { return decRcRet(this, getFlowRc1(f)); }
	inline void setFlowRc(String* f, Flow* v) { setFlowRc1(f, v); decRc(this); }
	inline Flow* callFlowRc(const std::vector<Flow*>& as) { return decRcRet(this, callFlowRc1(as)); }

	// these methods do not affect `this` RC, but return results RC is incremented
	virtual Flow* getFlowRc1(Int i) { fail("invalid flow value getter"); return nullptr; }
	virtual Bool getBoolRc1(Int i) { fail("invalid flow value getter"); return false; }
	virtual Int getIntRc1(Int i) { fail("invalid flow value getter"); return 0; }
	virtual Double getDoubleRc1(Int i) { fail("invalid flow value getter"); return 0.0; }
	virtual void setFlowRc1(Int i, Flow* v) { fail("invalid flow value setter"); }
	virtual Flow* getFlowRc1(String* f) { fail("invalid flow value getter"); return nullptr; }
	virtual void setFlowRc1(String* f, Flow* v) { fail("invalid flow value setter"); }
	virtual Flow* callFlowRc1(const std::vector<Flow*>&) { fail("invalid flow value getter"); return nullptr; }

	// these methods do not change any RCs. NODE: only non-scalar components may be accessed this way,
	// attempt to apply this method to a scalar component will cause runtime error
	virtual Flow* getFlow(Int i) { fail("invalid flow value getter"); return nullptr; }
	virtual Flow* getFlow(const string& f) { fail("invalid flow value getter"); return nullptr; }

	template<typename T> inline T get() { return static_cast<T>(this); }
	template<typename T> inline T getRc1() { return incRcRet(static_cast<T>(this)); }
	template<typename T> inline T getRc() { return static_cast<T>(this); }
};

struct FVoid : public Flow {
	enum { TYPE = TypeFx::VOID };
	void destroy() override { this->~FVoid(); }
	void append2string(string& s) override { flow::append2string<Void>(s, void_value); }
	static FVoid* make() {
		if constexpr (use_memory_manager) {
			return new(Memory::alloc<FVoid>()) FVoid();
		} else {
			return new FVoid();
		}
	}
	TypeId typeId() const override { return TypeFx::VOID; }
};
struct FInt : public Flow {
	enum { TYPE = TypeFx::INT };
	FInt(Int v): val(v) {}
	void destroy() override { this->~FInt(); }
	void append2string(string& s) override { flow::append2string<Int>(s, val); }
	static FInt* make(Int v) {
		if constexpr (use_memory_manager) {
			return new(Memory::alloc<FInt>()) FInt(v);
		} else {
			return new FInt(v);
		}
	}
	TypeId typeId() const override { return TypeFx::INT; }
	Int val;
};
struct FBool : public Flow {
	enum { TYPE = TypeFx::BOOL };
	FBool(Bool v): val(v) {}
	void destroy() override { this->~FBool(); }
	void append2string(string& s) override { flow::append2string<Bool>(s, val); }
	static FBool* make(Bool v) {
		if constexpr (use_memory_manager) {
			return new(Memory::alloc<FBool>()) FBool(v);
		} else {
			return new FBool(v);
		}
	}
	TypeId typeId() const override { return TypeFx::BOOL; }
	Bool val;
};
struct FDouble : public Flow {
	enum { TYPE = TypeFx::DOUBLE };
	FDouble(Double v): val(v) {}
	void destroy() override { this->~FDouble(); }
	void append2string(string& s) override { flow::append2string<Double>(s, val); }
	static FDouble* make(Double v) {
		if constexpr (use_memory_manager) {
			return new(Memory::alloc<FDouble>()) FDouble(v);
		} else {
			return new FDouble(v);
		}
	}
	TypeId typeId() const override { return TypeFx::DOUBLE; }
	Double val;
};

template<> inline Void Flow::getRc<Void>() { return decRcRet(this, void_value); }
template<> inline Int Flow::getRc<Int>() { return decRcRet(this, static_cast<FInt*>(this)->val); }
template<> inline Bool Flow::getRc<Bool>() { return decRcRet(this, static_cast<FBool*>(this)->val); }
template<> inline Double Flow::getRc<Double>() { return decRcRet(this, static_cast<FDouble*>(this)->val); }

template<> inline Void Flow::getRc1<Void>() { return void_value; }
template<> inline Int Flow::getRc1<Int>() { return static_cast<FInt*>(this)->val; }
template<> inline Bool Flow::getRc1<Bool>() { return static_cast<FBool*>(this)->val; }
template<> inline Double Flow::getRc1<Double>() { return static_cast<FDouble*>(this)->val; }

template<> inline Void Flow::get<Void>() { return void_value; }
template<> inline Int Flow::get<Int>() { return static_cast<FInt*>(this)->val; }
template<> inline Bool Flow::get<Bool>() { return static_cast<FBool*>(this)->val; }
template<> inline Double Flow::get<Double>() { return static_cast<FDouble*>(this)->val; }

}
