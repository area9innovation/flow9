#pragma once

// #define FLOW_MEM_SIZE_STATS

#include "flow_mem_pool.hpp"
#include "flow_ref_counter.hpp"

#include <functional>

#ifdef DEBUG
	#include <iostream>
	#include <atomic>
#endif

#ifdef FLOW_MEM_SIZE_STATS
	#include <map>
	#include <typeinfo>
#endif

namespace flow {

	typedef string::char_t char_t;
	
	struct flow_t;
	
	// base class for structs
	struct object : ref_counted_base {
		const uint16_t obj_id_;
		const uint16_t obj_size_;
		
		FLOW_INLINE object(int id, int size) : obj_id_(id), obj_size_(size) {}
		
		virtual ~object() {}
		
		virtual flow::string toString() const = 0;
		
		virtual void toBinary(std::function<void(const flow_t&)> callback) const {
			std::wcout << "ERROR! toBinary() for obj_id_ == " << obj_id_ << " is not implemented!" << std::endl;
			FLOW_ABORT; // not implemented by default!
		}
		
		virtual ref_counter_ptr<object> deep_copy() const {
			FLOW_ABORT
		}
	};
	
	struct struct_desc {
		flow::string name;
		int fields_count;
	};
	
	extern const struct_desc struct_descs[];
	
	const struct_desc& get_struct_desc(int id) {
		return struct_descs[id];
	}

#ifdef DEBUG
	#ifdef FLOW_ENABLE_CONCURRENCY
		std::atomic_int gAllocated = 0;
	#else
		int gAllocated = 0;
	#endif
	int gMoved = 0;
	int gNew0 = 0;
	int gNew1 = 0;
	int gCreated = 0;
	int gDeleted = 0;
	int gCreatedInPool = 0;
#endif

#ifdef FLOW_MEM_SIZE_STATS
	std::map<int, int>	mem_size_stats;
#endif
	
	mem_pools_manager mem_pools;
	
	FLOW_ALWAYS_INLINE mem_pools_manager* get_mem_pools() {
		#ifdef FLOW_ENABLE_CONCURRENCY
			if (threads_pool::concurrency_enabled) {
				return g_local_thread_mem_pools;
			} else {
				return &mem_pools;
			}
		#else
			return &mem_pools;
		#endif
	}
	
	struct object_ref {
		ref_counter_ptr<object> ptr_;
		
		object_ref(const object* ptr) {
			ptr_.init(ptr);
			#ifdef DEBUG
				#ifdef FLOW_ENABLE_CONCURRENCY
					if (!threads_pool::concurrency_enabled) {
						gAllocated.fetch_add(1);
					}
				#else
					gAllocated++;
				#endif
			#endif
		}
		
		object_ref(const object_ref& oth) : ptr_(oth.ptr_) {
		}

		object_ref(object_ref&& oth) : ptr_(std::move(oth.ptr_)) {}
		
		object_ref(ref_counter_ptr<object>&& ptr) : ptr_(std::move(ptr)) {}

		FLOW_INLINE int obj_id() const {
			return ptr_->obj_id_;
		}
		
		FLOW_INLINE void operator= (const object_ref& oth) {
			release();
			ptr_ = oth.ptr_;
		}
		
		FLOW_INLINE const object& operator* () const {
			return *(ptr_.get());
		}
		
		FLOW_ALWAYS_INLINE ~object_ref() {
			if (!ptr_) return;
			release();
		}
		
		FLOW_INLINE bool is_same(const object_ref& oth) const {
			return ptr_.get() == oth.ptr_.get();
		}
	
	private:
		FLOW_ALWAYS_INLINE void release() {
			FLOW_ASSUME(ptr_.ptr_ != nullptr);
			FLOW_ASSERT(!!ptr_);
			auto ptr = ptr_.release();
			if (!!ptr) {
				destroy(ptr);
			}
		}
		
		FLOW_ALWAYS_INLINE void destroy(const object* ptr) {
			#ifdef DEBUG
				#ifdef FLOW_ENABLE_CONCURRENCY
					if (!threads_pool::concurrency_enabled) {
						gAllocated.fetch_sub(1);
					}
				#else
					gAllocated--;
				#endif
				gDeleted++;
			#endif
			ptr->~object();
			get_mem_pools()->release((char*)ptr, ptr->obj_size_);
		}
	};
	
	template <typename T>
	using is_struct_type_t = std::enable_if_t<std::is_base_of_v<object, T>>;

	// base class for unions
	struct union_base {
		flow::object_ref ptr_;
		
		FLOW_ALWAYS_INLINE int id_() const {
			return ptr_.ptr_->obj_id_;
		}

		union_base(const flow::object_ref& ptr) : ptr_(ptr) {}
		union_base(flow::object_ref&& ptr) : ptr_(std::move(ptr)) {}
		
		union_base(int id, const flow::object_ref& ptr) : ptr_(ptr) {
			FLOW_ASSERT(id == ptr_.ptr_->obj_id_);
		}
		
		union_base(int id, flow::object_ref&& ptr) : ptr_(std::move(ptr)) {
			FLOW_ASSERT(id == ptr_.ptr_->obj_id_);
		}
		
		FLOW_ALWAYS_INLINE ~union_base() {}
		
	};

	static_assert (sizeof(union_base) == sizeof(void*), "union_base size");
	
	template <typename T>
	using is_union_type_t = std::enable_if_t<std::is_base_of_v<union_base, T>>;
	
	struct flow_t;
	
	template <typename T>
	struct ptr {
		object_ref ref_;
		
		ptr(const T* obj) : ref_(obj) {}
		
		template <typename TT>
		ptr(const ptr<TT>& ptr1) : ptr<T>(ptr1.ref_) {}
		
		ptr(const object_ref ref) : ref_(ref) {
			FLOW_ASSERT(ref_.ptr_->obj_id_ == T::struct_id_);
		}
		
		ptr(const flow_t&);
		
		ptr(const union_base& u) : ref_(u.ptr_) {
			if (u.id_() != T::struct_id_) {
				std::wcout << "ERROR! Attempt to convert from " 
						   << static_cast<std::wstring>(get_struct_desc(u.id_()).name)
						   << " to " 
						   << static_cast<std::wstring>(get_struct_desc(T::struct_id_).name)
						   << std::endl;
				FLOW_ABORT;
			}
		}
		
		FLOW_ALWAYS_INLINE ~ptr() {}
		
		FLOW_INLINE int obj_id() const {
			return ref_.obj_id();
		}
		
		FLOW_INLINE const T& operator*() const {
			return *static_cast<const T*>(&(*ref_));
		}

		FLOW_INLINE const T* operator->() const {
			return static_cast<const T*>(&(*ref_));
		}
	};
	
	template <typename T, bool is_struct>
	struct ptr_type2 {};
	
	template <typename T>
	struct ptr_type2<T, false> {
		typedef T type;
	};
	
	template <typename T>
	struct ptr_type2<T, true> {
		typedef ptr<T> type;
	};
	
	template <typename T>
	using ptr_type_t = typename ptr_type2<T, std::is_base_of_v<object, T>>::type;
	
	template <typename T, class... Args>
	__attribute__((always_inline)) inline ptr<T> create_struct_ptr(Args&&... args) {
		#ifdef FLOW_MEM_SIZE_STATS
			mem_size_stats[sizeof(T)]++;
		#endif
		
		char* ptr1 = get_mem_pools()->allocate(sizeof(T));
		T* ptr2 = new (ptr1) T(std::forward<Args>(args)...);
		return flow::ptr<T>(ptr2);
	}
	
	template <typename T>
	bool operator== (const ptr<T>& p1, const ptr<T>& p2) { return *p1 == *p2; }

	template <typename T>
	bool operator< (const ptr<T>& p1, const ptr<T>& p2) { return *p1 < *p2; }
	
	template <typename T, typename TT>
	T cast(const TT& oth) {
		return T(reinterpret_cast<const T&>(oth));
	}
	
	template <typename T>
	struct fparam2 {
		typedef const ptr_type_t<T>& type;
	};
	
	template <>
	struct fparam2<int> {
		typedef const int type;
	};
	
	template <>
	struct fparam2<double> {
		typedef const double type;
	};
	
	template <>
	struct fparam2<bool> {
		typedef const bool type;
	};
	
	template <typename T>
	using fparam = typename fparam2<T>::type;
	
	void print_mem_stat() {
#ifndef NDEBUG
		std::wcout << L"gNew0 = " 		<< gNew0 		<< std::endl;
		std::wcout << L"gNew1 = " 		<< gNew1 		<< std::endl;
		std::wcout << L"gAllocated = "	<< gAllocated 	<< std::endl;
		std::wcout << L"gMoved     = " 	<< gMoved 		<< std::endl;
		std::wcout << L"gCreated   = " 	<< gCreated		<< std::endl;
		std::wcout << L"gDeleted   = " 	<< gDeleted		<< std::endl;
		std::wcout << L"gCreatedInPool = " 	<< gCreatedInPool << std::endl;
		// FLOW_ASSERT(gCreated == gDeleted);
#endif
#ifdef FLOW_MEM_SIZE_STATS
		for (auto& p : mem_size_stats) {
			std::wcout << p.first << L" - " << p.second << std::endl;
		}
#endif
	}

} // namespace flow