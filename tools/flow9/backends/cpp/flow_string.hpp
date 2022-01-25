#include <string>

struct _FlowString {
	int _counter = 1;
	std::u16string value;

	_FlowString(_In_z_ const char16_t* const _Ptr) : value(_Ptr) {}
	_FlowString(std::u16string&& _Right) : value(_Right) {}
	

	void dupFields() {}
	void dropFields() {}

	// TODO: operator+
};
