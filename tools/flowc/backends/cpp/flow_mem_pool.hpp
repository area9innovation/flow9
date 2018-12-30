#pragma once

#include "flow_defines.hpp"
#include "flow_perf.hpp"

#ifdef FLOW_ENABLE_CONCURRENCY
	#include "concurrency.hpp"
#endif

#include <vector>
#include <memory>
#include <thread>

#ifdef DEBUG
	#include <set>
	#include <iostream>
#endif

namespace flow {
	
	struct mem_pool_page {
		// TODO: vector might be changed to malloc()
		std::vector<char> page_bytes_;
		const static int page_size = 1024*16*4;
		char* head_;
		
		struct free_slot_marker {
			free_slot_marker*	next;
		#ifdef FLOW_DEBUG_MEMPOOLS
			free_slot_marker*	next2;
		#endif
			
			void mark_free(void* ptr) {
				next = (free_slot_marker*)ptr;
				#ifdef FLOW_DEBUG_MEMPOOLS
					next2 = next;
				#endif
			}
		};
		
		static_assert(sizeof(free_slot_marker) <= 16);
		
		mem_pool_page(int elem_size) {
			int n = page_size / elem_size;
			FLOW_ASSERT(page_bytes_.empty());
			// TODO: change it to malloc()
			page_bytes_.resize(n * elem_size);
			char* page_ptr = &(page_bytes_[0]);
			char* prev_free = nullptr;
			char* cur = nullptr;
			for (int i = 0; i < n; i++) {
				cur = page_ptr + elem_size * (n-1-i);
				((mem_pool_page::free_slot_marker*)cur)->mark_free(prev_free);
				prev_free = cur;
			}
			head_ = cur;
		}
		
		free_slot_marker* head() {
			return (free_slot_marker*)head_;
		}
		
		mem_pool_page(mem_pool_page&& oth) : page_bytes_(std::move(oth.page_bytes_)) {
		}
		
		~mem_pool_page() {
		}
		
	#ifdef DEBUG
		inline bool belongs(char* ptr) {
			char* page_ptr = &(page_bytes_[0]);
			return ptr >= page_ptr && ptr < page_ptr + page_size;
		}
	#endif
	
	};
	
	uint64_t g_page_alloc = 0;

	struct mem_pool {
		std::vector<mem_pool_page> pages_;	// pages_ are actually used only in debug...
		int elem_size_ = 0;
		
		mem_pool_page::free_slot_marker* top_free_slot_ = nullptr;
		
		// const bool is_concurrent
	
		mem_pool() {}
		
		mem_pool(int elem_size) {
			init(elem_size);
		}
		
		void init(int elem_size) {
			elem_size_ = elem_size;
			FLOW_ASSERT(elem_size_ > 0);
		}
		
		FLOW_INLINE char* allocate() {
			auto result = top_free_slot_;
			if (result != nullptr) {
				#ifdef FLOW_DEBUG_MEMPOOLS
					if (result->next != result->next2) {
						FLOW_PRN(result->next);
						FLOW_PRN(result->next2);
					}
					FLOW_ASSERT(result->next == result->next2);
				#endif
				top_free_slot_ = result->next;
				return (char*)result;
			} else {
				return allocate2();
			}
		}
		
		char* allocate2() {
			FLOW_ASSERT(top_free_slot_ == nullptr);
			tsc_holder holder(g_page_alloc);
			pages_.emplace_back(elem_size_);
			auto result = pages_.back().head();
			FLOW_ASSERT(result != nullptr);
			#ifdef FLOW_DEBUG_MEMPOOLS
				FLOW_ASSERT(result->next == result->next2);
			#endif
			top_free_slot_ = result->next;
			return (char*)result;
		}
		
		FLOW_INLINE void release(char* ptr) {
			#ifdef DEBUG
				FLOW_ASSERT(belongs(ptr));
			#endif
			#ifdef DEBUG
				std::memset(ptr, -1, elem_size_);
			#endif
			mem_pool_page::free_slot_marker* prev_free = top_free_slot_;
			auto new_free = ((mem_pool_page::free_slot_marker*)ptr);
			new_free->mark_free(prev_free);
			top_free_slot_ = new_free;
		}
		
		uint64_t mem_size() const {
			return pages_.size() * mem_pool_page::page_size;
		}

	private:
		#ifdef DEBUG
		FLOW_INLINE bool belongs(char* ptr) {
			for (int i = 0; i < pages_.size(); i++) {
				if (pages_[i].belongs(ptr)) return true;
			}
			return false;
		}
		#endif
	};
	
	struct mem_pools_manager {
		const static int max_obj_size = 1024;
		
		mem_pools_manager() {
			int max_id = max_obj_size/16;
			for (int i = 0; i <= max_id; i++) {
				pools_[i].init((i+1)*16);
			}
		}
		
		FLOW_INLINE constexpr static int size2poolId(int size) {
			FLOW_ASSERT(size <= max_obj_size);
			FLOW_ASSERT(size > 0);
			return (size + 15) / 16 - 1;
		}
		
		FLOW_INLINE char* allocate(int size) {
			// tsc_holder holder(alloc_tsc_);
			return pools_[size2poolId(size)].allocate();
		}
		
		FLOW_INLINE void release(char* ptr, int size) {
			// tsc_holder holder(release_tsc_);
			pools_[size2poolId(size)].release(ptr);
		}
		
		uint64_t mem_size() const {
			uint64_t s = 0;
			for (int i = 0; i < pools_count; i++) {
				s += pools_[i].mem_size();
			}
			return s;
		}
		
		uint64_t alloc_tsc_ = 0;
		uint64_t release_tsc_ = 0;
		
	private:
		static const int pools_count = max_obj_size/16+1;
		mem_pool 	pools_[pools_count];

	};
	
#ifdef FLOW_ENABLE_CONCURRENCY
	mem_pools_manager concurrent_mem_pools_managers[threads_pool::NTHREADS];
	thread_local mem_pools_manager* g_local_thread_mem_pools = nullptr;
#endif
	
} // namespace flow
