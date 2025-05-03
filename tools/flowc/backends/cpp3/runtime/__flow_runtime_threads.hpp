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
#include "__flow_runtime_types.hpp"

namespace flow {

class ThreadPool {
public:
	enum class Shutdown { Block, Skip };
	ThreadPool(size_t num, bool register_ = true) : thread_joiner_(threads_) {
		if (register_) {
			mutex_.lock();
			pool_id_ = max_id_++;
			instances_.emplace(pool_id_, this);
			mutex_.unlock();
		}
		threads_.reserve(num);
		for (size_t i = 0; i < num; ++i) {
			threads_.emplace_back(std::bind(&ThreadPool::run, this));
		}
	}
	~ThreadPool() {{
			std::lock_guard<std::mutex> lock(pool_mutex_);
			running_ = false;
		}
		not_empty_.notify_all();
		if (pool_id_ != -1) {
			instances_.erase(pool_id_);
		}
	}
	static inline void release() {
		mutex_.lock();
		while (!instances_.empty()) {
			delete instances_.begin()->second;
		}
		mutex_.unlock();
	}
	template<typename R>
    std::future<R> push(Shutdown behavior, std::function<R()> fn) {
		return pushTask(behavior, std::move(fn));
    }
	Int size() {
		return threads_.size();
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
				break;
			}
			try {
				task.first();
			} catch (std::exception& ex) {
				std::cerr << ex.what() << std::endl;
				break;
			}
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
	Int pool_id_ = -1;
    std::mutex pool_mutex_;
    std::condition_variable not_empty_;
    std::deque<Task> task_queue_;
    bool running_ = true;
    std::vector<std::thread> threads_;
    ThreadsJoiner thread_joiner_;

	static inline std::mutex mutex_;
	static inline Int max_id_ = 0;
	static inline std::map<Int, ThreadPool*> instances_;
};

}
