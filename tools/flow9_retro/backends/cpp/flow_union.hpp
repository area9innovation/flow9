#include <variant>
#include "flow_memory.hpp"


template <typename ...T>
struct _FlowUnion : std::variant<T...> {
	int _counter = 1;
	~_FlowUnion() {
		std::cout << (_counter == 0 ? "" : " !!ERROR!! ") << " ~ destroy _FlowUnion; counter=" << _counter << " &=" << this << " ~ " << std::endl;
		dropFields();
	}
	bool operator!=(const _FlowUnion& a) const { return *this != a; }

	template <typename F>
	decltype(auto) visit(F&& f)& {
		return std::visit(std::forward<F>(f), static_cast<_FlowUnion::variant&>(*this));
	}
	void dupFields() {
		// std::visit([](auto&& a) { dup(a); }, *this); // VS (win) compiler
		(*this).visit([&](auto&& v) { dup(v); }); // g++ -std=c++2a ...
	}
	void dropFields() {
		// std::visit([](auto&& a) { drop(a); }, *this);
		(*this).visit([&](auto&& v) { drop(v); });
	}
};

// TODO: fix it!
template <typename ...A, typename ...B>
bool operator==(const _FlowUnion<A*...>& a, const _FlowUnion<B*...>& b) {	
	bool res = false;
	// works. VS, win
	//std::visit(
	//	[&b, &res](auto&& v1) { std::visit(
	//		[&v1, &res](auto&& v2) { res= (*v1 == *v2);/*std::cout<< "INSIDE!!! "<< (*v1 == *v2)<<std::endl;*/ },
	//		b
	//	); },
	//	a
	//);

	_FlowUnion<A*...>& a1 = const_cast <_FlowUnion<A*...>&>(a);
	_FlowUnion<B*...>& b1 = const_cast <_FlowUnion<B*...>&>(b);
	a1.visit(
		[&b1, &res](auto&& v1) { b1.visit(
			[&v1, &res](auto&& v2) { res = (*v1 == *v2);}
		); }
	);

	return res;
}

template <typename ...A, typename ...B>
bool operator<(const _FlowUnion<A*...>& a, const _FlowUnion<B*...>& b) {
	bool res = false;
	_FlowUnion<A*...>& a1 = const_cast <_FlowUnion<A*...>&>(a);
	_FlowUnion<B*...>& b1 = const_cast <_FlowUnion<B*...>&>(b);
	a1.visit(
		[&b1, &res](auto&& v1) { b1.visit(
			[&v1, &res](auto&& v2) { res = (*v1) < (*v2);}
	); }
	);

	return res;
}

template <typename ...A, typename ...B>
bool operator>(const _FlowUnion<A*...>& a, const _FlowUnion<B*...>& b) {
	bool res = false;
	_FlowUnion<A*...>& a1 = const_cast <_FlowUnion<A*...>&>(a);
	_FlowUnion<B*...>& b1 = const_cast <_FlowUnion<B*...>&>(b);
	a1.visit(
		[&b1, &res](auto&& v1) { b1.visit(
			[&v1, &res](auto&& v2) { res = (*v1 > *v2);}
	); }
	);

	return res;
}

template <typename ...A, typename ...B>
bool operator<=(const _FlowUnion<A*...>& a, const _FlowUnion<B*...>& b) {
	bool res = false;
	_FlowUnion<A*...>& a1 = const_cast <_FlowUnion<A*...>&>(a);
	_FlowUnion<B*...>& b1 = const_cast <_FlowUnion<B*...>&>(b);
	a1.visit(
		[&b1, &res](auto&& v1) { b1.visit(
			[&v1, &res](auto&& v2) { res = (*v1 <= *v2);}
	); }
	);

	return res;
}

template <typename ...A, typename ...B>
bool operator>=(const _FlowUnion<A*...>& a, const _FlowUnion<B*...>& b) {
	bool res = false;
	_FlowUnion<A*...>& a1 = const_cast <_FlowUnion<A*...>&>(a);
	_FlowUnion<B*...>& b1 = const_cast <_FlowUnion<B*...>&>(b);
	a1.visit(
		[&b1, &res](auto&& v1) { b1.visit(
			[&v1, &res](auto&& v2) { res = (*v1 >= *v2);}
	); }
	);

	return res;
}