#pragma once

#include <list>
#include <functional>
//#include <emscripten.h>

struct native {
	int data_;

	native() {}
	native(const int& i) : data_(i) {}

	//bool operator< (const native& oth) const {
	//	FLOW_ABORT
	//}
	//bool operator== (const native& oth) const {
	//	data_ == oth.data_;
	//	//		FLOW_ABORT
	//}
	//explicit operator flow::flow_t() const;
};

template <typename T>
std::vector<T> extractArrayFromJSMem(T* arr) {
	int length = (int)arr[0];
	printf("extractArrayFromJSMem c part, length: %d\n", length);

	std::vector<T> ret;
	for (int i = 1; i <= length; ++i) {
		printf("%d: %.2f\n", i, (double)arr[i]);
		ret.push_back(arr[i]);
	}

	return ret;
}
//
//std::string getStringFromJS(int strPtr, int strSize) {
//	unicode_char* begin = (unicode_char*)strPtr;
//	return encodeUtf8(begin, strSize);
//}

unicode_string getStringFromJS(int strPtr, int strSize) {
	return unicode_string((unicode_char*)strPtr, strSize);
}


static size_t allocatedSSS = 0;

class Callback {
public:
	Callback() {
		size_t sz = sizeof(*this);
		allocatedSSS += sz;
		printf("ALLOCATE: %d total: %d\n", sz, allocatedSSS);
	}
	virtual ~Callback() {
		size_t sz = sizeof(*this);
		allocatedSSS -= sz;
		printf("~Callback TOTAL: %d\n", allocatedSSS);
	}
};
//
//class Callback_V : public Callback {
//	std::function<void()> func;
//public:
//	Callback_V(const std::function<void()>& func) : Callback() {
//		printf("Callback_V\n");
//		this->func = func;
//	}
//
//	static void Func(Callback_V* cb) {
////		printf("Callback_V Func\n");
//		if (cb->func) {
//			cb->func();
//		}
//	}
//};
//
//class Callback_VS : public Callback {
//	std::function<void(std::string)> func;
//public:
//	Callback_VS(const std::function<void(std::string)>& func) : Callback() {
//		printf("Callback_VS\n");
//		this->func = func;
//	}
//
//	static void Func(Callback_VS* cb, int utf16, int utf16sz) {
//		printf("Callback_VS Func\n");
//		std::string str = getStringFromJS(utf16, utf16sz);
//		if (cb->func) {
//			cb->func(str);
//		}
//	}
//};
//
//class Callback_VN : public Callback {
//	std::function<void(native)> func;
//public:
//	Callback_VN(const std::function<void(native)>& func) : Callback() {
//		printf("Callback_VN\n");
//		this->func = func;
//	}
//
//	static void Func(Callback_VN* cb, int native_id) {
//		printf("Callback_VS Func\n");
//		//native n = toNative(native_id);
//		if (cb->func) {
//			cb->func(native(native_id));
//		}
//	}
//};
//
//class Callback_VD : public Callback {
//	std::function<void(double)> func;
//public:
//	Callback_VD(const std::function<void(double)>& func) : Callback() {
//		printf("Callback_VD\n");
//		this->func = func;
//	}
//
//	static void Func(Callback_VD* cb, double arg1) {
//		printf("Callback_VD Func\n");
//		if (cb->func) {
//			cb->func(arg1);
//		}
//	}
//};
//
//class Callback_VB : public Callback {
//	std::function<void(bool)> func;
//public:
//	Callback_VB(const std::function<void(bool)>& func) : Callback() {
//		printf("Callback_VB\n");
//		this->func = func;
//	}
//
//	static void Func(Callback_VB* cb, bool arg1) {
//		printf("Callback_VB Func\n");
//		if (cb->func) {
//			cb->func(arg1);
//		}
//	}
//};
//
//class Callback_VDD : public Callback {
//	std::function<void(double, double)> func;
//public:
//	Callback_VDD(const std::function<void(double, double)>& func) : Callback() {
//		printf("Callback_VDD\n");
//		this->func = func;
//	}
//
//	static void Func(Callback_VDD* cb, double arg1, double arg2) {
//		printf("Callback_VDD Func\n");
//		if (cb->func) {
//			cb->func(arg1, arg2);
//		}
//	}
//};
//
//class Callback_VIDDDD : public Callback {
//	std::function<void(int, double, double, double, double)> func;
//public:
//	Callback_VIDDDD(const std::function<void(int, double, double, double, double)>& func) : Callback() {
//		printf("Callback_VIDDDD\n");
//		this->func = func;
//	}
//
//	static void Func(Callback_VIDDDD* cb, int i1, double d1, double d2, double d3, double d4) {
//		printf("Callback_VIDDDD Func\n");
//		if (cb->func) {
//			cb->func(i1, d1, d2, d3, d4);
//		}
//	}
//};
//
//class Callback_VSBBBBIFn : public Callback {
//	std::function<void(std::string, bool, bool, bool, bool, int, std::function<void()>)> func;
//	int subFuncID = -1;
//
//public:
//	~Callback_VSBBBBIFn() {
//		printf("~Callback_VSBBBBIFn: subFuncID = %d\n", subFuncID);
//		//if (subFuncID >= 0) {
//		//	EM_ASM_({
//		//		Module.print('Callback_VSBBBBIFn: revoke subfunc ' + $0);
//		//		IDHandler.revokeObjectId($0);
//		//	}, subFuncID);
//		//}
//	}
//
//	Callback_VSBBBBIFn(const std::function<void(std::string, bool, bool, bool, bool, int, std::function<void()>)>& func) : Callback() {
//		printf("Callback_VSBBBBIFn\n");
//		this->func = func;
//	}
//
//	static void Func(Callback_VSBBBBIFn* cb, int utf16, int utf16sz, bool b1, bool b2, bool b3, bool b4, int i1, int cbId) {
//		cb->subFuncID = cbId;
//		std::string str = getStringFromJS(utf16, utf16sz);
//
//		printf("Call Callback_VSBBBBIFn 1: %s, %d, cbID: %d\n", str.c_str(), str.size(), cbId);
//		if (cb->func) {
//			cb->func(str, b1, b2, b3, b4, i1, [=]() {
//				EM_ASM_({
//					testApi.executeCallback($0);
//					Module.print('Call Callback_VSBBBBIFn cb: ' + $0);
//				}, cbId);
//			});
//		}
//	}
//};
//
//template <typename T>
//class Callback_VT : public Callback {
//	std::function<void(T)> func;
//public:
//	Callback_VT(const std::function<void(T)>& func) : Callback() {
//		printf("Callback_VT\n");
//		this->func = func;
//	}
//
//	static void Func(Callback_VT* cb, T val) {
//		printf("Callback_VT Func\n");
//		if (cb->func) {
//			cb->func(val);
//		}
//	}
//};
////
////class Callback_VAN : public Callback {
////	std::function<void(std::vector<native>)> func;
////public:
////	Callback_VAN(const std::function<void(std::vector<native>)>& func) : Callback() {
////		printf("Callback_VAN\n");
////		this->func = func;
////	}
////
////	static void Func(Callback_VAN* cb, int* val) {
////		printf("Callback_VAN Func\n");
////		if (cb->func) {
////			std::vector<int> tmp = extractArrayFromJSMem<int>(val);
////			std::function<native(int)> f = [](int a) { return native(a); };
////			cb->func(std::vector<native>(tmp, f));
////		}
////	}
////};
//
//typedef std::list<Callback*> cb_list_t;
//typedef std::map<int, cb_list_t>  cb_map_t;
//cb_map_t cb_map;
//
//void registerCallback(const native& key, Callback* cb) {
//	cb_map_t::iterator  it = cb_map.find((int)key.data_);
//	cb_list_t* v = NULL;
//	if (it == cb_map.end()) {
//		cb_map[(int)key.data_] = cb_list_t();
//		v = &cb_map[(int)key.data_];
//	}
//	else {
//		v = &it->second;
//	}
//
//	printf("registerCallback  %d %d\n", (int)key.data_, (int)cb);
//
//	v->push_back(cb);
////	cb_map[(int)key.data_] = v;
//}
//
//// if cb == null then we'll remove (and delete) all callbacks for such native
//void releaseCallback(const native& key, Callback* cb = NULL) {
//	cb_map_t::iterator it = cb_map.find((int)key.data_);
//	if (it == cb_map.end())
//		return;
//
//	if (cb != NULL) {
//		bool found = (std::find(it->second.begin(), it->second.end(), cb) != it->second.end());
//		if (found) {
//			it->second.remove(cb);
//			delete cb;
//			printf("releaseCallback  %d %d\n", (int)key.data_, (int)cb);
//		} else {
//			printf("releaseCallback  %d %d: ALREADY RELEASED\n", (int)key.data_, (int)cb);
//		}
//	} else {
//		std::for_each(it->second.begin(), it->second.end(), [=](Callback* _cb) { 
//			printf("releaseCallback  %d %d\n", (int)key.data_, (int)_cb);
//			delete _cb;
//		});
//
//		it->second.clear();
//	}
//}
