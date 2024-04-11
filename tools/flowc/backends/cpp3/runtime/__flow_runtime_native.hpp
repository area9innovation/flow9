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
	bool convertsToFlow() const { return converts_to_flow_; }

	template<typename... As> static Native* make(As... as) {
		if constexpr (use_memory_manager) {
			return new(Memory::alloc<Native>()) Native(as...);
		} else {
			return new Native(as...);
		}
	}
	template<typename T> inline bool hasType() {
		return val_.type() == typeid(T);
	}
	template<typename T> inline T getRc() { return decRcRet(this, getRc1<T>()); }
	template<typename T> inline T getRc1() { return incRcRet(get<T>()); }
	template<typename T> inline T get() {
		return std::any_cast<T>(val_);
	}
	template<typename T> inline T* getPtr() {
		return std::any_cast<T*>(&val_);
	}

	const std::any& val() { return val_; }
	std::any& valRef() { return val_; }

private:
	template<typename T>
	Native(T v): converts_to_flow_(is_rcbase_ancestor_v<T>), cleanup_([](){}), val_(v) {
		static_assert(is_rcbase_ancestor_v<T>, "Native has no explicit destructor");
		cleanup_ = [this]() { decRc(std::any_cast<T>(val_)); };
	}
	template<typename T>
	Native(T v, std::function<void()>&& c):
		converts_to_flow_(is_rcbase_ancestor_v<T>), cleanup_(std::move(c)), val_(v) {
	}
	const bool converts_to_flow_;
	std::function<void()> cleanup_;
	std::any val_;
};

}
