#include "__flow_runtime_tostring.hpp"

namespace flow {

/*void appendEscaped(string& str, const string& x) {
	for (char16_t c : x) {
		switch (c) {
			case '"':  str.append(u"\\\""); break;
			case '\\': str.append(u"\\\\"); break;
			case '\n': str.append(u"\\n");  break;
			case '\t': str.append(u"\\t");  break;
			case '\r': str.append(u"\\r");  break;
			default: str += c; break;
		}
	}
}*/

/*
inline void flow2stringComponents(Flow* v, string& str, Int i) {
	if (i > 0) {
		str.append(u", ");
	}
	switch (v->componentTypeId(i)) {
		case TypeFx::INT:    str.append(int2string(v->getIntRc1(i))); break;
		case TypeFx::BOOL:   str.append(bool2string(v->getBoolRc1(i))); break;
		case TypeFx::DOUBLE: str.append(double2string(v->getDoubleRc1(i), true)); break;
		default:             flow2string(v->getFlow(i), str);
	}
}

void flow2string(Flow* v, string& str) {
	switch (v->typeId()) {
		case TypeFx::VOID:   str.append(u"{}"); break;
		case TypeFx::INT:    str.append(int2string(v->get<Int>())); break;
		case TypeFx::BOOL:   str.append(bool2string(v->get<Bool>())); break;
		case TypeFx::DOUBLE: str.append(double2string(v->get<Double>(), true)); break;
		case TypeFx::STRING: {
			str.append(u"\""); appendEscaped(str, v->get<String*>()->str()); str.append(u"\"");
			break;
		}
		case TypeFx::ARRAY: {
			str.append(u"[");
			Int size = v->componentSize();
			for (Int i = 0; i < size; ++i) {
				flow2stringComponents(v, str, i);
			}
			str.append(u"]");
			break;
		}
		case TypeFx::REF: {
			str.append(u"ref ");
			flow2stringComponents(v, str, 0);
			break;
		}
		case TypeFx::FUNC: {
			str.append(u"<function>");
			break;
		}
		case TypeFx::NATIVE: {
			str.append(u"<native>");
			break;
		}
		default: {
			str.append(RTTI::typeName(v->typeId()));
			str.append(u"(");
			Int size = v->componentSize();
			for (Int i = 0; i < size; ++ i) {
				flow2stringComponents(v, str, i);
			}
			str.append(u")");
			break;
		}
	}
}
*/
}
