#pragma once

#include "__flow_runtime_string.hpp"
#include "__flow_runtime_native.hpp"
#include "__flow_runtime_struct.hpp"
#include "__flow_runtime_vec.hpp"
#include "__flow_runtime_ref.hpp"
#include "__flow_runtime_fun.hpp"

namespace flow {

// Cast templates: from any type to any

template<typename T1, typename T2>
inline T2 errorCast(T1 x) {
	fail("invalid conversion from type: '" + type2StdString<T1>() + "' to type: '" + type2StdString<T1>() + "' " + "of value:\n" + toStdString(x));
}

template<typename T1, typename T2>
inline T2 castRc(T1 x) {
	if constexpr (std::is_same_v<T1, T2>) {
		return x;
	} 
	else if constexpr (std::is_same_v<T2, Void>) {
		if constexpr (std::is_same_v<T1, Void>) { return void_value; }
		else { decRc(x); return void_value; }
	} 
	else if constexpr (std::is_same_v<T2, Flow*>) {
		if constexpr (std::is_same_v<T1, Bool>) { return FBool::make(x); }
			else if constexpr (std::is_same_v<T1, Int>) { return FInt::make(x); }
			else if constexpr (std::is_same_v<T1, Double>) { return FDouble::make(x); }
			else if constexpr (std::is_same_v<T1, Void>) { return FVoid::make(); }
			else if constexpr (std::is_same_v<T1, Native*>) {
				if (x->template castsTo<Flow*>()) {
					return x->template getRc<Flow*>();
				} else {
					return x;
				}
			}
			else if constexpr (is_flow_ancestor_v<T1>) {
				return x; 
			} else {
				errorCast<T1, T2>(x);
			}
	} 
	else if constexpr (std::is_same_v<T2, Int>) {
		if constexpr (std::is_same_v<T1, Bool>) { return bool2int(x); }
		else if constexpr (std::is_same_v<T1, Double>) { return double2int(x); }
		else if constexpr (std::is_same_v<T1, String*>) { Int ret = string2int(x->str()); decRc(x); return ret; }
		else if constexpr (std::is_same_v<T1, Flow*>) {
			switch (x->typeId()) {
				case TypeFx::INT:    return x->template getRc<Int>();
				case TypeFx::BOOL:   return bool2int(x->template getRc<Bool>());
				case TypeFx::DOUBLE: return double2int(x->template getRc<Double>());
				case TypeFx::STRING: { Int ret = string2int(x->template get<String*>()->str()); decRc(x); return ret; }
				default: errorCast<T1, T2>(x);
			}
		}
		else if constexpr (std::is_same_v<T1, Native*>) {
			return x->template getRc<Int>();
		} else {
			errorCast<T1, T2>(x);
		}
	}
	else if constexpr (std::is_same_v<T2, Bool>) {
		if constexpr (std::is_same_v<T1, Int>) { return int2bool(x); }
		else if constexpr (std::is_same_v<T1, Double>) { return double2bool(x); }
		else if constexpr (std::is_same_v<T1, String*>) { Bool ret = string2bool(x->str()); decRc(x); return ret; }
		else if constexpr (std::is_same_v<T1, Flow*>) {
			switch (x->typeId()) {
				case TypeFx::INT:    return int2bool(x->template getRc<Int>());
				case TypeFx::BOOL:   return x->template getRc<Bool>();
				case TypeFx::DOUBLE: return double2bool(x->template getRc<Double>());
				case TypeFx::STRING: { Bool ret = string2bool(x->template get<String*>()->str()); decRc(x); return ret; }
				default: errorCast<T1, T2>(x);
			}
		}
		else if constexpr (std::is_same_v<T1, Native*>) {
			return x->template getRc<Bool>();
		} else {
			errorCast<T1, T2>(x);
		}
	}
	else if constexpr (std::is_same_v<T2, Double>) {
		if constexpr (std::is_same_v<T1, Int>) { return int2double(x); }
		else if constexpr (std::is_same_v<T1, Bool>) { return bool2double(x); }
		else if constexpr (std::is_same_v<T1, String*>) { Double ret = string2double(x->str()); decRc(x); return ret; }
		else if constexpr (std::is_same_v<T1, Flow*>) {
			switch (x->typeId()) {
				case TypeFx::INT:    return int2double(x->template getRc<Int>());
				case TypeFx::BOOL:   return bool2double(x->template getRc<Bool>());
				case TypeFx::DOUBLE: return x->template getRc<Double>();
				case TypeFx::STRING: { Double ret = string2double(x->template get<String*>()->str()); decRc(x); return ret; }
				default: errorCast<T1, T2>(x);
			}
		}
		else if constexpr (std::is_same_v<T1, Native*>) {
			return x->template getRc<Double>();
		} else {
			errorCast<T1, T2>(x);
		}
	}
	else if constexpr (std::is_same_v<T2, String*>) {
		if constexpr (std::is_same_v<T1, Int>) { return String::make(std::move(int2string(x))); }
		else if constexpr (std::is_same_v<T1, Bool>) { return String::make(std::move(bool2string(x))); }
		else if constexpr (std::is_same_v<T1, Double>) { return String::make(std::move(double2string(x))); }
		else if constexpr (std::is_same_v<T1, Flow*>) {
			if (x->typeId() == TypeFx::STRING) {
				return x->template getRc<String*>();
			} else {
				return flow2stringRc(x);
			}
		} else {
			return flow2stringRc(x);
		}
	}
	else if constexpr (std::is_same_v<T2, Native*>) {
		return Native::make(x);
	}
	else if constexpr (is_type_v<TypeFx::ARRAY, T2>) {
		using V2 = std::remove_pointer_t<T2>;
		if constexpr (is_type_v<TypeFx::ARRAY, T1>) {
			T2 ret = V2::make(x->size());
			using V1 = std::remove_pointer_t<T1>;
			for (auto e : *x) {
				incRc(e);
				ret->pushBack(castRc<typename V1::ElType, typename V2::ElType>(e));
			}
			decRc(x);
			return ret;
		} else if (T2 f = dynamic_cast<T2>(x)) {
			return f;
		} else {
			T2 ret = V2::make(x->componentSize());
			for (Int i = 0; i < x->componentSize(); ++ i) {
				Flow* e = x->getFlowRc1(i);
				ret->pushBack(castRc<Flow*, typename V2::ElType>(e));
			}
			decRc(x);
			return ret;
		}
	}
	else if constexpr (is_type_v<TypeFx::REF, T2>) {
		using V2 = std::remove_pointer_t<T2>;
		if constexpr (is_type_v<TypeFx::REF, T1>) {
			using V1 = std::remove_pointer_t<T1>;
			return V2::make(castRc<typename V1::RefType, typename V2::RefType>(x->getRc()));
		} else if (T2 f = dynamic_cast<T2>(x)) {
			return f;
		} else {
			return V2::make(castRc<Flow*, typename V2::RefType>(x->getFlowRc(0)));
		}
	}
	else if constexpr (is_type_v<TypeFx::FUNC, T2>) {
		using V2 = std::remove_pointer_t<T2>;
		if constexpr (is_type_v<TypeFx::FUNC, T1>) {
			using V1 = std::remove_pointer_t<T1>;
			T2 ret = [x]<std::size_t... I>(std::index_sequence<I...>) constexpr { 
				return V2::make([x](std::tuple_element_t<I, typename V2::Args>... as) mutable {
					return castRc<typename V1::RetType, typename V2::RetType>(x->callFlowRc(
						castRc<
							std::tuple_element_t<I, typename V2::Args>, 
							std::tuple_element_t<I, typename V1::Args>
						>(std::get<I>(as))...
					));
				}, {});
			}
			(std::make_index_sequence<V2::ARITY>{});
			decRc(x);
			return ret;
		} 
		else if (T2 f = dynamic_cast<T2>(x)) {
			return f;
		} else {
			T2 ret = [x]<std::size_t... I>(std::index_sequence<I...>) constexpr { 
				return V2::make([x](std::tuple_element_t<I, typename V2::Args>... as) mutable {
					std::vector<Flow*> as_vect {castRc<std::tuple_element_t<I, typename V2::Args>, Flow*>(as)...};
					return castRc<Flow*, typename V2::RetType>(x->callFlowRc(as_vect));
				}, x);
			}
			(std::make_index_sequence<V2::ARITY>{});
			decRc(x);
			return ret;
		}
	}
	else if constexpr (std::is_same_v<T2, Union*>) {
		if constexpr (is_struct_v<T1>) {
			return x;
		} else if constexpr (std::is_same_v<T2, Union*>) {
			return static_cast<Union*>(x);
		} else {
			errorCast<T1, T2>(x);
		}
	}
	else if constexpr (is_struct_v<T2>) {
		using V2 = std::remove_pointer_t<T2>;
		if constexpr (is_struct_v<T1>) {
			using V1 = std::remove_pointer_t<T1>;
			using V1_Fields = typename V1::Fields;
			using V2_Fields = typename V2::Fields;
			T2 ret = [x]<std::size_t... I>(std::index_sequence<I...>) constexpr { 
				return V2::template make<T2>(
					castRc<
						std::tuple_element_t<I, V1_Fields>, 
						std::tuple_element_t<I, V2_Fields>
					>(x->template getRc1<I>())...
				);
			}
			(std::make_index_sequence<V2::SIZE>{});
			decRc(x);
			return ret;
		} else if constexpr (std::is_same_v<T1, Union*>) {
			return static_cast<T2>(x);
		} else {
			using V2_Fields = typename V2::Fields;
			T2 ret = [x]<std::size_t... I>(std::index_sequence<I...>) constexpr { 
				return V2::template make<T2>(
					castRc<Flow*, std::tuple_element_t<I, V2_Fields>>(x->getFlowRc1(I))...
				);
			}
			(std::make_index_sequence<V2::SIZE>{});
			decRc(x);
			return ret;
		}
	} else {
		errorCast<T1, T2>(x);
	}
}

}
