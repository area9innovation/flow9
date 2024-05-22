#pragma once

#include <vector>
#include <functional>
#include <unordered_map>
#include <cxxabi.h>
#include "__flow_runtime_types.hpp"
//#include <iostream>
#include <parallel_hashmap/phmap.h>

namespace flow {

// Runtime dynamic features

template<typename T>
inline string type2string() {
	int status = -1;
	char* name = abi::__cxa_demangle(typeid(T).name(), NULL, NULL, &status);
	std::string ret(name);
	free(name);
	return std2string(ret);
}
template<typename T>
inline std::string type2StdString() {
	int status = -1;
	char* name = abi::__cxa_demangle(typeid(T).name(), NULL, NULL, &status);
	std::string ret(name);
	free(name);
	return ret;
}
struct FieldDef {
	string name;
	TypeId type;
};

struct StructDef {
	string name;
	TypeId type;
	std::vector<FieldDef> fields;
	std::function<Flow*(Vec<Flow*>*)> constructor;
};

struct ArgDef {
	string name;
	TypeId type;
};

struct FunDef {
	string name;
	TypeId returnType;
	std::vector<ArgDef> args;
	std::function<Flow*(Vec<Flow*>*)> fn;
};

struct Dyn {
	static inline TypeId typeId2structId(TypeId id) {
		return id - structTypeIdOffset;
	}
	// Types
	static const string& typeName(TypeId id) {
		if (id < 0) return type_names[0]; else
		if (id < structTypeIdOffset) return type_names[id + 1]; else {
			Int struct_id = typeId2structId(id);
			if (struct_id < static_cast<TypeId>(struct_id_to_def.size())) {
				return struct_id_to_def.at(struct_id).name;
			} else {
				return type_names[0];
			}
		}
	}
	static inline std::string typeNameStd(TypeId id) {
		return string2std(typeName(id));
	}

	// Structs
	static inline bool structExists(TypeId id) {
		TypeId struct_id = typeId2structId(id);
		return 0 <= struct_id && typeId2structId(id) < static_cast<TypeId>(struct_id_to_def.size());
	}
	static inline const StructDef& structDef(TypeId id) {
		return struct_id_to_def.at(typeId2structId(id));
	}
	static int structField(TypeId id, const string& field) {
		int i = 0;
		for (auto& f : structDef(id).fields) {
			if (f.name == field) break;
			i += 1;
		}
		return i;
	}
	static TypeId structId(const string& struct_name) {
		auto x = struct_name_to_id.find(struct_name);
		TypeId id = (x == struct_name_to_id.end()) ? -1 : x->second;
		return (x == struct_name_to_id.end()) ? -1 : x->second;
	}
	static void registerStruct(StructDef&& def) {
		struct_name_to_id.insert({def.name, def.type});
		TypeId struct_id = typeId2structId(def.type);
		if (static_cast<TypeId>(struct_id_to_def.size()) <= struct_id) {
			struct_id_to_def.resize(struct_id + 1);
		}
		struct_id_to_def[struct_id] = std::move(def);
	}
	static void removeStruct(TypeId id) {
		TypeId struct_id = typeId2structId(id);
		if (0 <= struct_id && typeId2structId(id) < static_cast<TypeId>(struct_id_to_def.size())) {
			auto p2 = struct_name_to_id.find(struct_id_to_def.at(struct_id).name);
			if (p2 != struct_name_to_id.end()) {
				struct_name_to_id.erase(p2);
			}
			struct_id_to_def.erase(struct_id_to_def.begin() + struct_id);
		}
	}

	// Functions
	static inline bool funExists(const string& fn_name) {
		return fun_name_to_def.find(fn_name) != fun_name_to_def.end();
	}
	static const FunDef& funDef(const string& fn_name) {
		auto p = fun_name_to_def.find(fn_name);
		if (p != fun_name_to_def.end()) {
			return p->second;
		} else {
			static FunDef undef;
			fail("undefined function: " + string2std(fn_name));
			return undef;
		}
	}
	static inline void registerFun(FunDef&& def) {
		fun_name_to_def.insert({def.name, std::move(def)});
	}
	static void removeFun(const string& fn_name) {
		auto p = fun_name_to_def.find(fn_name);
		if (p != fun_name_to_def.end()) {
			fun_name_to_def.erase(p);
		}
	}

private:
	// List of names for the types in TypeFx
	static inline const string type_names[] = {
		u"unknown", u"void",   u"int",   u"bool", u"double",
		u"string",  u"native", u"array", u"ref",  u"function"
	};
	// Vector of struct definitions, indexed by struct_id
	static inline std::vector<StructDef> struct_id_to_def;
	// Maps a struct name to its id.
	static inline phmap::flat_hash_map<string, int32_t> struct_name_to_id;
	// Functions by name
	static inline phmap::flat_hash_map<string, FunDef> fun_name_to_def;
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
template<typename T> constexpr bool is_rcbase_ancestor_v = std::is_base_of_v<RcBase, std::remove_pointer_t<T>>;
template<typename T> constexpr bool is_scalar_v =
	is_type_v<TypeFx::VOID, T> ||
	is_type_v<TypeFx::INT, T> ||
	is_type_v<TypeFx::BOOL, T> ||
	is_type_v<TypeFx::DOUBLE, T>;

}
