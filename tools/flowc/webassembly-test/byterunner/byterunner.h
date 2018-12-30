#include <stdio.h>
#include <assert.h>
#include <emscripten.h>
#include <string.h>
//#include "CommonTypes.h"
#include "mem_pool.h"
//#include "codememory.hpp"
#include <sstream>
//#include "native_program.hpp"
#include "RunnerMacros.h"
//#include "natives.hpp"

bool debug_log_v = false;
#define debug_log(log_fn) \
	{ \
		if (debug_log_v) { log_fn; } \
		else {} \
	}

using std::stringstream;
//
//enum CallbackType {
//	ct_addEventListener,
//};


#pragma region Defines
#define FLOW_ASSERT	assert(false)
//
//#define RUNNER_RefArgs1(arg0) \
//    const StackSlot &arg0 = GetStackSlotRef(0);
//
//#define RUNNER_RefArgsRet1(rv_arg0) \
//    StackSlot &rv_arg0 = *GetStackSlotPtr(0);
//
//#define RUNNER_RefArgsRet2(rv_arg1, arg0) \
//    StackSlot &rv_arg1 = *GetStackSlotPtr(1); \
//    const StackSlot &arg0 = GetStackSlotRef(0);
//
//#define RUNNER_CheckTag_WA(tag, slot) \
//    if (unlikely(!slot.Is##tag())) { \
//        ReportTagError(slot, tag, #slot, NULL); \
//        return LastError; \
//    }
//
//#define RUNNER_CheckTag2_WA(tag, slot1, slot2) \
//    RUNNER_CheckTag_WA(tag, slot1) \
//    RUNNER_CheckTag_WA(tag, slot2)

//#undef RUNNER_CheckTag
//#define RUNNER_CheckTag(tag, slot) \
//    if (unlikely(!slot.Is##tag())) { \
//        ReportTagError(slot, tag, #slot, NULL); \
//        RETVOID; \
//    }

//#undef RUNNER_CheckError
//#define RUNNER_CheckError() \
//    if (unlikely(LastError != NoError)) RETVOID;

//#undef RUNNER_DefSlotArray
//#define RUNNER_DefSlotArray(name, size) \
//    StackSlot name[size]; \
//    SlotArrayInit<size>::init(name); \
//    LocalRootDefinition _flow_root_def_##name(NULL, size, name);

//// The native function is a static method of the host
//#define TRY_USE_NATIVE_STATIC_NAME_WA(method_name, string_name, num_method_args) \
//    if (NATIVE_NAME_MATCHES(string_name, num_method_args)) \
//        return new SimpleNative(NATIVE_NAME_PREFIX string_name, num_method_args, &native_ns::method_name);
//
//#define TRY_USE_NATIVE_STATIC_WA(method_name, num_method_args) \
//    TRY_USE_NATIVE_STATIC_NAME_WA(method_name, #method_name, num_method_args)

#pragma endregion //Defines

const char * tag2string(int tag);

class ByteCodeRunner : public LocalRootHost {
	friend class StubNative;

public:
	TDataStack DataStack = TDataStack(MAX_DATA_STACK);

	bool NotifyStubs = true;
	ostream flow_out, flow_err;
protected:
	CodeMemory code;
	RuntimeError LastError = NoError;
	TCallStack CallStack = TCallStack(MAX_CALL_STACK);
	FlowPtr closurepointer;
	int FramePointer = 0;
	FlowPtr LastInstructionPtr = MakeFlowPtr(0);

	typedef STL_HASH_MAP<unicode_string, unicode_string> T_UrlParameters;
	unicode_string &getUrlString() { return UrlString; }
	void setUrlString(unicode_string url) { UrlString = url; }
	T_UrlParameters &getUrlParameterMap() { return UrlParameters; }

	// Program launch url and parameters
	unicode_string UrlString;
	T_UrlParameters UrlParameters;

	// Table of native functions. Note how it is an array grown at the end instead
	// of map, so continuously allocating new native functions is inefficient.
	typedef CStack<NativeFunction*> T_Natives;
	typedef STL_HASH_MAP<int, AbstractNativeValue*> T_NativeValues;
	T_Natives Natives = T_Natives(MAX_NATIVE_STACK);
	unsigned NativeCallDepth = 0;

	friend class NativeFunction;
	NativeFunction *CurNativeFn = NULL;

	FlowPtr NativeReturnInsn = MakeFlowPtr(0);
	T_NativeValues NativeValues;
	int NextNativeIdx=0, NativeValueBudget=1000;


	// Struct definition data
	std::vector<StructDef> StructDefs;
	typedef STL_HASH_MAP<std::string, int> T_StructNameIds;
	T_StructNameIds StructNameIds;

	// Table of struct field counts for faster access
	typedef FlowStack<unsigned, 128> T_StructSizes;
	T_StructSizes StructSizes;

	// For optimization of opcodes that access fields by name
	std::vector<std::string> FieldRefNames;
	std::map<std::string, int> FieldRefIds;

	#ifdef FLOW_COMPACT_STRUCTS
	std::vector<FlowStructFieldDef*> AutoStructFields;
	std::vector<FlowStructFieldGCDef*> AutoStructGCFields;
	#endif

	// For efficient handling of certain structs from native code
	typedef std::pair<int*, int> T_KnownStructTableItem;
	typedef STL_HASH_MAP<std::string, T_KnownStructTableItem> T_KnownStructTable;
	T_KnownStructTable KnownStructTable;

	std::map<FlowPtr, std::string> DebugFnInfo;

	std::string LastErrorDescr;
	std::string LastErrorInfo;

public:
	ByteCodeRunner();


#pragma region Error reporting
	// Error reporting
	void DoReportError(RuntimeError code) {
		if (code == NoError) return;

		stringstream info_str;
		info_str << "Error during last opcode [0x" << hex << FlowPtrToInt(LastInstructionPtr)
			<< "]: " << dec << code << endl;

#ifdef FLOW_JIT
		if (!JitProgram)
#endif
			info_str << "Location: " << AddressToFunction(LastInstructionPtr) << endl;

		info_str << "DataStack.size() = " << DataStack.size()
			<< ", CallStack.size() = " << CallStack.size()
			//<< "hp = " << hex << FlowPtrToInt(hp)
			//<< ", HeapStart = 0x" << FlowPtrToInt(HeapStart)
			//<< ", HeapEnd = 0x" << FlowPtrToInt(HeapEnd)
			<< dec << endl;

#ifdef FLOW_JIT
		if (!JitProgram)
#endif
			//			Disassemble(info_str, LastInstructionPtr, 1);
			//
			//#ifdef FLOW_DEBUGGER
			//		if (!DebuggerPtr)
			//#endif
			//			PrintCallStack(info_str, true);

			LastErrorInfo = info_str.str();
			flow_err << LastErrorDescr << endl << LastErrorInfo << endl;
			//
			//#ifdef FLOW_DEBUGGER
			//		if (DebuggerPtr)
			//			DebuggerPtr->onError(code, LastInstructionPtr);
			//#endif
			//
					//if (code == DivideByZerro || code == InvalidArgument || code == InvalidFieldName)
					//	callFlowCrashHandlers(LastErrorDescr + "\n" + LastErrorInfo);

		PrintDataStack(0);

		LastError = code;

		//NotifyHostEvent(NativeMethodHost::HostEventError);
	}

	void PrintDataStack(int _max = 10) {
		flow_err << "Stack:\n";
		if (_max <= 0) _max = DataStack.size();
		int n = DataStack.size() - _max;
		for (int i = DataStack.size() - 1; i >= n && i >= 0; i--) {
			flow_err << dec << i << ": ";
			PrintData(flow_err, DataStack[i]);
			flow_err << endl;
		}
	}

	void ReportError(RuntimeError code, const char *msg, ...) {
		if (LastError == NoError) return;
		va_list vl;
		va_start(vl, msg);
		//	LastErrorDescr = stl_vsprintf(msg, vl);
		va_end(vl);
		DoReportError(code);
	}

	void ReportTagError(const StackSlot &slot, DataTag expected, const char *varname, const char *msg, ...) {
		//if (IsErrorReported()) return;
		LastErrorDescr = stl_sprintf("Invalid Tag: %s (%s expected, %s found)", varname, tag2string(expected), tag2string(slot.GetType()));
		//if (msg != NULL) {
		//	va_list vl;
		//	va_start(vl, msg);
		//	LastErrorDescr += "\n" + stl_vsprintf(msg, vl);
		//	va_end(vl);
		//}
		DoReportError(InvalidArgument);
	}

	void StackError(RuntimeError error, bool overflow = true) {
		const char *name = "unknown";
		switch (error) {
		case DatastackFull: name = "data"; break;
		case CallstackFull: name = "call"; break;
		case ClosurestackFull: name = "closure"; break;
		default:;
		}

		ReportError(error, "Stack %s in the %s stack.", (overflow ? "overflow" : "underflow"), name);
	}

	void ReportFieldNameError(const StackSlot &struct_ref, const char *fname, const char *where) {
		StructDef *def = safeVectorPtrAt(StructDefs, struct_ref.GetStructId());

		if (unlikely(def == NULL || def->Name.empty())) {
			ReportError(UnknownStructDefId, "Unknown struct kind: %d", struct_ref.GetStructId());
			return;
		}

		ReportError(InvalidFieldName, "Invalid field name \"%s\" for struct '%s' at [%08Xh] in %s",
			fname, def->Name.c_str(), FlowPtrToInt(struct_ref.GetRawStructPtr()), where);
	}
#pragma endregion

#pragma region Stack
	CallFrame *CallStackPush(FlowPtr addr) {
		if (likely(CallStack.size() < MAX_CALL_STACK)) {
			CallFrame *pf = CallStack.push_ptr();
			pf->last_pc = addr;
			pf->last_frame = FramePointer;
			pf->last_closure = closurepointer;
#ifdef FLOW_DEBUGGER
			pf->impersonate_pc = ImpersonateInsn;
			pf->is_closure = false;
#endif
			return pf;
		}
		else {
			StackError(CallstackFull);
			return NULL;
		}
	}

	CallFrame *CallStackPop() {
		if (likely(!CallStack.empty())) {
			return CallStack.pop_ptr();
		}
		else {
			StackError(CallstackFull, false);
			return NULL;
		}
	}

	const StackSlot &GetStackSlotRef(int offset) {
		return DataStack.top(offset);
	}

	std::string AddressToFunction(FlowPtr pc) {
		static std::string q("?");
		static std::string invalid("<invalid>");
		static std::string native("<native>");

		if (int(FlowPtrToInt(pc)) < 0)
			return stl_sprintf("<special %d>", -1 - int(FlowPtrToInt(pc)));
		
		//#ifdef FLOW_JIT
		//	if (JitProgram)
		//		return JitProgram->AddressToFunction(pc);
		//#endif
		//
		if (pc >= code.GetLastAddr())
			return invalid;
		else if (pc == NativeReturnInsn)
			return native;

		//	if (ExtDbgInfo)
		//	{
		//		ExtendedDebugInfo::FunctionEntry *func = ExtDbgInfo->find_function(pc);
		//		if (func)
		//			return func->name;
		//	}

		std::map<FlowPtr, std::string>::iterator it = mapFindLE(DebugFnInfo, pc);
		if (it != DebugFnInfo.end())
			return it->second;
		else
			return q;

		return invalid;
	}

	StackSlot *GetStackSlotPtr(int offset) {
		return &DataStack.top(offset);
	}

	inline void logDatastackSize(const char* op) {
//		printf("Datastack size: %d (%s)\n", DataStack.size(), op);
	}

	// Pop operations
	inline StackSlot* PopPtr(unsigned sz = 1) {
		StackSlot* ret = DataStack.pop_ptr(sz);
		logDatastackSize("pop_ptr");
		return ret;
	}

	inline StackSlot PopStackSlot() {
		if (likely(!DataStack.empty())) {
			return *(DataStack.pop_ptr());
		}
		else {
			StackError(DatastackFull, false);
			return StackSlot::MakeVoid();
		}
	}

	void DiscardStackSlots(int num) {
		if (likely(DataStack.size() >= unsigned(num)))
			PopPtr(num);
		else
			StackError(DatastackFull, false);
	}

#define FLOW_KNOWN_STRUCTS \
    STRUCT(Cons, 2) \
    STRUCT(EmptyList, 0) \
    STRUCT(None, 0) \
    STRUCT(Some, 1) \
    STRUCT(TreeNode, 5) \
    STRUCT(TreeEmpty, 0)

#define STRUCT(name,size) int name ## StructId;
	FLOW_KNOWN_STRUCTS
#undef STRUCT

		// Lists
#define STRUCT(name,size) bool Is##name##Struct(const StackSlot &slot) { \
        return slot.IsStruct() && slot.GetStructId() == name##StructId; \
    }
		FLOW_KNOWN_STRUCTS
#undef STRUCT

	StackSlot GetConsItem(const StackSlot &cons) {
		return GetStructSlot(cons, 0);
	}

	void StructTypeError(const StackSlot &slot, const char *fn, const char *tname, int struct_id) {
		if (struct_id < 0)
		{
			ReportError(InvalidArgument, "Undefined struct type: %s", tname);
		}
		else
		{
			StructDef *def = safeVectorPtrAt(StructDefs, slot.GetStructId());
			ReportError(InvalidArgument,
				"Not a %s argument in %s: '%s'",
				tname, fn, (def ? def->Name.c_str() : "?"));
		}
	}
	const StructDef & GetStructDef(int struct_id) {
		assert(unsigned(struct_id) < StructSizes.size());
		return StructDefs[struct_id];
	}
	int FindStructId(const std::string &name, int fields_num) {
		int index = safeMapAt(StructNameIds, name, -1);
		if (unlikely(index < 0))
			return -1;

		unsigned dcnt = StructSizes[index];
		if (unlikely(dcnt != (unsigned)fields_num))
			return -2;

		return index;
	}
	bool VerifyStruct(const StackSlot &arr, int struct_id) {
		if (unsigned(struct_id) >= StructDefs.size())
			return false;

		StructDef *def = &StructDefs[struct_id];
		if (GetArraySize(arr) != def->FieldsCount)
			return false;

		for (int i = 0; i < def->FieldsCount; ++i) {
			if (!isValueFitInType(this, def->FieldTypes[i], GetArraySlot(arr, i), 0))
				return false;
		}

		return true;
	}
	bool isValueFitInType(RUNNER_VAR, const std::vector<FieldType> &type, const StackSlot &value, int ti) {
		switch (type[ti++]) {
		case FTVoid: return value.IsVoid();
		case FTBool: return value.IsBool();
		case FTInt: return value.IsInt();
		case FTDouble: return value.IsDouble();
		case FTString: return value.IsString();
		case FTArray: return value.IsArray();
		case FTStruct: return value.IsStruct();
		case FTRefTo:return value.IsRefTo();
		case FTTypedArray: {
			if (unlikely(!value.IsArray())) return false;
			FieldType arrtype = type[ti];
			if (arrtype != FTFlow) { // Type is not Flow
				for (int i = 0; i < RUNNER->GetArraySize(value); ++i)
					if (unlikely(!isValueFitInType(RUNNER, type, RUNNER->GetArraySlot(value, i), ti))) return false;
			}
			return true;
		}
		case FTTypedRefTo: {
			if (unlikely(!value.IsRefTo())) return false;
			return isValueFitInType(RUNNER, type, mem_pool.GetStackSlot(value.GetRawRefPtr()), ti);
		}
		case FTTypedStruct: {
			if (unlikely(!value.IsStruct())) return false;
			return (value.GetStructId() == type[ti]);
		}
		default: return true;
		}
	}

	StackSlot MakeStruct(const std::string& name, int fields_num, const StackSlot * fields) {
		int index = safeMapAt(StructNameIds, name, -1);

		if (unlikely(index < 0)) {
			ReportError(InvalidArgument, "Unknown struct: '%s'", name.c_str());
			return StackSlot::MakeVoid();
		}

		StructDef *def = &StructDefs[index];
		if (unlikely(def->FieldsCount != fields_num)) {
			ReportError(InvalidArgument, "Struct %s has %d fields; %d found",
				name.c_str(), def->FieldsCount, fields_num);
			return StackSlot::MakeVoid();
		}

		StackSlot arr = mem_pool.AllocateRawStruct(*def, false);

		for (int i = 0; i < fields_num; ++i) {
			SetStructSlot(arr, i, fields[i]);
		}

		return arr;
	}

#define STRUCT(name,size) bool Verify##name(const StackSlot &slot, const char *fn) { \
        if (unlikely(!slot.IsStruct() || slot.GetStructId() != name##StructId || name##StructId < 0)) {\
            StructTypeError(slot, fn, #name, name##StructId); return false; \
        } else return true; \
    }
	FLOW_KNOWN_STRUCTS
#undef STRUCT

#define STRUCT(name,size) StackSlot Allocate##name##Struct(StackSlot *data = NULL) { \
        return AllocateKnownStruct(#name,size,name##StructId,data); \
    }
		FLOW_KNOWN_STRUCTS
#undef STRUCT

	StackSlot AllocateKnownStruct(const char *name, int size, int id, StackSlot *data) {
		if (unlikely(id < 0))
		{
			ReportError(InvalidArgument, "Undefined structure: '%s'", name);
			return StackSlot::MakeVoid();
		}

		StackSlot rv = mem_pool.AllocateRawStruct(StructDefs[id], data == NULL);
		if (data)
			StructSlotPack(rv, data, 0, size);
		return rv;
	}
	StackSlot AllocateSomeStruct(StackSlot data);

	StackSlot AllocNativeFn(NativeFunction *fn, FlowPtr cp) {
		if (fn->num_args() > MAX_NATIVE_ARGS) {
			// Trying to call this native will overrun a stack buffer.
			// Increase the constant and recompile if this becomes a problem.
			ReportError(UnknownNativeName, "Too many args for native \"%s\": %d", fn->name(), fn->num_args());
			return StackSlot::MakeVoid();
		}

		int id = Natives.size();
		Natives.push_back(fn);
		fn->debug_token_ = cp;
//		fn->set_debug_token(cp);

#ifdef FLOW_JIT
		if (JitProgram)
			JitProgram->RegisterNative(this, id, fn);
#endif

		return StackSlot::MakeNativeFn(id);
	}

	FlowPtr AllocateClosureBuffer(int code, unsigned short len, StackSlot *data) {
		int bytes = len * STACK_SLOT_SIZE;
		FlowPtr buf = mem_pool.allocate(bytes + 4 + 4) + 4; // ALLOC

		mem_pool.SetInt32(buf - 4, code);
		mem_pool.SetInt32(buf, len);

		if (data)
			CopySlots(buf + 4, data, len);
		else
			mem_pool.FillBytes(buf + 4, -1, bytes);

		return buf;
	}

	StackSlot AllocateNativeClosure(NativeClosurePtr ptr, const char *name, int num_args, void *data, int num_slots, ...) {
		StackSlot *buf = new StackSlot[num_slots + 1];
		StackSlot &base = buf[0];

		va_list vl;
		va_start(vl, num_slots);
		for (int i = 0; i < num_slots; ++i)
			buf[i + 1] = va_arg(vl, StackSlot);
		va_end(vl);

		base = AllocNativeFn(new NativeClosure(name, num_args, ptr, data), NativeReturnInsn);
		assert(base.IsNativeFn() && !base.GetSign());

		LocalRootDefinition frame(this, num_slots + 1, buf); (void)&frame;
		FlowPtr arr = AllocateClosureBuffer(base.slot_private.IntValue, num_slots, buf + 1); // ALLOC

		delete[] buf;
		return StackSlot::InternalMakeNativeClosure(arr, num_slots);
	}

	inline StackSlot* PushPtr(unsigned sz = 1) {
		StackSlot* ret = DataStack.push_ptr(sz);
		logDatastackSize("push_ptr");
		return ret;
	}

	inline void DataStackResize(unsigned size) {
		DataStack.resize(size);
		logDatastackSize("resize");
	}

	inline void Push(const StackSlot &value) {
		if (DataStack.size() < MAX_DATA_STACK)
			DataStack.push_back(value);
		else
			StackError(DatastackFull);

		logDatastackSize("push");
	}

	inline void PushVoid() {
		Push(StackSlot::MakeVoid());
	}

	inline void PushInt(int value) {
		Push(StackSlot::MakeInt(value));
	}

	inline void PushBool(int value) {
		Push(StackSlot::MakeBool(value));
	}

	inline void PushDouble(FlowDouble value) {
		Push(StackSlot::MakeDouble(value));
	}

	void Push(const unicode_string &str) {
		Push(mem_pool.AllocateString(str.data(), str.size()));
	}

	void PushDataStackSlot(int offset) {
		unsigned size = DataStack.size();

		if (likely(size < MAX_DATA_STACK && unsigned(offset) < size)) {
			// Must do in two phases in case the stack buffer is reallocated
			StackSlot *dest = PushPtr();
			*dest = DataStack[offset];
		}
		else {
			if (unsigned(offset) >= size)
				ReportError(InvalidArgument, "Trying to push an invalid data stack index: %d", offset);
			else
				StackError(DatastackFull);
		}
	}

#pragma endregion

#pragma region Helpers
	void CopySlots(FlowPtr target, FlowPtr src, int count) {
		mem_pool.Copy(src, target, count * STACK_SLOT_SIZE);
//		if (unlikely(target >= hp_big_pos)) RegisterWrite(target, count);
	}
	void CopySlots(FlowPtr target, const StackSlot *src, int count) {
		mem_pool.SetBytes(target, src, count * STACK_SLOT_SIZE);
//		if (unlikely(target >= hp_big_pos)) RegisterWrite(target, count);
	}
	void CopyArraySlots(const StackSlot &target, int toff, const StackSlot &src, int soff, int count) {
		CopySlots(target.GetInternalArrayPtr() + toff * STACK_SLOT_SIZE, src.GetInternalArrayPtr() + soff * STACK_SLOT_SIZE, count);
	}
	void CopyArraySlots(const StackSlot &target, int toff, const StackSlot *src, int count) {
		CopySlots(target.GetInternalArrayPtr() + toff * STACK_SLOT_SIZE, src, count);
	}

	unsigned GetSplitAuxValue(const StackSlot &str) {
		return str.GetSign() ? (str.slot_private.AuxValue << 16) | mem_pool.GetUInt16(str.slot_private.PtrValue) : str.slot_private.AuxValue;
	}

	FlowPtr GetStringAddr(const StackSlot &str) {
		assert(str.IsString());
		return str.GetSign() ? mem_pool.GetFlowPtr(str.slot_private.PtrValue + 4) : str.slot_private.PtrValue;
	}

	inline unsigned GetStringSize(const StackSlot &str) {
		assert(str.IsString());
		return GetSplitAuxValue(str);
	}

	const unicode_char *GetStringPtrSize(const StackSlot &str, unsigned *psize) {
		unsigned size = *psize = GetStringSize(str);
		return size ? (unicode_char*)mem_pool.GetRawPointer(GetStringAddr(str), size * FLOW_CHAR_SIZE, false) : NULL;
	}

	const unicode_char *GetStringPtr(const StackSlot &str) {
#ifdef DEBUG_FLOW
		return (unicode_char*)mem_pool.GetRawPointer(GetStringAddr(str), GetStringSize(str) * FLOW_CHAR_SIZE, false);
#else
		return (unicode_char*)mem_pool.GetRawPointer(GetStringAddr(str), 0, false);
#endif
	}

	inline int GetArraySize(const StackSlot &arr) {
		assert(arr.IsArray());
		return GetSplitAuxValue(arr);
	}

	const StackSlot &GetArraySlot(const StackSlot &arr, int index) {
		return mem_pool.GetStackSlot(arr.GetInternalArrayPtr() + index * STACK_SLOT_SIZE);
	}

	const StackSlot *GetArraySlotPtr(const StackSlot &arr, int count) {
		return (StackSlot*)mem_pool.GetRawPointer(arr.GetInternalArrayPtr(), count * STACK_SLOT_SIZE, false);
	}

	const StackSlot *GetClosureSlotPtr(const StackSlot &arr, int count) {
		return (StackSlot*)mem_pool.GetRawPointer(arr.GetClosureDataPtr(), count*STACK_SLOT_SIZE, false);
	}

	inline int GetStructSize(const StackSlot &arr) {
		int id = arr.GetStructId();
		if (unsigned(id) >= StructSizes.size())
			return -1;
		else
			return StructSizes[id];
	}

	void SetArraySlot(const StackSlot &arr, int index, const StackSlot &val) {
		mem_pool.SetMemorySlot(arr.GetInternalArrayPtr(), index, val);
	}

	const StackSlot GetStructSlot(const StackSlot &str, int index) {
		const FlowStructFieldDef &fd = StructDefs[str.GetStructId()].FieldDefs[index];
		FlowStructHeader *ph = mem_pool.GetStructPointer(str.GetRawStructPtr(), false);
		return fd.fn_get(ph->Bytes + fd.offset, this);
	}

	void SetStructSlot(const StackSlot &str, int index, const StackSlot &val) {
		const FlowStructFieldDef &fd = StructDefs[str.GetStructId()].FieldDefs[index];
		FlowStructHeader *ph = mem_pool.GetStructPointer(str.GetRawStructPtr(), true);
		if (unlikely(!fd.fn_set(ph->Bytes + fd.offset, val)))
			ReportTagError(val, fd.tag, StructDefs[str.GetStructId()].FieldNames[index].c_str(), "SetStructSlot");
		//else if (unlikely(ph->GC_Tag))
		//	RegisterWrite(ph, str.GetRawStructPtr());
	}

	const StackSlot &GetRefTarget(const StackSlot &ref) {
		return mem_pool.GetStackSlot(ref.GetRawRefPtr());
	}

	void SetRefTarget(const StackSlot &ref, const StackSlot &val) {
		mem_pool.SetMemorySlot(ref.GetRawRefPtr(), 0, val);
	}

	int GetRefId(const StackSlot &ref) {
		assert(ref.IsRefTo());
		return GetSplitAuxValue(ref);
	}

	int GetNativeFnId(const StackSlot &ref) {
		assert(ref.IsNativeFn());
		return ref.GetSign() ? mem_pool.GetInt32(ref.slot_private.PtrValue - 4) : ref.slot_private.IntValue;
	}

	FlowPtr GetCodePointer(const StackSlot &ref) {
		assert(ref.IsFlowCode());
		return ref.GetSign() ? mem_pool.GetFlowPtr(ref.slot_private.PtrValue - 4) : ref.slot_private.PtrValue;
	}

	unicode_string GetString(const StackSlot &str) {
		if (unlikely(!str.IsString())) {
			ReportTagError(str, TString, "GetString()", NULL);
			return unicode_string();
		}

		unsigned len;
		const void *data = GetStringPtrSize(str, &len);
		return unicode_string((unicode_char*)data, len);
	}
#pragma endregion // Helpers

#pragma region Opcode processing
	inline bool doTailCall(int locals) {
		// Peek without popping the closure type
		StackSlot &arg = DataStack.top();

		if (arg.IsCodePointer()) {
			// This is our guy! We can do tail calls of this stuff
			// Get rid of the code address
			FlowPtr code_addr = arg.GetCodePtr();
			printf("TailCall to: %d\n", code_addr);
			DiscardStackSlots(1);

			// OK, move the arguments down to the previous frame, which we are going to reuse
			memmove(&DataStack[FramePointer], &DataStack[DataStack.size() - locals], locals * STACK_SLOT_SIZE);

			// Fix the frame up so that Treservelocals in the function itself will make this the reuse
			FramePointer += locals;
			DataStackResize(FramePointer);

			// And then go!
			code.SetPosition(code_addr);

			return true;
		}
		else {
			return false;
		}
	}

	inline NativeFunction *lookupNativeFn(int id) {
		return likely(unsigned(id) < Natives.size()) ? Natives[id] : NULL;
	}

	void DoNativeCall(const StackSlot &arg_in) {
		// Array for the native arguments. A static buffer
		// used to avoid malloc overhead on every call.
		StackSlot arg_buffer[1 + MAX_NATIVE_ARGS];

		// Stash the function reference
		StackSlot &arg = arg_buffer[0];
		arg = arg_in;

		// Lookup the native function
		NativeFunction *fn = lookupNativeFn(GetNativeFnId(arg));

		if (unlikely(fn == NULL)) {
			ReportError(InvalidNativeId, "Invalid native %d", GetNativeFnId(arg));
			return;
		}
		else {
			printf("Found a native function: %s\n", fn->name());
		}

		int num_args = fn->num_args();
#ifdef DEBUG_FLOW
		const char *name = fn->name();
#endif

		// Move the arguments to the buffer above
		if (unlikely((unsigned)num_args > DataStack.size()))
		{
			StackError(DatastackFull, false);
			return;
		}

		if (NativeCallDepth >= MAX_NATIVE_CALLS)
		{
			StackError(CallstackFull, true);
			return;
		}

		FramePointer -= num_args;
		memcpy(arg_buffer + 1, DataStack.pop_ptr(num_args), sizeof(StackSlot)*num_args);

		// Register a local root for the arg buffer (and the function reference)
		LocalRootDefinition arg_buffer_root(this, num_args + 1, arg_buffer);
		(void)&arg_buffer_root;

		// Tag for debugging:
		CallFrame *tag_frame = CallStackPush(fn->debug_token());
		if (unlikely(!tag_frame))
			return;

		LastInstructionPtr = NativeReturnInsn;

#ifdef DEBUG_FLOW
		// Save stack positions for control
		unsigned sp_save = DataStack.size();
		unsigned cp_save = CallStack.size();
#endif

		NativeCallDepth++;

		// Invoke the function
		StackSlot retval = (CurNativeFn = fn)->func_(this, arg_buffer + 1); // ALLOC

		NativeCallDepth--;

		if (LastError != NoError)
			return;

#ifdef FLOW_TIME_PROFILING
		if (unlikely(ProfileTimeCount))
			ProfileTimeEvent();
#endif

#ifdef DEBUG_FLOW
		// Verify stack discipline
		if (unlikely(cp_save != CallStack.size())) {
			int delta = (CallStack.size() - cp_save);
			ReportError(StackCorruption, "Call stack position changed in call to %s: added %d slots.",
				name, delta);
			CallStack.resize(cp_save);
		}

		if (unlikely(sp_save != DataStack.size())) {
			int delta = (DataStack.size() - sp_save);
			// Note: forgetting to return a value is reported as using 1 additional argument.
			ReportError(StackCorruption, "Native function %s expected to use %d args; actually used %d.",
				name, num_args, num_args - delta);
			DataStack.resize(sp_save);
		}
#endif

		// Push the return value
		DataStack.push_back(retval);

		// Return immediately
		CallFrame *frame = CallStack.pop_ptr(2);
		code.SetPosition(frame->last_pc);
		FramePointer = frame->last_frame;

#ifdef FLOW_DEBUGGER
		ImpersonateInsn = frame->impersonate_pc;

		if (unlikely(DbgReturnTrap))
		{
			if (DebuggerPtr)
				DebuggerPtr->onReturnTrap(Code.GetPosition());
		}
#endif
	}

	inline void doCall();

	void DoMultiply(StackSlot &val1, const StackSlot &val2) {
		if (val1.IsInt() && val2.IsInt())
			val1.SetIntValue(val1.GetInt() * val2.GetInt());
		else if (val1.IsDouble() && val2.IsDouble())
			val1.SetDoubleValue(val1.GetDouble() * val2.GetDouble());
		else
			ReportError(InvalidArgument, "Error in arguments types in CMultiply: %s + %s",
				tag2string(val1.GetType()), tag2string(val2.GetType()));
	}

	void DoDivide(StackSlot &val1, const StackSlot &val2) {
		// TODO: division by zero
		if (val1.IsInt() && val2.IsInt())
			val1.SetIntValue(val1.GetInt() / val2.GetInt());
		else if (val1.IsDouble() && val2.IsDouble())
			val1.SetDoubleValue(val1.GetDouble() / val2.GetDouble());
		else
			ReportError(InvalidArgument, "Error in arguments types in CDivide: %s + %s",
				tag2string(val1.GetType()), tag2string(val2.GetType()));
	}

	void DoModulo(StackSlot &val1, const StackSlot &val2) {
		// TODO: division by zero
		if (val1.IsInt() && val2.IsInt())
			val1.SetIntValue(val1.GetInt() % val2.GetInt());
		else if (val1.IsDouble() && val2.IsDouble())
			val1.SetDoubleValue(fmod(val1.GetDouble(), val2.GetDouble()));
		else
			ReportError(InvalidArgument, "Error in arguments types in CModulo");
	}

	inline void DoNegate(StackSlot &val) {
		if (val.IsInt())
			val.SetIntValue(-val.GetInt());
		else if (val.IsDouble())
			val.SetDoubleValue(-val.GetDouble());
		else
			ReportError(InvalidArgument, "Error in arguments types in CNegative");
	}

	int Compare(ByteCodeRunner *self, const StackSlot &slot1, const StackSlot &slot2);

	inline int CompareInt(int a, int b) {
		if (a == b)
			return 0;
		else
			return (a < b) ? -1 : 1;
	}

	int CompareFlowString(FlowPtr p1, int l1, FlowPtr p2, int l2) {
		if (p1 != p2) {
			// String comparison in UCS-2 format
			unsigned m = (unsigned)std::min(l1, l2);
			unicode_char *pchar1 = (unicode_char*)mem_pool.GetRawPointer(p1, m * FLOW_CHAR_SIZE, false);
			unicode_char *pchar2 = (unicode_char*)mem_pool.GetRawPointer(p2, m * FLOW_CHAR_SIZE, false);

			for (unsigned i = 0; likely(i < m); ) {
				unicode_char a = pchar1[i];
				unicode_char b = pchar2[i];
				i++;
				if (a != b)
					return (a > b) ? 1 : -1;
			}
		}

		return CompareInt(l1, l2);
	}

	int Compare(const StackSlot &slot1, const StackSlot &slot2) { return Compare(this, slot1, slot2); }
	bool CompareByRef(const StackSlot &slot1, const StackSlot &slot2);

	int Compare(FlowPtr a1, FlowPtr a2) {
		if (a1 == a2)
			return 0;
		else
			return Compare(mem_pool.GetStackSlot(a1), mem_pool.GetStackSlot(a2));
	}

	inline void DoEqual();
	inline void DoLessThan();
	inline void DoLessEqual();

	bool DoSubstring(StackSlot *pdata, int idx, int size);

	void DoPlusString(StackSlot &val1, const StackSlot &val2) {
		if (val2.IsEmpty())
			return;

		if (val1.IsEmpty()) {
			val1 = val2;
			return;
		}

		int l1 = GetStringSize(val1);
		int l2 = GetStringSize(val2);

		if (GetStringAddr(val1) + l1 * FLOW_CHAR_SIZE == GetStringAddr(val2))
		{
			// Merge the strings in-place
			StackSlot rv;
			FlowPtr *rp = mem_pool.AllocateStringRef(&rv, l1 + l2); // ALLOC

			*rp = GetStringAddr(val1);
			val1 = rv;
		}
		else {
			StackSlot rv;
			unicode_char *ptr = mem_pool.AllocateStringBuffer(&rv, l1 + l2); // ALLOC

			{
				// Assume val1 & val2 don't move, since gc
				// doesn't reallocate the stack anymore
				memcpy(ptr, GetStringPtr(val1), l1 * FLOW_CHAR_SIZE);
				memcpy(ptr + l1, GetStringPtr(val2), l2 * FLOW_CHAR_SIZE);
				val1 = rv;
			}
		}
	}
	void DoPlus(StackSlot &val1, const StackSlot &val2)
	{
		if (val1.IsInt() && val2.IsInt())
			val1.SetIntValue(val1.GetInt() + val2.GetInt());
		else if (val1.IsDouble() && val2.IsDouble())
			val1.SetDoubleValue(val1.GetDouble() + val2.GetDouble());
		else if (val1.IsString() && val2.IsString())
			DoPlusString(val1, val2);
		else
			ReportError(InvalidArgument, "Error in arguments types in CPlus: %s + %s",
				tag2string(val1.GetType()), tag2string(val2.GetType()));
	}

	void DoMinus(StackSlot &val1, const StackSlot &val2) {
		if (val1.IsInt() && val2.IsInt())
			val1.SetIntValue(val1.GetInt() - val2.GetInt());
		else if (val1.IsDouble() && val2.IsDouble())
			val1.SetDoubleValue(val1.GetDouble() - val2.GetDouble());
		else
			ReportError(InvalidArgument, "Error in arguments types in CMinus: %s - %s",
				tag2string(val1.GetType()), tag2string(val2.GetType()));
	}

	inline void DoReturn(bool closure) {
		printf("DoReturn: closure: %d\n", closure ? 1 : 0);
		CallFrame *frame = CallStackPop();
		if (unlikely(!frame))
			return;

		// Copy the result to the right place
		DataStack[FramePointer] = DataStack.top();
		DataStackResize(FramePointer + 1);

		code.SetPosition(LastInstructionPtr = frame->last_pc);
		FramePointer = frame->last_frame;
		closurepointer = frame->last_closure;
	}

	StackSlot DoInt2String(const StackSlot &value) {
		if (unlikely(!value.IsInt())) {
			ReportTagError(value, TInt, "value", NULL);
			return StackSlot::MakeVoid();
		}

		char buf[40] = { 0 };
		snprintf(buf, sizeof(buf), "%d", value.GetInt());
		return mem_pool.AllocateString(buf); // ALLOC
	}

	static std::string double2string(double val, bool force_pt) {
		stringstream ss;
		ss.precision(15);
		ss << val;

		std::string rv = ss.str();
		if (force_pt && rv.find('.') == std::string::npos && rv.find('e') == std::string::npos)
			rv += ".0";
		return rv;
	}

	StackSlot DoDouble2String(const StackSlot &value) {
		double aval;

		if (likely(value.IsDouble())) {
			aval = value.GetDouble();
		}
		else if (value.IsInt()) {
			// Hack: be more robust
			aval = value.GetInt();
		}
		else {
			aval = 0.0;
			ReportTagError(value, TDouble, "value", NULL);
		}

		return mem_pool.AllocateString(parseUtf8(double2string(aval, false))); // ALLOC
	}

#pragma endregion

#pragma region Structs
#ifdef FLOW_COMPACT_STRUCTS
	void StructSlotPack(const StackSlot &str, const StackSlot *src, int start, int count) {
		StructDef &def = StructDefs[str.GetStructId()];
		FlowStructHeader *ph = mem_pool.GetStructPointer(str.GetRawStructPtr(), true);

		for (int i = 0; i < count; i++) {
			const FlowStructFieldDef &fd = def.FieldDefs[start + i];

			if (unlikely(!fd.fn_set(ph->Bytes + fd.offset, src[i]))) {
				ReportTagError(src[i], fd.tag, def.FieldNames[start + i].c_str(), "StructSlotPack");
				return;
			}
		}

		//if (unlikely(ph->GC_Tag))
		//	RegisterWrite(ph, str.GetRawStructPtr());
	}

	void StructSlotUnpack(const StackSlot &str, StackSlot *tgt, int start, int count)
	{
		StructDef &def = StructDefs[str.GetStructId()];
		FlowStructHeader *ph = mem_pool.GetStructPointer(str.GetRawStructPtr(), false);

		for (int i = 0; i < count; i++)
		{
			const FlowStructFieldDef &fd = def.FieldDefs[start + i];
			tgt[i] = fd.fn_get(ph->Bytes + fd.offset, this);
		}
	}
#endif

	void MoveStructToStack(StackSlot str, int count) {
		if (unlikely(MAX_DATA_STACK - DataStack.size() < unsigned(count))) {
			ReportError(DatastackFull, "Cannot push %d items to the data stack.", count);
			return;
		}

		StructSlotUnpack(str, PushPtr(count), 0, count);
	}

	/*
	* Optimization of struct field access by field name by generating lookup tables
	* for each used name. The lookup table index is stored in unnecessary bytes
	* within the instruction.
	*/

	int LookupFieldName(const StackSlot &struct_ref, char const * n, int length, short *idx, StructDef **pdef) {
		StructDef *def = safeVectorPtrAt(StructDefs, struct_ref.GetStructId());

		if (unlikely(def == NULL || def->Name.empty())) {
			ReportError(UnknownStructDefId, "Unknown struct kind: %d", struct_ref.GetStructId());
			return -1;
		}

		*pdef = def;

		int field_id;

		if (idx) {
			int id = *idx;

			// Initially the bytes are zero, so look up or allocate an id for this field name
			if (id == 0) {
				std::string name(n, length);
				id = safeMapAt(FieldRefIds, name, 0);

				if (id == 0) {
					FieldRefNames.push_back(name);
					FieldRefIds[name] = id = FieldRefNames.size();
				}

				*idx = (short)id;
			}

			if (id < 0)
				return -2;
			else if (def->FieldsCount == 0)
				field_id = -1;
			else
			{
				// Initialize lookup table for this struct definition if necessary
				if (def->FieldIds.size() < unsigned(id)) {
					def->FieldIds.resize(FieldRefNames.size(), -1);

					for (size_t i = 0; i < def->FieldNames.size(); i++) {
						int idx = safeMapAt(FieldRefIds, def->FieldNames[i], 0);
						if (idx > 0)
							def->FieldIds[idx - 1] = i;
					}
				}

				field_id = def->FieldIds[id - 1];
			}
		}
		else {
			if (strncmp(n, "structname", length) == 0)
				return -2;
			else
				field_id = def->findField(n, length);
		}

		if (field_id < 0)
			ReportFieldNameError(struct_ref, std::string(n, length).c_str(), "CFieldName");

		return field_id;
	}

	inline RuntimeError DoSetMutable(int i);
	RuntimeError DoSetMutableName(char const *n, int length, short *idx);


	/*
	* Import a struct definition from the relevant opcode.
	*/
	void RegisterStructDef(unsigned id, const StructDef &sd);

#pragma endregion // Structs

	bool PrintData(ostream &out, const StackSlot &slot, int max_depth = -1, int max_count = -1);

	int run_local(int length, char *data);
	int run();

	inline bool IsErrorReported() { return unlikely(LastError != NoError); }

	/*
	* Implements the DeleteNative native, which can be used to immediately free and invalidate native value.
	*/
	bool DeleteNative(const StackSlot &slot) {
		if (unlikely(!slot.IsNative())) {
			ReportTagError(slot, TNative, "DeleteNative()", NULL);
			return false;
		}

		T_NativeValues::iterator it = NativeValues.find(slot.GetNativeValId());

		if (it != NativeValues.end()) {
			FlowNativeObject *obj = it->second->nativeObject();

			if (obj != NULL)
			{
				// FlowNativeObject instances can refuse to be deleted
				if (!obj->flowDestroyObject())
					return false;

				obj->flowFinalizeObject();
			}

			delete it->second;
			NativeValues.erase(it);
			NativeValueBudget++;
		}

		return true;
	}

#pragma region Natives
	NativeFunction *MakeNativeFunction(const char *name, int num_args, bool optional);

	bool EvalFunctionStack(const StackSlot &func, int args_num);
	StackSlot EvalFunctionArr(const StackSlot &func, int args_num, StackSlot *args);
	StackSlot EvalFunction(const StackSlot &func, int args_num, ...);
	inline StackSlot FastEvalFunction(StackSlot *func_and_args, int args_num);
	static StackSlot println(RUNNER_ARGS);
	static StackSlot failWithError(RUNNER_ARGS);
	static StackSlot deleteNative(RUNNER_ARGS);
	static StackSlot mapi(RUNNER_ARGS);
	static StackSlot map(RUNNER_ARGS);
	static StackSlot iter(RUNNER_ARGS);
	static StackSlot iteri(RUNNER_ARGS);
	static StackSlot fold(RUNNER_ARGS);
	static StackSlot foldi(RUNNER_ARGS);
	static StackSlot filter(RUNNER_ARGS);

	static StackSlot elemIndex(ByteCodeRunner*, StackSlot*);
	static StackSlot exists(ByteCodeRunner*, StackSlot*);
	static StackSlot find(ByteCodeRunner*, StackSlot*);

	static StackSlot gc(ByteCodeRunner*, StackSlot*);

	static StackSlot subrange(ByteCodeRunner*, StackSlot*);
	static StackSlot length(ByteCodeRunner*, StackSlot*);
	static StackSlot NativeStrlen(ByteCodeRunner*, StackSlot*);
	static StackSlot strIndexOf(ByteCodeRunner*, StackSlot*);
	static StackSlot strContainsAt(ByteCodeRunner*, StackSlot*);
	static StackSlot strRangeIndexOf(ByteCodeRunner*, StackSlot*);
	static StackSlot substring(ByteCodeRunner*, StackSlot*);
	static StackSlot concat(ByteCodeRunner*, StackSlot*);
	static StackSlot replace(ByteCodeRunner*, StackSlot*);

	static StackSlot s2a(ByteCodeRunner*, StackSlot*);
	static StackSlot string2utf8(ByteCodeRunner*, StackSlot*);

	static StackSlot bitXor(ByteCodeRunner*, StackSlot*);
	static StackSlot bitAnd(ByteCodeRunner*, StackSlot*);
	static StackSlot bitOr(ByteCodeRunner*, StackSlot*);
	static StackSlot bitShl(ByteCodeRunner*, StackSlot*);
	static StackSlot bitUshr(ByteCodeRunner*, StackSlot*);
	static StackSlot bitNot(ByteCodeRunner*, StackSlot*);

	static StackSlot NativeTimestamp(ByteCodeRunner*, StackSlot*);
	static StackSlot Timer(ByteCodeRunner*, StackSlot*);

	static StackSlot random(ByteCodeRunner*, StackSlot*);

	static StackSlot NativeGetTargetName(ByteCodeRunner*, StackSlot*);


	static StackSlot loaderUrl(ByteCodeRunner*, StackSlot*);
	static StackSlot getUrlParameter(ByteCodeRunner*, StackSlot*);
	static StackSlot getAllUrlParameters(ByteCodeRunner*, StackSlot*);


	static StackSlot list2array(ByteCodeRunner*, StackSlot*);
	static StackSlot list2string(ByteCodeRunner*, StackSlot*);
	static StackSlot isArray(ByteCodeRunner*, StackSlot*);
	static StackSlot isSameStructType(ByteCodeRunner*, StackSlot*);
	static StackSlot isSameObj(ByteCodeRunner*, StackSlot*);
	static StackSlot iteriUntil(ByteCodeRunner*, StackSlot*);
	static StackSlot toBinary(ByteCodeRunner*, StackSlot*);
	static StackSlot fromBinary(ByteCodeRunner*, StackSlot*);
	static StackSlot fromBinary2(ByteCodeRunner*, StackSlot*);

    static StackSlot enumFromTo(ByteCodeRunner*,StackSlot*);



	static StackSlot makeTextField(ByteCodeRunner*, StackSlot*);
	static StackSlot setTextAndStyle(ByteCodeRunner*, StackSlot*);

	static StackSlot addEventListener(ByteCodeRunner*, StackSlot*);
	static StackSlot addKeyEventListener(ByteCodeRunner*, StackSlot*);

	static StackSlot setAdvancedText(ByteCodeRunner*, StackSlot*);
	static StackSlot getTextMetrics(ByteCodeRunner*, StackSlot*);
	static StackSlot getTextFieldWidth(ByteCodeRunner*, StackSlot*);
	static StackSlot getTextFieldHeight(ByteCodeRunner*, StackSlot*);

	static StackSlot getContent(ByteCodeRunner*, StackSlot*);
	static StackSlot addChild(ByteCodeRunner*, StackSlot*);
	static StackSlot makeClip(ByteCodeRunner*, StackSlot*);

	static StackSlot enableResize(ByteCodeRunner*, StackSlot*);

	//static StackSlot addMouseWheelEventListener(ByteCodeRunner*, StackSlot*);
	//static StackSlot addFinegrainMouseWheelEventListener(ByteCodeRunner*, StackSlot*);

	//static StackSlot setTextFieldWidth(ByteCodeRunner*, StackSlot*);
	//static StackSlot setTextFieldHeight(ByteCodeRunner*, StackSlot*);

	static StackSlot makeBlur(ByteCodeRunner*, StackSlot*);
	static StackSlot makeBevel(ByteCodeRunner*, StackSlot*);
	static StackSlot makeDropShadow(ByteCodeRunner*, StackSlot*);
	static StackSlot makeGlow(ByteCodeRunner*, StackSlot*);

	static StackSlot addFilters(ByteCodeRunner*, StackSlot*);

	static StackSlot currentClip(ByteCodeRunner*, StackSlot*);

	static StackSlot getStage(ByteCodeRunner*, StackSlot*);
	static StackSlot getStageWidth(ByteCodeRunner*, StackSlot*);
	static StackSlot getStageHeight(ByteCodeRunner*, StackSlot*);

	private:
		int next_cb_id = 0;
		typedef std::map<int, StackSlot> T_Callbacks;
		T_Callbacks callbacks;

		static int addEventCallback(ByteCodeRunner* runner, StackSlot& cb);
		static void callback_onevent(int runner, int cb_id);
		static void callback_onkeyevent(int _runner, int cb_id, int s_ptr, int s_len, int ctrl, int shift, int alt, int meta, int code, int prevent_fn);
//		static void callback(ByteCodeRunner* runner, CallbackType name, int cb_id, ...);
		static StackSlot removeEventListener(ByteCodeRunner*, StackSlot*, void *);
		static StackSlot executeCallback(ByteCodeRunner*, StackSlot*, void *);
		static int strRangeIndexOf(const unicode_char *pstr, const unicode_char *psub, unsigned l1, unsigned l2, unsigned start, unsigned end);

		static StackSlot fast_lookupTree(ByteCodeRunner*, StackSlot*);
		static StackSlot fast_rebalancedTree(ByteCodeRunner*, StackSlot*);
		static StackSlot fast_treeLeftRotation(ByteCodeRunner*, StackSlot*);
		static StackSlot fast_treeRightRotation(ByteCodeRunner*, StackSlot*);
		static StackSlot fast_setTree(ByteCodeRunner*, StackSlot*);

#pragma endregion // Natives


};
