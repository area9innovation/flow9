#pragma once

#include "flow_defines.hpp"

#ifdef FLOW_ENABLE_CONCURRENCY
	#include "concurrency.hpp"
#endif

namespace flow {

	struct ref_counted_base {

		mutable int ref_count_;
		
	#ifdef FLOW_ENABLE_CONCURRENCY
		bool is_concurrent_object_;
		mutable void* copy_;
	#endif
	
	#ifdef FLOW_DEBUG_MEMPOOLS
		const int dbg_mark_ = 0x12345678;
	#endif
		
		FLOW_ALWAYS_INLINE ~ref_counted_base() {
			// if (ref_count_ != 0) FLOW_PRN("ref_count_ == " << ref_count_);
			FLOW_ASSERT(ref_count_ == 0);
			#ifdef FLOW_DEBUG_MEMPOOLS
				FLOW_ASSERT(dbg_mark_ == 0x12345678);
			#endif
		}
		
		FLOW_ALWAYS_INLINE ref_counted_base() 
			: ref_count_(1) 
			#ifdef FLOW_ENABLE_CONCURRENCY
			, is_concurrent_object_(threads_pool::concurrency_enabled)
			, copy_(nullptr)
			#endif
		{
		}
		
		ref_counted_base(const ref_counted_base&)	= delete;
		ref_counted_base(ref_counted_base&&)		= delete;
		void operator= (const ref_counted_base&)	= delete;
		
	#ifdef DEBUG	
		int dbg_ref_count() {
			return ref_count_;
		}
	#endif
		
		FLOW_ALWAYS_INLINE bool on_release_ref() const {
			#ifdef FLOW_DEBUG_MEMPOOLS
				FLOW_ASSERT(dbg_mark_ == 0x12345678);
			#endif
			#ifdef FLOW_ENABLE_CONCURRENCY
				if (threads_pool::concurrency_enabled) {
					if (is_concurrent_object_) {
						FLOW_ASSERT(ref_count_ > 0);
						ref_count_--;
						return ref_count_ == 0;
					} else {
						return false;
					}
				}
			#endif
			FLOW_ASSUME(ref_count_ >= 1);
			FLOW_ASSERT(ref_count_ > 0);
			ref_count_--;
			return ref_count_ == 0;
		}
		
		FLOW_ALWAYS_INLINE void on_add_ref() const {
			#ifdef FLOW_DEBUG_MEMPOOLS
				FLOW_ASSERT(dbg_mark_ == 0x12345678);
			#endif
			#ifdef FLOW_ENABLE_CONCURRENCY
				if (threads_pool::concurrency_enabled) {
					if (is_concurrent_object_) {
						ref_count_++;
					}
					return;
				}
			#endif
			FLOW_ASSUME(ref_count_ >= 1);
			FLOW_ASSUME(ref_count_ < 1000000000);
			ref_count_++;
		}
		
	};
	
	template <typename T> //, typename = std::enable_if_t<std::is_base_of_v<ref_counted_base, T>>>
	struct ref_counter_ptr {
		const T* ptr_;
		
		FLOW_ALWAYS_INLINE ref_counter_ptr() : ptr_(nullptr) {}
		
		FLOW_ALWAYS_INLINE ref_counter_ptr(const ref_counter_ptr& oth) {
			FLOW_ASSUME(oth.ptr_ != nullptr);
			FLOW_ASSUME(oth.ptr_->ref_count_ >= 1);
			ptr_ = oth.ptr_;
			FLOW_ASSERT(!!ptr_);
			ptr_->on_add_ref();
		}
		
		FLOW_ALWAYS_INLINE ref_counter_ptr(ref_counter_ptr&& oth) {
			FLOW_ASSUME(oth.ptr_ != nullptr);
			FLOW_ASSUME(oth.ptr_->ref_count_ >= 1);
			ptr_ = oth.ptr_;
			FLOW_ASSERT(!!ptr_);
			FLOW_ASSERT(ptr_->ref_count_ > 0);
			FLOW_ASSUME(ptr_ != nullptr);
			FLOW_ASSUME(ptr_->ref_count_ >= 1);
			oth.ptr_ = nullptr;
		}
		
		FLOW_ALWAYS_INLINE ~ref_counter_ptr() {
			FLOW_ASSERT(ptr_ == nullptr);
		}

		FLOW_ALWAYS_INLINE void operator= (const ref_counter_ptr& oth) {
			FLOW_ASSUME(oth.ptr_ != nullptr);
			FLOW_ASSUME(oth.ptr_->ref_count_ >= 1);
			ptr_ = oth.ptr_;
			FLOW_ASSERT(!!ptr_);
			FLOW_ASSUME(ptr_ != nullptr);
			FLOW_ASSUME(ptr_->ref_count_ >= 1);
			ptr_->on_add_ref();
		}
		
		FLOW_ALWAYS_INLINE const T* get() const {
			FLOW_ASSERT(!!ptr_);
			FLOW_ASSERT(ptr_->ref_count_ > 0);
			return ptr_;
		}
		
		FLOW_ALWAYS_INLINE const T* operator-> () const {
			return get();
		}
		
		FLOW_ALWAYS_INLINE void init(const T* ptr) {
			FLOW_ASSUME(ptr != nullptr);
			FLOW_ASSERT(!ptr_);
			FLOW_ASSUME(ptr->ref_count_ == 1);
			ptr_ = ptr;
			FLOW_ASSUME(ptr_->ref_count_ == 1);
		}
		
		FLOW_ALWAYS_INLINE void init2(const T* ptr) {
			FLOW_ASSUME(ptr != nullptr);
			FLOW_ASSERT(!ptr_);
			ptr->on_add_ref();
			ptr_ = ptr;
		}
		
		FLOW_ALWAYS_INLINE const T* release() {
			FLOW_ASSUME(ptr_ != nullptr);
			FLOW_ASSERT(!!ptr_);
			auto ptr = ptr_;
		#ifdef DEBUG
			ptr_ = nullptr;
		#endif
			if (ptr->on_release_ref()) {
				return ptr;
			} else {
				return nullptr;
			}
		}
		
		FLOW_ALWAYS_INLINE bool operator! () const {
			return ptr_ == nullptr;
		}
		
	};

} // namespace flow 
