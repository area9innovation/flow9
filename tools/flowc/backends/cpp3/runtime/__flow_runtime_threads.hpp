#pragma once

#include <vector>
#include <functional>
#include <memory>
#include <mutex>
#include <thread>
#include <condition_variable>
#include <deque>
#include <future>
#include <iostream>
#include "__flow_runtime_memory.hpp"

namespace flow {

class ThreadPool {
public:
	ThreadPool(size_t num) : running_(true), thread_joiner_(threads_) {
		main_thread_id_ = std::this_thread::get_id();
		MemoryPool::addThread(main_thread_id_, true);
		threads_.reserve(num);
		for (size_t i = 0; i < num; ++i) {
			threads_.emplace_back(std::bind(&ThreadPool::run, this));
			MemoryPool::addThread(threads_.back().get_id(), false);
		}
	}
	~ThreadPool() {{
			std::lock_guard<std::mutex> lock(pool_mutex_);
			for (const auto& th: threads_) {
				MemoryPool::removeThread(th.get_id());
			}
			MemoryPool::removeThread(main_thread_id_);
			running_ = false;
		}
		not_empty_.notify_all();
	}
	enum class Shutdown { Block, Skip };
	static void init(Int numThreads) {
		instance_ = std::make_unique<ThreadPool>(numThreads);
	}
	static inline void release() {
		std::cout << "going to release ThreadPool..." << std::endl;
		instance_.reset();
		std::cout << "ThreadPool is RELEASED" << std::endl;
	}
	template<typename R>
    static std::future<R> push(Shutdown behavior, std::function<R()> fn) {
        return instance_->pushTask(behavior, std::move(fn));
    }
	static const std::vector<std::thread>& threads() {
		return instance_->threads_;
	}
	static Int size() {
		return instance_->threads_.size();
	}
	static const std::thread& thread(Int i) {
		auto p = instance_->threads_.begin();
		while (i-- > 0) ++p;
		return *p;
	}
	static Int currentThread() {
		if (std::this_thread::get_id() == instance_->main_thread_id_) {
			return 0;
		} else {
			Int i = 1;
			for (auto& th: instance_->threads_) {
				if (th.get_id() == std::this_thread::get_id()) {
					return i;
				} else {
					++i;
				}
			}
			return -1;
		}
	}
	static void join() {
		instance_->thread_joiner_.join();
	}
private:
	using Task = std::pair<std::function<void()>, Shutdown>;
	template<typename R>
    std::future<R> pushTask(Shutdown behavior, std::function<R()> fn) {
        // We have to manage the packaged_task with shared_ptr, because std::function<>
        // requires being copy-constructible and copy-assignable.
        auto task_fn = std::make_shared<std::packaged_task<R()>>(fn);
        auto future = task_fn->get_future();
        Task task([task_fn=std::move(task_fn)] { (*task_fn)(); }, behavior); {
            std::lock_guard<std::mutex> lock(pool_mutex_);
            task_queue_.push_back(std::move(task));
        }
        not_empty_.notify_one();
        return future;
    }
    void run() {
		while (true) {
			Task task(retrieve());
			// The pool is going to shutdown.
			if (!task.first) {
				return;
			}
			task.first();
		}
	}

    Task retrieve() {
		Task task;
		std::unique_lock<std::mutex> lock(pool_mutex_);
		not_empty_.wait(lock, [this] { return !running_ || !task_queue_.empty(); });
		while (!task_queue_.empty()) {
			if (!running_ && task_queue_.front().second == Shutdown::Skip) {
				task_queue_.pop_front();
				continue;
			}
			task = std::move(task_queue_.front());
			task_queue_.pop_front();
			break;
		}
		return task;
	}

	class ThreadsJoiner {
		public:
			explicit ThreadsJoiner(std::vector<std::thread>& threads) noexcept: threads_(threads) {}
			~ThreadsJoiner() {
				join();
			}
			void join() {
				for (auto& th : threads_) {
					th.join();
				}
			}
		private:
			std::vector<std::thread>& threads_;
	};
	std::thread::id main_thread_id_;
    std::mutex pool_mutex_;
    std::condition_variable not_empty_;
    std::deque<Task> task_queue_;
    bool running_;
    std::vector<std::thread> threads_;
    ThreadsJoiner thread_joiner_;
	static std::unique_ptr<ThreadPool> instance_;
};

}
