#include <vector>

template <typename T>
struct _FlowArray {
	int _counter = 1;
	std::vector<T> value;
	_FlowArray(std::initializer_list<T> il) { value = std::vector<T>(il); }

	// todo: simple types (remove dup)
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
		//std::cout << "ERROR :: can't free memory for NULL" << std::endl;
	} else {
		(*a)._counter -= 1;

		if ((*a)._counter < 1) {
			//std::cout << "FREE simple vector:: &=" << &a << "; counter = " << (*a)._counter << "; type=" << demangle(typeid(a).name()) << std::endl;
			delete a;
			a = nullptr;
		}
		else {
			//std::cout << "DEC COUNTER simple vector:: &=" << &a << "; counter = " << (*a)._counter << "; type=" << demangle(typeid(a).name()) << std::endl;
		}
	}
}

template <typename T>
void drop(_FlowArray<T*>* a) {
	if (a == nullptr) {
		//std::cout << "ERROR :: can't free memory for NULL" << std::endl;
	}
	else {
		(*a)._counter -= 1;
		(*a).dropFields();

		if ((*a)._counter < 1) {
			//std::cout << "FREE vector of structs:: &=" << &a << "; counter = " << (*a)._counter << "; type=" << demangle(typeid(a).name()) << std::endl;
			delete a;
			a = nullptr;
		}
		else {
			//std::cout << "DEC COUNTER vector of structs:: &=" << &a << "; counter = " << (*a)._counter << "; type=" << demangle(typeid(a).name()) << std::endl;
		}
	}
}

template <typename A, typename B>
bool operator==(const _FlowArray<A*>& a, const _FlowArray<B*>& b) {
	if (b.value.size() == a.value.size()) {
		bool eq = b.value.empty();
		for (std::size_t i = 0; i != b.value.size(); ++i) {
			eq = (*b.value[i]) == (*a.value[i]);
			if (!eq) break;
		}
		return eq;
	}
	else {
		return false;
	}
}

template <typename A, typename B>
bool operator==(const _FlowArray<A>& a, const _FlowArray<B>& b) {
	if (b.value.size() == a.value.size()) {
		bool eq = false;
		for (std::size_t i = 0; i != b.value.size(); ++i) {
			eq = b.value[i] == a.value[i];
			if (eq) break;
		}
		return eq;
	}
	else {
		return false;
	}
}

template <typename A, typename B>
bool operator<(const _FlowArray<A*>& a, const _FlowArray<B*>& b) {
	return std::lexicographical_compare(a.value.begin(), a.value.end(), b.value.begin(), b.value.end(), [](auto const& p1, auto const& p2) { return (*p1) < (*p2);});
}

template <typename A, typename B>
bool operator<(const _FlowArray<A>& a, const _FlowArray<B>& b) {
	return std::lexicographical_compare(a.value.begin(), a.value.end(), b.value.begin(), b.value.end(), [](auto const& p1, auto const& p2) { return (p1) < (p2);});
}

template <typename A, typename B>
bool operator>(const _FlowArray<A*>& a, const _FlowArray<B*>& b) {
	return b < a;
}

template <typename A, typename B>
bool operator>(const _FlowArray<A>& a, const _FlowArray<B>& b) {
	return b < a;
}

template <typename A, typename B>
bool operator<=(const _FlowArray<A*>& a, const _FlowArray<B*>& b) {
	return a == b || a < b;
}

template <typename A, typename B>
bool operator>=(const _FlowArray<A*>& a, const _FlowArray<B*>& b) {
	return a == b || a < b;
}

template <typename A, typename B>
bool operator==(const _FlowArray<A*>& a, const _FlowArray<B>& b) {
	return false;
}
template <typename A, typename B>
bool operator==(const _FlowArray<A>& a, const _FlowArray<B*>& b) {
	return false;
}

template <typename A, typename B>
bool operator<(const _FlowArray<A*>& a, const _FlowArray<B>& b) {
	return false;
}
template <typename A, typename B>
bool operator<(const _FlowArray<A>& a, const _FlowArray<B*>& b) {
	return false;
}

template <typename A, typename B>
bool operator>(const _FlowArray<A*>& a, const _FlowArray<B>& b) {
	return false;
}
template <typename A, typename B>
bool operator>(const _FlowArray<A>& a, const _FlowArray<B*>& b) {
	return false;
}

template <typename A, typename B>
bool operator<=(const _FlowArray<A*>& a, const _FlowArray<B>& b) {
	return false;
}
template <typename A, typename B>
bool operator<=(const _FlowArray<A>& a, const _FlowArray<B*>& b) {
	return false;
}

template <typename A, typename B>
bool operator>=(const _FlowArray<A*>& a, const _FlowArray<B>& b) {
	return false;
}
template <typename A, typename B>
bool operator>=(const _FlowArray<A>& a, const _FlowArray<B*>& b) {
	return false;
}

template <typename T>
T* getFlowArrayItem(_FlowArray<T*>* a, int32_t index) {
	T* res = dup((*(a)).value[index]);
	drop(a);
	return res;
}

// simple types
template <typename T>
T getFlowArrayItem(_FlowArray<T>* a, int32_t index) {
	T res = (*(a)).value[index];
	drop(a);
	return res;
}