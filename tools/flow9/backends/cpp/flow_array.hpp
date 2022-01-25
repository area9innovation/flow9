#include <vector>

template <typename T>
struct _FlowArray {
	int _counter = 1;
	std::vector<T> value;
	_FlowArray(std::initializer_list<T> il) { value = std::vector<T>(il); }

	void dupFields() {
		for (std::size_t i = 0; i < value.size(); ++i) {
			dup(value[i]);
		}
	}
	void dropFields() {
		for (std::size_t i = 0; i < value.size(); ++i) {
			drop(value[i]);
		}
	}
};

template <typename T>
void drop(_FlowArray<T>* a) {
	if (a == nullptr) {
		std::cout << "ERROR :: can't free memory for NULL" << std::endl;
	} else {
		(*a)._counter -= 1;

		if ((*a)._counter < 1) {
			std::cout << "FREE simple vector:: &=" << &a << "; counter = " << (*a)._counter << "; type=" << demangle(typeid(a).name()) << std::endl;
			delete a;
			a = nullptr;
		}
		else {
			std::cout << "DEC COUNTER simple vector:: &=" << &a << "; counter = " << (*a)._counter << "; type=" << demangle(typeid(a).name()) << std::endl;
		}
	}
}

template <typename T>
void drop(_FlowArray<T*>* a) {
	if (a == nullptr) {
		std::cout << "ERROR :: can't free memory for NULL" << std::endl;
	}
	else {
		(*a)._counter -= 1;
		(*a).dropFields();

		if ((*a)._counter < 1) {
			std::cout << "FREE vector of structs:: &=" << &a << "; counter = " << (*a)._counter << "; type=" << demangle(typeid(a).name()) << std::endl;
			delete a;
			a = nullptr;
		}
		else {
			std::cout << "DEC COUNTER vector of structs:: &=" << &a << "; counter = " << (*a)._counter << "; type=" << demangle(typeid(a).name()) << std::endl;
		}
	}
}