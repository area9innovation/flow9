#pragma once

#include <atomic>
#include "__flow_runtime_rtti.hpp"

namespace flow {

using RcCounter = int32_t; // long?

constexpr RcCounter CONSTANT_OBJECT_RC = -1;

template<typename T>
inline bool isConstatntObj(T x) {
	if constexpr (is_flow_ancestor_v<T>) {
		return x->rc_ == CONSTANT_OBJECT_RC;
	} else {
		return false;
	}
}

template<typename T> inline void incRc(T x, Int d = 1) {
	if constexpr (is_flow_ancestor_v<T>) {
		if (!isConstatntObj<T>(x)) {
			std::atomic_ref<RcCounter>(x->rc_).fetch_add(d);
		}
	}
}

template<typename T> inline void decRc(T x) {
	if constexpr (is_flow_ancestor_v<T>) {
		//x->decRc();
		if (!isConstatntObj<T>(x)) {
			if (std::atomic_ref<RcCounter>(x->rc_).fetch_sub(1) == 1) {
				//delete x;
				x->destroy();
			}
		}
	}
}

template<typename T> inline T decRcReuse(T x) {
	if constexpr (is_flow_ancestor_v<T>) {
		//return x->decRcReuse();
		if (isConstatntObj<T>(x)) {
			return nullptr;
		} else {
			if (std::atomic_ref<RcCounter>(x->rc_).fetch_sub(1) == 1) {
				return x;
			} else {
				return nullptr;
			}
		}
	} else {
		fail("trying to decRcReuse of type: " + type2StdString<T>());
	}
}

template<typename T> inline void decRcFinish(T x) {
	if constexpr (is_flow_ancestor_v<T>) {
		//delete x;
		if (x) {
			x->destroy();
		}
	}
}

template<typename T> inline bool isUnitRc(T x) { return x->rc_ == 1; }

template<typename T, typename R> inline R decRcRet(T x, R ret) { decRc(x); return ret; }

template<typename T> inline T incRcRet(T x) { incRc(x); return x; }

}
