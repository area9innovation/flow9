#include <variant>
#include "flow_memory.hpp"


template <typename ...T>
struct _FlowUnion : std::variant<T...> {
	int _counter = 1;
	~_FlowUnion() {
		std::cout << (_counter == 0 ? "" : " !!ERROR!! ") << " ~ destroy _FlowUnion; counter=" << _counter << " &=" << this << " ~ " << std::endl;
		dropFields();
	}
	//bool operator==(const _FlowUnion& a) const { return areValuesEqual(*this, a); }

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

