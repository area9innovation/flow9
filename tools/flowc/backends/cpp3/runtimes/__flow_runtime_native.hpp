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
		if constexpr (use_memory_manager) {
			return new(Memory::alloc<Native>()) Native(as...);
		} else {
			return new Native(as...);
		}
	}
	template<typename T> inline bool castsTo() {
		return val_.type() == typeid(T);
	}
	template<typename T> inline T getRc() { return decRcRet(this, getRc1<T>()); }
	template<typename T> inline T getRc1() { return incRcRet(get<T>()); }
	template<typename T> inline T get() {
		if (castsTo<T>()) {
			return std::any_cast<T>(val_);
		} else {
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

}
