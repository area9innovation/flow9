#include "byterunner.h"
//#include <stdio.h>
//#include <assert.h>
//#include <emscripten.h>
//#include <string.h>
#include "CommonTypes.h"
//#include "mem_pool.h"
//#include "codememory.hpp"
//#include <sstream>
#include "native_program.hpp"
//#include "RunnerMacros.h"
#include "natives.hpp"

using std::stringstream;

const char strdata[] = "M\0O\0O\0";

ByteCodeRunner::ByteCodeRunner() : 
	flow_out(std::cout.rdbuf()), 
	flow_err(std::cerr.rdbuf()) {

#define STRUCT(name,size) KnownStructTable[#name] = T_KnownStructTableItem(& name ## StructId, size);
	FLOW_KNOWN_STRUCTS
#undef STRUCT

}

void ByteCodeRunner::RegisterStructDef(unsigned id, const StructDef &sd) {
	if (unsigned(id) >= StructDefs.size()) {
		unsigned csz = StructDefs.size();

		StructDefs.resize(id + 1);
		StructSizes.resize(id + 1);

		memset(&StructSizes[csz], 0, sizeof(unsigned)*(StructSizes.size() - csz));
	}

	StructDefs[id] = sd;
	StructDefs[id].StructId = id;
	StructSizes[id] = sd.FieldsCount;
	StructNameIds[sd.Name] = id;

#ifdef FLOW_COMPACT_STRUCTS
	StructDef &def = StructDefs[id];

	if (!def.FieldDefs && def.FieldsCount > 0) {
		FlowStructFieldDef *fdefs = new FlowStructFieldDef[def.FieldsCount];
		AutoStructFields.push_back(fdefs);

		std::vector<FlowStructFieldGCDef> gcdefs;
		int offset = 4;

		static const FlowStructFieldDef def_bool = FLOW_FIELD_DEF(bool, 0);
		static const FlowStructFieldDef def_int = FLOW_FIELD_DEF(int, 0);
		static const FlowStructFieldDef def_double = FLOW_FIELD_DEF(double, 0);
		static const FlowStructFieldDef def_string = FLOW_FIELD_DEF(string, 0);
		static const FlowStructFieldGCDef gcdef_string = FLOW_FIELD_GC_DEF(string, 0);
		static const FlowStructFieldDef def_array = FLOW_FIELD_DEF(array, 0);
		static const FlowStructFieldGCDef gcdef_array = FLOW_FIELD_GC_DEF(array, 0);
		static const FlowStructFieldDef def_ref = FLOW_FIELD_DEF(ref, 0);
		static const FlowStructFieldGCDef gcdef_ref = FLOW_FIELD_GC_DEF(ref, 0);
		static const FlowStructFieldDef def_struct = FLOW_FIELD_DEF(struct, 0);
		static const FlowStructFieldGCDef gcdef_struct = FLOW_FIELD_GC_DEF(struct, 0);
		static const FlowStructFieldDef def_slot = FLOW_FIELD_DEF(slot, 0);
		static const FlowStructFieldGCDef gcdef_slot = FLOW_FIELD_GC_DEF(slot, 0);

		for (int i = 0; i < def.FieldsCount; i++)
		{
			fdefs[i].offset = offset;

			bool has_gc = true;
			FlowStructFieldGCDef gcdef;
			int size = 4;

			switch (def.FieldTypes[i][0]) {
			case FTBool:
				fdefs[i] = def_bool;
				has_gc = false;
				break;
			case FTInt:
				fdefs[i] = def_int;
				has_gc = false;
				break;
			case FTDouble:
				size = sizeof(double);
				fdefs[i] = def_double;
				has_gc = false;
				break;
			case FTString:
				size = sizeof(FlowStructString);
				fdefs[i] = def_string;
				gcdef = gcdef_string;
				break;
			case FTArray:
			case FTTypedArray:
				size = sizeof(FlowStructArray);
				fdefs[i] = def_array;
				gcdef = gcdef_array;
				break;
			case FTRefTo:
			case FTTypedRefTo:
				size = sizeof(FlowStructRef);
				fdefs[i] = def_ref;
				gcdef = gcdef_ref;
				break;
			case FTStruct:
			case FTTypedStruct:
				size = sizeof(FlowPtr);
				fdefs[i] = def_struct;
				gcdef = gcdef_struct;
				break;
			default:
				size = STACK_SLOT_SIZE;
				fdefs[i] = def_slot;
				gcdef = gcdef_slot;
			}

			fdefs[i].offset = offset;
			gcdef.offset = offset;
			offset += size;

			if (has_gc)
				gcdefs.push_back(gcdef);
		}

		def.FieldDefs = fdefs;
		def.GCFieldCount = gcdefs.size();
		def.ByteSize = offset;

		if (!gcdefs.empty())
		{
			FlowStructFieldGCDef *pgcdefs = new FlowStructFieldGCDef[gcdefs.size()];
			memcpy(pgcdefs, gcdefs.data(), sizeof(FlowStructFieldGCDef)*gcdefs.size());
			def.FieldGCDefs = pgcdefs;
			AutoStructGCFields.push_back(pgcdefs);
		}
	}
#endif

	// Save some notable structures directly
	T_KnownStructTable::iterator it = KnownStructTable.find(sd.Name);
	if (it != KnownStructTable.end())
		*it->second.first = id;
}

/*
* Deep comparison.
*/
int ByteCodeRunner::Compare(ByteCodeRunner *self, const StackSlot &slot1, const StackSlot &slot2) {
	DataTag t1 = slot1.GetType();
	DataTag t2 = slot2.GetType();

	if (unlikely(t1 != t2))
	{
		/*if ((t1 == TClosurePointer || t1 == TCodePointer || t1 == TNativeFn) &&
		(t2 == TClosurePointer || t2 == TCodePointer || t2 == TNativeFn))*/

		// It is legal to equality compare different types, but they are never identical!
		return CompareInt(t1, t2);
	}

#ifdef FLOW_INSTRUCTION_PROFILING
	// This is a complicated recursive function, so
	// expose its cost in the profile counter
	if (unlikely(++self->InstructionCount == self->ProfileICBarrier))
		self->ProfileICEvent(true);
#endif

	switch (t1) {
	case TInt: {
		int i1 = slot1.GetInt();
		int i2 = slot2.GetInt();
		return CompareInt(i1, i2);
	}
	case TDouble: {
		FlowDouble d1 = slot1.GetDouble();
		FlowDouble d2 = slot2.GetDouble();
		if (d1 == d2) return 0;
		else if (d1 < d2) return -1;
		else return 1;
	}
	case TBool: {
		char c1 = (slot1.GetBool() ? 1 : 0);
		char c2 = (slot2.GetBool() ? 1 : 0);
		return CompareInt(c1, c2);
	}
	case TString:
		return self->CompareFlowString(
			self->GetStringAddr(slot1), self->GetStringSize(slot1),
			self->GetStringAddr(slot2), self->GetStringSize(slot2)
		);

	case TArray: {
		if (slot1.GetInternalArrayPtr() == slot2.GetInternalArrayPtr())
			return 0;

		int l1 = self->GetArraySize(slot1);
		int l2 = self->GetArraySize(slot2);
		unsigned m = (unsigned)std::min(l1, l2);

		if (m != 0) {
			const StackSlot *arr1 = self->GetArraySlotPtr(slot1, m);
			const StackSlot *arr2 = self->GetArraySlotPtr(slot2, m);

			while (likely(m-- != 0))
			{
				int c = Compare(self, *arr1++, *arr2++);
				if (c != 0)
					return c;
			}
		}

		return CompareInt(l1, l2);
	}
	case TStruct: {
		// Test types of structs
		if (slot1.GetStructId() != slot2.GetStructId())
		{
#if 1
			if (unlikely(unsigned(slot1.GetStructId()) >= self->StructSizes.size()) ||
				unlikely(unsigned(slot2.GetStructId()) >= self->StructSizes.size()))
			{
				self->ReportError(InvalidArgument, "Invalid struct id in Compare");
				return 0;
			}

			return (self->StructDefs[slot1.GetStructId()].CompareIdx <
				self->StructDefs[slot2.GetStructId()].CompareIdx) ? -1 : 1;
#else
			return (slot1.IntValue2 < slot2.IntValue2) ? -1 : 1;
#endif
		}

		if (slot1.GetRawStructPtr() == slot2.GetRawStructPtr())
			return 0;

		int m = self->GetStructSize(slot1);
		if (unlikely(m < 0))
			self->ReportError(InvalidArgument, "Invalid struct type in compare: %d", slot1.GetStructId());

		if (m == 0) return 0;

#ifdef FLOW_COMPACT_STRUCTS
		StructDef &def = self->StructDefs[slot1.GetStructId()];
		uint8_t *p1 = (uint8_t*)mem_pool.GetRawPointer(slot1.GetRawStructPtr(), def.ByteSize, false);
		uint8_t *p2 = (uint8_t*)mem_pool.GetRawPointer(slot2.GetRawStructPtr(), def.ByteSize, false);

		for (int i = 0; likely(i < m); i++)
		{
			const FlowStructFieldDef &fd = def.FieldDefs[i];
			int c = Compare(self, fd.fn_get(p1 + fd.offset, self), fd.fn_get(p2 + fd.offset, self));
			if (c != 0)
				return c;
		}
#else
		StackSlot *arr1 = (StackSlot*)Memory.GetRawPointer(slot1.GetRawStructPtr(), m*STACK_SLOT_SIZE, false);
		StackSlot *arr2 = (StackSlot*)Memory.GetRawPointer(slot2.GetRawStructPtr(), m*STACK_SLOT_SIZE, false);

		while (likely(m-- > 0))
		{
			int c = Compare(self, *arr1++, *arr2++);
			if (c != 0)
				return c;
		}
#endif

		return 0;
	}
	case TRefTo: {
		return CompareInt(self->GetRefId(slot1), self->GetRefId(slot2));
	}
	case TClosurePointer: {
		return CompareInt(FlowPtrToInt(slot1.GetClosureDataPtr()), FlowPtrToInt(slot2.GetClosureDataPtr()));
	}
	case TCodePointer: {
		return CompareInt(FlowPtrToInt(slot1.GetCodePtr()), FlowPtrToInt(slot2.GetCodePtr()));
	}
	case TNative: {
		return CompareInt(slot1.GetNativeValId(), slot2.GetNativeValId());
	}
	case TCapturedFrame: {
		int c = CompareInt(FlowPtrToInt(slot1.GetCapturedFramePtr()), FlowPtrToInt(slot2.GetCapturedFramePtr()));
		if (c != 0) return c;
		return CompareInt(slot1.slot_private.AuxValue, slot2.slot_private.AuxValue);
	}
	case TNativeFn: {
		int c = CompareInt(self->GetNativeFnId(slot1), self->GetNativeFnId(slot2));
		if (c != 0) return c;
		c = CompareInt(slot1.GetSign(), slot2.GetSign());
		if (c != 0 || !slot1.GetSign()) return c;
		return CompareInt(FlowPtrToInt(slot1.GetNativeFnDataPtr()), FlowPtrToInt(slot2.GetNativeFnDataPtr()));
	}
	case TVoid: {
		return 0;
	}
	default: {
		// TODO: Implement for union
		self->ReportError(InvalidArgument, "Cannot compare tag 0x%02x", t1);
		return 0;
	}
	}
}

/*
* Shallow comparison - only compares non-slot memory data for strings.
*/
bool ByteCodeRunner::CompareByRef(const StackSlot &slot1, const StackSlot &slot2) {
	if (slot1.GetType() != slot2.GetType())
		return false;

	switch (slot1.GetType()) {
	case TInt:
		return slot1.GetInt() == slot2.GetInt();
	case TNative:
		return slot1.GetNativeValId() == slot2.GetNativeValId();
	case TDouble:
		return slot1.GetDouble() == slot2.GetDouble();
	case TBool:
		return slot1.GetBool() == slot2.GetBool();
	case TString:
		return CompareFlowString(GetStringAddr(slot1), GetStringSize(slot1), GetStringAddr(slot2), GetStringSize(slot2)) == 0;

	case TCodePointer:
		return slot1.GetCodePtr() == slot2.GetCodePtr();

	case TArray:
	case TRefTo:
	case TStruct:
	case TNativeFn:
	case TClosurePointer:
	case TCapturedFrame:
		return slot1.slot_private.PtrValue == slot2.slot_private.PtrValue && slot1.slot_private.AuxValue == slot2.slot_private.AuxValue;

	case TVoid:
		return true;

	default:
		// TODO: Implement for union
		ReportError(InvalidArgument, "Cannot compare tag 0x%02x", slot1.GetType());
		return false;
	}
}

NativeFunction *ByteCodeRunner::MakeNativeFunction(const char *name, int num_args, bool optional) {
	//// Try external hosts from latest to oldest
	//T_NativeHosts::reverse_iterator it;;
	//for (it = NativeHosts.rbegin(); it != NativeHosts.rend(); ++it) {
	//	NativeFunction *nf = (*it)->MakeNativeFunction(name, num_args);
	//	if (nf != NULL)
	//		return nf;
	//}

#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "Native."

	TRY_USE_NATIVE_STATIC(ByteCodeRunner, println, 1);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, failWithError, 1);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, deleteNative, 1);

	TRY_USE_NATIVE_STATIC(ByteCodeRunner, mapi, 2);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, map, 2);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, iter, 2);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, iteri, 2);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, fold, 3);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, foldi, 3);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, filter, 2);

	// optional
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, elemIndex, 3);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, exists, 2);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, find, 2);

	TRY_USE_NATIVE_STATIC(ByteCodeRunner, gc, 0);

	TRY_USE_NATIVE_STATIC(ByteCodeRunner, subrange, 3);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, length, 1);
	TRY_USE_NATIVE_STATIC_NAME(ByteCodeRunner, NativeStrlen, "strlen", 1);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, strIndexOf, 2);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, strContainsAt, 3);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, strRangeIndexOf, 4);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, substring, 3);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, concat, 2);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, replace, 3);

	TRY_USE_NATIVE_STATIC(ByteCodeRunner, s2a, 1);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, string2utf8, 1);

	TRY_USE_NATIVE_STATIC(ByteCodeRunner, bitXor, 2);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, bitAnd, 2);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, bitOr, 2);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, bitUshr, 2);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, bitShl, 2);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, bitNot, 1);

	TRY_USE_NATIVE_STATIC_NAME(ByteCodeRunner, NativeTimestamp, "timestamp", 0);
	TRY_USE_NATIVE_STATIC_NAME(ByteCodeRunner, Timer, "timer", 2);

	TRY_USE_NATIVE_STATIC(ByteCodeRunner, random, 0);

	TRY_USE_NATIVE_STATIC_NAME(ByteCodeRunner, NativeGetTargetName, "getTargetName", 0);

	TRY_USE_NATIVE_STATIC(ByteCodeRunner, loaderUrl, 0);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, getUrlParameter, 1);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, getAllUrlParameters, 0);


	TRY_USE_NATIVE_STATIC(ByteCodeRunner, list2array, 1);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, list2string, 1);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, isArray, 1);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, isSameStructType, 2);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, isSameObj, 2);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, iteriUntil, 2);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, toBinary, 1);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, fromBinary, 3);
	TRY_USE_NATIVE_STATIC_NAME(ByteCodeRunner, fromBinary2, "fromBinary", 2);

	TRY_USE_NATIVE_STATIC(ByteCodeRunner, enumFromTo, 2);

	TRY_USE_NATIVE_STATIC(ByteCodeRunner, fast_lookupTree, 2);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, fast_setTree, 3);

#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "RenderSupport."

	TRY_USE_NATIVE_STATIC(ByteCodeRunner, makeTextField, 1);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, setTextAndStyle, 12);

	TRY_USE_NATIVE_STATIC(ByteCodeRunner, addEventListener, 3);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, addKeyEventListener, 3);

	TRY_USE_NATIVE_STATIC(ByteCodeRunner, setAdvancedText, 4);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, getTextMetrics, 1);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, getTextFieldWidth, 1);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, getTextFieldHeight, 1);

	TRY_USE_NATIVE_STATIC(ByteCodeRunner, getStage, 0);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, getStageWidth, 0);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, getStageHeight, 0);


	TRY_USE_NATIVE_STATIC(ByteCodeRunner, getContent, 1);

	TRY_USE_NATIVE_STATIC(ByteCodeRunner, enableResize, 0);

	TRY_USE_NATIVE_STATIC(ByteCodeRunner, addChild, 2);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, makeClip, 0);

	//TRY_USE_NATIVE_STATIC(ByteCodeRunner, addMouseWheelEventListener, 2);
	//TRY_USE_NATIVE_STATIC(ByteCodeRunner, addFinegrainMouseWheelEventListener, 2);

	//TRY_USE_NATIVE_STATIC(ByteCodeRunner, setTextFieldWidth, 2);
	//TRY_USE_NATIVE_STATIC(ByteCodeRunner, setTextFieldHeight, 2);

	TRY_USE_NATIVE_STATIC(ByteCodeRunner, makeBlur, 2);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, makeBevel, 9);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, makeDropShadow, 7);
	TRY_USE_NATIVE_STATIC(ByteCodeRunner, makeGlow, 5);

	TRY_USE_NATIVE_STATIC(ByteCodeRunner, addFilters, 2);

	TRY_USE_NATIVE_STATIC(ByteCodeRunner, currentClip, 0);

	//if (optional)
	//	return NULL;

	// TODO: restrict
#ifdef DEBUG_FLOW
	flow_err << "Substituting a stub for: " << name << " (" << num_args << " args)" << endl;
#endif
	printf("making a stub for: %s\n", name);
	return new StubNative(strdup(name), num_args);
}

//bool PrintData(ostream &out, const StackSlot &slot, int max_depth = -1, int max_count = -1);

inline NativeFunction *NativeFunction::get_self(ByteCodeRunner *runner) {
	return runner->CurNativeFn;
}

StackSlot StubNative::thunk(ByteCodeRunner *runner, StackSlot*) {
	NativeFunction *self = get_self(runner);
	if (runner->NotifyStubs)
		runner->flow_err << "Stub native function called: " << self->name() << endl;
	RETVOID;
}

StackSlot NativeClosure::thunk(ByteCodeRunner *runner, StackSlot *args) {
	NativeClosure *self = (NativeClosure*)get_self(runner);
	return (self->Clos)(runner, args, self->data);
}

int StructDef::findField(const char *name, int length) {
	for (int i = 0; i < FieldsCount; ++i) {
		if (strncmp(FieldNames[i].c_str(), name, length) == 0)
			return i;
	}

	return -1;
}


const char *OpCode2String(OpCode opcode) {
	switch (opcode) {
	case CVoid: return "Void";
	case CBool: return "Bool";
	case CInt: return "Int";
	case CDouble: return "Double";
	case CString: return "String";
	case CArray: return "Array";
	case CStruct: return "Struct";
	case CSetLocal: return "SetLocal";
	case CGetLocal: return "GetLocal";
	case CGetGlobal: return "GetGlobal";
	case CReturn: return "Return";
	case CPop: return "Pop";
	case CGoto: return "Goto";
	case CCodePointer: return "CodePointer";
	case CCall: return "Call";
	case CNotImplemented: return "NotImplemented";
	case CIfFalse: return "IfFalse";
	case CNot: return "Not";
	case CNegate: return "Negate";
	case CMultiply:  return "Multiply";
	case CDivide: return "Divide";
	case CModulo: return "Modulo";
	case CPlus: return "Plus";
	case CMinus: return "Minus";
	case CEqual: return "Equal";
	case CLessThan: return "LessThan";
	case CLessEqual: return "LessEqual";
	case CNativeFn: return "NativeFn";
	case COptionalNativeFn: return "OptionalNativeFn";
	case CArrayGet: return "ArrayGet";
	case CReserveLocals: return "ReserveLocals";
	case CRefTo: return "RefTo";
	case CDeref: return "Deref";
	case CSetRef: return "SetRef";
	case CInt2Double: return "Int2Double";
	case CInt2String: return "Int2String";
	case CDouble2Int: return "Double2Int";
	case CDouble2String: return "Double2String";
	case CField: return "Field";
	case CFieldName: return "FieldName";
	case CStructDef: return "StructDef";
	case CGetFreeVar:return "GetFreeVar";
	case CDebugInfo: return "DebugInfo";
	case CClosureReturn: return "ClosureReturn";
	case CClosurePointer: return "ClosurePointer";
	case CSwitch: return "Switch";
	case CUncaughtSwitch: return "UncaughtSwitch";
	case CTailCall: return "TailCall";
	case CPlusString: return "PlusString";
	case CPlusInt: return "PlusInt";
	case CMinusInt: return "MinusInt";
	case CNegateInt: return "NegateInt";
	case CMultiplyInt: return "MultiplyInt";
	case CDivideInt: return "DivideInt";
	case CModuloInt: return "ModuloInt";
	case CSimpleSwitch: return "SimpleSwitch";
	case CWString: return "WString";
	case CLast: return "Last";
	case CBreakpoint: return "<BREAKPOINT>";
	case CTypedArray: return "TypedArray";
	case CTypedStruct: return "TypedStruct";
	case CTypedRefTo: return "TypedRefTo";
	case CSetMutable: return "SetMutable";
	case CSetMutableName: return "SetMutableName";
	case CCodeCoverageTrap: return "<COVERAGE-TRAP>";
	}

	return "Unknown";
}

const char * tag2string(int tag) {
	switch (tag) {
	case TVoid: return "void";
	case TBool: return "bool";
	case TInt: return "int";
	case TDouble: return "double";
	case TString: return "string";
	case TArray: return "array";
	case TStruct: return "struct";
	case TCodePointer: return "codepointer";
	case TNativeFn: return "nativefn";
	case TRefTo: return "ref";
	case TNative: return "native";
	case TClosurePointer: return "closure";
	case TCapturedFrame: return "native/frame";
	}
	return "Unknown Tag";
}

/*
* Recursively prints data. As a hack, negative max_depth is used to mean no explicit limit.
*/
bool ByteCodeRunner::PrintData(ostream &out, const StackSlot &slot, int max_depth, int max_count) {
	DataTag tag = slot.GetType();

	if (unlikely(max_depth < -8000)) {
		out << "... <TOO DEEP>";
		return false;
	}

	bool ok = true;

	switch (tag) {
	case TVoid:
		out << "{}";
		break;
	case TBool:
		out << (slot.GetBool() ? "true" : "false");
		break;
	case TInt:
		out << slot.GetInt();
		break;
	case TDouble:
		out << double2string(slot.GetDouble(), true);
		break;

	case TString: {
		unicode_string tmp = GetString(slot);
		if (max_count > 0 && tmp.size() > unsigned(5 * max_count))
			tmp = tmp.substr(0, max_count * 5) + parseUtf8("...");
		printQuotedString(out, encodeUtf8(tmp));
		break;
	}
	case TArray: {
		int len = GetArraySize(slot);

		if (max_depth == 0 && len > 0) {
			out << "[...]";
			return ok;
		}

		out << "[";

		for (int i = 0; i < len && ok; ++i) {
			if (i > 0)
				out << ", ";

			if (max_count >= 0 && i == max_count) {
				out << "...";
				break;
			}

			ok = PrintData(out, GetArraySlot(slot, i), max_depth - 1, max_count);
		}

		out << "]";
		break;
	}
	case TStruct:
	{
		int id = slot.GetStructId();
		StructDef *def = safeVectorPtrAt(StructDefs, id);
		int len = GetStructSize(slot);

		out << def->Name << "(";

		if (def->Name == "DLink")
		{
			// Avoid infinite recursion from cyclical links
			max_depth = 0;
		}

		if (max_depth == 0 && len > 0)
		{
			out << "...)";
			return ok;
		}

		for (int i = 0; i < len && ok; ++i)
		{
			if (i > 0)
				out << ", ";

			const StackSlot &value = GetStructSlot(slot, i);
			ok = PrintData(out, value, max_depth - 1, max_count);

			if (def->FieldTypes[i][0] == FTDouble && value.IsInt()) {
				// We need a double, but get an int!
				out << ".0";
			}
		}

		out << ")";
		break;
	}
	case TCapturedFrame:
		out << "<frame: " << AddressToFunction(slot.GetCapturedFramePtr()) << ">";
		break;
	case TCodePointer:
		out << "<fn: " << AddressToFunction(slot.GetCodePtr()) << ">";
		break;
	case TRefTo:
		if (max_depth >= 0)
		{
			out << "<ref #" << GetRefId(slot) << ": ";
			if (max_depth > 0)
				ok = PrintData(out, GetRefTarget(slot), max_depth - 1, max_count);
			else
				out << "...";
			out << ">";
		}
		else
		{
			out << "ref ";
			ok = PrintData(out, GetRefTarget(slot), max_depth - 1, max_count);
		}
		break;
	case TNative:
	{
		//AbstractNativeValue *val = safeMapAt(NativeValues, slot.GetNativeValId(), NULL);
		//out << "<native " << slot.GetNativeValId() << ": " << (val ? val->type()->name() : "?invalid?") << ">";
		out << "<native> " << slot.GetNativeValId() ;
		break;
	}
	case TNativeFn:
	{
		//NativeFunction *fn = lookupNativeFn(GetNativeFnId(slot));
		//const char *name = fn ? fn->name() : "?";
		//out << "<native fn " << GetNativeFnId(slot) << ": " << name << ">";
		break;
	}
	case TClosurePointer:
		out << "<closure 0x" << std::hex << FlowPtrToInt(slot.GetClosureDataPtr()) << std::dec
			<< ": " << AddressToFunction(GetCodePointer(slot)) << ">";
		break;
	default:
		out << "Unknown data-type tag 0x" << std::hex << tag << std::dec;
	}

	return ok;
}

#define RUNNER_RefArgs1(arg0) \
    const StackSlot &arg0 = GetStackSlotRef(0);
#define RUNNER_RefArgs2(arg1, arg0) \
    const StackSlot &arg1 = GetStackSlotRef(1); \
    const StackSlot &arg0 = GetStackSlotRef(0);

// Like above, but the first argument is made writable
#define RUNNER_RefArgsRet1(rv_arg0) \
    StackSlot &rv_arg0 = *GetStackSlotPtr(0);
#define RUNNER_RefArgsRet2(rv_arg1, arg0) \
    StackSlot &rv_arg1 = *GetStackSlotPtr(1); \
    const StackSlot &arg0 = GetStackSlotRef(0);

#undef RUNNER_CheckTag
#define RUNNER_CheckTag(tag, slot) \
    if (unlikely(!slot.Is##tag())) { \
        ReportTagError(slot, tag, #slot, NULL); \
        return LastError; \
    }

#undef RUNNER_CheckTag2
#define RUNNER_CheckTag2(tag, slot1, slot2) \
    RUNNER_CheckTag(tag, slot1) \
    RUNNER_CheckTag(tag, slot2)

int ByteCodeRunner::run_local(int length, char *data) {
	printf("run_bytecod\n");
//	printf("run_bytecode: %d: %s\n", length, data);

	//FlowPtr p = mem_pool.allocate(mem_pool.align(length, mem_pool::align_value));
	//memcpy((void*)((char*)mem_pool.data_ptr() + p), data, length);

	LastError = NoError;
	closurepointer = MakeFlowPtr(0);
	code = CodeMemory(data, 0, length);
//	code = CodeMemory((char*)mem_pool.data_ptr() + p, 0, length);

	NativeReturnInsn = code.GetLastAddr() - 1;

	/* NOTE: Instruction implementations in this function
	use some low-level optimizations that may be
	invalidated by Allocate. Therefore, all lines
	that may result in it being called must be
	commented as // ALLOC

	Namely, the code assumes that between potential
	allocation (and therefore gc) sites, it can do
	whatever it pleases with pointers to flow memory.
	This obviously requires precise understanding
	of the location of said sites. For example, see
	the implementation of CPlus for strings.
	*/

	FlowPtr LastInstructionPtr = 0;
	printf("code.GetLastAddr(): %d\n", code.GetLastAddr());

	return run();
}

int ByteCodeRunner::run() {

	while (likely(LastError == NoError)) {
		FlowPtr cur_insn = code.GetPosition();

		if (likely(cur_insn < code.GetLastAddr()))
			LastInstructionPtr = cur_insn;
		else {
			//				ReportError(InvalidCall, "Invalid instruction address: %08x", FlowPtrToInt(cur_insn));
			return LastError;
		}

		OpCode opcode = (OpCode)code.ReadByte();

		if (opcode != CDebugInfo)
			debug_log(printf("opcode: %02x (%s), cur_insn: %d (%x)\n", opcode, OpCode2String(opcode), cur_insn, cur_insn));

		switch (opcode) {
		case CTailCall:	{
			int locals = code.ReadInt31_16();
			if (doTailCall(locals))
				break;
			// fall through
		}
		case CCall:
			doCall(); // CALL->ALLOC
			break;
		case CLast:
			debug_log(printf("CLast. Datastack size: %d, Calstack size: %d\n", DataStack.size(), CallStack.size()));
			return LastError;
		case CUncaughtSwitch:
			ReportError(UncaughtSwitch, "Unexpected case in switch.");
			break;
		case CVoid:
			PushVoid();
			break;
		case CBool:
			PushBool(code.ReadByte());
			break;
		case CInt: {
			int v = code.ReadInt32();
			PushInt(v);
			break;
		}
		case CDouble:
			PushDouble(code.ReadDouble());
			break;
		case CString: {
			int len = code.ReadInt31();
			debug_log(printf("CString len: %d\n", len));
			if (len) {
				Push(parseUtf8(code.ReadString(len)));
				PrintData(flow_out, DataStack.top()); flow_out << endl;
			} else {
				Push(StackSlot::MakeEmptyString());
			}
			break;
		}
		case CWString: {
			int len = code.ReadByte();
			debug_log(printf("CWString len: %d (ptr: %d): ", len, code.GetPosition()));
			if (len) {
				StackSlot str;
				unicode_char *tmp = mem_pool.AllocateStringBuffer(&str, len); // ALLOC
				memcpy(tmp, code.GetBytes(len * FLOW_CHAR_SIZE), len* FLOW_CHAR_SIZE);

				//StackSlot str;
				//*mem_pool.AllocateStringRef(&str, len) = code.GetPosition();
				Push(str);
				PrintData(flow_out, str); 
//				code.SetPosition(code.GetPosition() + len * 2); // Skip string
			} else {
				Push(StackSlot::MakeEmptyString());
			}
			flow_out << endl;
			break;
		}
		case CArray: {
			int len = code.ReadInt31_16();
//			printf("CArray len: %d\n", len);
			if (len) {
				if (unlikely(DataStack.size() < unsigned(len))) {
					StackError(DatastackFull, false);
					break;
				}

				StackSlot arr = mem_pool.AllocateUninitializedArray(len); // ALLOC
				memcpy(mem_pool.GetArrayWritePtr(arr, len), PopPtr(len), len * STACK_SLOT_SIZE);
				Push(arr);
			} else {
				Push(StackSlot::MakeEmptyArray());
			}
			break;
		}
		case CStruct: {
			int id = code.ReadInt31_16();
			StructDef *def = safeVectorPtrAt(StructDefs, id);
			if (unlikely(def == NULL || def->Name.empty())) {
				ReportError(UnknownStructDefId, "Unknown struct kind: %d", id);
				break;
			}
			debug_log(printf("CStruct id: %d (%s)\n", id, def->Name.c_str()));
			// Now make an array out of all of this
			StackSlot rv = mem_pool.AllocateRawStruct(*def, false);
			StructSlotPack(rv, PopPtr(def->FieldsCount), 0, def->FieldsCount);
			Push(rv);
			break;
		}
		case CArrayGet: {
			RUNNER_RefArgsRet2(array, index);
			RUNNER_CheckTag(TArray, array);
			RUNNER_CheckTag(TInt, index);
			int len = GetArraySize(array);
			if (unlikely(index.GetInt() < 0 || index.GetInt() >= len)) {
				PrintDataStack();
				ReportError(InvalidArgument, "Array index out of bounds: %d", index.GetInt());
			}
			array = GetArraySlot(array, index.GetInt());
			DiscardStackSlots(1);
			break;
		}
		case CGoto: {
			int offset = code.ReadInt31(); // TO DO error
//			printf("CGoto: offset: %d (%x)\n", offset, offset);
			code.SetPosition(code.GetPosition() + offset);
			break;
		}
		case CCodePointer: {
			int offset = code.ReadInt31();
			debug_log(printf("CCodePointer: offset: %d (%x)\n", offset, offset));
//			printf("position after: %d\n", code.GetPosition());
			Push(StackSlot::MakeCodePointer(code.GetPosition() + offset));
			break;
		}
		case CReturn: {
			DoReturn(false); // RETURN
			break;
		}
		case CClosureReturn: {
			DoReturn(true); // RETURN
			break;
		}
		case CNativeFn: {
			// Push a native pointer to code here on the stack
			int args = code.ReadInt31();
			std::string fn = code.ReadString();

			NativeFunction *native_fn = MakeNativeFunction(fn.c_str(), args, false);

			if (unlikely(native_fn == NULL)) {
				ReportError(UnknownNativeName, "Unknown native: \"%s\"", fn.c_str());
				break;
			}

			StackSlot s = AllocNativeFn(native_fn, LastInstructionPtr);
			Push(s);

//			printf("CNativeFn name: %s, args: %d, id: %d\n", fn.c_str(), args, GetNativeFnId(s));
			break;
		}
		case COptionalNativeFn: {
			RUNNER_RefArgsRet1(curval);
			int args = code.ReadInt31();
			std::string fn = code.ReadString();
			debug_log(printf("COptionalNativeFn name: %s, args: %d\n", fn.c_str(), args));

			NativeFunction *native_fn = MakeNativeFunction(fn.c_str(), args, true);
			if (native_fn)
				curval = AllocNativeFn(native_fn, LastInstructionPtr);
			break;
		}
		case CSetLocal: {
			int slot = code.ReadInt31_16();
//			printf("CSetLocal id: %d\n", slot);
			DataStack[FramePointer + slot] = DataStack.top();
			DiscardStackSlots(1);
			break;
		}
		case CPlus: {
//			printf("CPlus:\n");
			RUNNER_RefArgsRet2(val1, val2);
			DoPlus(val1, val2);
			DiscardStackSlots(1);
			break;
		}
		case CPlusInt: {
//			printf("CPlusInt:\n");
			RUNNER_RefArgsRet2(val1, val2);
			RUNNER_CheckTag2(TInt, val1, val2);
			debug_log(printf("CPlusInt: v1: %d; v2: %d\n", val1.GetInt(), val2.GetInt()));
			val1.SetIntValue(val1.GetInt() + val2.GetInt());
			DiscardStackSlots(1);
			break;
		}
		case CPlusString: {
//			printf("CPlusString:\n");
			RUNNER_RefArgsRet2(val1, val2);
			RUNNER_CheckTag2(TString, val1, val2);
			DoPlusString(val1, val2);
			DiscardStackSlots(1);
			break;
		}
		case CMinus: {
//			printf("CMinus:\n");
			RUNNER_RefArgsRet2(val1, val2);
			DoMinus(val1, val2);
			DiscardStackSlots(1);
			break;
		}
		case CMinusInt: {
//			printf("CMinusInt:\n");
			RUNNER_RefArgsRet2(val1, val2);
			RUNNER_CheckTag2(TInt, val1, val2);
			val1.SetIntValue(val1.GetInt() - val2.GetInt());
			DiscardStackSlots(1);
			break;
		}
		case CMultiply: {
//			printf("CMultiply:\n");
			RUNNER_RefArgsRet2(val1, val2);
			DoMultiply(val1, val2);
			DiscardStackSlots(1);
			break;
		}
		case CMultiplyInt: {
//			printf("CMultiplyInt:\n");
			RUNNER_RefArgsRet2(val1, val2);
			RUNNER_CheckTag2(TInt, val1, val2);
			val1.SetIntValue(val1.GetInt() * val2.GetInt());
			DiscardStackSlots(1);
			break;
		}
		case CDivide: {
//			printf("CDivide:\n");
			RUNNER_RefArgsRet2(val1, val2);
			DoDivide(val1, val2);
			DiscardStackSlots(1);
			break;
		}
		case CDivideInt: {
//			printf("CDivideInt:\n");
			RUNNER_RefArgsRet2(val1, val2);
			RUNNER_CheckTag2(TInt, val1, val2);
			if (unlikely(val2.GetInt() == 0)) {
				ReportError(InvalidArgument, "Integer division by zero.");
				return LastError;
			}
			val1.SetIntValue(val1.GetInt() / val2.GetInt());
			DiscardStackSlots(1);
			break;
		}
		case CModulo: {
//			printf("CModulo:\n");
			RUNNER_RefArgsRet2(val1, val2);
			DoModulo(val1, val2);
			DiscardStackSlots(1);
			break;
		}
		case CModuloInt: {
//			printf("CModuloInt:\n");
			RUNNER_RefArgsRet2(val1, val2);
			RUNNER_CheckTag2(TInt, val1, val2);
			if (unlikely(val2.GetInt() == 0)) {
				ReportError(InvalidArgument, "Integer division by zero in CModuloInt.");
				return LastError;
			}
			val1.SetIntValue(val1.GetInt() % val2.GetInt());
			DiscardStackSlots(1);
			break;
		}
		case CNegate: {
//			printf("CNegate:\n");
			RUNNER_RefArgsRet1(val);
			DoNegate(val);
			break;
		}
		case CNegateInt: {
//			printf("CNegateInt:\n");
			RUNNER_RefArgsRet1(val1);
			RUNNER_CheckTag(TInt, val1);
			val1.SetIntValue(-val1.GetInt());
			break;
		}
		case CEqual: {
//			printf("CEqual:\n");
			DoEqual();
			break;
		}
		case CLessThan: {
//			printf("CLessThan:\n");
			DoLessThan();
			break;
		}
		case CLessEqual: {
//			printf("CLessEqual:\n");
			DoLessEqual();
			break;
		}
		case CNot: {
//			printf("CNot:\n");
			RUNNER_RefArgsRet1(flag);
			RUNNER_CheckTag(TBool, flag);
			flag.SetBoolValue(!flag.GetBool());
			break;
		}
		case CIfFalse: {
//			printf("CIfFalse:\n");
			RUNNER_RefArgs1(flag);
			RUNNER_CheckTag(TBool, flag);
			if (!flag.GetBool()) {
				int offset = code.ReadInt31();
				code.SetPosition(code.GetPosition() + offset);
			} else
				code.SkipInt();
			DiscardStackSlots(1);
			break;
		}
		case CGetGlobal: {
			int val = code.ReadInt31_16();
			PushDataStackSlot(val);
			debug_log(printf("CGetGlobal: %d: ", val));
			PrintData(flow_out, DataStack[val]); printf("\n");
			break;
		}
		case CGetLocal: {
			int offset = FramePointer + code.ReadInt31_16();
			PushDataStackSlot(offset);
			debug_log(printf("CGetLocal: "));
			PrintData(flow_out, DataStack[offset]); printf("\n");
			break;
		}
		case CReserveLocals: {
			char *data = code.GetBytes(8);
			int ncnt = ((PackedVals*)data)->usv;
			int v = *(unsigned char*)(data + 4);

//			printf("CReserveLocals ncnt: %d (%x), v: %d (%x)\n", ncnt, ncnt, v, v);

			// Allocate locals
			if (ncnt > 0) {
				if (unlikely(MAX_DATA_STACK - DataStack.size() < unsigned(ncnt))) {
					ReportError(DatastackFull, "Cannot reserve %d locals: stack overflow.", ncnt);
					return LastError;
				}
				memset(PushPtr(ncnt), -1, STACK_SLOT_SIZE*ncnt);
			}
			// Eat parameters
			FramePointer -= v;
			break;
		}
		case CPop: {
			debug_log(printf("CPop:\n"));
			DiscardStackSlots(1);
			break;
		}
		case CRefTo: {
			debug_log(printf("CRefTo:\n"));
			RUNNER_RefArgsRet1(ref);
			ref = mem_pool.AllocateRef(ref); // ALLOC
			break;
		}
		case CDeref: {
			debug_log(printf("CDeref:\n"));
			RUNNER_RefArgsRet1(ref);
			RUNNER_CheckTag(TRefTo, ref);
			ref = mem_pool.GetStackSlot(ref.GetRawRefPtr());
			break;
		}
		case CSetRef: {
			debug_log(printf("CSetRef:\n"));
			RUNNER_RefArgsRet2(ref, value);
			RUNNER_CheckTag(TRefTo, ref);
//			RegisterWrite(ref.GetRawRefPtr());
			mem_pool.SetStackSlot(ref.GetRawRefPtr(), value);
			DiscardStackSlots(1);
			StackSlot::SetVoid(ref);
			break;
		}
		case CInt2Double: {
//			printf("CInt2Double:\n");
			RUNNER_RefArgsRet1(value);
			RUNNER_CheckTag(TInt, value);
			StackSlot::SetDouble(value, FlowDouble(value.GetInt()));
			break;
		}
		case CInt2String: {
//			printf("CInt2Double:\n");
			RUNNER_RefArgsRet1(value);
			value = DoInt2String(value);
			break;
		}
		case CDouble2Int: {
//			printf("CDouble2Int:\n");
			RUNNER_RefArgsRet1(value);
			RUNNER_CheckTag(TDouble, value);
			StackSlot::SetInt(value, int(value.GetDouble()));
			break;
		}
		case CDouble2String: {
//			printf("CDouble2String:\n");
			RUNNER_RefArgsRet1(value);
			value = DoDouble2String(value);
			break;
		}
		case CField: {
			int i = code.ReadInt31_8();
			debug_log(printf("CField i: %d\n", i));
			RUNNER_RefArgsRet1(struct_ref);
			debug_log(printf("CField 2\n"));
			PrintData(flow_out, struct_ref); flow_out << endl;
			RUNNER_CheckTag(TStruct, struct_ref);
			debug_log(printf("CField 3\n"));

			int size = GetStructSize(struct_ref);

			int id = struct_ref.GetStructId();
			debug_log(printf("Name: %s, fields count: %d", StructDefs[id].Name.c_str(), StructDefs[id].FieldsCount));
			debug_log(printf("CField size: %d\n", size));
			if (likely(i >= 0 && i < size))
				struct_ref = GetStructSlot(struct_ref, i);
			else
				ReportError(InvalidArgument, "Field index out of bounds: %d (size %d)", i, size);
			debug_log(printf("CField 4\n"));
			break;
		}
		case CFieldName: {
			char *plen = code.GetBytes(4);
			int len = (unsigned char)plen[0];
//			printf("CFieldName len: %d\n", len);
			char const* n = code.GetBytes(len);
			short* idx = (short*)(plen + 2);
			RUNNER_RefArgsRet1(struct_ref);
			RUNNER_CheckTag(TStruct, struct_ref);

			StructDef *def = NULL;
			int field_id = LookupFieldName(struct_ref, n, len, idx, &def);

			if (field_id == -2) {
				// structname
				DiscardStackSlots(1);
				Push(def->NameU); // ALLOC
			} else if (likely(field_id >= 0)) {
				struct_ref = GetStructSlot(struct_ref, field_id);
			}
			break;
		}
		case CSetMutable: {
			int i = code.ReadInt31_8();
			debug_log(printf("CSetMutable i: %d\n", i));
			if (DoSetMutable(i) != RuntimeError::NoError)
				return LastError;
			break;
		}
		case CSetMutableName: {
			char *plen = code.GetBytes(4);
			int len = (unsigned char)plen[0];
			debug_log(printf("CSetMutableName len: %d\n", len));
			if (DoSetMutableName(code.GetBytes(len), len, (short*)(plen + 2)) != RuntimeError::NoError)
				return LastError;
			break;
		}
		case CStructDef: {
			int id = code.ReadInt31();
			std::string name = code.ReadString();
//			printf("CStructDef id: %d, name: %s\n", id, name.c_str());
			StructDef sd;
			sd.Name = name;
			sd.NameU = parseUtf8(name);
			int n = code.ReadInt31();
			sd.FieldsCount = n;
			sd.CompareIdx = id;
			sd.IsMutable.resize(n);
			for (int i = 0; i < n; ++i) {
				sd.FieldNames.push_back(code.ReadString());
				sd.FieldTypes.push_back(code.ReadFieldType(&sd.IsMutable[i], NULL));
			}
#ifdef FLOW_COMPACT_STRUCTS
			sd.EmptyPtr = LastInstructionPtr + 1;
#endif

			//if (unlikely(Program != NULL))
			//	ReportError(InvalidCall, "The StructDef instruction is disabled in native mode.");
			//else
				RegisterStructDef(id, sd);

			break;
		}
		case CGetFreeVar: {
//			printf("CGetFreeVar:\n");
			int n = code.ReadInt31_8();
			Push(mem_pool.GetStackSlot(closurepointer + n * STACK_SLOT_SIZE));
			break;
		}
		case CDebugInfo: {
			std::string name = code.ReadString();
			debug_log(printf("debuginfo (%x): %s\n", cur_insn, name.c_str()));
			DebugFnInfo[code.GetPosition()] = name;
			//DebugFnList.push_back(name);
			break;
		}
		case CClosurePointer: {
//			printf("CClosurePointer:\n");
			int n = code.ReadInt31_8();
			int offset = code.ReadInt31();

			if (unlikely(DataStack.size() < unsigned(n))) {
				StackError(DatastackFull, false);
				break;
			}

			StackSlot clos = mem_pool.AllocateUninitializedClosure(n, code.GetPosition() + offset); // ALLOC
			memcpy(mem_pool.GetClosureWritePtr(clos, n), PopPtr(n), n * STACK_SLOT_SIZE);
			Push(clos);
			break;
		}
		case CSimpleSwitch:
		case CSwitch: {
			debug_log(printf("CSwitch 1\n"));
			RUNNER_RefArgsRet1(struct_ref);
			debug_log(printf("CSwitch 2\n"));
			RUNNER_CheckTag(TStruct, struct_ref);
			debug_log(printf("CSwitch 3\n"));

			int cases = *(unsigned char*)code.GetBytes(8);
			debug_log(printf("CSwitch 4\n"));
			char *data = code.GetBytes(cases * 8);

			debug_log(printf("CSwitch cases: %d, data: %s\n", cases, data));

			int structId = struct_ref.GetStructId();

			debug_log(printf("CSwitch structId: %d\n", structId));

			// In the default case, we just eat the struct value
			DiscardStackSlots(1);

			for (int i = 0; i < cases; ++i) {
				int cn = *(short*)(data + i * 8);
				if (cn == structId) {
					debug_log(printf("CSwitch cn == structId, We have a hit\n"));
					// We have a hit. Let's unpack the struct on the stack.
					int offset = *(int*)(data + i * 8 + 4);

					if (opcode != CSimpleSwitch) {
						debug_log(printf("CSwitch opcode != CSimpleSwitch\n"));
						int len = GetStructSize(struct_ref);
						if (unlikely(len < 0)) {
							ReportError(InvalidArgument, "Malformed struct object; unknown type %d", struct_ref.GetStructId());
							debug_log(printf("CSwitch Malformed struct object\n"));
							return LastError;
						}
						debug_log(printf("CSwitch MoveStructToStack\n"));
						MoveStructToStack(struct_ref, len); // struct_ref overwritten
					}
					code.SetPosition(code.GetPosition() + offset);
					break;
				}
			}
			break;
		}

		case CBreakpoint: {
			ReportError(InvalidOpCode, "Invalid breakpoint");
			break;
		}

		case CCodeCoverageTrap: {
			ReportError(InvalidOpCode, "Invalid coverage trap");
			break;
		}

		default:
			ReportError(InvalidOpCode, "Invalid OpCode %d (%02Xh)", opcode, opcode);
			break;
		} // switch
	}// while

	return LastError;
}

inline void ByteCodeRunner::doCall() {
	RUNNER_RefArgs1(arg);

	CallFrame *frame = CallStackPush(code.GetPosition());
	if (unlikely(!frame))
		return;

	DiscardStackSlots(1);
	FramePointer = DataStack.size();

	// None of these allocate except native:
	switch (arg.slot_private.Tag) {
	case (StackSlot::TAG_FLOWCODE):
		code.SetPosition(LastInstructionPtr = arg.GetCodePtr());
		break;
	case (StackSlot::TAG_FLOWCODE | StackSlot::TAG_SIGN):
		closurepointer = arg.GetClosureDataPtr();
		code.SetPosition(LastInstructionPtr = mem_pool.GetFlowPtr(closurepointer - 8));
		debug_log(printf("doCall() CHECK THIS\n"));
		break;
	case (StackSlot::TAG_NATIVEFN):
	case (StackSlot::TAG_NATIVEFN | StackSlot::TAG_SIGN):
		debug_log(printf("DoNativeCall\n"));
		DoNativeCall(arg);
		break;
	default:
		// Undo stack changes:
		CallStackPop();
		PushPtr(1);
		ReportError(InvalidCall, "Not callable tag: %02x", arg.GetType());
	}
}

inline void ByteCodeRunner::DoEqual() {
	RUNNER_RefArgsRet2(val1, val2);
	int c = Compare(val1, val2);
	StackSlot::SetBool(val1, (c == 0) ? 1 : 0);
	DiscardStackSlots(1);
}

inline void ByteCodeRunner::DoLessThan() {
	RUNNER_RefArgsRet2(val1, val2);
	int c = Compare(val1, val2);
	StackSlot::SetBool(val1, (c < 0) ? 1 : 0);
	DiscardStackSlots(1);
}

inline void ByteCodeRunner::DoLessEqual() {
	RUNNER_RefArgsRet2(val1, val2);
	int c = Compare(val1, val2);
	StackSlot::SetBool(val1, (c <= 0) ? 1 : 0);
	DiscardStackSlots(1);
}

inline RuntimeError ByteCodeRunner::DoSetMutable(int i) {
	RUNNER_RefArgsRet2(struct_ref, val_ref);
	RUNNER_CheckTag(TStruct, struct_ref);

	int size = GetStructSize(struct_ref);
	if (likely(i >= 0 && i < size))
	{
		StructDef &def = StructDefs[struct_ref.GetStructId()];

		if (likely(def.IsMutable[i]))
			SetStructSlot(struct_ref, i, val_ref);
		else
			ReportError(InvalidArgument, "Field %d is not mutable in %s", i, def.Name.c_str());
	}
	else
		ReportError(InvalidArgument, "Field index out of bounds: %d (size %d)", i, size);

	DiscardStackSlots(1);
	StackSlot::SetVoid(struct_ref);
	return LastError;
}

RuntimeError ByteCodeRunner::DoSetMutableName(char const *n, int length, short *idx) {
	RUNNER_RefArgsRet2(struct_ref, val_ref);
	RUNNER_CheckTag(TStruct, struct_ref);

	StructDef *def = NULL;
	int field_id = LookupFieldName(struct_ref, n, length, idx, &def);

	if (field_id == -2)
		ReportError(InvalidArgument, "Cannot set structname");
	else if (likely(field_id >= 0))
	{
		if (likely(def->IsMutable[field_id]))
			SetStructSlot(struct_ref, field_id, val_ref);
		else
			ReportError(InvalidArgument, "Field %s is not mutable in %s", n, def->Name.c_str());
	}

	DiscardStackSlots(1);
	StackSlot::SetVoid(struct_ref);
	return LastError;
}


#ifdef FLOW_COMPACT_STRUCTS
namespace flow_fields {
	StackSlot get_int(const void *p, ByteCodeRunner*) {
		return StackSlot::MakeInt(*(const int*)p);
	}
	bool set_int(void *p, const StackSlot &v) {
		if (!v.IsInt()) return false;
		*(int*)p = v.GetInt();
		return true;
	}
	StackSlot get_bool(const void *p, ByteCodeRunner*) {
		return StackSlot::MakeBool(*(const char*)p);
	}
	bool set_bool(void *p, const StackSlot &v) {
		if (!v.IsBool()) return false;
		*(char*)p = v.GetBool();
		return true;
	}
	StackSlot get_double(const void *p, ByteCodeRunner*) {
		return StackSlot::MakeDouble(*(const double*)p);
	}
	bool set_double(void *p, const StackSlot &v) {
		if (!v.IsDouble()) return false;
		*(double*)p = v.GetDouble();
		return true;
	}
	StackSlot get_slot(const void *p, ByteCodeRunner*) {
		return *(const StackSlot*)p;
	}
	bool set_slot(void *p, const StackSlot &v) {
		*(StackSlot*)p = v;
		return true;
	}
#if 0
	StackSlot get_array(const void *p, ByteCodeRunner*) {
		const FlowStructArray *pp = (const FlowStructArray*)p;
		return StackSlot::MakeArray(pp->addr, pp->size);
	}
	bool set_array(void *p, const StackSlot &v) {
		if (!v.IsArray()) return false;
		FlowStructArray *pp = (FlowStructArray*)p;
		pp->addr = v.GetInternalArrayPtr();
		pp->size = v.GetInternalArraySize();
		return true;
	}
	StackSlot get_string(const void *p, ByteCodeRunner*) {
		const FlowStructString *pp = (const FlowStructString*)p;
		return StackSlot::MakeString(pp->addr, pp->size);
	}
	bool set_string(void *p, const StackSlot &v) {
		if (!v.IsString()) return false;
		FlowStructString *pp = (FlowStructString*)p;
		pp->addr = v.GetInternalStringPtr();
		pp->size = v.GetInternalStringSize();
		return true;
	}
	StackSlot get_ref(const void *p, ByteCodeRunner*) {
		const FlowStructRef *pp = (const FlowStructRef*)p;
		return StackSlot::MakeRefTo(pp->addr, pp->id);
	}
	bool set_ref(void *p, const StackSlot &v) {
		if (!v.IsRefTo()) return false;
		FlowStructRef *pp = (FlowStructRef*)p;
		pp->addr = v.GetRawRefPtr();
		pp->id = v.GetInternalRefId();
		return true;
	}
#else
	StackSlot get_array(const void *p, ByteCodeRunner*) {
		return *(const StackSlot*)p;
	}
	bool set_array(void *p, const StackSlot &v) {
		if (!v.IsArray()) return false;
		*(StackSlot*)p = v;
		return true;
	}
	StackSlot get_string(const void *p, ByteCodeRunner*) {
		return *(const StackSlot*)p;
	}
	bool set_string(void *p, const StackSlot &v) {
		if (!v.IsString()) return false;
		*(StackSlot*)p = v;
		return true;
	}
	StackSlot get_ref(const void *p, ByteCodeRunner*) {
		return *(const StackSlot*)p;
	}
	bool set_ref(void *p, const StackSlot &v) {
		if (!v.IsRefTo()) return false;
		*(StackSlot*)p = v;
		return true;
	}
#endif
	StackSlot get_struct(const void *p, ByteCodeRunner *runner) {
		FlowPtr pv = *(const FlowPtr*)p;
		FlowStructHeader *sh = mem_pool.GetStructPointer(pv, false);
		return StackSlot::MakeStruct(pv, sh->StructId);
	}
	bool set_struct(void *p, const StackSlot &v) {
		if (!v.IsStruct()) return false;
		assert(v.GetRawStructPtr() != MakeFlowPtr(0));
		*(FlowPtr*)p = v.GetRawStructPtr();
		return true;
	}
}
#endif

	ByteCodeRunner r;
extern "C" {
	EMSCRIPTEN_KEEPALIVE
	int run_bytecode(int length, int data_ptr) {
		return r.run_local(length, (char*)data_ptr);
//		return run_local(length, (char*)data_ptr);
	}
}


int main(int argc, char **argv) {
	printf("Hello, world!\n");

	if (::getParameter(mem_pool.AllocateString(parseUtf8("verbose"))) == parseUtf8("1"))
		debug_log_v = true;

	StackSlot param_name = mem_pool.AllocateString(parseUtf8("flowfile"));
	StackSlot fname = mem_pool.AllocateString(::getParameter(param_name));

	r.flow_out << "FLOW_FILE: ";
	r.PrintData(r.flow_out, fname); r.flow_out << std::endl;

	StackSlot out;
	unicode_char *tmp = mem_pool.AllocateStringBuffer(&out, 3); // ALLOC
	memcpy(tmp, strdata, 3 * FLOW_CHAR_SIZE);

	//unicode_string s = parseUtf8("flowunit.bytecode");
	//StackSlot fname = mem_pool.AllocateString(s.data(), s.size());

	StackSlot arr = mem_pool.AllocateUninitializedArray(5);
	StackSlot* parr = mem_pool.GetArrayWritePtr(arr, 5);

	parr[0] = fname;
	parr[1] = out;
	parr[2] = StackSlot::MakeInt(1);
	parr[3] = StackSlot::MakeDouble(2.5);
	parr[4] = StackSlot::MakeBool(true);

	mem_pool.print();

	EM_ASM_(proxy_NativeHx_println($0, $1), mem_pool.data_ptr(), &arr);

	emscripten_exit_with_live_runtime();

	return 0;
}
