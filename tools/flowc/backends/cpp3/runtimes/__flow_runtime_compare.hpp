#pragma once

#include "__flow_runtime_flow.hpp"

namespace flow {

// General comparison functions

template<typename T>
inline Int compare(T v1, T v2) {
	if constexpr (std::is_same_v<T, Void>) return true;
	else if constexpr (std::is_same_v<T, void*>) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); }
	else if constexpr (std::is_same_v<T, Int>) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); }
	else if constexpr (std::is_same_v<T, Bool>) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); }
	else if constexpr (std::is_same_v<T, Double>) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); }
	else if constexpr (std::is_same_v<T, String*>) { return v1->str().compare(v2->str()); }
	else if constexpr (std::is_same_v<T, Native*>) { return compare<void*>(v1, v2); }
	else if constexpr (is_type_v<TypeFx::ARRAY, T>) {
		Int c1 = compare<Int>(v1->size(), v2->size());
		if (c1 != 0) {
			return c1;
		} else {
			for (auto it1 = v1->vec().begin(), it2 = v2->vec().begin(); it1 != v1->vec().end(); ++it1, ++it2) {
				Int c2 = compare<typename std::remove_pointer_t<T>::ElType>(*it1, *it2);
				if (c2 != 0) {
					return c2;
				}
			}
			return 0;
		}
	} else if constexpr (is_type_v<TypeFx::REF, T>) {
		return compare<typename std::remove_pointer_t<T>::RefType>(v1->get(), v2->get());
	} else if constexpr (is_type_v<TypeFx::FUNC, T> || is_type_v<TypeFx::NATIVE, T>) {
		return compare<void*>(v1, v2);
	} else if constexpr (is_struct_v<T>) {
		return v1->compare(v2);
	} else if constexpr (is_union_v<T>) {
		return v1->compare(v2);
	} else if constexpr (is_flow_ancestor_v<T>) {
		return flowCompare(v1, v2);
	} else {
		fail("illegal compare type: " + type2StdString<T>());
		return 0;
	}
}

}
