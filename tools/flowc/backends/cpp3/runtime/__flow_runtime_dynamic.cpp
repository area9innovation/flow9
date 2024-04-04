#include "__flow_runtime_dynamic.hpp"

namespace flow {

const string Dyn::type_names[] = {
	u"unknown", u"void",   u"int",   u"bool", u"double", 
	u"string",  u"native", u"array", u"ref",  u"function"
};

std::unordered_map<string, int32_t> Dyn::struct_name_to_id;
std::unordered_map<int32_t, StructDef> Dyn::struct_id_to_def;
std::unordered_map<string, FunDef> Dyn::fun_name_to_def;

}
