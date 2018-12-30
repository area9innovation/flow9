#ifndef MEM_POOL_H
#define MEM_POOL_H

//#include <stdio.h>
//#include <assert.h>
//#include <emscripten.h>
//#include <string.h>
#include "CommonTypes.h"
#include "codememory.hpp"

#define MAX_HEAP_SIZE_L 1048576u
#define HEAP_RESIZE_STEP 32068u

//bool operator> (const StackSlot &c1, const StackSlot &c2) {
//	return c1.m_cents > c2.m_cents;
//}

bool operator< (const StackSlot &c1, const StackSlot &c2) {
	return c1.GetType() < c2.GetType();
}

class mem_pool {
public: 
	static const unsigned align_value = 4;
private:
	unsigned buffer_offset = 0;
	std::vector<char> buffer;
	unsigned long           NextRefId = 0;

	struct Range {
	public:
		unsigned start;
		unsigned length;
		unsigned short marked;

		Range() {  }
		Range(unsigned s, unsigned l) { start = s; length = l; marked = 0; }
	};

	std::map<StackSlot, Range> memmap;

	StackSlot registerObject(StackSlot& s, Range p) {
		memmap[s] = p;
		return s;
	}

public:
	mem_pool() {
		buffer.resize(HEAP_RESIZE_STEP);
	}
	~mem_pool (){}

	void print() {
		printf("MEM (%d):", buffer_offset +16);
		for (int i = 0; i < buffer_offset+16; ++i) {
			if (i%4 == 0)
				printf(";");
			printf(" %d", buffer[i]);
		}
		printf("\n");
	}

	inline const void* data_ptr() { return &buffer[0]; }

	//// copy to buffer at current position and increment position by aligned data size
	//void copyToBuffer(const void* src, int size) {
	//	memcpy(buffer, src, size);
	//	buffer_offset += align(size, mem_pool::align_value);
	//}

	//template<class T>
	//T *alloc_obj(int extra_size = 0) {
	//	int size = align(sizeof(T) + extra_size, align_value);
	//	return (T*)allocate(size);
	//}

	StackSlot *GetArrayWritePtr(const StackSlot &arr, int count) {
		return GetMemorySlotWritePtr(arr.GetInternalArrayPtr(), count);
	}

	/*
	* Allocate an uninitialized string of the specified length, returning a pointer to the buffer.
	*/
	unicode_char *AllocateStringBuffer(StackSlot *out, unsigned length) {
		assert(length > 0);

		FlowPtr buf;
		unsigned bytes = align(length * FLOW_CHAR_SIZE, mem_pool::align_value);

		Range r = Range(buffer_offset, bytes);

		if (length & 0xffff0000u) {
			r.length += 4 + 4;
			FlowPtr str = allocate(r.length); //ALLOC
			buf = str + 8;
			SetInt32(str, length & 0xffff);
			SetFlowPtr(str + 4, buf);

			StackSlot::InternalSetString(*out, str, length >> 16, true);
		} else {
			buf = allocate(bytes); // ALLOC

			StackSlot::InternalSetString(*out, buf, length, false);
		}

		registerObject(*out, r);

		return (unicode_char*)GetRawPointer(buf, bytes, true);
	}

	StackSlot AllocateString(const unicode_string &str) {
		return AllocateString(str.data(), str.size());
	}

	StackSlot AllocateString(const char *str) {
		return AllocateString(parseUtf8(str, strlen(str)));
	}

	StackSlot AllocateString(const unicode_char *str, int len) {
		if (len == 0)
			return StackSlot::MakeEmptyString();

		StackSlot out;
		unicode_char *tmp = AllocateStringBuffer(&out, len); // ALLOC

		if (str)
			memcpy(tmp, str, len * FLOW_CHAR_SIZE);

		return out;
	}
	/*
	* Allocate a reference to a string of the given length.
	*
	* Returns a pointer to the location where the address of the string buffer must be stored.
	*/
	FlowPtr *AllocateStringRef(StackSlot *out, unsigned length) {
		static FlowPtr dummy = MakeFlowPtr(0);

		if (length == 0) {
			*out = StackSlot::MakeEmptyString();
			return &dummy;
		}

		Range r = Range(buffer_offset, 4 + 4);
		FlowPtr* ret = NULL;

		if (length & 0xffff0000u) {
			FlowPtr str = allocate(4 + 4);

			SetInt32(str, length & 0xffff);
			StackSlot::InternalSetString(*out, str, length >> 16, true);

			ret = (FlowPtr*)GetRawPointer(str + 4, 4, true);
		} else {
			StackSlot::InternalSetString(*out, MakeFlowPtr(0), length, false);

			ret = &out->slot_private.PtrValue;
		}

		registerObject(*out, r);

		return ret;
	}

	StackSlot AllocateUninitializedArray(unsigned len)
	{
		assert(len > 0);

		Range r = Range(buffer_offset, len * STACK_SLOT_SIZE + 4);

		FlowPtr buf = allocate(r.length); // ALLOC

		//if (unlikely(IsErrorReported()))
		//	return StackSlot::MakeEmptyArray();

		SetInt32(buf, len & 0xffffu);

		StackSlot ret = (len & 0xffff0000u) ? StackSlot::InternalMakeArray(buf, len >> 16, true) : StackSlot::InternalMakeArray(buf, len, false);

		registerObject(ret, r);

		return ret;
	}

	StackSlot AllocateArray(int length, StackSlot *data = NULL) { // data must be immovable
		if (length <= 0)
			return StackSlot::MakeEmptyArray();

		StackSlot rv = AllocateUninitializedArray(length);
		StackSlot *buf = GetArrayWritePtr(rv, length);

		if (data)
			memcpy(buf, data, length * STACK_SLOT_SIZE);
		else
			memset(buf, -1, length * STACK_SLOT_SIZE);

		return rv;
	}

	StackSlot AllocateUninitializedClosure(unsigned short len, FlowPtr code) {
		Range r = Range(buffer_offset, len * STACK_SLOT_SIZE + 4 + 4);
		FlowPtr buf = allocate(r.length) + 4; // ALLOC

		SetFlowPtr(buf - 4, code);
		SetInt32(buf, len);

		StackSlot ret = StackSlot::InternalMakeClosurePointer(buf, len);
		return registerObject(ret, r);
	}

	StackSlot AllocateRef(const StackSlot &value) {
		unsigned id = NextRefId++;

		Range r = Range(buffer_offset, STACK_SLOT_SIZE + 4);

		FlowPtr buf = allocate(STACK_SLOT_SIZE + 4); // ALLOC
		SetInt32(buf, id & 0xffffu);

		SetMemorySlot(buf + 4, 0, value);

		StackSlot rv;
		if (id & 0xffff0000u) {
			rv = StackSlot::InternalMakeRefTo(buf, id >> 16, true);
		}
		else {
			rv = StackSlot::InternalMakeRefTo(buf, id, false);
		}

		return registerObject(rv, r);
	}

#ifdef FLOW_COMPACT_STRUCTS
	FlowStructHeader *GetStructPointer(FlowPtr ptr, bool for_write) {
		return (FlowStructHeader*)VerifyAccess(ptr, 4, for_write);
	}
#endif

	StackSlot AllocateRawStruct(StructDef &def, bool clear)
	{
#ifdef FLOW_COMPACT_STRUCTS
		if (def.FieldsCount == 0)
			return StackSlot::MakeStruct(def.EmptyPtr, def.StructId);

		assert(def.ByteSize >= 8);
		Range r = Range(buffer_offset, def.ByteSize);
		FlowPtr buf = allocate(def.ByteSize);

		FlowStructHeader *ph = GetStructPointer(buf, true);
		ph->StructId = def.StructId;
		ph->GC_Tag = 0;// unlikely(buf >= hp_ref_base) ? NextGCTag : 0;

		if (clear)
			memset(ph->Bytes + 4, 0, def.ByteSize - 4);
#else
		if (def.FieldsCount == 0)
			return StackSlot::Make(TStruct, MakeFlowPtr(0), def.StructId);

		int bytes = def.FieldsCount * STACK_SLOT_SIZE;
		FlowPtr buf = allocate(bytes);
		if (clear)
			Memory.FillBytes(buf, 0, bytes);
#endif
		StackSlot ret = StackSlot::MakeStruct(buf, def.StructId);

		return registerObject(ret, r);
	}


	void SetMemorySlot(FlowPtr ptr, int index, const StackSlot &val) {
		FlowPtr slot = ptr + index * STACK_SLOT_SIZE;
		SetStackSlot(slot, val);
		//	if (slot > hp_ref_base) RegisterWrite(slot);
	}

	FlowPtr GetFlowPtr(FlowPtr addr) { return *(FlowPtr*)VerifyAccess(addr, sizeof(int), false); }
	void SetFlowPtr(FlowPtr addr, FlowPtr val) { *(FlowPtr*)VerifyAccess(addr, sizeof(int), true) = val; }

	const StackSlot &GetStackSlot(FlowPtr addr) { return *(StackSlot*)VerifyAccess(addr, STACK_SLOT_SIZE, false); }
	void SetStackSlot(FlowPtr addr, const StackSlot &val) { *(StackSlot*)VerifyAccess(addr, STACK_SLOT_SIZE, true) = val; }

	unsigned short GetUInt16(FlowPtr addr) { return *(unsigned short*)VerifyAccess(addr, sizeof(short), false); }

	char *GetRawPointer(FlowPtr ptr, size_t size, bool for_write) { return VerifyAccess(ptr, size, for_write); }

	StackSlot *GetClosureWritePtr(const StackSlot &arr, int count) { return GetMemorySlotWritePtr(arr.GetClosureDataPtr(), count); }

	int GetInt32(FlowPtr addr) { return *(int*)VerifyAccess(addr, sizeof(int), false); }
	void SetInt32(FlowPtr addr, int val) { *(int*)VerifyAccess(addr, sizeof(int), true) = val; }

	void Copy(FlowPtr from, FlowPtr to, size_t size) {
		if (unlikely(size == 0)) return;
		memmove(VerifyAccess(to, size, true), VerifyAccess(from, size, false), size);
	}

	void FillBytes(FlowPtr addr, int val, size_t size) {
		if (unlikely(size == 0)) return;
		memset(VerifyAccess(addr, size, true), val, size);
	}

	void SetBytes(FlowPtr addr, const void *buf, size_t size) {
		if (unlikely(size == 0)) return;
		memcpy(VerifyAccess(addr, size, true), buf, size);
	}

	void GetBytes(FlowPtr addr, void *buf, size_t size) {
		if (unlikely(size == 0)) return;
		memcpy(buf, VerifyAccess(addr, size, false), size);
	}

	// size should be aligned
	FlowPtr allocate(int size) {
		if (buffer.size() - buffer_offset < size) {
			if (!grow()) return NULL;
		}

		unsigned ret = buffer_offset;
		buffer_offset += size;

		return (FlowPtr)ret;
	}

	inline int align(int value, int a) {
		return (value + a - 1) / a * a;
	}

private:
	char *VerifyAccess(FlowPtr ptr, size_t, bool) { return &buffer[ptr];	}

	StackSlot *GetMemorySlotWritePtr(FlowPtr ptr, int count) {
		return (StackSlot*)GetRawPointer(ptr, count * STACK_SLOT_SIZE, true);
	}

	bool grow() {
		if (buffer.size() < MAX_HEAP_SIZE_L) {
			buffer.resize(buffer.size() + std::min(int(MAX_HEAP_SIZE_L - buffer.size()), (int)HEAP_RESIZE_STEP));
			return true;
		}

		return false;
	}

	// gc functions
	void markAll(TDataStack& datastack) {
		datastack.forEach([=](StackSlot s) {
			if (memmap[s].marked)
				return true;

			memmap[s].marked = 1;

			if (s.IsStruct()) {
				// go through fields and mark them as well
			}

			return true;
		});
	}

	void sweep(TDataStack& datastack) {
		// free memory for unreachable objects and unmark reachable for next gc calls
	}

} mem_pool;

// from GarbageCollector.h
#ifdef FLOW_COMPACT_STRUCTS
namespace flow_fields {
	void enum_slot(GarbageCollector*, const void*) {}
	void gc_slot(GarbageCollector*, void*) {}
	void enum_array(GarbageCollector*, const void*) {}
	void gc_array(GarbageCollector*, void*) {}
	void enum_string(GarbageCollector*, const void*) {}
	void gc_string(GarbageCollector*, void*) {}
	void enum_ref(GarbageCollector*, const void*) {}
	void gc_ref(GarbageCollector*, void*) {}
	void enum_struct(GarbageCollector*, const void*) {}
	void gc_struct(GarbageCollector*, void*) {}
#define FLOW_FIELD_GC_DEF(type,offset) \
    { int(offset), flow_fields::enum_##type, flow_fields::gc_##type }
}
#endif

#endif // !MEM_POOL_H
