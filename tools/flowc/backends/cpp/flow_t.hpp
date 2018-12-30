#pragma once

#include "flow_object.hpp"
#include "flow_array.hpp"

#include <variant>

struct native;

namespace flow {
	
	template <typename T>
	using array_t = array<ptr_type_t<T>>;
	
	struct flow_t {
		
		enum {
			is_struct = 0,
			is_array_of_flow_t = 1,
			is_int = 2,
			is_double = 3,
			is_string = 4,
			is_bool = 5,
		};
		
		std::variant<flow::object_ref, array<flow_t>, int, double, flow::string, bool> value_;
		
		template <typename T>
		flow_t(const ptr<T>& p) : value_(p.ref_) {}	// TODO: add move constructor later
		
		flow_t(const flow::object_ref& ref) : value_(ref) {}
		
		flow_t(const array<flow_t>& a) : value_(a) {}
		
		template <typename T>
		flow_t(const array_t<T>& a) : flow_t(convert_array(a)) {
			// TODO: avoid recreating of array here 
		}
		
		template <typename T, typename = is_union_type_t<T>>
		flow_t(const T& u) : flow_t(u.ptr_) {}
		
		flow_t(const int v) : value_(v) {}
		
		flow_t(const double v) : value_(v) {}
		
		flow_t(const bool v) : value_(v) {}
		
		flow_t(const flow::string& s) : value_(s) {}
		
		flow_t(const native&) : value_(0) {
			FLOW_ABORT
		}
		
		template <typename T>
		flow_t(const flow::ref<T>&) : value_(0) {
			FLOW_ABORT
		}
		
		template <typename T>
		flow_t(const std::function<T>&) : value_(0) {
			FLOW_ABORT
		}
		
		int id_() const {
			if (index() == is_struct) {
				return get_object_ref().obj_id();
			} else {
				return -1;
			}
		}
		
		const flow::object_ref& get_object_ref() const {
			FLOW_ASSERT(value_.index() == is_struct);
			return std::get<flow::object_ref>(value_);
		}
		
		const array<flow_t>& get_array() const {
			FLOW_ASSERT(value_.index() == flow_t::is_array_of_flow_t);
			return std::get<array<flow_t>>(value_);
		}
		
		template <typename T>
		const array<T> get_custom_array() const {
			const array<flow_t>& a = get_array();
			std::vector<T> v;
			v.reserve(a.size());
			for (size_t i = 0; i < a.size(); i++) {
				v.emplace_back(a[i]);
			}
			return v;
		}
		
		template <typename T, typename = is_struct_type_t<T>>
		array_t<T> get_struct_array() const {
			auto& arr = get_array();
			std::vector<ptr<T>> v;
			v.reserve(arr.size());
			for (int i = 0; i < arr.size(); i++) {
				v.emplace_back(arr[i].get_struct_ptr<T>());
			}
			return v;
		}
		
		template <typename T, typename = is_union_type_t<T>>
		array_t<T> get_union_array() const {
			auto& arr = get_array();
			std::vector<T> v;
			v.reserve(arr.size());
			for (int i = 0; i < arr.size(); i++) {
				v.emplace_back(T(arr[i].get_object_ref()));
			}
			return v;
		}
		
		array_t<string> get_string_array() const {
			auto& arr = get_array();
			std::vector<string> v;
			v.reserve(arr.size());
			for (int i = 0; i < arr.size(); i++) {
				v.push_back(arr[i].get_string());
			}
			return v;
		}
		
		FLOW_INLINE int index() const {
			return value_.index();
		}
		
		int get_int() const {
			FLOW_ASSERT(index() == flow_t::is_int);
			return std::get<int>(value_);
		}
		
		int get_bool() const {
			FLOW_ASSERT(index() == flow_t::is_bool);
			return std::get<bool>(value_);
		}
		
		double get_double() const {
			FLOW_ASSERT(index() == flow_t::is_double);
			return std::get<double>(value_);
		}
		
		flow::string get_string() const {
			FLOW_ASSERT(index() == flow_t::is_string);
			return std::get<flow::string>(value_);
		}
		
		template <typename T, typename = is_struct_type_t<T>>
		ptr<T> get_struct_ptr() const {
			auto& s = get_object_ref();
			// FLOW_PRN(s.ptr_->obj_size_);
			// FLOW_PRN(sizeof(T));
			// FLOW_PRN(s.ptr_->obj_size_ == sizeof(T));
			FLOW_ASSERT(s.obj_id() == T::struct_id_);
			FLOW_ASSERT(s.ptr_->obj_size_ == sizeof(T));
			// TODO: ensure type is correct?
			return ptr<T>(s);
		}
		
		template <typename T, typename = is_union_type_t<T>>
		T get_union() const {
			return T(get_object_ref());
		}
		
		int get_struct_type() const {
			if (index() == is_struct) {
				return get_object_ref().obj_id();
			} else {
				return -1;
			}
		}
		
		template <typename T>
		bool operator== (const flow::ptr<T>&) const {
			// fake implementation. TODO: extend it
			return get_struct_type() == T::struct_id_;
		}
		
		bool operator== (const flow_t& oth) const {
			if (index() != oth.index()) return false;
			switch (index()) {
				case is_string:
					return get_string() == oth.get_string();
				case is_int:
					return get_int() == oth.get_int();
				case is_double:
					return get_double() == oth.get_double();
				case is_bool:
					return get_bool() == oth.get_bool();
				case is_array_of_flow_t:
					return get_array() == oth.get_array();
				default:
					FLOW_ABORT; // not implemented
				// is_struct = 0,
				// is_array_of_flow_t = 1,
				// is_int = 2,
				// is_double = 3,
				// is_bool = 5,
			}
		}
		
		bool operator< (const flow_t& oth) const {
			FLOW_ABORT
		}
		
		explicit operator int() const {
			return get_int();
		}
		
		explicit operator bool() const {
			return get_bool();
		}
		
		explicit operator double() const {
			return get_double();
		}
		
		/*explicit*/ operator flow::string() const {
			return get_string();
		}

		template <typename T, typename = is_struct_type_t<T>>
		explicit operator flow::ptr<T>() const {
			return get_struct_ptr<T>();
		}
		
		template <typename T, typename = is_union_type_t<T>>
		explicit operator T() const {
			return get_union<T>();
		}
		
	protected:
		template <typename T>
		array<flow_t> convert_array(const array_t<T>& a) {
			std::vector<flow_t> v;
			v.reserve(a.size());
			for (int i = 0; i < a.size(); i++) {
				v.emplace_back(a[i]);
			}
			return v;
		}
		
	};
	
	template <typename T>
	ptr<T>::ptr(const flow_t& f) : ptr(f.get_object_ref()) {
		// TODO: ensure type is correct?
	}
	
	template <>
	array<flow_t>::array(const flow_t& f) : array<flow_t>(f.get_array()) {}
	
	template <typename T>
	array<T>::array(const flow_t& f) : array<T>(f.get_custom_array<T>()) {}
	
	template <typename T0, typename T1>
	std::function<T0(const flow_t&)> func_cast(const std::function<T0(T1)>& f) {
		return [=] (const flow_t& x) {
			T1 xx = T1(x);
			return f(xx);
		};
	}
	
} // namespace flow

struct native {
	void* data_;
	
	bool operator< (const native& oth) const {
		FLOW_ABORT
	}
	bool operator== (const native& oth) const {
		FLOW_ABORT
	}
	explicit operator flow::flow_t() const {
		FLOW_ABORT
	}
};



