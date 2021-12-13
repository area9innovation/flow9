#include <any>
#include "tools/flow9/backends/cpp/flow_natives.hpp" 

struct _FlowType : std::any {
  void(*print)(_FlowType const&) = nullptr;

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
    print([](_FlowType const& self ) { flow_print2(std::any_cast<std::decay_t<T>>(self)); } )
  {}

  bool operator==(const _FlowType& a) const { return a == *this; }
  bool operator!=(const _FlowType& a) const { return a != *this; }
  bool operator>(const _FlowType& a) const {return a > *this;}
  bool operator<(const _FlowType& a) const {return a < *this;}
  bool operator>=(const _FlowType& a) const {return (a == *this) || (a > *this);}
  bool operator<=(const _FlowType& a) const {return (a == *this) || (a < *this);}
};


template <typename T>
T flow_cast(const _FlowType& val) {
  try {
    return std::any_cast<std::decay_t<T>>(val);
  }
  catch(const std::bad_any_cast& e) {
    std::cout<< "ERROR casting from '" << demangle(val.type().name()) << "' to '" << demangle(typeid(T).name()) << "'" << std::endl;
    T res;
    return res;
  }
}
