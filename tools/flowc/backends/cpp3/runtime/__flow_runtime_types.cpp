//#include <iostream>
#include <iomanip>
#include <cmath>
#include "__flow_runtime.hpp"

namespace flow {

bool modules_are_initialized = false;

string double2string(Double x, bool persistent_dot) {
	if (std::isnan(x)) {
		return u"NaN";
	} else {
		std::stringstream os;
		os << std::setprecision(15) << x;
		std::string str = os.str();
		os.str("");
		os.clear();
		std::size_t point_pos = str.find('.');
		if (point_pos != std::string::npos) {
			bool trailing_zeroes = true;
			for (std::size_t i = point_pos + 1; i < str.length() && trailing_zeroes; ++ i) {
				char ch = str.at(i);
				trailing_zeroes = !('1' <= ch && ch <= '9');
			}
			if (trailing_zeroes) {
				str = str.substr(0, point_pos);
			}
		}
		if (persistent_dot && str.find('.') == std::string::npos) {
			str.append(".0");
		}
		return std2string(str);
	}
}

unsigned int2stringLen(unsigned __value, int __base = 10) noexcept {
	unsigned __n = 1;
	const unsigned __b2 = __base  * __base;
	const unsigned __b3 = __b2 * __base;
	const unsigned long __b4 = __b3 * __base;
	for (;;) {
		if (__value < (unsigned)__base) return __n;
		if (__value < __b2) return __n + 1;
		if (__value < __b3) return __n + 2;
		if (__value < __b4) return __n + 3;
		__value /= __b4;
		__n += 4;
	}
}

void int2stringImpl(char16_t* __first, unsigned __len, unsigned __val) noexcept {
    static constexpr char __digits[201] =
	"0001020304050607080910111213141516171819"
	"2021222324252627282930313233343536373839"
	"4041424344454647484950515253545556575859"
	"6061626364656667686970717273747576777879"
	"8081828384858687888990919293949596979899";
	unsigned __pos = __len - 1;
	while (__val >= 100) {
		auto const __num = (__val % 100) * 2;
		__val /= 100;
		__first[__pos] = __digits[__num + 1];
		__first[__pos - 1] = __digits[__num];
		__pos -= 2;
	}
	if (__val >= 10) {
		auto const __num = __val * 2;
		__first[1] = __digits[__num + 1];
		__first[0] = __digits[__num];
	} else {
		__first[0] = '0' + __val;
	}
}

string int2string(Int __val) noexcept {
	const bool __neg = __val < 0;
    const unsigned __uval = __neg ? (unsigned)~__val + 1u : __val;
    const auto __len = int2stringLen(__uval);
    string __str(__neg + __len, '-');
    int2stringImpl(&__str[__neg], __len, __uval);
    return __str;
}

void appendEscaped(string& s, const string& x) {
	for (char16_t c : x) {
		switch (c) {
			case '"':  s.append(u"\\\""); break;
			case '\\': s.append(u"\\\\"); break;
			case '\n': s.append(u"\\n");  break;
			case '\t': s.append(u"\\t");  break;
			//case '\r': s.append(u"\\r");  break;
			case '\r': s.append(u"\\u000d");  break;
			default: s += c; break;
		}
	}
}
/*
template<> void append2string<Void>(string& s, Void v) { s.append(u"{}"); }
template<> void append2string<Int>(string& s, Int v) { s.append(int2string(v)); }
template<> void append2string<Bool>(string& s, Bool v) { s.append(bool2string(v)); }
template<> void append2string<Double>(string& s, Double v) { s.append(double2string(v)); }

template<> Int compare<Void>(Void v1, Void v2) { return true; }
template<> Int compare<Bool>(Bool v1, Bool v2)  { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); }
template<> Int compare<Int>(Int v1, Int v2) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); }
template<> Int compare<Double>(Double v1, Double v2) { return (v1 < v2) ? -1 : ((v1 > v2) ? 1 : 0); }
*/
}
