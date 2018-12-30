#pragma once

#include "flow_perf.hpp"

namespace flow {

	struct flow_t;

	template <typename T>
	struct array_access_type {
		typedef const T& type;
	};
	
	template <>
	struct array_access_type<bool> {
		typedef bool type;
	};
	
	uint64_t g_array_tsc = 0;
	
	template <typename T>
	struct array {
		typedef std::vector<T> vector_t;
		typedef typename vector_t::const_iterator const_iterator;
		typename std::shared_ptr<vector_t> vec_;

		// uint64_t t0_ = rdtsc();
		
		// we explicitly define all properties that we are gonna use
		inline array() {}
		inline array(vector_t&& v)	: vec_(v.size() > 0 ? std::make_shared<vector_t>(std::move(v)) : nullptr) {}
		
		template <typename TT, typename = std::enable_if_t<!std::is_same_v<T, TT>>>
		inline array(const std::vector<TT>& oth) {
			// tsc_holder holder(g_array_tsc);
			auto len = oth.size();
			if (len > 0) {
				vector_t v;
				v.reserve(len);
				for (size_t i = 0; i < len; i++) {
					v.push_back(static_cast<T>(oth[i]));
				}
				vec_ = std::make_shared<vector_t>(std::move(v));
			}
		}

		template <typename TT, 
				 typename = std::enable_if_t<!std::is_same_v<T, TT>>,
				 typename = std::enable_if_t<std::is_convertible_v<TT, T>>>
		inline array(const flow::array<TT>& oth) {
			// tsc_holder holder(g_array_tsc);
			// TODO: avoid recreating array when converting from [struct] to [union] later
			auto len = oth.size();
			if (len > 0) {
				vector_t v;
				v.reserve(len);
				for (size_t i = 0; i < len; i++) {
					v.push_back(static_cast<T>(oth[i]));
				}
				// TODO: get rid of make_shared...
				vec_ = std::make_shared<vector_t>(std::move(v));
			}
		}
		
		template <typename TT>
		inline array(std::initializer_list<TT> l) {
			// tsc_holder holder(g_array_tsc);
			auto len = l.end() - l.begin();
			if (len > 0) {
				vector_t v;
				v.reserve(len);
				for (size_t i = 0; i < len; i++) {
					v.push_back(static_cast<T>(*(l.begin() + i)));
				}
				vec_ = std::make_shared<vector_t>(std::move(v));
			}
		}
		
		// template <typename = std::enable_if_t<std::is_same_v<T, flow_t>>
		array(const flow_t&);
		
		FLOW_ALWAYS_INLINE const_iterator cbegin() const	{ return vec_ ? vec_->cbegin() : const_iterator();	}
		FLOW_ALWAYS_INLINE const_iterator cend() const		{ return vec_ ? vec_->cend()   : const_iterator();	}
		FLOW_ALWAYS_INLINE int size() const 								{ return vec_ ? vec_->size() : 0; }
		FLOW_ALWAYS_INLINE bool operator== (const array<T>& oth) const { 
			return (size() == oth.size()) && (vec_.get() == oth.vec_.get() || (*vec_ == *(oth.vec_)));	
		}
		
		FLOW_ALWAYS_INLINE bool operator<  (const array<T>& oth) const {
			if (size() == 0) return oth.size() > 0;
			if (oth.size() == 0) return false;
			return (*vec_) < (*oth.vec_);
		}
		
		FLOW_ALWAYS_INLINE typename array_access_type<T>::type operator[] (int i) const { 
			FLOW_ASSERT(i >= 0 && i < size());
			return (*vec_)[i]; 
		}
	};
	
} // namespace flow
