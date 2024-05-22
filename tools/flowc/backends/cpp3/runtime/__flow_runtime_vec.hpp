#pragma once

#include <iostream>
#include <stacktrace>
#include "__flow_runtime_stats.hpp"
#include "__flow_runtime_flow.hpp"

namespace flow {

template<typename T>
struct Vec : public Flow {
	enum { TYPE = TypeFx::ARRAY };
	using ElType = T;

	struct ConstIterator {
		ConstIterator(typename std::vector<T>::const_iterator p): ptr(p.operator ->()) { }
		ConstIterator(const T* p = nullptr): ptr(p) { }
		ConstIterator& operator ++() { ++ptr; return *this; }
		ConstIterator operator + (std::size_t i) { return ConstIterator(ptr + i); }
		bool operator != (ConstIterator i) { return ptr != i.ptr; }
		const T& operator* () const { return *ptr; }
		const T* ptr;
	};

	struct Iterator {
		Iterator(typename std::vector<T>::iterator p): ptr(p.operator ->()) { }
		Iterator(T* p = nullptr): ptr(p) { }
		Iterator& operator ++() { ++ptr; return *this; }
		Iterator operator + (std::size_t n) { return Iterator(ptr + n); }
		bool operator != (Iterator i) { return ptr != i.ptr; }
		T& operator* () { return *ptr; }
		T* ptr;
	};

	~Vec() override {
		decRcVec();
	}
	void destroy() override { this->~Vec(); }
	inline void incRcVec() {
		if constexpr (is_flow_ancestor_v<T>) {
			for (T x : vec_) {
				incRc(x);
			}
		}
	}

	Vec& operator = (Vec&& r) = delete;
	Vec& operator = (const Vec& r) = delete;

	// There must be only one instance of empty vector
	static Vec* make() {
		static Vec* x = makeSingleton();
		return x;
	}
	static Vec* makeFilled(Int size) {
		return new Vec(std::move(std::vector<T>(size, makeDefInit<T>())));
	}
	template<typename A>
	static Vec* make(A a) {
		if constexpr (use_memory_manager) {
			return new(Memory::alloc<Vec>()) Vec(std::move(a));
		} else {
			return new Vec(std::move(a));
		}
	}
	static Vec* make(std::initializer_list<T>&& il) {
		if constexpr (use_memory_manager) {
			return new(Memory::alloc<Vec>()) Vec(std::move(il));
		} else {
			return new Vec(std::move(il));
		}
	}

	static Vec* makeOrReuse(Vec* v) {
		if (v == nullptr || isConstatntObj(v)) {
			return make();
		} else {
			v->decRcVec();
			v->vec_.clear();
			v->makeUnitRc();
			return v;
		}
	}
	static Vec* makeOrReuse(Vec* v, std::initializer_list<T>&& il) {
		if (v == nullptr || isConstatntObj(v)) {
			return make(std::move(il));
		} else {
			v->decRcVec();
			v->vec_.clear();
			v->vec_.reserve(il.size());
			for (T x: il) {
				v->vec_.push_back(x);
			}
			v->makeUnitRc();
			return v;
		}
	}

	// std::vector interface
	ConstIterator begin() const { return ConstIterator(vec_.begin()); }
	ConstIterator end() const { return ConstIterator(vec_.end()); }
	Iterator begin() { return Iterator(vec_.begin()); }
	Iterator end(){ return Iterator(vec_.end()); }

	// general interface
	void append2string(string& s) override {
		s.append(u"[");
		for (Int i = 0; i < size(); ++i) {
			if (i > 0) {
				s.append(u", ");
			}
			flow::append2string(s, get(i));
		}
		s.append(u"]");
	}
	TypeId typeId() const override { return TYPE; }
	Int componentSize() const override { 
		return static_cast<Int>(vec_.size()); 
	}
	TypeId componentTypeId(Int i) override {
		return get_type_id_v<T>;
	}

	Flow* getFlowRc1(Int i) override { 
		return castRc<T, Flow*>(getRc1(i)); 
	}
	Bool getBoolRc1(Int i) override {
		return castRc<T, Bool>(getRc1(i));
	}
	Int getIntRc1(Int i) override {
		return castRc<T, Int>(getRc1(i));
	}
	Double getDoubleRc1(Int i) override {
		return castRc<T, Double>(getRc1(i));
	}
	void setFlowRc1(Int i, Flow* v) override { 
		setRc1(i, castRc<Flow*, T>(v));
	}
	Flow* getFlow(Int i) override {
		if constexpr (is_flow_ancestor_v<T>) {
			return vec_[i];
		} else {
			fail("only flow ancestor components may be accessed directly as Flow");
		}
	}

	// specific methods
	inline Int size() const { 
		return static_cast<Int>(vec_.size()); 
	}
	inline void pushBack(T x) {
		vec_.push_back(x);
	}
	inline void pushBackRc(T x) {
		pushBack(x);
		decRc(this);
	}
	inline T getRc(Int i) {
		return decRcRet(this, getRc1(i));
	}
	void setRc(Int i, T x) {
		setRc1(i, x);
		decRc(this);
	}
	inline T getRc1(Int i) {
		return incRcRet(get(i));
	}
	inline void setRc1(Int i, T x) {
		set(i, x);
	}
	inline T get(Int i) {
		return vec_.at(i);
	}
	inline void set(Int i, ElType x) {
		if constexpr (is_scalar_v<T>) {
			vec_[i] = x;
		} else {
			assignRc<T>(vec_[i], x);
		}
	}
	inline void remove(Int i) {
		decRc(vec_.at(i));
		vec_.erase(vec_.begin() + i);
	}

	static Vec* concatRc(Vec* v1, Vec* v2) {
		if (v1->vec_.size() == 0) {
			decRc(v1);
			return v2;
		} else if (v2->vec_.size() == 0) {
			decRc(v2);
			return v1;
		} else if (isUnitRc(v1)) {
			v1->vecRef().reserve(v1->vec_.size() + v2->vec_.size());
			for(T x : *v2) {
				incRc(x);
				v1->pushBack(x);
			}
			decRc(v2);
			return v1;
		} else {
			Vec* ret = make(v1->vec_.size() + v2->vec_.size());
			for(T x : *v1) {
				incRc(x);
				ret->pushBack(x);
			}
			for(T x : *v2) {
				incRc(x);
				ret->pushBack(x);
			}
			decRc(v1); decRc(v2);
			return ret;
		}
	}

	inline const std::vector<T>& vec() { return vec_; }
	inline std::vector<T>& vecRef() { return vec_; }

private:
	Vec(): vec_() { }
	Vec(Int s): vec_() {
		vec_.reserve(s);
	}
	Vec(const std::initializer_list<T>& il): vec_(il) { }
	Vec(Vec* a): vec_(a->vec_) { incRcVec(); }
	Vec(std::vector<T>&& v): vec_(std::move(v)) { }
	inline void decRcVec() {
		if constexpr (is_flow_ancestor_v<T>) {
			for (T x : vec_) {
				decRc(x);
			}
		}
	}
	static Vec* makeSingleton() { static Vec x; x.makeConstantRc(); return &x; }
	std::vector<T> vec_;
};

template<>
struct Vec<Bool> : public Flow {
	enum { TYPE = TypeFx::ARRAY };
	using ElType = Bool;
	using ConstIterator = typename std::vector<Bool>::const_iterator;
	using Iterator = typename std::vector<Bool>::iterator;

	Vec& operator = (Vec&& r) = delete;
	Vec& operator = (const Vec& r) = delete;

	// There must be only one instance of empty vector
	static Vec* make() {
		static Vec* x = makeSingleton();
		return x;
	}
	template<typename A>
	static Vec* make(A a) {
		if constexpr (use_memory_manager) {
			return new(Memory::alloc<Vec>()) Vec(std::move(a));
		} else {
			return new Vec(std::move(a));
		}
	}
	static Vec* make(std::initializer_list<Bool>&& il) {
		if constexpr (use_memory_manager) {
			return new(Memory::alloc<Vec>()) Vec(std::move(il));
		} else {
			return new Vec(std::move(il));
		}
	}

	static Vec* makeOrReuse(Vec* v) {
		if (v == nullptr || isConstatntObj(v)) {
			return make();
		} else {
			v->vec_.clear();
			v->makeUnitRc();
			return v;
		}
	}
	static Vec* makeOrReuse(Vec* v, std::initializer_list<Bool>&& il) {
		if (v == nullptr || isConstatntObj(v)) {
			return make(std::move(il));
		} else {
			v->vec_.clear();
			v->vec_.reserve(il.size());
			for (Bool x: il) {
				v->vec_.push_back(x);
			}
			v->makeUnitRc();
			return v;
		}
	}

	// std::vector interface
	ConstIterator begin() const { return vec_.begin(); }
	ConstIterator end() const { return vec_.end(); }
	Iterator begin() { return vec_.begin(); }
	Iterator end(){ return vec_.end(); }

	// general interface
	void destroy() override { }
	void append2string(string& s) override {
		s.append(u"[");
		for (Int i = 0; i < size(); ++i) {
			if (i > 0) {
				s.append(u", ");
			}
			flow::append2string(s, get(i));
		}
		s.append(u"]");
	}
	TypeId typeId() const override { return TYPE; }
	Int componentSize() const override { 
		return static_cast<Int>(vec_.size()); 
	}
	TypeId componentTypeId(Int i) override {
		return get_type_id_v<Bool>;
	}

	Flow* getFlowRc1(Int i) override { 
		return castRc<Bool, Flow*>(getRc1(i)); 
	}
	Bool getBoolRc1(Int i) override {
		return castRc<Bool, Bool>(getRc1(i));
	}
	Int getIntRc1(Int i) override {
		return castRc<Bool, Int>(getRc1(i));
	}
	Double getDoubleRc1(Int i) override {
		return castRc<Bool, Double>(getRc1(i));
	}
	void setFlowRc1(Int i, Flow* v) override {
		setRc1(i, castRc<Flow*, Bool>(v));
	}
	Flow* getFlow(Int i) override {
		fail("only flow ancestor components may be accessed directly as Flow");
	}

	// specific methods
	inline Int size() const {
		return static_cast<Int>(vec_.size()); 
	}
	inline void pushBack(Bool x) {
		vec_.push_back(x);
	}
	inline void pushBackRc(Bool x) {
		pushBack(x);
		decRc(this);
	}
	inline Bool getRc(Int i) {
		return decRcRet(this, getRc1(i));
	}
	void setRc(Int i, Bool x) {
		setRc1(i, x);
		decRc(this);
	}
	inline Bool getRc1(Int i) {
		return get(i);
	}
	inline void setRc1(Int i, Bool x) {
		set(i, x);
	}
	inline Bool get(Int i) {
		return vec_.at(i);
	}
	inline void set(Int i, Bool x) {
		vec_[i] = x;
	}
	inline void remove(Int i) {
		vec_.erase(vec_.begin() + i);
	}

	static Vec* concatRc(Vec* v1, Vec* v2) {
		if (v1->vec_.size() == 0) {
			decRc(v1);
			return v2;
		} else if (v2->vec_.size() == 0) {
			decRc(v2);
			return v1;
		} else if (isUnitRc(v1)) {
			v1->vecRef().reserve(v1->vec_.size() + v2->vec_.size());
			for(Bool x : *v2) {
				incRc(x);
				v1->pushBack(x);
			}
			decRc(v2);
			return v1;
		} else {
			Vec* ret = make(v1->vec_.size() + v2->vec_.size());
			for(Bool x : *v1) {
				incRc(x);
				ret->pushBack(x);
			}
			for(Bool x : *v2) {
				incRc(x);
				ret->pushBack(x);
			}
			decRc(v1); decRc(v2);
			return ret;
		}
	}

	inline const std::vector<Bool>& vec() { return vec_; }
	inline std::vector<Bool>& vecRef() { return vec_; }

private:
	Vec(): vec_() { }
	Vec(Int s): vec_() { }
	Vec(const std::initializer_list<Bool>& il): vec_(il) { }
	Vec(Vec* a): vec_(a->vec_) { }
	Vec(std::vector<Bool>&& v): vec_(std::move(v)) { }
	static Vec* makeSingleton() { static Vec x; x.makeConstantRc(); return &x; }
	std::vector<Bool> vec_;
};


}
