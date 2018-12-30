#pragma once

#include "flow_ref_counter.hpp"
#include "flow_mem_pool.hpp"

// #include <memory>

namespace flow {

	template <typename T>
	struct ref_holder : ref_counted_base {
		mutable ptr_type_t<T> value_;
		
		ref_holder(const ptr_type_t<T>& value): value_(value) {}
		~ref_holder() {}
	};
	
	template <typename T>
	struct ref {
		ref_counter_ptr<ref_holder<T>> ptr_;
		
		ref(const ptr_type_t<T>& value) {
			ptr_.init(new (get_mem_pools()->allocate(sizeof(ref_holder<T>))) ref_holder<T>(value));
		}
		
		ref(const ref_holder<T>& holder) {
			ptr_.init2(&holder);
		}

		template <typename TT>
		ref(const ref<TT>& oth) : ptr_(reinterpret_cast<const ref_counter_ptr<ref_holder<T>>&>(oth.ptr_)) {
			// TODO: dangerous cast, but correctness should be provided by the code generator
			static_assert(sizeof(ptr_type_t<T>) == sizeof(ptr_type_t<TT>));
		}
		
		// TODO: add ref(ref<TT>&& oth) later if needed
		
		~ref() {
			if (!!ptr_) {
				auto p = ptr_.release();
				if (!!p) {
					p->~ref_holder();
					get_mem_pools()->release((char*)p, sizeof(ref_holder<T>));
				}
			}
		}
		
		FLOW_INLINE bool operator== (const ref<T>& oth) const { 
			return ptr_.get() == oth.ptr_.get();
		}
		
		FLOW_INLINE bool operator< (const ref<T>& oth) const { 
			return ptr_.get() < oth.ptr_.get();
		}
		
		FLOW_INLINE ptr_type_t<T>& operator*() const {
			return ptr_->value_;
		}
		
		FLOW_INLINE ptr_type_t<T>& operator*() {
			return ptr_->value_;
		}
		
	};
	
	template <typename T>
	ref<T> make_ref(const T& value) {
		return ref<T>(value);
	}

} // namespace flow
