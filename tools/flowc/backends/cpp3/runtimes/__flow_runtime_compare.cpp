#include "__flow_runtime_string.hpp"
#include "__flow_runtime_compare.hpp"

namespace flow {
/*
inline Int flowCompareComponents(Flow* v1, Flow* v2, Int i) {
	TypeId type_id1 = v1->componentTypeId(i);
	TypeId type_id2 = v2->componentTypeId(i);
	if (type_id1 == type_id2) {
		switch (type_id1) {
			case TypeFx::INT:    return compare<Int>(v1->getIntRc1(i), v2->getIntRc1(i));
			case TypeFx::BOOL:   return compare<Bool>(v1->getBoolRc1(i), v2->getBoolRc1(i));
			case TypeFx::DOUBLE: return compare<Double>(v1->getDoubleRc1(i), v2->getDoubleRc1(i));
			default:             return flowCompare(v1->getFlow(i), v2->getFlow(i));
		}
	} else {
		if (type_id1 != TypeFx::FLOW && type_id2 != TypeFx::FLOW) {
			return compare<TypeId>(type_id1, type_id2);
		} else {
			return flowCompare(v1->getFlow(i), v2->getFlow(i));
		}
	}
}

Int flowCompare(Flow* v1, Flow* v2) {
	TypeId type_id1 = v1->typeId();
	TypeId type_id2 = v2->typeId();
	if (type_id1 != type_id2) {
		return compare<Int>(type_id1, type_id2);
	} else {
		switch (type_id1) {
			case TypeFx::VOID:   return 0;
			case TypeFx::INT:    return compare<Int>(v1->get<Int>(), v2->get<Int>());
			case TypeFx::BOOL:   return compare<Bool>(v1->get<Bool>(), v2->get<Bool>());
			case TypeFx::DOUBLE: return compare<Double>(v1->get<Double>(), v2->get<Double>());
			case TypeFx::STRING: return compare<String*>(v1->get<String*>(), v2->get<String*>());
			case TypeFx::ARRAY: {
				Int c1 = compare<Int>(v1->componentSize(), v2->componentSize());
				if (c1 != 0) {
					return c1;
				} else {
					Int size = v1->componentSize();
					for (Int i = 0; i < size; ++ i) {
						Int c2 = flowCompareComponents(v1, v2, i);
						if (c2 != 0) {
							return c2;
						}
					}
					return 0;
				}
			}
			case TypeFx::REF: {
				return flowCompareComponents(v1, v2, 0);
			}
			case TypeFx::FUNC: {
				return compare<void*>(v1, v2);
			}
			case TypeFx::NATIVE: {
				return compare<void*>(v1, v2);
			}
			default: {
				Int size = v1->componentSize();
				for (Int i = 0; i < size; ++ i) {
					Int c = flowCompareComponents(v1, v2, i);
					if (c != 0) {
						return c;
					}
				}
				return 0;
			}
		}
	}
}
*/
}
