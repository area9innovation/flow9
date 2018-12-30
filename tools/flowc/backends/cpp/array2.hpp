#pragma once

#include <utility>
#include <cstddef>
#include <memory>

namespace flow {
	
	template<typename Container>
	class array_writer {
	public:
		using value_type = typename Container::value_type;

		array_writer(Container& cont) : container(cont), current(cont.cbegin()) {}

		void push_back(const typename Container::value_type& val) {
			container.init_value(current++, val);
		}

		void push_back(typename Container::value_type&& val) {
			container.init_value(current++, std::move(val));
		}

		size_t get_count() const { return current - container.cbegin(); }

	private:
		Container& container;
		typename Container::const_iterator current;
	};

	constexpr size_t sso_seed = 2 * sizeof(int);

	template <class T, class = void>
	struct array_sso_size {
		constexpr static size_t size = sso_seed;
	};

	template <class T>
	struct array_sso_size< T, decltype(void(sizeof(T))) > {
		constexpr static size_t compute_size() {
			size_t count = sso_seed / sizeof(T);
			return count * sizeof(T);
		}
		constexpr static size_t size = compute_size();
	};

	template <typename T, size_t max_size = array_sso_size<T>::size>
	struct array2 {
		using const_iterator = const T*;
		using iterator = T*;
		using value_type = T;

		array2() : length(0), ptr() {}
		array2(size_t nLength) : length(nLength), ptr() {
			if (nLength > max_size / sizeof(T))
				init_storage();
		}

		template<typename It>
		array2(It begin, It end) : ptr() {
			length = end - begin;
			if (length > max_size / sizeof(T)) {
				init_storage();
				std::uninitialized_copy(begin, end, storage_begin());
			}
			else {
				std::uninitialized_copy(begin, end, data_begin());
			}
		}

		array2(std::initializer_list<T> l) : array2::array2(l.begin(), l.end()) {}

		array2(const array2<T, max_size>& other) : ptr(other.ptr), length(other.length) {
			// TODO: fix compilation error!
			// c:\program files(x86)\microsoft visual studio\2017\community\vc\tools\msvc\14.11.25503\include\memory(53) :
			// error C4996 : 'std::uninitialized_copy::_Unchecked_iterators::_Deprecate' : Call to 'std::uninitialized_copy' with parameters that
			// may be unsafe - this call relies on the caller to check that the passed values are correct.To disable this warning, use
			// -D_SCL_SECURE_NO_WARNINGS.See documentation on how to use Visual C++ 'Checked Iterators'
			if (!ptr)
				std::uninitialized_copy(other.cbegin(), other.cend(), data_begin());
		}

		array2(array2<T, max_size>&& other) : ptr(std::move(other.ptr)), length(other.length) {
			if (!ptr)
				std::uninitialized_move(other.cbegin(), other.cend(), data_begin());
			other.length = 0;
		}
		
		array2<T, max_size>& operator=(const array2<T, max_size>& other) {
			destroy();
			ptr = other.ptr;
			length = other.length;
			if (!ptr)
				std::uninitialized_copy(other.cbegin(), other.cend(), data_begin());

			return *this;
		}

		array2<T, max_size>& operator=(array2<T, max_size>&& other) {
			destroy();
			ptr = std::move(other.ptr);
			length = other.length;
			if (!ptr)
				std::uninitialized_move(other.cbegin(), other.cend(), data_begin());

			other.length = 0;

			return *this;
		}

		~array2() {
			destroy();
			length = 0;
		}

		inline const_iterator cbegin() const { return ptr ? storage_begin() : data_begin(); }
		inline const_iterator cend() const { return ptr ? (storage_begin() + size()) : (data_begin() + size()); }
		inline constexpr int size() const { return static_cast<int>(length); }
		const T& operator[] (size_t index) const {
			return *(cbegin() + index);
		}
		
		inline bool operator== (const array2<T, max_size>& other) const {
			if (length != other.length) return false;
			return std::equal(cbegin(), cend(), other.cbegin(), other.cend());
		}

		inline bool operator < (const array2& other) const {
			for (size_t i = 0; i < length; i++) {
				if (i >= other.length) return false;
				if ((*this)[i] < other[i]) return true;
			}
			return length < other.length;
		}
		
		inline void init_value(const_iterator it, const T& value) {
			new ((void*)it) T(value);
		}

		inline void init_value(const_iterator it, T&& value) {
			new ((void*)it) T(std::move(value));
		}

		inline array_writer<array2<T, max_size>> writer() {
			return array_writer<array2<T, max_size>>(*this);
		}

		inline iterator data_begin() const {
			return reinterpret_cast<iterator>(const_cast<std::byte*>(&data[0]));
		}

		inline iterator storage_begin() const {
			return reinterpret_cast<iterator>(ptr.get());
		}

		inline void init_storage() {
			ptr = std::shared_ptr<std::byte>(new std::byte[length * sizeof(T)],
				[](std::byte* p) { delete[] p; });
		}

		inline void destroy() {
			if (!ptr || ptr.use_count() == 1) {
				auto end = cend();
				for (auto it = cbegin(); it != end; ++it)
					it->~T();
			}
		}

		std::byte data[max_size];
		size_t length;
		std::shared_ptr<std::byte> ptr;
	};

	template <typename T>
	struct array2<T, 0> {
		using const_iterator = const T*;
		using iterator = T*;
		using value_type = T;

		array2() : length(0), ptr() {}
		array2(size_t nLength) : length(nLength), ptr() {
			init_storage();
		}

		template<typename It>
		array2(It begin, It end) : ptr() {
			length = end - begin;
			init_storage();
			std::uninitialized_copy(begin, end, storage_begin());
		}

		array2(std::initializer_list<T> l) : array2::array2(l.begin(), l.end()) {}
		array2(const array2<T, 0>& other) : ptr(other.ptr), length(other.length) {}
		array2(array2<T, 0>&& other) : ptr(std::move(other.ptr)), length(other.length) {
			other.length = 0;
		}

		template <typename TT>
		array2(const array2<TT, 0>& other) : length(other.length) {
			init_storage();
			for (size_t i = 0; i < length; i++) {
				new (storage_begin() + i) T(other[i]);
			}
		}

		array2<T, 0>& operator=(const array2<T, 0>& other) {
			destroy();
			ptr = other.ptr;
			length = other.length;

			return *this;
		}

		array2<T, 0>& operator=(array2<T, 0>&& other) {
			destroy();
			ptr = std::move(other.ptr);
			length = other.length;

			other.length = 0;

			return *this;
		}

		~array2() {
			destroy();
		}

		inline const_iterator cbegin() const { return storage_begin(); }
		inline const_iterator cend() const { return storage_begin() + size(); }
		inline constexpr int size() const { return static_cast<int>(length); }
		const T& operator[] (size_t index) const {
			return *(cbegin() + index);
		}
		
		inline bool operator== (const array2<T, 0>& other) const {
			if (length != other.length) return false;
			return std::equal(cbegin(), cend(), other.cbegin(), other.cend());
		}
		
		inline bool operator < (const array2& other) const {
			for (size_t i = 0; i < length; i++) {
				if (i >= other.length) return false;
				if ((*this)[i] < other[i]) return true;
			}
			return length < other.length;
		}

		inline void init_value(const_iterator it, const T& value) {
			new ((void*)it) T(value);
		}

		inline void init_value(const_iterator it, T&& value) {
			new ((void*)it) T(std::move(value));
		}

		array_writer<array2<T, 0>> writer() {
			return array_writer<array2<T, 0>>(*this);
		}

		inline iterator storage_begin() const {
			return reinterpret_cast<iterator>(ptr.get());
		}

		inline void init_storage() {
			ptr = std::shared_ptr<std::byte>(new std::byte[length * sizeof(T)],
				[](std::byte* p) { delete[] p; });
		}

		inline void destroy() {
			if (ptr.use_count() == 1) {
				auto end = cend();
				for (auto it = cbegin(); it != end; ++it)
					it->~T();
			}
		}

		size_t length;
		std::shared_ptr<std::byte> ptr;
	};
	
}	// namespace flow