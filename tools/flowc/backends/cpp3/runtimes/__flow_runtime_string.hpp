#pragma once

#include "__flow_runtime_stats.hpp"
#include "__flow_runtime_flow.hpp"

namespace flow {

inline constexpr Int UNI_HALF_BASE = 0x10000;
inline constexpr Int UNI_HALF_SHIFT = 10;
inline constexpr Int UNI_HALF_MASK = 0x3FF;
inline constexpr Int UNI_SUR_HIGH_START = 0xD800;
inline constexpr Int UNI_SUR_HIGH_END = 0xDBFF;
inline constexpr Int UNI_SUR_LOW_START = 0xDC00;
inline constexpr Int UNI_SUR_LOW_END = 0xDFFF;

// String length statistics
extern IntStats string_leng_stats;

struct String : public Flow {
	enum { TYPE = TypeFx::STRING };
	String& operator = (String&& r) = delete;
	String& operator = (const String& r) = delete;
	~String() = default;
	void destroy() override { this->~String(); }
	// There must be only one instance of empty string
	static String* make() {
		static String* es = makeSingleton();
		return es;
	}
	template<typename... As>
	static String* make(As... as) {
		if constexpr (use_memory_manager) {
			return new(Memory::alloc<String>()) String(std::move(as)...);
		} else {
			return new String(std::move(as)...);
		}
	}
	static String* make(std::initializer_list<char16_t>&& codes) {
		if constexpr (use_memory_manager) {
			return new(Memory::alloc<String>()) String(std::move(codes));
		} else {
			return new String(std::move(codes));
		}
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
	void append2string(string& s) override {
		s.append(u"\"");
		appendEscaped(s, str_);
		s.append(u"\"");
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

	struct FString : public Flow {
		enum { TYPE = TypeFx::STRING };
		FString(String* v): val_(v) { }
		~FString() { decRc(val_); }
		void destroy() override { this->~FString(); }
		void append2string(string& s) override { val_->append2string(s); }
		static FString* make(String* v) { return new(Memory::alloc<FString>()) FString(v); }
		TypeId typeId() const override { return TypeFx::STRING; }
		String* val() { return val_; }

	private:
		String* val_;
	};

	inline Flow* toFlow() { return FString::make(this); }

private:
	inline void registerLen(Int len) {
		if constexpr (gather_string_leng_stats) {
			string_leng_stats.registerVal(len);
		}
	}
	String(): str_() { }
	String(const std::string& s): str_(std2string(s)) { registerLen(s.size()); }
	String(const string& s): str_(s) { registerLen(s.size()); }
	String(string&& s): str_(std::move(s)) { }
	String(const char16_t* s): str_(s) { std::char_traits<char16_t>::length(s); }
	String(const char16_t* s, Int len): str_(s, len) { registerLen(len); }
	String(char16_t c): str_(1, c) { registerLen(1); }
	String(Int c) {
		if (c <= 0xFFFF) {
			str_.append(1, static_cast<char16_t>(c));
			registerLen(1);
		} else {
			c -= UNI_HALF_BASE;
			str_.append(1, static_cast<char16_t>((c >> UNI_HALF_SHIFT) + UNI_SUR_HIGH_START));
      		str_.append(1, static_cast<char16_t>((c & UNI_HALF_MASK) + UNI_SUR_LOW_START));
			registerLen(2);
		}
	}
	String(std::initializer_list<char16_t>&& codes): str_(std::move(codes)) { registerLen(codes.size()); }
	static String* makeSingleton() { static String es; es.makeConstantRc(); return &es; }
	string str_;
};

template<typename T> inline String* toStringRc(T v) { string s; append2string(s, v); decRc(v); return String::make(std::move(s)); }
template<typename T> inline String* toString(T v) { string s; append2string(s, v); return String::make(std::move(s)); }

}
