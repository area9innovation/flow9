#pragma once

#include <thread>
#include <condition_variable>
#include <mutex>
#include <deque>
#include <atomic>
#include <map>
#include <iostream>

namespace flow {
	
	struct spin_lock_guard {
		std::atomic_flag& flag_;

		spin_lock_guard(std::atomic_flag& flag) : flag_(flag) {
			while (flag_.test_and_set(std::memory_order_acquire))
				;
		}
		
		~spin_lock_guard() {
			flag_.clear();
		}
	};
	
	/*
	struct concurrent_allocator {
		
		static thread_local concurrent_allocator* allocator_;
		const static int BLOCK_SIZE = 1024*1024;
		
		char* current_block_ = nullptr;
		int current_pos_ = 0;
		
		char padding_[128];
		
		std::map<std::pair<int, int>, int> stat_;
		std::map<std::string, int> stat2_;
		
		std::vector<char*>	allocated_pages_;
		
		char* allocate(int size) {
			// stat_[size]++;
			size += sizeof(void*);
			size = (size+15)/16*16;
			if (size > BLOCK_SIZE) {
				FLOW_ABORT;
			}
			if (current_block_ == nullptr || current_pos_ + size > BLOCK_SIZE) {
				current_block_ = new char[BLOCK_SIZE];
				allocated_pages_.push_back(current_block_);
				current_pos_ = 0;
			}
			FLOW_ASSERT(current_pos_ + size <= BLOCK_SIZE);
			char* res = current_block_ + current_pos_;
			current_pos_ += size;
			*((void**)res) = nullptr;
			return res + sizeof(void*);
		}
		
		void clear() {
			for (auto& p : stat_) {
				const auto& pp = p.first;
				FLOW_PRN(pp.first << " " << pp.second << " * " << p.second << " = " << pp.second * p.second / 1048576.0);
			}
			for (auto& p : stat2_) {
				if (p.second > 1000)
				FLOW_PRN(p.first.c_str() << " - " << p.second);
			}
			stat_.clear();
			stat2_.clear();
			if (!allocated_pages_.empty()) {
				FLOW_PRN("deleted " << allocated_pages_.size() << " pages");
			}
			for (auto ptr : allocated_pages_) {
				delete ptr;
			}
			allocated_pages_.clear();
			current_block_ = nullptr;
		}
		
	};
	
	thread_local concurrent_allocator* concurrent_allocator::allocator_ = nullptr;
	*/
	
	class threads_pool {
		typedef std::function<void()> task_t;
		
		std::vector<std::thread> threads_;
		std::condition_variable cond_;
		std::condition_variable cond2_;
		std::mutex mutex_;
		std::deque<task_t> tasks_;
		std::atomic_flag tasks_lock_ = ATOMIC_FLAG_INIT;
		std::atomic_int threads_running_;
		
		std::function<void(int)> on_thread_start_;
		
		bool stop_ = false;
		
	public:
		static const int NTHREADS = 8;

		static bool concurrency_enabled;
		
		threads_pool(std::function<void(int)> on_thread_start) : on_thread_start_(on_thread_start) {
			threads_.reserve(NTHREADS);
			for (int i = 0; i < NTHREADS; i++) {
				std::thread th([this, i]() { thread_proc(i); });
				threads_.emplace_back(std::move(th));
			}
		}
		
		~threads_pool() {
			stop();
			for (int i = 0; i < NTHREADS; i++) {
				threads_[i].join();
			}
		}
		
		void run(const std::vector<task_t>& tasks) {
			FLOW_ASSERT(tasks_.empty());
			for (const task_t& t : tasks) {
				tasks_.emplace_back(t);
			}
			// FLOW_PRN("notify_all");
			threads_running_ = NTHREADS;
			cond_.notify_all();
			std::unique_lock<std::mutex> lock(mutex_);
			cond2_.wait(lock);
			FLOW_ASSERT(threads_running_.load() == 0);
		}
		
		// void clear_memory() {
			// for (int i = 0; i < NTHREADS; i++) {
				// allocators_[i].clear();
			// }
		// }
		
	private:
		
		void stop() {
			stop_ = true;
			cond_.notify_all();
		}
		
		void thread_proc(int thread_idx) {
			std::mutex m;
			on_thread_start_(thread_idx);
			while (true) {
				std::unique_lock<std::mutex> lock(m);
				// FLOW_PRN("thread " << thread_idx << " wait");
				cond_.wait(lock);
				if (stop_) break;
				concurrency_enabled = true;
				while (true) {
					while (tasks_lock_.test_and_set(std::memory_order_acquire))
						;
					if (tasks_.empty()) {
						tasks_lock_.clear(std::memory_order_release);
						break;
					}
					task_t f = std::move(tasks_.front());
					tasks_.pop_front();
					tasks_lock_.clear(std::memory_order_release);
					f();
				}
				// FLOW_PRN("thread " << thread_idx << " finished");
				if (1 == threads_running_.fetch_sub(1)) {
					cond2_.notify_one();
				}
			}
		}
	};
	
	bool threads_pool::concurrency_enabled = false;
	
} // namespace flow