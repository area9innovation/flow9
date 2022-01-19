#include <any>
#include "flow_natives.hpp"

struct _FlowType : std::any {
  void(*print)(_FlowType const&) = nullptr;
  bool(*equal)(_FlowType const&, _FlowType const&) = nullptr;
  bool(*greater)(_FlowType const&, _FlowType const&) = nullptr;
  bool(*less)(_FlowType const&, _FlowType const&) = nullptr;

  friend std::ostream& operator<<( std::ostream& os, _FlowType const& a ) {
    a.print( a );
    return os;
  }

  /*template<typename T>
  _FlowType( T&& t ):
    std::any( std::forward<T>(t) ),
    print([](_FlowType const& self ) { flow_print2(std::any_cast<std::decay_t<T>>(self)); } )
  {}*/

  template<typename T>
  _FlowType( T t ):
    std::any( std::forward<T>(t) ),
    print([](_FlowType const& self ) { flow_print2(std::any_cast<std::decay_t<T>>(self)); } ),
    equal([](_FlowType const& a, _FlowType const& b) {
    	auto tmp1 = std::any_cast<std::decay_t<T>>(a);
    	auto tmp2 = std::any_cast<std::decay_t<T>>(b);
    	return areValuesEqual(tmp1, tmp2);//tmp1 == tmp2;
    } ),
    greater([](_FlowType const& a, _FlowType const& b) {
    	auto tmp1 = std::any_cast<std::decay_t<T>>(a);
    	auto tmp2 = std::any_cast<std::decay_t<T>>(b);
    	return tmp1 > tmp2;
    } ),
    less([](_FlowType const& a, _FlowType const& b) {
    	auto tmp1 = std::any_cast<std::decay_t<T>>(a);
    	auto tmp2 = std::any_cast<std::decay_t<T>>(b);
    	return tmp1 < tmp2;
    } )
  {}

  bool operator==(const _FlowType& a) const { return equal(a, *this); }
  bool operator!=(const _FlowType& a) const { return !equal(a, *this); }
  bool operator>(const _FlowType& a) const { return greater(*this, a); }
  bool operator<(const _FlowType& a) const { return less(*this, a); }
  bool operator>=(const _FlowType& a) const {return equal(a, *this) || greater(*this, a);}
  bool operator<=(const _FlowType& a) const {return equal(a, *this) || less(*this, a);}
};


template <typename T>
T flow_cast(const _FlowType& val) {
	//std::cout<< "Casting from '" << demangle(val.type().name()) << "' to '" << demangle(typeid(T).name()) << "' ..." << std::endl;
  try {
    return std::any_cast<std::decay_t<T>>(val);
  }
  catch (const std::bad_any_cast& e) {
    throw std::invalid_argument("ERROR casting from '" + demangle(val.type().name()) + "' to '" + demangle(typeid(T).name()) + "'");
   /* std::cout<< "ERROR casting from '" << demangle(val.type().name()) << "' to '" << demangle(typeid(T).name()) << "'" << std::endl;
    T res;
    return res;*/
  }
}