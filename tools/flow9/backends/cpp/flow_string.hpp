// strings
// TODO: fix u16 for win (c++ 17)
//#define _SILENCE_CXX17_CODECVT_HEADER_DEPRECATION_WARNING //or _SILENCE_ALL_CXX17_DEPRECATION_WARNINGS

#include <codecvt>
#include <string>

// TODO: fix it 
//std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> codecvt;

struct _FlowString {
	int _counter = 1;
	std::u16string value;

	_FlowString(const char16_t* const _Ptr) : value(_Ptr) {} // for generated code / constants
	_FlowString(std::u16string&& _Right) : value(_Right) {} // for natives
	_FlowString(std::string s) {
		std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> codecvt;
		value = codecvt.from_bytes(s);
	}

	bool operator==(const _FlowString& a) const { return value == a.value; }
	bool operator!=(const _FlowString& a) const { return value != a.value; }
	bool operator<(const _FlowString& a) const { return value < a.value; }
	bool operator>(const _FlowString& a) const { return value > a.value; }
	bool operator<=(const _FlowString& a) const { return value <= a.value; }
	bool operator>=(const _FlowString& a) const { return value >= a.value; }

	void dupFields() {}
	void dropFields() {}

	std::string toString() {
		std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> codecvt;
		return codecvt.to_bytes(value);
	}
};

_FlowString* concatFlowStrings(_FlowString* s1, _FlowString* s2) {
	// reuse
	if (s1->_counter == 1) {
		s1->value += s2->value;
		drop(s2);
		return s1;
	// reuse
	} else if (s2->_counter == 1) {
		s2->value += s1->value;
		drop(s1);
		return s2;
	// drop
	} else {
		_FlowString* res = new _FlowString(s1->value + s2->value);
		drop(s1);
		drop(s2);
		return res;
	}
}

std::ostream& operator<<(std::ostream& os, const _FlowString& s) {
	std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> codecvt;
	os << codecvt.to_bytes(s.value);
	return os;
}