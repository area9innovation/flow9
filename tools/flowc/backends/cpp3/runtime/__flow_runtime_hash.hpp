#pragma once

#include "__flow_runtime_flow.hpp"

namespace flow {

template<typename S> struct FNV;
template<> struct FNV<uint32_t> { enum { prime = 0x01000193, offset = 0x811C9DC5 }; };
template<> struct FNV<uint64_t> { enum { prime = 0x00000100000001B3, offset = 0xcbf29ce484222325 }; };

template<typename S, typename T> struct Hash {
	inline S operator() (T n) const {
		S h = FNV<S>::offset;
		calc(h, n);
		return h;
	}
	inline static S hash(T n) {
		S h = FNV<S>::offset;
		calc(h, n);
		return h;
	}
	inline static void calc(S& h, T v) {
		if constexpr (std::is_same_v<T, uint8_t>) {
			h = (h ^ v) * FNV<S>::prime;
		} else if constexpr (std::is_same_v<T, int8_t>) {
			Hash<S, uint8_t>::calc(h, static_cast<uint8_t>(v));
		} else if constexpr (std::is_same_v<T, uint16_t>) {
			h = (h ^ ( v       & 0xFF)) * FNV<S>::prime;
			h = (h ^ ((v >> 8) & 0xFF)) * FNV<S>::prime;
		} else if constexpr (std::is_same_v<T, int16_t>) {
			Hash<S, uint16_t>::calc(h, static_cast<uint16_t>(v));
		} else if constexpr (std::is_same_v<T, uint32_t>) {
			h = (h ^ ( v        & 0xFF)) * FNV<S>::prime;
			h = (h ^ ((v >> 8)  & 0xFF)) * FNV<S>::prime;
			h = (h ^ ((v >> 16) & 0xFF)) * FNV<S>::prime;
			h = (h ^ ((v >> 24) & 0xFF)) * FNV<S>::prime;
		} else if constexpr (std::is_same_v<T, int32_t>) {
			Hash<S, uint32_t>::calc(h, static_cast<uint32_t>(v));
		} else if constexpr (std::is_same_v<T, uint64_t>) {
			h = (h ^ ( v        & 0xFF)) * FNV<S>::prime;
			h = (h ^ ((v >> 8)  & 0xFF)) * FNV<S>::prime;
			h = (h ^ ((v >> 16) & 0xFF)) * FNV<S>::prime;
			h = (h ^ ((v >> 24) & 0xFF)) * FNV<S>::prime;
			h = (h ^ ((v >> 32) & 0xFF)) * FNV<S>::prime;
			h = (h ^ ((v >> 40) & 0xFF)) * FNV<S>::prime;
			h = (h ^ ((v >> 48) & 0xFF)) * FNV<S>::prime;
			h = (h ^ ((v >> 56) & 0xFF)) * FNV<S>::prime;
		} else if constexpr (std::is_same_v<T, int64_t>) {
			Hash<S, uint64_t>::calc(h, static_cast<uint64_t>(v));
		} else if constexpr (std::is_same_v<T, float>) {
			Hash<S, uint32_t>::calc(h, static_cast<uint32_t>(v));
		} else if constexpr (std::is_same_v<T, double>) {
			Hash<S, uint64_t>::calc(h, static_cast<uint64_t>(v));
		} else if constexpr (std::is_same_v<T, String*>) {
			for (char16_t c : v->str()) {
				Hash<S, uint16_t>::calc(h, static_cast<uint16_t>(c));
			}
		} else if constexpr (std::is_same_v<T, Native*>) {
			Hash<S, ptrdiff_t>::calc(h, reinterpret_cast<ptrdiff_t>(v));
		} else if constexpr (is_type_v<TypeFx::ARRAY, T>) {
			for (typename T::ElType c : *v) {
				Hash<S, typename T::ElType>::calc(h, c);
			}
		} else if constexpr (is_type_v<TypeFx::REF, T>) {
			Hash<S, ptrdiff_t>::calc(h, reinterpret_cast<ptrdiff_t>(v));
			Hash<S, typename T::RefType>::calc(h, v->val());
		} else if constexpr (is_type_v<TypeFx::FUNC, T>) {
			Hash<S, ptrdiff_t>::calc(h, reinterpret_cast<ptrdiff_t>(v));
		} else if constexpr (is_struct_v<T>) {
			v->template hashCalc<S>(h);
		} else if constexpr (is_flow_ancestor_v<T>) {
			switch (v->typeId()) {
				case TypeFx::INT:    Hash<S, Int>::calc(h, v->template get<Int>()); break;
				case TypeFx::BOOL:   Hash<S, Bool>::calc(h, v->template get<Bool>()); break;
				case TypeFx::DOUBLE: Hash<S, Double>::calc(h, v->template get<Double>()); break;
				case TypeFx::STRING: Hash<S, String*>::calc(h, v->template get<String*>()); break;
				case TypeFx::ARRAY: {
					for (Int i = 0; i < v->componentSize(); ++i) {
						calcComponent(h, v, i);
					}
					break;
				}
				case TypeFx::REF:
					calcComponent(h, v, 0);
					break;
				case TypeFx::FUNC:
					Hash<S, ptrdiff_t>::calc(h, reinterpret_cast<ptrdiff_t>(v));
					break;
				case TypeFx::NATIVE:
					Hash<S, Native*>::calc(h, v->template get<Native*>());
					break;
				default: {
					Hash<S, TypeId>::calc(h, v->typeId());
					for (Int i = 0; i < v->componentSize(); ++ i) {
						calcComponent(h, v, i);
					}
					break;
				}
			}
		} else fail("illegal hash type" + type2StdString<T>());
	}
	inline static void calcComponent(S& h, Flow* v, Int i) {
		switch (v->componentTypeId(i)) {
			case TypeFx::INT:    Hash<S, Int>::calc(h, v->getIntRc1(i)); break;
			case TypeFx::BOOL:   Hash<S, Bool>::calc(h, v->getBoolRc1(i)); break;
			case TypeFx::DOUBLE: Hash<S, Double>::calc(h, v->getDoubleRc1(i)); break;
			default:             Hash<S, Flow*>::calc(h, v->getFlow(i)); break;
		}
	}
};

template<typename S, typename T> inline S hash(T v) {
	return Hash<S, T>::hash(v);
}

}
