// getStructName
#ifdef __GNUG__
#include <cstdlib>
#include <memory>
#include <cxxabi.h>
std::string demangle(const char* name) {
	int status = -4; // some arbitrary value to eliminate the compiler warning
	// enable c++11 by passing the flag -std=c++11 to g++
	std::unique_ptr<char, void(*)(void*)> res{
		abi::__cxa_demangle(name, NULL, NULL, &status),
		std::free
	};
	return (status == 0) ? res.get() : name;
}
#else
// does nothing if not g++
std::string demangle(const char* name) {
	return name;
}
#endif

// memory
// 
// templates
void drop(int32_t a) {}
void drop(double a) {}
void drop(bool a) {}

// Structs

template <typename T>
void drop(T& a) {
	a.drop();
}

template <typename T>
void dropStruct(T& a) {
	a._counter -= 1;
	if (a._counter < 1) {
		//std::cout<<"FREE:: &=" << &a << "; counter = " << a._counter << "; type=" << demangle(typeid(a).name()) << std::endl;
		// we will free the memory of the fields inside struct.drop();
		//a.~T();
	} else {
		//std::cout<<"DEC COUNTER:: &=" << &a << "; counter = " << a._counter << "; type=" << demangle(typeid(a).name()) << std::endl;
	}
}

template <typename T>
void drop(T* a) {
	dropValue(a);
}

template <typename T>
bool dropValue(T* a) {
	if (a == nullptr) {
		//std::cout << "ERROR :: can't free memory for NULL" << std::endl;
		// TODO: fix: 2 pointers, 1 object. delete ptr1 - OK. delete ptr2 - Error (wrong the cell)
		return false;
	}
	else {
		(*a)._counter -= 1;
		if ((*a)._counter < 1) {
			//std::cout << "FREE:: &=" << &a << "; counter = " << (*a)._counter << "; type=" << demangle(typeid(a).name()) << std::endl;
			delete a;
			a = nullptr;
			return true;
		}
		else {
			//std::cout << "DEC COUNTER:: &=" << &a << "; counter = " << (*a)._counter << "; type=" << demangle(typeid(a).name()) << std::endl;
			(*a).dropFields();
			return false;
		}
	}
}

// TODO: reuse field
template <typename T>
T* reuse(T* a) {
	//std::cout << "REUSE PTR:: &=" << &a << "; counter = " << (*a)._counter << std::endl;
	return a;
}

// TODO
// memory leak (?)
// use std::unique_ptr
template <typename T>
T& reuse(T& a) {
	if (a._counter > 1) {
		//std::cout<<"REUSE:: &=" << &a << "; counter = " << a._counter << std::endl;
		return a;
	} else {
		T* tmp;
		//std::cout<<"REUSE:: from &=" << &a <<" to &="<< tmp << std::endl;
		tmp = &a;
		drop<T>(a);
		return *tmp;
	}
	// does not transfer ownership
	// does not work as expected because it does not break the link to the variable.
	/*std::cout<<"REUSE:: &=" << &a << std::endl;
	a._counter = 1;
	return a;*/
}

template <typename T>
T* dup(T* a) {
	(*a)._counter += 1;
	//std::cout<<"DUP:: cnt after: "<< (*a)._counter/* << "; &=" << a <<" " << &a << " " << *a */<< std::endl;
	(*a).dupFields();
	return a;
}

int32_t dup(int32_t a) {
	//std::cout<<"DUP:: int value "<< a <<std::endl;
	return a;
}

int32_t reuse(int32_t a) {
	//std::cout<<"REUSE:: int value "<< a <<std::endl;
	return a;
}

std::u16string dup(std::u16string a) {
	//std::cout<<"DUP:: string value " <<std::endl;
	return a;
}

void drop(std::u16string& a) {
	//std::cout<<"DROP:: string value " <<std::endl;
	a = u"";
}

std::u16string reuse(std::u16string a) {
	//std::cout<<"REUSE:: string value " <<std::endl;
	return a;
}

bool dup(bool a) {
	//std::cout<<"DUP:: bool value "<< a <<std::endl;
	return a;
}

bool reuse(bool a) {
	//std::cout<<"REUSE:: bool value "<< a <<std::endl;
	return a;
}

double dup(double a) {
	//std::cout<<"DUP:: double value "<< a <<std::endl;
	return a;
}

double reuse(double a) {
	//std::cout<<"REUSE:: double value "<< a <<std::endl;
	return a;
}

