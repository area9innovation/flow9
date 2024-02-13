#pragma once

#include "__flow_runtime_native.hpp"
#include "__flow_runtime_string.hpp"
#include "__flow_runtime_ref.hpp"
#include "__flow_runtime_vec.hpp"
#include "__flow_runtime_struct.hpp"

namespace flow {

template<typename T>
inline T clone(T v) {
	if constexpr (std::is_same_v<T, Void>) return v;
	else if constexpr (std::is_same_v<T, Int>) { return v; }
	else if constexpr (std::is_same_v<T, Bool>) { return v; }
	else if constexpr (std::is_same_v<T, Double>) { return v; }
	else if constexpr (std::is_same_v<T, String*>) { return String::make(v->str()); }
	else if constexpr (std::is_same_v<T, Native*>) { return Native::make(v->val()); }
	else if constexpr (is_type_v<TypeFx::ARRAY, T>) {
		using E = std::remove_pointer_t<T>::ElType;
		Vec<E>* ret = Vec<E>::make(v->size());
		for (E x : *v) {
			ret->pushBack(clone(x));
		}
		return ret;
	} else if constexpr (is_type_v<TypeFx::REF, T>) {
		using R = std::remove_pointer_t<T>;
		return R::make(v->getRc1());
	} else if constexpr (is_type_v<TypeFx::FUNC, T>) {
		fail("cloning of functions is not yet implemented");
		return v;
	} else if constexpr (is_struct_v<T>) {
		using S = std::remove_pointer_t<T>;
		using S_Fields = typename S::Fields;
		return [v]<std::size_t... I>(std::index_sequence<I...>) constexpr { 
			return S::template make<S*>(
				clone<std::tuple_element_t<I, S_Fields>>(v->template get<I>())...
			);
		}(std::make_index_sequence<S::SIZE>{});
	} else if constexpr (is_union_v<T>) {
		return v->clone();
	} else if constexpr (is_flow_ancestor_v<T>) {
		fail("cloning of flow objects is not yet implemented");
		return v;
	} else {
		fail("illegal clone type: " + type2StdString<T>());
		return 0;
	}
}

}
