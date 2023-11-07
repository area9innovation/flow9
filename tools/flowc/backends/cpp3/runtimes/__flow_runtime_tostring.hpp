#pragma once

#include "__flow_runtime_string.hpp"

namespace flow {

// Convert any value to string

//void flow2string(Flow* v, string& str);
/*
inline String* flow2stringRc(Flow* f) {
	string os; 
	//flow2string(f, os);
	append2string(os, f);
	decRc(f);
	return String::make(std::move(os));
}
*/
/*
template<typename T>
inline String* toString(T v) {
	string s;
	//toString(v, str);
	append2string(s, v);
	return String::make(std::move(s));
}

template<typename T>
inline String* toStringRc(T v) {
	string str;
	toString(v, str);
	decRc(v);
	return String::make(std::move(str));
}
*/
//void appendEscaped(string& str, const string& x);
/*
template<typename T>
inline void toString(T v, string& str) {
	if constexpr (std::is_same_v<T, Void>) { str.append(u"{}"); }
	else if constexpr (std::is_same_v<T, Int>) { str.append(int2string(v)); }
	else if constexpr (std::is_same_v<T, Bool>) { str.append(bool2string(v)); }
	else if constexpr (std::is_same_v<T, Double>) { str.append(double2string(v, true)); }
	else if constexpr (std::is_same_v<T, String*>) {
		str.append(u"\""); appendEscaped(str, v->str()); str.append(u"\"");
	} else if constexpr (is_type_v<TypeFx::ARRAY, T>) {
		str.append(u"[");
		Int size = v->size();
		for (Int i = 0; i < size; ++i) {
			if (i > 0) {
				str.append(u", ");
			}
			toString(v->get(i), str);
		}
		str.append(u"]");
	} else if constexpr (is_type_v<TypeFx::REF, T>) {
		str.append(u"ref ");
		toString(v->get(), str);
	} else if constexpr (is_type_v<TypeFx::FUNC, T>) {
		decRc(v);
		str.append(u"<function>");
	} else if constexpr (is_type_v<TypeFx::NATIVE, T>) {
		decRc(v);
		str.append(u"<native>");
	} else if constexpr (is_struct_v<T>) {
		v->toString(str);
	} else if constexpr (is_flow_ancestor_v<T>) {
		flow2string(v, str);
	} else {
		fail("illegal toString type" + type2StdString<T>());
	}
}
*/
}
