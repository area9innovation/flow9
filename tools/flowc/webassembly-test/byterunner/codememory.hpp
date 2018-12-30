#ifndef _CODE_MEMORY_H_
#define _CODE_MEMORY_H_

//#include "ByteMemory.h"

#ifdef _MSC_VER
#define _ALIGNED_4 align(4)
#define _ATTR(...) __declspec(##__VA_ARGS__)
#define __INLINE_WRAP(content) __forceinline content
#define _ATTR_PACK
#else
#define _ALIGNED_4 aligned(4)
#define _PACK packed
#define _ATTR(...) __attribute__((##__VA_ARGS__))
#define __INLINE_WRAP(content) content __attribute__((always_inline))
#define _ATTR_PACK __attribute__((packed))
#endif

// Unaligned memory access hack
#pragma pack(push,1)
union PackedVals {
	char bv;
	unsigned char ubv;
	unsigned short usv;
	int iv;
	unsigned uv;
	double dv;
} _ATTR_PACK;
#pragma pack(pop)

class CodeMemory {
private:
	char *Buffer;
	FlowPtr Position, Start, End;

	PackedVals *GetItemPtr(int size) {
		PackedVals *p = (PackedVals*)(Buffer + FlowPtrToInt(Position));
		Position += size;
#ifdef DEBUG_FLOW
		assert(Position <= End);
#endif
		return p;
	}

public:
	CodeMemory() {}
	CodeMemory(char *buffer, int start, int size) {
		SetBuffer(buffer, start, size);
	}

	void SetBuffer(char *buffer, int start, int size) {
		Buffer = buffer;
		Position = Start = MakeFlowPtr(start);
		End = Start + size;
	}

	__INLINE_WRAP(void SetPosition(FlowPtr position)) {
		if (position <= End)
			Position = position;
	}
	void ResetPosition() { Position = Start; }
	FlowPtr GetPosition() { return Position; }
	int GetSize() { return End - Start; }
	FlowPtr GetLastAddr() { return End; }

	bool Eof() { return Position >= End; }

	char ReadByte() {
		return GetItemPtr(1)->bv;
	}

	unsigned ReadInt32() {
		return GetItemPtr(4)->uv;
	}

	int ReadInt31() {
		return GetItemPtr(4)->iv;
	}

	void SkipInt() {
		Position += 4;
	}

	// Partial reads for constrained values:
	int ReadInt31_8() {
		return GetItemPtr(4)->ubv;
	}

	int ReadInt31_16() {
		return GetItemPtr(4)->usv;
	}

	FlowDouble ReadDouble() {
#ifdef IOS
		double d;
		memcpy(&d, &GetItemPtr(8)->dv, 8);
		return FlowDouble(d);
#else
		return FlowDouble(GetItemPtr(8)->dv);
#endif
	}

	unicode_string ReadWideString(int len) {
		unicode_string rv((unicode_char*)(Buffer + FlowPtrToInt(Position)), len);
		Position += len * 2;
		return rv;
	}

	std::string ReadString(int len) {
		return std::string(&GetItemPtr(len)->bv, len);
	}

	std::string ReadString() {
		int l = ReadInt31();
		if (l)
			return ReadString(l);
		else
			return std::string();
	}

	std::vector<FieldType> ReadFieldType(char *is_mutable, std::string *structname) {
		std::vector<FieldType> res;
		bool eot = false;
		*is_mutable = false;
		do {
			FieldType ft = (FieldType)(unsigned char)ReadByte();
			if (ft == FTMutable) {
				*is_mutable = true;
				continue;
			}
			res.push_back(ft);
			if (ft == FTTypedStruct) {
				std::string name = ReadString();
				if (structname)
					*structname = name;
			}
			if (ft != FTTypedArray && ft != FTTypedRefTo) eot = true;
		} while (!eot);
		return res;
	}

	char *GetBytes(int len) {
		return &GetItemPtr(len)->bv;
	}

	bool ParseOpcode(FlowInstruction *out, bool reparse = false);
};

#define MAX_DATA_STACK 1024
#define MAX_CALL_STACK 256
#define MAX_NATIVE_STACK 128

static const int MAX_NATIVE_ARGS = 15;
static const unsigned MAX_NATIVE_CALLS = 5000;

template<class T>
class CStack {
	std::vector<T> stack;
	typedef typename std::vector<T>::iterator iter;
	iter pos;
public:
	CStack() : stack(), pos(stack.begin()) {}
	CStack(int size) : stack(size), pos(stack.begin()) {}

	void push_back(const T &value) {
		(*pos) = value;
		pos++;
	}

	T *push_ptr(unsigned sz = 1) {
		T *rv = (T*)&(*pos);
		pos += sz;
		//if (pos > limit) grow(pos);
		return rv;
	}

	int size() {
		return pos - stack.begin();
	}

	void resize(unsigned size) {
		pos = stack.begin() + size;
		//if (pos > limit) grow(pos);
	}

	T &top(unsigned off = 0) { return *(pos - 1 - off); }

	T *pop_ptr(unsigned sz = 1) {
		pos = pos - sz;
		return (T*)&(*pos);
	}

	bool empty() const { return pos == stack.begin(); }

	T &operator[] (unsigned i) { return stack[i]; }

	// iteration breaks when f returns false
	void forEach(std::function<bool(T)> f) {
		for (iter it = stack.begin(); it != stack.end(); ++it) {
			if (!f(*it))
				break;
		}
	}
};

struct CallFrame {
	FlowPtr last_pc;
	FlowPtr last_closure;
	int last_frame;
};

typedef CStack<StackSlot> TDataStack;
typedef CStack<CallFrame> TCallStack;

#endif
