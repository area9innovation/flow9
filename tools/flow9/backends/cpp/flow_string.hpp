#include <string>

struct _FlowString {
	int _counter = 1;
	std::u16string value;

	/*_FlowString(_In_z_ const _Elem* const _Ptr) {
		value = _Elem;
	}*/

	void dupFields() {}
	void dropFields() {}

	// TODO: operator+
};
