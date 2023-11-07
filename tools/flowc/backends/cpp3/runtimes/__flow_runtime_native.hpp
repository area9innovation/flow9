#pragma once

#include <any>
#include "__flow_runtime_flow.hpp"

// C++ runtime for flow

namespace flow {

struct Native : public Flow {
	enum { TYPE = TypeFx::NATIVE };
	enum Kind { SCALAR = 0, FLOW_PTR = 1, FOREIGN_PTR = 2 };
	~Native() override {
		cleanup_();
	}
	void destroy() override { this->~Native(); }
	Native& operator = (Native&& r) = delete;
	Native& operator = (const Native& r) = delete;

	void append2string(string& s) override {
		s.append(u"<native>");
	}
	TypeId typeId() const override { return TypeFx::NATIVE; }

	template<typename... As> static Native* make(As... as) {
		return new(Memory::alloc<Native>()) Native(as...);
	}
	template<typename T> bool castsTo() {
		try {
			std::any_cast<T>(val_);
			return true;
		} catch(const std::bad_any_cast& e) {
			return false;
		}
	}
	template<typename T> inline T getRc() { return decRcRet(this, getRc1<T>()); }
	template<typename T> inline T getRc1() { return incRcRet(get<T>()); }
	template<typename T> inline T get() {
		try {
			return std::any_cast<T>(val_);
		} catch(const std::bad_any_cast& e) { 
			fail("incorrect type in native: " + type2StdString<T>());
		}
	}

	const std::any& val() { return val_; }
	std::any& valRef() { return val_; }

private:
	template<typename T>
	Native(T v): cleanup_([](){}), val_(v) {
		if constexpr (is_flow_ancestor_v<T>) {
			cleanup_ = [v]() { decRc(std::any_cast<Flow*>(v)); };
		} else if constexpr (std::is_pointer_v<T>) {
			cleanup_ = [v]() { delete std::any_cast<T>(v); };
		}
	}
	std::function<void()> cleanup_;
	std::any val_;
};

//template<> inline Int compare<Native*>(Native* v1, Native* v2) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); }

}
