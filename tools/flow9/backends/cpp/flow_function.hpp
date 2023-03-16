#include <functional>

template< class R, class... Args >
struct _FlowFunction {
	int _counter = 1;
	int _captured_counter = 1;
	std::function<R(Args...)> value;
	std::function<void()> dupCapturedVars;
	std::function<void()> dropCapturedVars;

	_FlowFunction(std::function<R(Args...)>&& _value) {
		value = _value;
		dupCapturedVars = []() {};
		dropCapturedVars = []() {};
	}

	_FlowFunction(std::function<R(Args...)>&& _value, std::function<void()> _dupCapturedVars, std::function<void()> _dropCapturedVars) {
		value = _value;
		dupCapturedVars = _dupCapturedVars;
		dropCapturedVars = _dropCapturedVars;
	}

	_FlowFunction(R (_value)(Args...) ) {
		value = _value;
		dupCapturedVars = []() {};
		dropCapturedVars = []() {};
	}

	~_FlowFunction() {
		if (_captured_counter > 0) dropCapturedVars();
	}

	R operator()(Args... args) {
		_captured_counter--;
		return value(args...);
	}

	void dropFields() {
		if (_captured_counter > 1) {
			dropCapturedVars(); _captured_counter--;
		}
	}
	void dupFields() { _captured_counter++; dupCapturedVars();  }
};
