#pragma once

#include "__flow_runtime_flow.hpp"

namespace flow {

template<typename R, typename... As> 
struct Fun : public Flow {
	enum { TYPE = TypeFx::FUNC, ARITY = sizeof...(As) };
	using RetType = R;
	using Args = std::tuple<As...>;
	using Fn = std::function<R(As...)>;
	using Fn1 = std::function<R(Args)>;
	void destroy() override { this->~Fun(); }
	~Fun() {
		for (Flow* x: closure_) {
			decRc(x);
		}
	}
	Fun& operator = (Fun&& r) = delete;
	Fun& operator = (const Fun& r) = delete;

	template<typename... As1>
	static Fun* make(As1... as) {
		if constexpr (use_memory_manager) {
			return new(Memory::alloc<Fun>()) Fun(std::move(as)...);
		} else {
			return new Fun(std::move(as)...);
		}
	}
	template<typename F, typename... Cs>
	static Fun* makeOrReuse(Fun* f, F fn, Cs... cl) {
		if (f == nullptr) {
			return make(std::move(fn), std::move(cl)...);
		} else {
			for (Flow* x: f->closure_) {
				decRc(x);
			}
			f->closure_.clear();
			f->fn_ = std::move(fn);
			f->initClosure<Cs...>(std::move(cl)...);
			f->makeUnitRc();
			return f;
		}
	}

	// general interface
	void append2string(string& s) override {
		s.append(u"<function>");
	}
	TypeId typeId() const override { return TYPE; }

	// specific methods
	inline R callRc(As... as) {
		return decRcRet(this, callRc1(as...));
	}
	inline R callRc1(As... as) {
		return call(as...);
	}
	virtual R call(As... as) {
		for (Flow* x: closure_) {
			incRc(x);
		}
		return fn_(as...);
	}

	template<typename... Cs> struct Closure;

private:
	Fun() {}
	Fun(Fn&& f): fn_(std::move(f)) { }
	Fun(const Fn& f): fn_(f) { }
	Fun(const Fn1& f): fn_(f) { }

	template<typename... Cs>
	Fun(Fn&& f, Cs... cl): fn_(std::move(f)) {
		initClosure<Cs...>(cl...);
	}
	template<typename C1, typename... Cs>
	constexpr void initClosure(C1 c1, Cs... cl) {
		static_assert(is_flow_ancestor_v<C1> || is_scalar_v<C1>, "illegal type in closure");
		if constexpr (is_flow_ancestor_v<C1>) {
			closure_.push_back(c1);
		}
		initClosure<Cs...>(cl...);
	}
	template<typename... Cs> constexpr void initClosure(Cs...) { }
	Fn fn_;
	std::vector<Flow*> closure_;
};

template<typename R, typename... As> 
template<typename... Cs>
struct Fun<R, As...>::Closure : public Fun<R, As...> {
	static inline const std::size_t SIZE = sizeof...(Cs);
	using Fn = std::function<R(As..., Cs...)>;

	static Fun* make(Fn&& fn, Cs... cl) {
		if constexpr (use_memory_manager) {
			return new(Memory::alloc<Fun>()) Closure(std::move(fn), std::move(cl)...);
		} else {
			return new Closure(std::move(fn), std::move(cl)...);
		}
	}

	R call(As... as) override {
		if constexpr (SIZE == 0) {
			return fn_(as...);
		} else {
			changeRc<0, true>();
			return [this, &as...]<std::size_t... I>(std::index_sequence<I...>) constexpr {
				return fn_(as..., std::get<I>(closure_)...);
			}
			(std::make_index_sequence<SIZE>{});
		}
	}
private:
	Closure(Fn fn, Cs... cl): fn_(fn), closure_(cl...) { }
	template<int i, bool inc>
	void changeRc() {
		if constexpr (i != SIZE) {
			if constexpr (inc) {
				incRc(std::get<i>(closure_));
			} else {
				decRc(std::get<i>(closure_));
			}
			changeRc<i + 1>();
		}
	}
	Fn fn_;
	std::tuple<Cs...> closure_;
};


}
