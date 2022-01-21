#include <vector>
//#include "flow_memory.hpp"


// https://quuxplusone.github.io/blog/2018/12/11/dont-inherit-from-std-types/

template <typename T>
struct _FlowArray : std::vector<T> {
	int _counter = 1;
	_FlowArray(std::initializer_list<T> il) : std::vector<T>(il) {}
	~_FlowArray() {
		std::cout << (_counter == 0 ? "" : " !!ERROR!! ") << " ~ destroy _FlowArray; counter=" << _counter << " &=" << this << " ~ " << std::endl;
		dropFields();
	}
	//bool operator==(const _FlowUnion& a) const { return areValuesEqual(*this, a); }

	void dupFields() {
		auto v = (*this);
		for (std::size_t i = 0; i < v.size(); ++i) {
			dup(v[i]);
		}
	}
	void dropFields() {
		auto v = (*this);
		for (std::size_t i = 0; i < v.size(); ++i) {
			drop(v[i]);
		}
	}
};
