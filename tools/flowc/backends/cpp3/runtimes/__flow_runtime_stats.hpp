#pragma once

#include <mutex>
#include <unordered_map>
#include <limits>
#include "__flow_runtime_types.hpp"

namespace flow {

struct IntStats {
	IntStats(): max_(std::numeric_limits<Int>::min()) { }
	void registerVal(Int v) {
		std::lock_guard<std::mutex> lock(m_);
		if (max_ < v) {
			max_ = v;
		}
		if (distrib_.find(v) == distrib_.end()) {
			distrib_[v] = 1;
		} else {
			++distrib_[v];
		}
	}
	Int valNum(Int v) const {
		if (distrib_.find(v) == distrib_.end()) {
			return 0;
		} else {
			return distrib_.at(v);
		}
	}
	inline Int maxVal() const { return max_; }
private:
	Int max_;
	std::mutex m_;
	std::unordered_map<Int, Int> distrib_;
};

}
