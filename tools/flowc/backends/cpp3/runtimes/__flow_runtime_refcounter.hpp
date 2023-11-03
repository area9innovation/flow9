#pragma once

#include <atomic>
#include "__flow_runtime_rtti.hpp"
#include "__flow_runtime_memory.hpp"

namespace flow {

struct RcBase {
	enum { CONSTANT_OBJECT_RC = -1, UNIT_OBJECT_RC = 1};
	using RcCounter = int32_t; // long ?
	RcBase(): rc_(1) { }
	virtual void destroy() = 0;
	void makeUnitRc() { rc_ = 1; }
	void makeConstantRc() { rc_ = CONSTANT_OBJECT_RC; }
	inline bool isConstant() { return rc_ == CONSTANT_OBJECT_RC; }
	inline bool isUnit() { return rc_ == UNIT_OBJECT_RC; }
	inline void incrementRc(Int d) {
		if (!isConstant()) {
			std::atomic_ref<RcCounter>(rc_).fetch_add(d);
		}
	}
	template<typename T>
	inline void decrementRc() {
		if (!isConstant()) {
			if (std::atomic_ref<RcCounter>(rc_).fetch_sub(1) == 1) {
				Memory::destroy<T>(static_cast<T>(this));
			}
		}
	}
	template<typename T>
	inline T decrementRcReuse() {
		if (isConstant()) {
			return nullptr;
		} else {
			if (std::atomic_ref<RcCounter>(rc_).fetch_sub(1) == 1) {
				return static_cast<T>(this);
			} else {
				return nullptr;
			}
		}
	}
	template<typename T>
	inline void decrementRcFinish() {
		Memory::destroy<T>(static_cast<T>(this));
	}
private:
	RcCounter rc_;
};

template<typename T>
inline bool isConstatntObj(T x) {
	if constexpr (is_rcbase_ancestor_v<T>) {
		return x->isConstant();
	} else {
		return false;
	}
}

template<typename T> inline void incRc(T x, Int d = 1) {
	if constexpr (is_rcbase_ancestor_v<T>) {
		x->incrementRc(d);
	}
}

template<typename T> inline void decRc(T x) {
	if constexpr (is_rcbase_ancestor_v<T>) {
		x->template decrementRc<T>();
	}
}

template<typename T> inline T decRcReuse(T x) {
	if constexpr (is_rcbase_ancestor_v<T>) {
		return x->template decrementRcReuse<T>();
	} else {
		fail("trying to decRcReuse of type: " + type2StdString<T>());
	}
}

template<typename T> inline void decRcFinish(T x) {
	if constexpr (is_rcbase_ancestor_v<T>) {
		if (x) {
			x->template decrementRcFinish<T>();
		}
	}
}

template<typename T> inline bool isUnitRc(T x) {
	if constexpr (is_rcbase_ancestor_v<T>) {
		return x->isUnit(); 
	} else {
		fail("trying to isUnitRc of type: " + type2StdString<T>());
	}
}

template<typename T, typename R>
inline R decRcRet(T x, R ret) {
	decRc(x);
	return ret; 
}

template<typename T>
inline T incRcRet(T x) {
	incRc(x);
	return x;
}

}
