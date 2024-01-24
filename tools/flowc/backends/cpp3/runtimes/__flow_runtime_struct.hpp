#pragma once

#include "__flow_runtime_union.hpp"

namespace flow {

// Any particular struct

template<TypeId Id, typename... Fs>
struct Str : public Union {
	enum { TYPE = Id, SIZE = sizeof...(Fs) };
	using Fields = std::tuple<Fs...>;
	~Str() override {
		decRcFields<0>();
	}
	void destroy() override { this->~Str(); }
	template<typename S>
	static S make(Fs... fs) {
		if constexpr (sizeof...(Fs) == 0) {
			static S singleton = makeSingleton<S>();
			return singleton;
		} else {
			if constexpr (use_memory_manager) {
				return new(Memory::alloc<S>()) std::remove_pointer_t<S>(std::move(fs)...);
			} else {
				return new std::remove_pointer_t<S>(std::move(fs)...);
			}
		}
	}
	template<typename S>
	static S makeOrReuse(S s, Fs... fs) {
		if (s == nullptr || isConstatntObj(s)) {
			return make<S>(std::move(fs)...);
		} else {
			s->template decRcFields<0>();
			s->fields = std::tie(fs...);
			s->makeUnitRc();
			return s;
		}
	}

	Str& operator = (Str&& r) = delete;
	Str& operator = (const Str& r) = delete;

	// general interface
	void append2string(string& s) override {
		s.append(RTTI::typeName(TYPE));
		s.append(u"(");
		append2stringArgs<0>(s);
		s.append(u")");
	}
	TypeId typeId() const override { return TYPE; }
	Int componentSize() const override { return sizeof...(Fs); }
	TypeId componentTypeId(Int i) override {
		return componentTypeId_<0>(i);
	}

	Flow* getFlowRc1(Int i) override {
		return getFlowRc1_<Flow*, 0>(i);
	}
	Bool getBoolRc1(Int i) override {
		return getFlowRc1_<Bool, 0>(i);
	}
	Int getIntRc1(Int i) override {
		return getFlowRc1_<Int, 0>(i);
	}
	Double getDoubleRc1(Int i) override {
		return getFlowRc1_<Double, 0>(i);
	}

	void setFlowRc1(Int i, Flow* v) override {
		setFlowRc1_<0>(i, v);
	}
	Flow* getFlowRc1(String* f) override {
		int field_idx = RTTI::structField(Id, f->str());
		decRc(f);
		return getFlowRc1(field_idx); 
	}
	void setFlowRc1(String* f, Flow* v) override {
		int field_idx = RTTI::structField(Id, f->str());
		decRc(f);
		setFlowRc1(field_idx, v);
	}

	Flow* getFlow(Int i) override {
		return getFlow_<0>(i);
	}
	Flow* getFlow(const string& f) override {
		int field_idx = RTTI::structField(Id, f);
		return getFlow(field_idx); 
	}

	// Union virtual methods
	Int compare(Union* u) override {
		Int c = flow::compare<TypeId>(TYPE, u->structId());
		if (c != 0) {
			return c;
		} else {
			return compare<0>(static_cast<Str*>(u));
		}
	}
	Union* clone() override {
		return flow::clone<Str*>(this);
	}

	// specific methods
	template<Int i>
	typename std::tuple_element_t<i, Fields> getRc() {
		std::tuple_element_t<i, Fields> f = getRc1<i>();
		decRc(this);
		return f;
	}
	template<Int i>
	void setRc(typename std::tuple_element_t<i, Fields> v) {
		setRc1<i>(v);
		decRc(this);
	}
	template<Int i>
	inline typename std::tuple_element_t<i, Fields> getRc1() {
		return incRcRet(get<i>());
	}
	template<Int i>
	inline void setRc1(typename std::tuple_element_t<i, Fields> v) {
		assignRc<typename std::tuple_element_t<i, Fields>>(std::get<i>(fields), v);
	}
	template<Int i>
	inline typename std::tuple_element_t<i, Fields> get() {
		return std::get<i>(fields);
	}
	template<Int i>
	inline void set(typename std::tuple_element_t<i, Fields> v) {
		std::get<i>(fields) = v;
	}

	inline Int compare(Str* s) {
		return compare<0>(s);
	}
	void toString(string& str) {
		str.append(RTTI::typeName(TYPE));
		str.append(u"(");
		toStringArgs<0>(str);
		str.append(u")");
	}
	template<typename S>
	inline void hashCalc(S& h) {
		Hash<S, TypeId>::calc(h, TYPE);
		hashCalcArgs<0>(h);
	}
/*
	template<class S>
	struct FStr : public Flow {
		FStr(Str* v): val_(static_cast<S>(v)) { }
		~FStr() { decRc(val_); }
		void destroy() override { this->~FStr(); }
		TypeId typeId() const override { return Str::TYPE; }
		Int componentSize() const override { return sizeof...(Fs); }
		TypeId componentTypeId(Int i) override {
			return componentTypeId_<0>(i);
		}

		Flow* getFlowRc1(Int i) override {
			return getFlowRc1_<Flow*, 0>(i);
		}
		Bool getBoolRc1(Int i) override {
			return getFlowRc1_<Bool, 0>(i);
		}
		Int getIntRc1(Int i) override {
			return getFlowRc1_<Int, 0>(i);
		}
		Double getDoubleRc1(Int i) override {
			return getFlowRc1_<Double, 0>(i);
		}
		void setFlowRc1(Int i, Flow* v) override {
			setFlowRc1_<0>(i, v);
		}
		Flow* getFlowRc1(String* f) override {
			int field_idx = RTTI::structField(Id, f->str());
			decRc(f);
			return getFlowRc1(field_idx); 
		}
		void setFlowRc1(String* f, Flow* v) override {
			int field_idx = RTTI::structField(Id, f->str());
			decRc(f);
			setFlowRc1(field_idx, v);
		}

		Flow* getFlow(Int i) override {
			return getFlow_<0>(i);
		}
		Flow* getFlow(const string& f) override {
			int field_idx = RTTI::structField(Id, f);
			return getFlow(field_idx); 
		}

		Int compareWithFlow(Flow* v) override {
			Int c = flow::compare<TypeId>(TYPE, v->typeId());
			if (c != 0) {
				return c;
			} else {
				return compare(static_cast<Str*>(v));
			}
		}
		S* val_;
	};
	template<class S>
	inline Flow* toFlow() { return FStr::make<S>(this); }
*/
protected:
	Str(Fs... fs): Union(Id), fields(fs...) { }
private:
	template<typename S>
	inline static S makeSingleton() {
		if constexpr (sizeof...(Fs) == 0) {
			static std::remove_pointer_t<S> x; x.makeConstantRc(); return &x;
		} else {
			return nullptr;
		}
	}
	template<Int i>
	inline void incRcFields() {
		if constexpr(i < SIZE) {
			incRc(std::get<i>(fields));
			incRcFields<i + 1>();
		}
	}
	template<Int i>
	inline void decRcFields() {
		if constexpr(i < SIZE) {
			if constexpr (is_flow_ancestor_v<std::tuple_element_t<i, Fields>>) {
				if (std::tuple_element_t<i, Fields> v = std::get<i>(fields)) {
					decRc(v);
				}
			}
			decRcFields<i + 1>();
		}
	}
	template<Int i>
	inline void resetFields() {
		if constexpr(i < SIZE) {
			if constexpr (is_flow_ancestor_v<std::tuple_element_t<i, Fields>>) {
				std::get<i>(fields) = nullptr;
			}
			resetFields<i + 1>();
		}
	}
	template<typename X, Int i>
	inline X getFlowRc1_(Int j) {
		if constexpr(i == SIZE) {
			fail("illegal access of field by index: " + string2std(int2string(i)) + ", size: " + string2std(int2string(SIZE)));
			return makeDefInit<X>();
		} else {
			if (i == j) {
				return castRc<std::tuple_element_t<i, Fields>, X>(getRc1<i>()); 
			} else {
				return getFlowRc1_<X, i + 1>(j);
			}
		}
	}
	template<Int i>
	inline void setFlowRc1_(Int j, Flow* v) {
		if constexpr(i == SIZE) {
			fail("illegal access of field by index: " + string2std(int2string(i)) + ", size: " + string2std(int2string(SIZE)));
		} else {
			if (i == j) {
				setRc1<i>(castRc<Flow*, std::tuple_element_t<i, Fields>>(v));
			} else {
				setFlowRc1_<i + 1>(j, v);
			}
		}
	}
	template<Int i>
	inline Flow* getFlow_(Int j) {
		if constexpr(i == SIZE) {
			fail("illegal access of field by index: " + string2std(int2string(i)) + ", size: " + string2std(int2string(SIZE)));
			return nullptr;
		} else {
			if (i == j) {
				if constexpr (is_flow_ancestor_v<std::tuple_element_t<i, Fields>>) {
					return get<i>(); 
				} else {
					fail("only flow ancestor fields may be accessed directly as Flow");
				}
			} else {
				return getFlow_<i + 1>(j);
			}
		}
	}
	template<Int i>
	inline TypeId componentTypeId_(Int j) {
		if constexpr(i == SIZE) return TypeFx::UNKNOWN; else {
			if (i == j) {
				return get_type_id_v<std::tuple_element_t<i, Fields>>;
			}
			return componentTypeId_<i + 1>(j);
		}
	}
	template<Int i>
	inline Int compare(Str* s) {
		if constexpr(i == SIZE) return 0; else {
			Int c = flow::compare<std::tuple_element_t<i, Fields>>(
				get<i>(), s->get<i>()
			);
			if (c != 0) return c;
			return compare<i + 1>(s);
		}
	}
	template<Int i>
	inline void toStringArgs(string& str) {
		if constexpr(i < SIZE) {
			if constexpr (i > 0) {
				str.append(u", ");
			}
			flow::toString(get<i>(), str);
			toStringArgs<i + 1>(str);
		}
	}
	template<Int i>
	inline void append2stringArgs(string& str) {
		if constexpr(i < SIZE) {
			if constexpr (i > 0) {
				str.append(u", ");
			}
			flow::append2string(str, get<i>());
			append2stringArgs<i + 1>(str);
		}
	}
	template<typename S, Int i>
	inline void hashCalcArgs(S& h) {
		if constexpr(i < SIZE) {
			Hash<S, std::tuple_element_t<i, Fields>>::calc(h, get<i>());
			hashCalcArgs<i + 1>(h);
		}
	}
	Fields fields;
};

}
