#pragma once

#include <string>
#include <ext/rope>
#include <ostream>
#include <type_traits>
#include <stdexcept>

namespace flow {

inline void fail(const std::string& msg) { throw std::runtime_error(msg); }

enum TypeFx {
	VOID = 0, // special void type - technically it is nullptr_t
	INT = 1,   BOOL = 2, DOUBLE = 3, STRING = 4, NATIVE = 5, // primary types
	ARRAY = 6, REF = 7,  FUNC = 8,   STRUCT = 9,             // complex types
	// These types can't be met in runtime, but are used in RTTI markup
	UNKNOWN = -1, FLOW = -2, PARAMETER = -3,
	STRUCT_TYPE_ID_OFFSET = STRUCT
};

// Types with id values < 9 are from TypeFx, others are structs. 

using TypeId = int32_t;
inline constexpr TypeId structTypeIdOffset = TypeFx::STRUCT_TYPE_ID_OFFSET;

// Flow internally uses utf-16 string format

using string = std::u16string;
using rstring = __gnu_cxx::rope<char16_t>;

// String conversions

void copyString2std(const string& str, std::string& s);
void copyStd2string(const std::string& str, string& s);
void string2ostream(const string& str, std::ostream& os);
void istream2string(std::istream& is, string& str);
inline std::string string2std(const string& str) { std::string s; copyString2std(str, s); return s; }
inline string std2string(const std::string& str) { string s; copyStd2string(str, s); return s; }

// Basic types

using Void = std::nullptr_t;
inline constexpr Void void_value = nullptr;

// Scalar types
using Int = int32_t;
using Bool = bool;
using Double = double;

// Basic scalar type conversions

inline Double int2double(Int x) { return x; }
inline Bool int2bool(Int x) { return x != 0; }
string int2string(Int x) noexcept;

inline Int double2int(Double x) { return (x >= 0.0) ? static_cast<Int>(x + 0.5) : static_cast<Int>(x - 0.5); }
inline Bool double2bool(Double x) { return x != 0.0; }
string double2string(Double x, bool persistent_dot = false);

inline Int bool2int(Bool x) { return x ? 1 : 0; }
inline Double bool2double(Bool x) { return x ? 1.0 : 0.0; }
inline string bool2string(Bool x) { return x ? u"true" : u"false"; }

inline Int string2int(const string& s) { if (s.size() == 0) { return 0; } else { try { return std::stoi(string2std(s)); } catch (std::exception& e) { return 0; } } }
inline Double string2double(const string& s) { if (s.size() == 0) { return 0.0; } else { try { return std::stod(string2std(s)); } catch (std::exception& e) { return 0.0; } } }
inline Bool string2bool(const string& s) { return s != u"false"; }

// append2string for scalar types

void appendEscaped(string& s, const string& x);

template<typename T> void append2string(string& s, T v) { v->append2string(s); }
template<> inline void append2string<Void>(string& s, Void v) { s.append(u"{}"); }
template<> inline void append2string<Int>(string& s, Int v) { s.append(int2string(v)); }
template<> inline void append2string<Bool>(string& s, Bool v) { s.append(bool2string(v)); }
template<> inline void append2string<Double>(string& s, Double v) { s.append(double2string(v, true)); }

template<typename T>
inline T makeDefInit() {
	if constexpr (std::is_same_v<T, Void>) return void_value;
	else if constexpr (std::is_same_v<T, Int>) return 0;
	else if constexpr (std::is_same_v<T, Bool>) return false;
	else if constexpr (std::is_same_v<T, Double>) return 0.0;
	else return nullptr;
}

struct RcBase; // Base type for all non-scalar types - includes a reference counter
struct Flow; // Flow dynamic type

// Forward declaration of all principal non-scalar types

struct String;
struct Native;
struct Union;

template<TypeId Id, typename... Fs> struct Str;
template<typename T> struct Vec;
template<typename T> struct Ref;
template<typename R, typename... As> struct Fun;

// Statistics gathering facilities: constants which enable such gathering

inline constexpr bool gather_vector_leng_stats = false;
inline constexpr bool gather_string_leng_stats = false;

}
