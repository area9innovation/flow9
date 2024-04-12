#pragma once

#include <vector>
#include <memory>
#include <unordered_map>
#include <mutex>
#include <thread>
#include <tuple>
#include <stack>
#include <meminfo.h>
#include "__flow_runtime_types.hpp"

namespace flow {

struct MemoryPool {
	enum { MAX_SIZE = 1024 };
	MemoryPool(std::size_t max_size): max_size_ (max_size) { }
	static void init(std::size_t max_size = MAX_SIZE) {
		instance_ = std::make_unique<MemoryPool>(max_size);
	}
	static inline void release() {
		instance_.reset();
	}
	static void addThread(std::thread::id thread_id, bool main) {
		instance_->threads_.emplace(std::pair<std::thread::id, PerThread>(
			std::piecewise_construct, std::tuple(thread_id), std::tuple(instance_->max_size_, main)
		));
	}
	static void removeThread(std::thread::id thread_id) {
		if (instance_) {
			auto p = instance_->threads_.find(thread_id);
			if (p != instance_->threads_.end()) {
				instance_->threads_.erase(p);
			}
		}
	}
	template<typename T>
	inline static void* alloc() {
		return instance_->threads_.at(std::this_thread::get_id()).alloc(sizeof(T));
	}
	template<typename T>
	inline static void free(T* p) {
		instance_->threads_.at(std::this_thread::get_id()).free(p, sizeof(T));
	}
	static void clear() {
		for (auto& p: instance_->threads_) {
			p.second.clear();
		}
	}
	struct PerSizeFixed {
		enum { MEM_CAPACITY = 64 * 1024 * 1024};
		PerSizeFixed(std::size_t s, bool in_main):
			size_(s),
			in_main_thread_(in_main),
			capacity_ (MEM_CAPACITY / size_),
			top_(0) {
				pool_ = new void* [capacity_];
		}
		~PerSizeFixed() {
			clear();
			delete[] pool_;
		}
		inline void* alloc() {
			if (top_ == 0) {
				return operator new(size_);
			} else {
				return pool_[--top_];
			}
		}
		inline void free(void* p) {
			if (top_ >= capacity_) {
				operator delete(p);
			} else {
				pool_[top_++] = p;
			}
		}
		void clear() {
			while (top_ > 0) {
				operator delete(pool_[--top_]);
			}
		}
		inline std::size_t size() const {
			return top_; 
		}
		inline std::size_t mem() const {
			return size_ * top_; 
		}
	private:
		const std::size_t size_;
		const bool in_main_thread_;
		std::size_t capacity_;
		std::size_t top_;
		void** pool_;
	};
	struct PerSize {
		enum { MEM_CAPACITY = 64 * 1024 * 1024};
		PerSize(std::size_t s, bool in_main):
			size_(s), capacity_(MEM_CAPACITY / size_), in_main_thread_(in_main) { 
 		}
		~PerSize() {
 			clear();
 		}
 		inline void* alloc() {
			if (pool_.empty()) {
				return operator new(size_);
 			} else {
				void* x = pool_.top();
				pool_.pop();
				return x;
 			}
 		}
 		inline void free(void* p) {
			if (pool_.size() < capacity_) {
				pool_.push(p);
			} else {
				operator delete(p);
			}
 		}
 		void clear() {
			while (!pool_.empty()) {
				operator delete(pool_.top());
				pool_.pop();
 			}
 		}
 		inline std::size_t size() const {
			return pool_.size();
 		}
 		inline std::size_t mem() const {
			return size_ * pool_.size(); 
 		}
 	private:
 		const std::size_t size_;
		const std::size_t capacity_;
 		const bool in_main_thread_;
		std::stack<void*> pool_;
 	};
	struct PerThread {
		PerThread(std::size_t ms, bool is_main): max_size_(ms), in_main_thread_(is_main) {
			shards_.reserve(max_size_);
			for (std::size_t size = 16; size <= max_size_; size += 8) {
				shards_.emplace_back(size, in_main_thread_);
			}
		}
		PerThread(const PerThread& pt) = default;
		PerThread(PerThread&& pt) = default;
		~PerThread() { clear(); }
		inline void* alloc(std::size_t size) {
			//if (size < 16 || size > max_size_) {
			//	return operator new(size);
			//} else {
				return shards_.at(size2ind(size)).alloc();
			//}
		}
		inline void free(void* p, std::size_t size) {
			//if (size < 16 || size > max_size_) {
			//	operator delete(p);
			//} else {
				shards_.at(size2ind(size)).free(p);
			//}
		}
		void clear() {
			for (PerSize& shard : shards_) {
				shard.clear();
			}
		}
		std::size_t mem() const {
			std::size_t m = 0;
			for (const PerSize& shard : shards_) {
				m += shard.mem() + sizeof(std::vector<PerSize>);
			}
			return m;
		}
		Int getShardsSize() const {
			return static_cast<Int>(shards_.size());
		}
		const PerSize& getSizePool(std::size_t size) const {
			return shards_.at(size2ind(size));
		}
	private:
		static inline std::size_t size2ind(std::size_t size) {
			return (size - 16) / 8;
		}
		const std::size_t max_size_;
		const bool in_main_thread_;
		std::vector<PerSize> shards_;
	};
	// Auxiliary functions
	static std::size_t mem() {
		std::size_t m = 0;
		for (auto& p : instance_->threads_) {
			m += p.second.mem() + sizeof(std::vector<PerThread>);
		}
		return m;
	}
	static std::size_t numThreads() {
		return static_cast<Int>(instance_->threads_.size());
	}
	static const PerThread& getThreadPool(Int i) {
		auto p = instance_->threads_.begin();
		while (i-- > 0) ++p;
		return p->second;
	}
	static std::size_t maxSize() {
		return instance_->max_size_;
	}
private:
	std::mutex m;
	std::size_t max_size_;
	std::unordered_map<std::thread::id, PerThread> threads_;
	static std::unique_ptr<MemoryPool> instance_;
};

constexpr bool use_memory_pool = false;
constexpr bool use_memory_manager = false;

struct Memory {
	template<typename T>
	inline static void* alloc() {
		using V = std::remove_pointer_t<T>;
		if constexpr (use_memory_pool) {
			return MemoryPool::alloc<V>();
		} else {
			return operator new(sizeof(V));
		}
	}
	template<typename T>
	inline static void destroy(T p) {
		if constexpr (use_memory_pool) {
			using V = std::remove_pointer_t<T>;
			p->destroy();
			MemoryPool::free<V>(p);
		} else {
			p->destroy();
			operator delete(p);
		}
	}
};

inline std::size_t memory_used_by_process() { return spp::GetProcessMemoryUsed(); }
inline std::size_t memory_total_used() { return spp::GetTotalMemoryUsed(); }
inline std::size_t memory_total_physical() { return spp::GetPhysicalMemory(); }
inline std::size_t memory_system() { return spp::GetSystemMemory();; }
inline std::size_t memory_free() { return static_cast<std::ptrdiff_t>(memory_total_physical()) - memory_total_used(); }
inline std::size_t memory_total() { return memory_free() + memory_used_by_process(); }
std::size_t memory_used(bool resident);

}
