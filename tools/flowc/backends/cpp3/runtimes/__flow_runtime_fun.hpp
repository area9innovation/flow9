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

}
