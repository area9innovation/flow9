#pragma once

#include "__flow_runtime_flow.hpp"

namespace flow {

template<typename T> 
struct Ref : public Flow {
	enum { TYPE = TypeFx::REF };
	using RefType = T;
	~Ref() override { 
		if constexpr (is_flow_ancestor_v<T>) {
			if (val_) {
				decRc(val_);
			}
		}
	}
	void destroy() override { this->~Ref(); }
	Ref& operator = (Ref&& r) = delete;
	Ref& operator = (const Ref& r) = delete;

	template<typename... As>
	static Ref* make(As... as) {
		if constexpr (use_memory_manager) {
			return new(Memory::alloc<Ref>()) Ref(std::move(as)...);
		} else {
			return new Ref(std::move(as)...);
		}
	}
	template<typename A>
	static Ref* makeOrReuse(Ref* r, A a) {
		if (r == nullptr) {
			return make(std::move(a));
		} else {
			decRc(r->val_);
			r->val_ = a;
			r->makeUnitRc();
			return r;
		}
	}

	// general interface
	void append2string(string& s) override {
		s.append(u"ref ");
		flow::append2string<T>(s, val_);
	}
	TypeId typeId() const override { return TypeFx::REF; }
	Int componentSize() const override { return 1; }
	TypeId componentTypeId(Int i) override {
		return get_type_id_v<T>;
	}

	Flow* getFlowRc1(Int i) override { 
		return castRc<RefType, Flow*>(getRc1());
	}
	Bool getBoolRc1(Int i) override {
		return castRc<RefType, Bool>(getRc1());
	}
	Int getIntRc1(Int i) override {
		return castRc<RefType, Int>(getRc1());
	}
	Double getDoubleRc1(Int i) override {
		return castRc<RefType, Double>(getRc1());
	}
	void setFlowRc1(Int i, Flow* v) override {
		setRc1(castRc<Flow*, RefType>(v));
	}
	Flow* getFlow(Int i) override {
		if constexpr (is_flow_ancestor_v<T>) {
			return val_;
		} else {
			fail("only flow ancestor components may be accessed directly as Flow, here is: " + type2StdString<T>());
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
		return val_;
	}
	inline void set(T v) {
		assignRc<T>(val_, v);
	}
	inline T& getRef() {
		return val_;
	}

private:
	Ref() { }
	Ref(T r): val_(r) { }
	Ref(const Ref& r): val_(r.val_) { }
	Ref(Ref&& r): val_(std::move(r.val_)) { }
	T val_;
};

}
