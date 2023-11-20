#include "__flow_runtime_rtti.hpp"

namespace flow {

const string RTTI::type_names[] = {
	u"unknown", u"void",   u"int",   u"bool", u"double", 
	u"string",  u"native", u"array", u"ref",  u"function"
};

std::unordered_map<string, int32_t> RTTI::struct_name_to_id;

}
