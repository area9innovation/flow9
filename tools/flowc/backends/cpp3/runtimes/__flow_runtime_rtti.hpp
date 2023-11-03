#pragma once

#include <vector>
#include <functional>
#include <unordered_map>
#include <cxxabi.h>
#include "__flow_runtime_types.hpp"

namespace flow {

// Runtime type information: structs

template<typename T>
inline string type2string() {
	int status = -1;
	char* name = abi::__cxa_demangle(typeid(T).name(), NULL, NULL, &status);
	std::string ret(name);
	delete name;
	return std2string(ret);
}
template<typename T>
inline std::string type2StdString() {
	int status = -1;
	char* name = abi::__cxa_demangle(typeid(T).name(), NULL, NULL, &status);
	std::string ret(name);
	delete name;
	return ret;
}
struct FieldDef {
	string name;
	TypeId type;
};

struct StructDef {
	string name;
	TypeId type;
	std::vector<FieldDef> args;
	std::function<Flow*(Vec<Flow*>*)> constructor;
};

struct RTTI {
	static const string& typeName(TypeId id) {
		if (id < 0) return type_names[0]; else
		if (id < structTypeIdOffset) return type_names[id + 1]; else
		if (id - structTypeIdOffset < static_cast<TypeId>(struct_defs.size())) {
			return struct_defs.at(id - structTypeIdOffset).name;
		} else {
			return type_names[0];
		}
	}
	static std::string typeNameStd(TypeId id) {
		return string2std(typeName(id));
	}
	static inline bool structExists(TypeId id) {
		return
			structTypeIdOffset <= id &&
			id - structTypeIdOffset < static_cast<TypeId>(struct_defs.size());
	}
	static const StructDef& structDef(TypeId id) {
		if (id - structTypeIdOffset < static_cast<TypeId>(struct_defs.size())) {
			return struct_defs.at(id - structTypeIdOffset);
		} else {
			static StructDef undef;
			fail("undefined struct with type id: " + string2std(int2string(id)));
			return undef;
		}
	}
	static int structField(TypeId id, const string& field) {
		int i = 0;
		for (auto& arg : structDef(id).args) {
			if (arg.name == field) break;
			i += 1;
		}
		return i;
	}
	static TypeId structId(const string& struct_name) {
		auto x = struct_name_to_id.find(struct_name);
		if (x == struct_name_to_id.end()) {
			return -1;
		} else {
			return x->second;
		}
	}
	static void initStructMap() {
		for (int i = structTypeIdOffset; i < static_cast<TypeId>(struct_defs.size()) + structTypeIdOffset; ++i) {
			const StructDef& def = struct_defs.at(i - structTypeIdOffset);
			struct_name_to_id[def.name] = i;
		}
	}
private:
	// List of names for the types in TypeFx
	static const string type_names[];
	// Sequence of all struct definitions
	static std::vector<StructDef> struct_defs;
	// Maps a struct name to its id.
	static std::unordered_map<string, int32_t> struct_name_to_id;
};

// Predicate for compile-time type resolution

namespace traits {
	template<typename T> struct get_type_id { enum { result = TypeFx::UNKNOWN }; };
	template<> struct get_type_id<Void> { enum { result = TypeFx::VOID }; };
	template<> struct get_type_id<Int> { enum { result = TypeFx::INT }; };
	template<> struct get_type_id<Bool> { enum { result = TypeFx::BOOL }; };
	template<> struct get_type_id<Double> { enum { result = TypeFx::DOUBLE }; };
	template<> struct get_type_id<String> { enum { result = TypeFx::STRING }; };
	template<> struct get_type_id<Native> { enum { result = TypeFx::NATIVE }; };
	template<> struct get_type_id<Flow> { enum { result = TypeFx::FLOW }; };
	template<typename T> struct get_type_id<Vec<T>> { enum { result = TypeFx::ARRAY }; };
	template<typename T> struct get_type_id<Ref<T>> { enum { result = TypeFx::REF }; };
	template<typename R, typename... As> struct get_type_id<Fun<R, As...>> { enum { result = TypeFx::FUNC }; };
	template<TypeId Id, typename... Fs> struct get_type_id<Str<Id, Fs...>> { enum { result = Id }; };
}
template<typename T> constexpr TypeId get_type_id_v = traits::get_type_id<std::remove_pointer_t<T>>::result;
template<TypeId Id, typename T> constexpr bool is_type_v = get_type_id_v<T> == Id;
template<typename T> constexpr bool is_struct_v = get_type_id_v<T> >= TypeFx::STRUCT_TYPE_ID_OFFSET;
template<typename T> constexpr bool is_union_v = std::is_same_v<std::remove_pointer_t<T>, Union>;
template<typename T> constexpr bool is_struct_or_union_v = is_struct_v<T> || std::is_same_v<Union, std::remove_pointer_t<T>>;
template<typename T> constexpr bool is_flow_ancestor_v = std::is_base_of_v<Flow, std::remove_pointer_t<T>>;
template<typename T> constexpr bool is_scalar_v =
	is_type_v<TypeFx::VOID, T> ||
	is_type_v<TypeFx::INT, T> ||
	is_type_v<TypeFx::BOOL, T> ||
	is_type_v<TypeFx::DOUBLE, T>;

}
