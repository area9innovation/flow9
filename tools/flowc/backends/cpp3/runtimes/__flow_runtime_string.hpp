#pragma once

#include "__flow_runtime_flow.hpp"

namespace flow {

constexpr Int UNI_HALF_BASE = 0x10000;
constexpr Int UNI_HALF_SHIFT = 10;
constexpr Int UNI_HALF_MASK = 0x3FF;
constexpr Int UNI_SUR_HIGH_START = 0xD800;
constexpr Int UNI_SUR_HIGH_END = 0xDBFF;
constexpr Int UNI_SUR_LOW_START = 0xDC00;
constexpr Int UNI_SUR_LOW_END = 0xDFFF;

struct String : public Flow {
	enum { TYPE = TypeFx::STRING };
	String& operator = (String&& r) = delete;
	String& operator = (const String& r) = delete;
	~String() = default;
	void destroy() override {
		this->~String();
		MemoryPool::freeSize<String>(this);
	}
	// There must be only one instance of empty string
	static String* make() {
		static String* es = makeSingleton();
		return es;
	}
	template<typename... As>
	static String* make(As... as) {
		return new(MemoryPool::allocSize<String>()) String(std::move(as)...);
	}
	static String* make(std::initializer_list<char16_t>&& codes) {
		return new(MemoryPool::allocSize<String>()) String(std::move(codes));
	}

	static String* makeOrReuse(String* s) {
		if (s == nullptr || isConstatntObj(s)) {
			return make();
		} else {
			s->str_.clear();
			s->makeUnitRc();
			return s;
		}
	}
	static String* makeOrReuse(String* s, string&& x) {
		if (s == nullptr || isConstatntObj(s)) {
			return make(std::move(x));
		} else {
			s->str_.clear();
			s->str_.reserve(x.size());
			for (char16_t c: x) {
				s->str_ += c;
			}
			s->makeUnitRc();
			return s;
		}
	}
	static String* makeOrReuse(String* s, std::initializer_list<char16_t>&& x) {
		if (s == nullptr || isConstatntObj(s)) {
			return make(std::move(x));
		} else {
			s->str_.clear();
			s->str_.reserve(x.size());
			for (char16_t c: x) {
				s->str_ += c;
			}
			s->makeUnitRc();
			return s;
		}
	}

	TypeId typeId() const override { return TypeFx::STRING; }
	std::string toStd() const { return string2std(str_); }
	void append(Int c) {
		if (c <= 0xFFFF) {
			str_.append(1, static_cast<char16_t>(c));
		} else {
			c -= UNI_HALF_BASE;
			str_.append(1, static_cast<char16_t>((c >> UNI_HALF_SHIFT) + UNI_SUR_HIGH_START));
      		str_.append(1, static_cast<char16_t>((c & UNI_HALF_MASK) + UNI_SUR_LOW_START));
		}
	}
	inline Int size() const { return static_cast<Int>(str_.size()); }
	inline char16_t getChar(Int i) const { return str_.at(i); }
	inline Int getInt(Int i) const {
		if (i < 0 || i >= static_cast<Int>(str_.size())) {
			return -1;
		} else {
			return static_cast<Int>(str_.at(i));
		}
	}
	inline const string& str() const { return str_; }
	inline string& strRef() { return str_; }
	static String* concatRc(String* s1, String* s2);

private:
	String(): str_() { }
	String(const std::string& s): str_(std2string(s)) { }
	String(const string& s): str_(s) { }
	String(string&& s): str_(std::move(s)) { }
	String(const char16_t* s): str_(s) { }
	String(const char16_t* s, Int len): str_(s, len) { }
	String(char16_t c): str_(1, c) { }
	String(Int c) { append(c); }
	String(std::initializer_list<char16_t>&& codes): str_(std::move(codes)) { }
	static String* makeSingleton() { static String es; es.makeConstantRc(); return &es; }
	string str_;
};


}
