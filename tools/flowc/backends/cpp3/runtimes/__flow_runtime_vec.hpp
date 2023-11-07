#pragma once

#include "__flow_runtime_flow.hpp"

namespace flow {

struct VecStats {
	enum { STATS_LEN = 2048 };
	static void registerLen(Int l) {
		/*if (max_len < l) {
			max_len = l;
		}
		std::size_t len = static_cast<Int>(l);
		std::lock_guard<std::mutex> lock(m);
		if (len >= len_distrib.size()) {
			Int x = len - len_distrib.size() + 1;
			while (x-- > 0) {
				len_distrib.push_back(0);
			}
		}
		len_distrib[len] += 1;*/
	}
	static Int lenUses(Int l) {
		std::size_t len = static_cast<Int>(l);
		if (len < len_distrib.size()) {
			return len_distrib.at(len);
		} else {
			return -1;
		}
	}
	static Int max_len;
	static std::mutex m;
	static std::vector<Int> len_distrib;
};

template<typename T> 
struct Vec : public Flow {
	enum { TYPE = TypeFx::ARRAY };
	using ElType = T;
	using const_iterator = typename std::vector<T>::const_iterator;
	using iterator = typename std::vector<T>::iterator;
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
	template<typename A>
	static Vec* make(A a) {
		return new(Memory::alloc<Vec>()) Vec(std::move(a));
	}
	static Vec* make(std::initializer_list<T>&& il) {
		return new(Memory::alloc<Vec>()) Vec(std::move(il));
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
	const_iterator begin() const { return vec_.begin(); }
	const_iterator end() const { return vec_.end(); }
	iterator begin() { return vec_.begin(); }
	iterator end(){ return vec_.end(); }

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
	Vec(Int s): vec_() { VecStats::registerLen(s); vec_.reserve(s); }
	Vec(std::initializer_list<T>&& il): vec_(std::move(il)) { VecStats::registerLen(il.size()); }
	Vec(const std::initializer_list<T>& il): vec_(il) { VecStats::registerLen(il.size()); }
	Vec(Vec* a): vec_(a->vec_) { incRcVec(); VecStats::registerLen(size()); }
	Vec(Vec&& a): vec_(std::move(a.vec_)) { }
	Vec(const Vec& a): vec_(a.vec_) { incRcVec(); VecStats::registerLen(size()); }
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
/*
template<typename T>
inline Int compare<Vec<T>*>(Vec<T>* v1, Vec<T>* v2) {
	Int c1 = compare<Int>(v1->size(), v2->size());
	if (c1 != 0) {
		return c1;
	} else {
		for (Int i = 0; i < v1->size(); ++ i) {
			Int c2 = compare<T>(v1->get(i), v2->get(i));
			if (c2 != 0) {
				return c2;
			}
		}
		return 0;
	}
}
*/
}
