#include <vector>

template <typename T>
struct _FlowArray : std::vector<T> {
	int _counter = 1;
	_FlowArray(std::initializer_list<T> il) : std::vector<T>(il) {}
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

template <typename T>
void drop(_FlowArray<T>* a) {
	if (a == nullptr) {
		std::cout << "ERROR :: can't free memory for NULL" << std::endl;
	} else {
		(*a)._counter -= 1;
		(*a).dropFields();

		if ((*a)._counter < 1) {
			std::cout << "FREE vector:: &=" << &a << "; counter = " << (*a)._counter << "; type=" << demangle(typeid(a).name()) << std::endl;
			delete a;
			a = nullptr;
		}
		else {
			std::cout << "DEC COUNTER vector:: &=" << &a << "; counter = " << (*a)._counter << "; type=" << demangle(typeid(a).name()) << std::endl;
		}
	}
}