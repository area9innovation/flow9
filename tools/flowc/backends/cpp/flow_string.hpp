#pragma once

#include "flow_mem_pool.hpp"
#include "flow_ref_counter.hpp"

#include <string>
#include <cstring>
#include <algorithm>

#include <iostream>

#ifdef DEBUG
	#include <set>
#endif

// #define FLOW_DEBUG_STRINGS

namespace flow {
	
#ifdef FLOW_DEBUG_STRINGS
	struct string_base;
	std::set<const string_base*> g_live_strings;
#endif	
	
	struct string_base : ref_counted_base {
		
		#ifdef __GNUC__
			using char_t = char16_t;
		#else
			using char_t = wchar_t;
		#endif
		
		const static int max_size = 10;
		// const static int max_size = 50;
		
		#ifdef DEBUG
			static int live_counter_;
		#endif
		
		const int size_;
		char_t* const begin_;
		
		string_base(int size) : size_(size), begin_(allocate(size)) {
			#ifdef DEBUG
				#ifdef FLOW_ENABLE_CONCURRENCY
					if (!threads_pool::concurrency_enabled) {
						live_counter_++;
					}
				#else
					live_counter_++;
				#endif
			#endif
			#ifdef FLOW_DEBUG_STRINGS
				g_live_strings.insert(this);
			#endif
		}
		
		~string_base() {
			if (begin_ != buf_) {
				delete[] begin_;
			}
			#ifdef DEBUG
				#ifdef FLOW_ENABLE_CONCURRENCY
					if (!threads_pool::concurrency_enabled) {
						live_counter_--;
					}
				#else
					live_counter_--;
				#endif
			#endif
			#ifdef FLOW_DEBUG_STRINGS
				FLOW_ASSERT(g_live_strings.count(this) == 1);
				g_live_strings.erase(this);
			#endif
		}
	
		FLOW_INLINE int size() const {
			return size_;
		}
		
		std::wstring to_wstring() const {
			return std::wstring(begin_, begin_ + size_);
		}
		
		void fill_buf() const {
			if (begin_ != buf_) {
				FLOW_ASSERT(size_ > max_size);
				std::copy(begin_, begin_ + max_size, const_cast<char_t*>(buf_));
			}
		}
		
		char_t buf_[max_size];
		
	private:
		char_t* allocate(int size) {
			FLOW_ASSERT(size >= 0);
			if (size <= max_size) {
				return buf_;
			} else {
				// TODO: get rid of new somehow later...
				return new char_t[size];
			}
		}
	};
	
	static_assert(sizeof(string_base::char_t) == 2, "sizeof(std::char_t) == 2");
	
#ifdef DEBUG
	int string_base::live_counter_ = 0;
#endif
	
	uint64_t g_string_tsc = 0;
	uint64_t g_string2_tsc = 0;
	uint64_t g_string_cmp_tsc = 0;
	
	struct string {
		ref_counter_ptr<string_base> ptr_;
		
		typedef string_base::char_t char_t;
		typedef const char_t* const_iterator;
		
		static mem_pool pool_;
		
		const static int npos = -1;
		
		mem_pool* get_pool() const {
			return &pool_;
		}
		
		char* allocate_string() const {
			#ifdef FLOW_ENABLE_CONCURRENCY
			if (threads_pool::concurrency_enabled) {
				return g_local_thread_mem_pools->allocate(sizeof(string_base));
			} else {
				return get_pool()->allocate();
			}
			#else 
				return get_pool()->allocate();
			#endif
		}
		
		void release_string(const string_base* ptr) {
			#ifdef FLOW_ENABLE_CONCURRENCY
			if (threads_pool::concurrency_enabled) {
				g_local_thread_mem_pools->release((char*)ptr, sizeof(string_base));
			} else {
				get_pool()->release((char*)ptr);
			}
			#else 
				get_pool()->release((char*)ptr);
			#endif
		}
		
		FLOW_INLINE string(const int size) {
			// tsc_holder holder(g_string_tsc);
			FLOW_ASSERT(size >= 0);
			ptr_.init(new (allocate_string()) string_base(size));
		}
		
		FLOW_INLINE string(const char_t* begin, const char_t* end) : string(end - begin) {
			// tsc_holder holder(g_string_tsc);
			std::copy(begin, end, ptr_->begin_);
			ptr_->fill_buf();
		}
		
		FLOW_INLINE string() : string(L"", 0) {}
		FLOW_INLINE string(const std::wstring& str) : string(str.c_str(), str.size()) {}
		
		FLOW_INLINE string(const wchar_t* str, int size) : string(size) {
			// tsc_holder holder(g_string_tsc);
			FLOW_ASSERT(size >= 0);
			for (int i = 0; i < size; i++) {
				ptr_->begin_[i] = str[i];
			}
			ptr_->fill_buf();
		}
		
		FLOW_INLINE string(const string& oth) : ptr_(oth.ptr_) {}

		FLOW_INLINE string(string&& oth) : ptr_(std::move(oth.ptr_)) {}
		
		FLOW_INLINE string(const string_base* ptr) {
			ptr_.init2(ptr);
		}

		FLOW_INLINE void operator= (const string& oth) {
			release();
			ptr_ = oth.ptr_;
		}
		
		FLOW_ALWAYS_INLINE ~string() {
			// ensure that it hasn't been not moved
			if (!!ptr_) {
				release();
			}
		}
		
		explicit operator std::wstring () const {
			return std::wstring(cbegin(), cend());
		}
		
		FLOW_ALWAYS_INLINE const_iterator cbegin() const { 
			FLOW_ASSERT(!!ptr_);
			return ptr_->begin_;	
		}
		
		FLOW_ALWAYS_INLINE const_iterator cend() const	{
			return cbegin() + size();
		}
		
		FLOW_ALWAYS_INLINE size_t size() const {
			FLOW_ASSERT(!!ptr_);
			return ptr_->size();
		}
		
		FLOW_ALWAYS_INLINE char_t operator[] (int i) const {
			FLOW_ASSERT(i >= 0 && i < size());
			return cbegin()[i];
		}
		
		string substr(int start, int end0 = npos) const {
			// tsc_holder holder(g_string2_tsc);
			int size = this->size();
			int end = (end0 == npos) ? size : std::min(end0, size);
			if (start < 0 || start >= size || end < start) {
				return string();
			} else {
				FLOW_ASSERT(start >= 0 && start <= end && end <= size);
				return string(cbegin() + start, cbegin() + end);
			}
		}
		
		int find(const string& pattern, int start = 0) const {
			// tsc_holder holder(g_string2_tsc);
			if (start < 0 || start >= size()) {
				return npos;
			} else {
				auto it = std::search(cbegin() + start, cend(), pattern.cbegin(), pattern.cend());
				return it == cend() ? npos : it - cbegin();
			}
		}
		
		FLOW_INLINE string operator+ (const string& oth) const {
			auto s1 = size(), s2 = oth.size();
			string s(s1 + s2);
			// tsc_holder holder(g_string2_tsc);
			auto p = s.ptr_->begin_;
			std::copy(cbegin(), cend(), p);
			std::copy(oth.cbegin(), oth.cend(), p + s1);
			s.ptr_->fill_buf();
			return s;
		}
	
		FLOW_ALWAYS_INLINE bool operator== (const string& oth) const {
			// tsc_holder holder(g_string_cmp_tsc);
			return (size() == oth.size()) 
				&& ((cbegin() == oth.cbegin()) || std::equal(cbegin(), cend(), oth.cbegin()));
		}
	
		FLOW_INLINE bool operator< (const string& oth) const {
			// tsc_holder holder(g_string_cmp_tsc);
			auto c = std::memcmp(cbegin(), oth.cbegin(), sizeof(char_t)*std::min(size(), oth.size()));
			return (c < 0) || (c==0) && (size() < oth.size());
			// return std::lexicographical_compare(cbegin(), cend(), oth.cbegin(), oth.cend());
		}
		
		FLOW_INLINE int memcmp(const char_t* a, const char_t* b, int len) const {
			for (int i = 0; i < len; i++) {
				int diff = int(a[i]) - int(b[i]);
				if (diff < 0) return -1;
				if (diff > 0) return 1;
			}
			return 0;
		}

		// FLOW_INLINE 
		int cmp(const string& oth) const {
			// tsc_holder holder(g_string_cmp_tsc);

			int min_size = std::min(size(), oth.size());
			int head_size = std::min(min_size, string_base::max_size);
			
			// for (int i = 0; i < head_size; i++) {
				// FLOW_ASSERT(ptr_->buf_[i] == cbegin()[i]);
				// FLOW_ASSERT(oth.ptr_->buf_[i] == oth.cbegin()[i]);
			// }
			
			// auto cc = std::memcmp(ptr_->buf_, oth.ptr_->buf_, sizeof(char_t)*head_size);
			auto cc = memcmp(ptr_->buf_, oth.ptr_->buf_, head_size);
			
			if (cc != 0) return cc;
			
			if (head_size < string_base::max_size) {
				return int(size()) - int(oth.size());
			}
			
			FLOW_ASSERT(size() >= string_base::max_size);
			FLOW_ASSERT(oth.size() >= string_base::max_size);
			
			auto c = std::memcmp(cbegin() + string_base::max_size, oth.cbegin() + string_base::max_size, sizeof(char_t)*(min_size - string_base::max_size));
			if (c == 0) {
				return int(size()) - int(oth.size());
			} else {
				return c;
			}
		}

	private:
		FLOW_ALWAYS_INLINE void release() {
			// tsc_holder holder(g_string_tsc);
			FLOW_ASSERT(!!ptr_);
			auto ptr = ptr_.release();
			if (!!ptr) {
				destroy(ptr);
			}
		}
		
		FLOW_ALWAYS_INLINE void destroy(const string_base* ptr) {
			ptr->~string_base();
			release_string(ptr);
		}
	};
	
	FLOW_ALWAYS_INLINE bool equal(const string& s1, const string& s2, const int len) {
		// tsc_holder holder(g_string2_tsc);
		return (s1.size() == len) 
			&& ((s1.cbegin() == s2.cbegin()) || std::equal(s1.cbegin(), s1.cbegin() + len, s2.cbegin()));
	}

	mem_pool string::pool_(sizeof(string_base));
	
	inline bool operator<= (const string& left, const string& right) {
		return (left < right) || (left == right);
	}
	
	inline bool operator>= (const string& left, const string& right) {
		return (right < left) || (left == right);
	}
	
	inline bool operator> (const string& left, const string& right) {
		return right < left;
	}
	
	string empty_string(L"");

#ifdef FLOW_DEBUG_STRINGS
	std::set<std::wstring> get_live_strings() {
		std::set<std::wstring> s;
		for (auto& sb : flow::g_live_strings) {
			s.insert(std::wstring(sb->begin_, sb->begin_ + sb->size_));
		}
		return s;
	}

	void print_live_strings() {
		FLOW_PRN("------------");
		for (auto& sb : flow::g_live_strings) {
			FLOW_PRN(std::wstring(sb->begin_, sb->begin_ + sb->size_));
		}
		FLOW_PRN("------------");
	}
#endif	
	
}	// namespace flow
