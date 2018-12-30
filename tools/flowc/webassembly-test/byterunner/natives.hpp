//#include "byterunner.h"
//namespace native_ns {

static void ClipLenToRange(int pidx, int *plen, int size) {
	// Range too long, or overflow even?
	int end = pidx + *plen;
	if (end > size || end < 0)
		*plen = size - pidx;
}

static void checkProperSubstringArguments(int *idx, int *len, int strLen) {
	// this function copies the current logic of JS target from NativeHx.substring
	// to unify targets
	if (unlikely(*len < 0)) {
		if (*idx != 0) *len = 0;
		else {
			int smartLen1 = *len + *idx;
			if (smartLen1 >= 0) *len = 0;
			else {
				int smartLen2 = smartLen1 + strLen;
				if (smartLen2 <= 0) *len = 0;
				else *len = smartLen2;
			}
		}
	}
	if (unlikely(*idx < 0)) {
		int smartIdx = *idx + strLen;
		if (smartIdx > 0) *idx = smartIdx;
		else *idx = 0;
	} else if (*idx >= strLen) {
		*len = 0;
	}
}

#undef IGNORE_LOCAL
#define IGNORE_LOCAL(name)
	bool ByteCodeRunner::EvalFunctionStack(const StackSlot &func, int args_num) {
#ifdef FLOW_JIT
		assert(!JitProgram);
#endif

#ifdef FLOW_TIME_PROFILING
		if (unlikely(ProfileTimeCount))
			ProfileTimeEvent();
#endif
		// At this point the flow return address must be already
		// on the stack, if any is needed.
		code.SetPosition(NativeReturnInsn);

		// Remember the stack position for control and push args
		unsigned cur_stack_pos = DataStack.size() - args_num + 1;
		unsigned cur_cstack_pos = CallStack.size();

		// Call the function
		Push(func);
		doCall(); // NATIVE: ALLOC
		run();    // FLOW: ALLOC

		if (unlikely(LastError != NoError))
			return false;

		// Verify stack integrity
		if (unlikely(cur_stack_pos != DataStack.size())) {
			int delta = (DataStack.size() - cur_stack_pos);
			// Note: forgetting to return a value is reported as using 1 additional argument.
			ReportError(StackCorruption, "Stack position changed in EvalFunction: added %d slots.", delta);
			DataStack.resize(cur_stack_pos);
			return false;
		}

		if (unlikely(cur_cstack_pos != CallStack.size())) {
			int delta = (CallStack.size() - cur_cstack_pos);
			ReportError(StackCorruption, "Call stack position changed in EvalFunction: added %d entries.", delta);
			CallStack.resize(cur_cstack_pos);
			return false;
		}

		return true;
	}

	StackSlot ByteCodeRunner::EvalFunctionArr(const StackSlot &func, int args_num, StackSlot *args) {
		if (unlikely(LastError != NoError))
			return StackSlot::MakeVoid();

		switch (func.slot_private.Tag & StackSlot::TAG_NOSIGN)
		{
		case StackSlot::TAG_NATIVEFN:
		{
			debug_log(printf("ByteCodeRunner::EvalFunctionArr StackSlot::TAG_NATIVEFN\n"));
			NativeFunction *p = lookupNativeFn(GetNativeFnId(func));

			if (unlikely(p == NULL)) {
				ReportError(InvalidNativeId, "Invalid native %d", GetNativeFnId(func));
				return StackSlot::MakeVoid();
			}

			if (unlikely(p->num_args() != args_num)) {
				ReportError(InvalidNativeId, "Invalid native argument count: %d vs %d for %s", args_num, p->num_args(), p->name());
				return StackSlot::MakeVoid();
			}

			StackSlot *func_and_args = (StackSlot*)alloca((args_num + 1) * sizeof(StackSlot));

			func_and_args[0] = func;
			memcpy(func_and_args + 1, args, sizeof(StackSlot)*args_num);

			LocalRootDefinition arg_buffer_root(NULL, args_num + 1, func_and_args);
			(void)&arg_buffer_root;

			return (CurNativeFn = p)->func_(NULL, func_and_args + 1);
		}

		case StackSlot::TAG_FLOWCODE:
		{
			debug_log(printf("ByteCodeRunner::EvalFunctionArr StackSlot::TAG_FLOWCODE\n"));
			for (int i = 0; i < args_num; ++i)
				Push(args[i]);

			if (likely(EvalFunctionStack(func, args_num)))
				return PopStackSlot();

			return StackSlot::MakeVoid();
		}

		default:
			debug_log(printf("ByteCodeRunner::EvalFunctionArr default\n"));
			ReportError(InvalidCall, "Not callable tag: %02x", func.GetType());
			return StackSlot::MakeVoid();
		}
	}

	StackSlot ByteCodeRunner::EvalFunction(const StackSlot &func, int args_num, ...) {
		va_list vl;

		if (unlikely(IsErrorReported()))
			return StackSlot::MakeVoid();

		switch (func.slot_private.Tag & StackSlot::TAG_NOSIGN) {
		case StackSlot::TAG_NATIVEFN:
		{
			NativeFunction *p = lookupNativeFn(GetNativeFnId(func));

			if (unlikely(p == NULL)) {
				ReportError(InvalidNativeId, "Invalid native %d", GetNativeFnId(func));
				return StackSlot::MakeVoid();
			}

			if (unlikely(p->num_args_ != args_num)) {
				ReportError(InvalidNativeId, "Invalid native argument count: %d vs %d for %s", args_num, p->num_args_, p->name());
				return StackSlot::MakeVoid();
			}

			StackSlot *func_and_args = (StackSlot*)alloca((args_num + 1) * sizeof(StackSlot));

			func_and_args[0] = func;

			va_start(vl, args_num);
			for (int i = 0; i < args_num; ++i)
				func_and_args[i + 1] = va_arg(vl, StackSlot);
			va_end(vl);

			LocalRootDefinition arg_buffer_root(this, args_num + 1, func_and_args);
			(void)&arg_buffer_root;

			return (CurNativeFn = p)->func_(this, func_and_args + 1);
		}

		case StackSlot::TAG_FLOWCODE:
		{
			va_start(vl, args_num);
			for (int i = 0; i < args_num; ++i)
				Push(va_arg(vl, StackSlot));
			va_end(vl);

			if (likely(EvalFunctionStack(func, args_num)))
				return PopStackSlot();

			return StackSlot::MakeVoid();
		}

		default:
			ReportError(InvalidCall, "Not callable tag: %02x", func.GetType());
			return StackSlot::MakeVoid();
		}
	}

	inline StackSlot ByteCodeRunner::FastEvalFunction(StackSlot *func_and_args, int args_num) {
		// Fast-track path for native-to-native calls, allowing branch prediction to kick in
		if (likely(func_and_args[0].IsNativeFn())) {
			NativeFunction *p = lookupNativeFn(GetNativeFnId(func_and_args[0]));
			if (unlikely(!p)) goto slow_path;
			if (unlikely(p->num_args() != args_num)) goto slow_path;
			// this call is what must be inlined per call site for branch prediction
			return (CurNativeFn = p)->func_(NULL, func_and_args + 1);
		}
		else {
		slow_path:
			return EvalFunctionArr(func_and_args[0], args_num, func_and_args + 1);
		}
	}

	StackSlot ByteCodeRunner::println(RUNNER_ARGS) {
		RUNNER_PopArgs1(object);

		printf("NATIVE_NS::PRINTLN\n");

		if (object.IsString())
			RUNNER->flow_out << encodeUtf8(RUNNER->GetString(object));
		else
			RUNNER->PrintData(RUNNER->flow_out, object);

		RUNNER->flow_out << endl;

		RETVOID;
	}

	StackSlot ByteCodeRunner::failWithError(RUNNER_ARGS) {
		RUNNER_PopArgs1(error);

		std::string msg = encodeUtf8(RUNNER->GetString(error));
		RUNNER->ReportError(InvalidCall, "Runtime failure: %s", msg.c_str());
		RETVOID;
	}

	StackSlot ByteCodeRunner::deleteNative(RUNNER_ARGS) {
		RUNNER_PopArgs1(arg);

		if (arg.IsNative())
			RUNNER->DeleteNative(arg);
		RETVOID;
	}

	// input & output via data stack ( array closure --> mapi(closure, array) )
	StackSlot ByteCodeRunner::mapi(RUNNER_ARGS) {
		RUNNER_PopArgs2(arr, clos);
		RUNNER_CheckTag(TArray, arr);

		RUNNER_DefSlotArray(fn_args, 3);
		fn_args[0] = clos;
		fn_args[1] = StackSlot::MakeInt(0);

		int len = RUNNER->GetArraySize(arr);
		RUNNER_DefSlots1(retarr);
		retarr = mem_pool.AllocateArray(len);

		if (RUNNER->IsErrorReported())
			return StackSlot::MakeVoid();

		for (int i = 0; i < len; ++i) {
			fn_args[1].SetIntValue(i);
			fn_args[2] = RUNNER->GetArraySlot(arr, i);
			fn_args[2] = RUNNER->FastEvalFunction(fn_args, 2);
			RUNNER->SetArraySlot(retarr, i, fn_args[2]);
		}

		return retarr;
	}

	StackSlot ByteCodeRunner::map(RUNNER_ARGS) {
		RUNNER_PopArgs2(arr, clos);
		RUNNER_CheckTag(TArray, arr);

		RUNNER_DefSlotArray(fn_args, 2);
		fn_args[0] = clos;

		int len = RUNNER->GetArraySize(arr);
		RUNNER_DefSlots1(retarr);
		retarr = mem_pool.AllocateArray(len);

		if (RUNNER->IsErrorReported())
			return StackSlot::MakeVoid();

		for (int i = 0; i < len; ++i) {
			fn_args[1] = RUNNER->GetArraySlot(arr, i);
			fn_args[1] = RUNNER->FastEvalFunction(fn_args, 1);
			RUNNER->SetArraySlot(retarr, i, fn_args[1]);
		}

		return retarr;
	}

	StackSlot ByteCodeRunner::iter(RUNNER_ARGS) {
		RUNNER_PopArgs2(arr, clos);
		RUNNER_CheckTag(TArray, arr);

		RUNNER_DefSlotArray(fn_args, 2);
		fn_args[0] = clos;

		int len = RUNNER->GetArraySize(arr);

		for (int i = 0; i < len; ++i)
		{
			fn_args[1] = RUNNER->GetArraySlot(arr, i);
			RUNNER->FastEvalFunction(fn_args, 1);
		}

		RETVOID;
	}

	StackSlot ByteCodeRunner::iteri(RUNNER_ARGS)
	{
		RUNNER_PopArgs2(arr, clos);
		RUNNER_CheckTag(TArray, arr);

		RUNNER_DefSlotArray(fn_args, 3);
		fn_args[0] = clos;
		fn_args[1] = StackSlot::MakeInt(0);

		int len = RUNNER->GetArraySize(arr);

		for (int i = 0; i < len; ++i) {
			fn_args[1].SetIntValue(i);
			fn_args[2] = RUNNER->GetArraySlot(arr, i);
			RUNNER->FastEvalFunction(fn_args, 2);
		}

		RETVOID;
	}

	StackSlot ByteCodeRunner::fold(RUNNER_ARGS) {
		RUNNER_PopArgs3(arr, init, clos);
		RUNNER_CheckTag(TArray, arr);
		RUNNER_DefSlotArray(fn_args, 3);
		debug_log(printf("fold(RUNNER_ARGS)\n"));
		int len = RUNNER->GetArraySize(arr);

		fn_args[0] = clos;
		fn_args[1] = init;

		for (int i = 0; i < len; ++i) {
			fn_args[2] = RUNNER->GetArraySlot(arr, i);

			// CALL
			fn_args[1] = RUNNER->FastEvalFunction(fn_args, 2);

			RUNNER_CheckError();
		}

		return fn_args[1];
	}

	StackSlot ByteCodeRunner::foldi(RUNNER_ARGS) {
		RUNNER_PopArgs3(arr, init, clos);
		RUNNER_CheckTag(TArray, arr);
		RUNNER_DefSlotArray(fn_args, 4);

		int len = RUNNER->GetArraySize(arr);

		fn_args[0] = clos;
		fn_args[2] = init;

		for (int i = 0; i < len; ++i) {
			fn_args[1] = StackSlot::MakeInt(i);
			fn_args[3] = RUNNER->GetArraySlot(arr, i);

			// CALL
			fn_args[2] = RUNNER->FastEvalFunction(fn_args, 3);

			RUNNER_CheckError();
		}

		return fn_args[2];
	}

	StackSlot ByteCodeRunner::filter(RUNNER_ARGS) {
		RUNNER_PopArgs2(arr, clos);
		RUNNER_CheckTag(TArray, arr);
		RUNNER_DefSlots2(retarr, val);

		int len = RUNNER->GetArraySize(arr);
		if (len == 0) {
			return StackSlot::MakeEmptyArray();
		}

		// Compute the result length and an inclusion mask
		std::vector<char> inctab(len, 0);
		int rlen = 0;

		RUNNER_DefSlotArray(fn_args, 2);
		fn_args[0] = clos;

		for (int i = 0; i < len; ++i) {
			fn_args[1] = RUNNER->GetArraySlot(arr, i);
			val = RUNNER->FastEvalFunction(fn_args, 1);
			RUNNER_CheckTag(TBool, val);
			char inc = val.GetBool() ? 1 : 0;
			inctab[i] = inc;
			rlen += inc;
		}

		// Allocate output and copy data
		retarr = mem_pool.AllocateArray(rlen);

		if (RUNNER->IsErrorReported())
			return StackSlot::MakeVoid();

		for (int i = 0, j = 0; i < len; ++i)
			if (inctab[i])
				RUNNER->SetArraySlot(retarr, j++, RUNNER->GetArraySlot(arr, i));

		return retarr;
	}

	StackSlot ByteCodeRunner::gc(RUNNER_ARGS) {
		FLOW_ASSERT;
		//IGNORE_RUNNER_ARGS;
		//RUNNER->ForceGC(0, true);
		RETVOID;
	}	

	StackSlot ByteCodeRunner::elemIndex(RUNNER_ARGS) {
		debug_log(printf("elemIndex 1\n"));
		RUNNER_PopArgs3(arr, key, defidx);

		RUNNER->PrintData(RUNNER->flow_out, arr); RUNNER->flow_out << endl;
		RUNNER->PrintData(RUNNER->flow_out, key); RUNNER->flow_out << endl;
		RUNNER->PrintData(RUNNER->flow_out, defidx); RUNNER->flow_out << endl;

		debug_log(printf("elemIndex 2\n"));
		RUNNER_CheckTag(TArray, arr);

		debug_log(printf("elemIndex 3\n"));
		int len = RUNNER->GetArraySize(arr);
		const StackSlot *data = RUNNER->GetArraySlotPtr(arr, len);

		for (int i = 0; i < len; i++)
			if (RUNNER->Compare(data[i], key) == 0)
				return StackSlot::MakeInt(i);

		return defidx;
	}

	StackSlot ByteCodeRunner::exists(RUNNER_ARGS) {
		RUNNER_PopArgs2(arr, clos);
		RUNNER_CheckTag(TArray, arr);

		RUNNER_DefSlots1(rv);
		rv = StackSlot::MakeBool(false);

		RUNNER_DefSlotArray(fn_args, 2);
		fn_args[0] = clos;

		int len = RUNNER->GetArraySize(arr);

		for (int i = 0; i < len; i++)
		{
			fn_args[1] = RUNNER->GetArraySlot(arr, i);
			rv = RUNNER->FastEvalFunction(fn_args, 1);
			RUNNER_CheckTag(TBool, rv);
			if (rv.GetBool())
				break;
		}

		return rv;
	}

	StackSlot ByteCodeRunner::AllocateSomeStruct(StackSlot data) {
		// Pin the argument for gc
		LocalRootDefinition frame(this, 1, &data);
		IGNORE_LOCAL(frame);

		if (unlikely(SomeStructId < 0))
			return AllocateSomeStruct(); // will emit error

		StackSlot rv = mem_pool.AllocateRawStruct(StructDefs[SomeStructId], false);
		SetStructSlot(rv, 0, data);
		return rv;
	}

	StackSlot ByteCodeRunner::find(RUNNER_ARGS) {
		debug_log(printf("find 1\n"));
		RUNNER_PopArgs2(arr, clos);
		RUNNER->PrintData(RUNNER->flow_out, arr); RUNNER->flow_out << endl;
		RUNNER->PrintData(RUNNER->flow_out, clos); RUNNER->flow_out << endl;
		debug_log(printf("find 2\n"));
		RUNNER_CheckTag(TArray, arr);
		debug_log(printf("find 3\n"));
		RUNNER_DefSlots1(rv);
		debug_log(printf("find 4\n"));

		RUNNER_DefSlotArray(fn_args, 2);
		fn_args[0] = clos;
		debug_log(printf("find 5\n"));

		int len = RUNNER->GetArraySize(arr);
		debug_log(printf("find 6\n"));

		for (int i = 0; i < len; i++)
		{
			fn_args[1] = RUNNER->GetArraySlot(arr, i);
			rv = RUNNER->FastEvalFunction(fn_args, 1);
			RUNNER_CheckTag(TBool, rv);
			if (rv.GetBool()) {
				debug_log(printf("find result: true\n"));
				return RUNNER->AllocateSomeStruct(fn_args[1]);
			}
		}

		debug_log(printf("find result: false\n"));
		return RUNNER->AllocateNoneStruct();
	}

	StackSlot ByteCodeRunner::subrange(RUNNER_ARGS)	{
		RUNNER_PopArgs3(arr, idx, len);
		RUNNER_CheckTag(TArray, arr);
		RUNNER_CheckTag2(TInt, idx, len);

		int arr_len = RUNNER->GetArraySize(arr);
		int len_int = len.GetInt();

		if (unlikely(idx.GetInt() < 0 || len_int < 1) || idx.GetInt() >= arr_len) {
			return StackSlot::MakeEmptyArray();
		}

		ClipLenToRange(idx.GetInt(), &len_int, arr_len);

		StackSlot rval = mem_pool.AllocateUninitializedArray(len_int); // ALLOC

		if (unlikely(RUNNER->IsErrorReported()))
			return StackSlot::MakeVoid();

		RUNNER->CopyArraySlots(rval, 0, arr, idx.GetInt(), len_int);

		return rval;
	}

	StackSlot ByteCodeRunner::length(RUNNER_ARGS) {
		RUNNER_PopArgs1(arr);
		RUNNER_CheckTag(TArray, arr);
		return StackSlot::MakeInt(RUNNER->GetArraySize(arr));
	}

	StackSlot ByteCodeRunner::NativeStrlen(RUNNER_ARGS)	{
		RUNNER_PopArgs1(str);
		RUNNER_CheckTag(TString, str);
		return StackSlot::MakeInt(RUNNER->GetStringSize(str));
	}

	int ByteCodeRunner::strRangeIndexOf(const unicode_char *pstr, const unicode_char *psub, unsigned l1, unsigned l2, unsigned start, unsigned end) {
		if (!pstr)
			return -1;

		if (start < 0)
			start = 0;

		if (end > l1)
			end = l1;

		if (l2 == 0) {
			return 0;
		}
		else if (l2 > end - start) {
			return -1;
		}
		else if (l2 == 1) {
			unicode_char key = *psub;

			for (const unicode_char *p = pstr + start; p <= pstr + end - l2; ++p) {
				if (*p == key) {
					return p - pstr;
				}
			}
		}
		else {
			unsigned size = l2 * FLOW_CHAR_SIZE;

			for (const unicode_char *p = pstr + start; p <= pstr + end - l2; ++p) {
				if (memcmp(p, psub, size) == 0) {
					return p - pstr;
				}
			}
		}

		return -1;
	}

	StackSlot ByteCodeRunner::strIndexOf(RUNNER_ARGS) {
		RUNNER_PopArgs2(str, sub);
		RUNNER_CheckTag2(TString, str, sub);

		unsigned l1, l2;
		const unicode_char *pstr = RUNNER->GetStringPtrSize(str, &l1);
		const unicode_char *psub = RUNNER->GetStringPtrSize(sub, &l2);

		return StackSlot::MakeInt(strRangeIndexOf(pstr, psub, l1, l2, 0, l1));
	}

	StackSlot ByteCodeRunner::strContainsAt(RUNNER_ARGS) {
		RUNNER_PopArgs3(str, pos, sub);
		RUNNER_CheckTag2(TString, str, sub);
		RUNNER_CheckTag1(TInt, pos);

		unsigned ppos = pos.GetInt();

		unsigned lstr, lsub;
		const unicode_char *pstr = RUNNER->GetStringPtrSize(str, &lstr);
		const unicode_char *psub = RUNNER->GetStringPtrSize(sub, &lsub);

		if (ppos + lsub > lstr) {
			return StackSlot::MakeBool(false);
		}

		const unicode_char *pstrpos = pstr + ppos;
		unsigned size = lsub * FLOW_CHAR_SIZE;

		return StackSlot::MakeBool(memcmp(pstrpos, psub, size) == 0);
	}

	StackSlot ByteCodeRunner::strRangeIndexOf(RUNNER_ARGS) {
		RUNNER_PopArgs4(str, sub, start, end);
		RUNNER_CheckTag2(TString, str, sub);
		RUNNER_CheckTag2(TInt, start, end);

		unsigned l1, l2;
		const unicode_char *pstr = RUNNER->GetStringPtrSize(str, &l1);
		const unicode_char *psub = RUNNER->GetStringPtrSize(sub, &l2);

		return StackSlot::MakeInt(strRangeIndexOf(pstr, psub, l1, l2, start.GetInt(), end.GetInt()));
	}

	StackSlot ByteCodeRunner::substring(RUNNER_ARGS) {
		RUNNER_PopArgs3(str, idx, len);
		RUNNER_CheckTag(TString, str);
		RUNNER_CheckTag2(TInt, idx, len);

		int idx_int = idx.GetInt();
		int len_int = len.GetInt();

		checkProperSubstringArguments(&idx_int, &len_int, RUNNER->GetStringSize(str));
		if (len_int < 1)
			return StackSlot::MakeEmptyString();
		else
			RUNNER->DoSubstring(&str, idx_int, len_int);
		return str;
	}

	bool ByteCodeRunner::DoSubstring(StackSlot *pdata, int idx, int len) {
		ClipLenToRange(idx, &len, GetStringSize(*pdata));

		StackSlot tmp;
		FlowPtr *pp = mem_pool.AllocateStringRef(&tmp, len); // ALLOC

		*pp = GetStringAddr(*pdata) + idx * FLOW_CHAR_SIZE;
		*pdata = tmp;

		return true;
	}

	StackSlot ByteCodeRunner::concat(RUNNER_ARGS) {
		RUNNER_PopArgs2(arr1, arr2);
		RUNNER_CheckTag2(TArray, arr1, arr2);

		int arr1_len = RUNNER->GetArraySize(arr1);
		int arr2_len = RUNNER->GetArraySize(arr2);

		int len = arr1_len + arr2_len;

		if (len == 0) {
			return StackSlot::MakeEmptyArray();
		}

		// Do not use safe wrappers for speed:
		StackSlot rval = mem_pool.AllocateUninitializedArray(len); // ALLOC

		if (RUNNER->IsErrorReported())
			return StackSlot::MakeVoid();

		RUNNER->CopyArraySlots(rval, 0, arr1, 0, arr1_len);
		RUNNER->CopyArraySlots(rval, arr1_len, arr2, 0, arr2_len);

		return rval;
	}

	StackSlot ByteCodeRunner::replace(RUNNER_ARGS) {
		RUNNER_PopArgs3(arr, idx, new_val);
		RUNNER_CheckTag(TArray, arr);
		RUNNER_CheckTag(TInt, idx);

		int len = RUNNER->GetArraySize(arr);

		if (idx.GetInt() < 0 || idx.GetInt() > len) {
			RUNNER->ReportError(InvalidArgument, "Replace index %d out of bound %d",
				idx.GetInt(), len);
			RETVOID;
		}

		// for arrayPush using !!!
		int new_len = (idx.GetInt() == len ? len + 1 : len);

		// Do not use safe wrappers for speed:
		StackSlot rval = mem_pool.AllocateUninitializedArray(new_len); // ALLOC

		if (RUNNER->IsErrorReported())
			return StackSlot::MakeVoid();

		RUNNER->CopyArraySlots(rval, 0, arr, 0, len);
		RUNNER->SetArraySlot(rval, idx.GetInt(), new_val);

		return rval;
	}

	// Convert a string to an array of character codes
	// native s2a : (string) -> [int] = Native.s2a;
	StackSlot ByteCodeRunner::s2a(RUNNER_ARGS) {
		RUNNER_PopArgs1(str);
		RUNNER_CheckTag(TString, str);

		int len = RUNNER->GetStringSize(str);

		if (len == 0) {
			return StackSlot::MakeEmptyArray();
		}

		// Do not use safe wrappers for speed:
		StackSlot aptr = mem_pool.AllocateUninitializedArray(len); // ALLOC

		if (RUNNER->IsErrorReported())
			return StackSlot::MakeVoid();

		const unicode_char *str_data = RUNNER->GetStringPtr(str);
		StackSlot *arr_data = (StackSlot*)mem_pool.GetRawPointer(aptr.GetInternalArrayPtr(), len*STACK_SLOT_SIZE, true);

		for (int i = 0; i < len; ++i)
			arr_data[i] = StackSlot::MakeInt(str_data[i]);

		return aptr;
	}

	StackSlot ByteCodeRunner::string2utf8(RUNNER_ARGS) {
		RUNNER_PopArgs1(str);
		RUNNER_CheckTag(TString, str);

		std::string utf8 = encodeUtf8(RUNNER->GetString(str));
		int len = utf8.size();

		if (len == 0) {
			return StackSlot::MakeEmptyArray();
		}

		// Do not use safe wrappers for speed:
		StackSlot aptr = mem_pool.AllocateUninitializedArray(len); // ALLOC
		StackSlot *arr_data = (StackSlot*)mem_pool.GetRawPointer(aptr.GetInternalArrayPtr(), len*STACK_SLOT_SIZE, true);

		if (RUNNER->IsErrorReported())
			return StackSlot::MakeVoid();

		for (int i = 0; i < len; ++i)
			arr_data[i] = StackSlot::MakeInt(uint8_t(utf8[i]));

		return aptr;
	}

	// 32 bit xor
	// native xor : (int, int) -> int = Native.bitXor;
	StackSlot ByteCodeRunner::bitXor(RUNNER_ARGS) {
		RUNNER_PopArgs2(a1, a2);
		RUNNER_CheckTag2(TInt, a1, a2);
		return StackSlot::MakeInt(a1.GetInt() ^ a2.GetInt());
	}

	StackSlot ByteCodeRunner::bitOr(RUNNER_ARGS){
		RUNNER_PopArgs2(a1, a2);
		RUNNER_CheckTag2(TInt, a1, a2);
		return StackSlot::MakeInt(a1.GetInt() | a2.GetInt());
	}

	StackSlot ByteCodeRunner::bitAnd(RUNNER_ARGS) {
		RUNNER_PopArgs2(a1, a2);
		RUNNER_CheckTag2(TInt, a1, a2);
		return StackSlot::MakeInt(a1.GetInt() & a2.GetInt());
	}

	StackSlot ByteCodeRunner::bitUshr(RUNNER_ARGS) {
		RUNNER_PopArgs2(a1, a2);
		RUNNER_CheckTag2(TInt, a1, a2);
		return StackSlot::MakeInt((unsigned int)(a1.GetInt()) >> a2.GetInt());
	}

	StackSlot ByteCodeRunner::bitShl(RUNNER_ARGS) {
		RUNNER_PopArgs2(a1, a2);
		RUNNER_CheckTag2(TInt, a1, a2);
		return StackSlot::MakeInt(a1.GetInt() << a2.GetInt());
	}

	StackSlot ByteCodeRunner::bitNot(RUNNER_ARGS) {
		RUNNER_PopArgs1(a1);
		RUNNER_CheckTag1(TInt, a1);
		return StackSlot::MakeInt(~a1.GetInt());
	}
	
	StackSlot ByteCodeRunner::list2array(RUNNER_ARGS) {
		debug_log(printf("list2array 1\n"));
		RUNNER_PopArgs1(list);
		RUNNER->PrintData(RUNNER->flow_out, list); RUNNER->flow_out << endl;
		debug_log(printf("list2array 2\n"));
		RUNNER_CheckTag(TStruct, list);
		debug_log(printf("list2array 3\n"));
		RUNNER_DefSlots2(cur, arr);

		// 1st pass: measure size
		int count = 0;
		RUNNER_ForEachCons(cur, list) {
			count++;
		}
		debug_log(printf("list2array 4, count: %d\n", count));

//		RUNNER_CheckEmptyList(cur, "list2array");

		debug_log(printf("list2array 5\n"));
		// 2nd pass: construct the array (in reverse)
		arr = mem_pool.AllocateArray(count);
		debug_log(printf("list2array 6\n"));

		if (RUNNER->IsErrorReported())
			return StackSlot::MakeVoid();

		printf("list2array 7\n");
		RUNNER_ForEachCons(cur, list) {
			StackSlot item = RUNNER->GetConsItem(cur);
			RUNNER->flow_out << dec << count << ": "; RUNNER->PrintData(RUNNER->flow_out, item); RUNNER->flow_out << endl;
			RUNNER->SetArraySlot(arr, --count, item);
		}

		RUNNER->PrintData(RUNNER->flow_out, arr); RUNNER->flow_out << endl;

		return arr;
	}

	StackSlot ByteCodeRunner::list2string(RUNNER_ARGS) {
		RUNNER_PopArgs1(list);
		RUNNER_CheckTag(TStruct, list);
		RUNNER_DefSlots3(cur, str_item, string);

		// 1st pass: measure size
		int size = 0;
		RUNNER_ForEachCons(cur, list) {
			str_item = RUNNER->GetConsItem(cur);
			RUNNER_CheckTag(TString, str_item);
			size += RUNNER->GetStringSize(str_item);
		}

		RUNNER_CheckEmptyList(cur, "list2string");

		// 2nd pass: construct the string (in reverse)
		string = mem_pool.AllocateString(NULL, size);

		if (RUNNER->IsErrorReported())
			return StackSlot::MakeVoid();

		FlowPtr dest_ptr = RUNNER->GetStringAddr(string);

		RUNNER_ForEachCons(cur, list) {
			str_item = RUNNER->GetConsItem(cur);
			int item_size = RUNNER->GetStringSize(str_item);
			size -= item_size;
			mem_pool.Copy(RUNNER->GetStringAddr(str_item), dest_ptr + size * FLOW_CHAR_SIZE, item_size * FLOW_CHAR_SIZE);
		}

		return string;
	}

	StackSlot ByteCodeRunner::isArray(RUNNER_ARGS) {
		RUNNER_PopArgs1(value);
		return StackSlot::MakeBool(value.IsArray());
	}

	StackSlot ByteCodeRunner::isSameStructType(RUNNER_ARGS) {
		RUNNER_PopArgs2(value1, value2);

		bool rv = value1.IsStruct() && value2.IsStruct() &&
			value1.GetStructId() == value2.GetStructId();

		return StackSlot::MakeBool(rv);
	}

	StackSlot ByteCodeRunner::isSameObj(RUNNER_ARGS) {
		RUNNER_PopArgs2(slot1, slot2);

		return StackSlot::MakeBool(RUNNER->CompareByRef(slot1, slot2));
	}


	StackSlot ByteCodeRunner::iteriUntil(RUNNER_ARGS) {
		RUNNER_PopArgs2(arr, callback);
		RUNNER_CheckTag(TArray, arr);
		RUNNER_DefSlots1(tmp);

		RUNNER_DefSlotArray(fn_args, 3);
		fn_args[0] = callback;
		fn_args[1] = StackSlot::MakeInt(0);

		int arr_len = RUNNER->GetArraySize(arr);
		int i = 0;
		for (; i < arr_len; i++) {
			fn_args[1].SetIntValue(i);
			fn_args[2] = RUNNER->GetArraySlot(arr, i);
			tmp = RUNNER->FastEvalFunction(fn_args, 2);
			RUNNER_CheckTag(TBool, tmp);
			if (tmp.GetBool())
				break;
		}

		return StackSlot::MakeInt(i);
	}

	class BinarySerializer {
		RUNNER_VAR;

		std::map<int, int> structIdxs;
		std::vector<int> structIds;

		unicode_string buf;

		inline void pushInt32(int val) {
			buf.push_back(val & 0xFFFF);
			buf.push_back(val >> 16);
		}

		void pushInteger(int int_value) {
			if (int_value & 0xFFFF8000) {
				buf.push_back(0xFFF5);
				pushInt32(int_value);
			}
			else {
				buf.push_back(int_value);
			}
		}

		void pushString(const unicode_char *data, unsigned len) {
			if (len & 0xFFFF0000) {
				buf.push_back(0xFFFB);
				pushInt32(len);
			}
			else {
				buf.push_back(0xFFFA);
				buf.push_back(len);
			}

			buf.append(data, len);
		}

		void pushString(const unicode_string &obj) { pushString(obj.data(), obj.size()); }

		void pushArraySize(unsigned len) {
			if (len == 0) {
				buf.push_back(0xFFF7);
			}
			else {
				if (len & 0xFFFF0000) {
					buf.push_back(0xFFF9);
					pushInt32(len);
				}
				else {
					buf.push_back(0xFFF8);
					buf.push_back(len);
				}
			}
		}

		int registerStruct(int struct_id) {
			int struct_idx = 0;
			std::map<int, int>::iterator it = structIdxs.find(struct_id);
			if (it == structIdxs.end()) {
				structIdxs[struct_id] = struct_idx = structIds.size();
				structIds.push_back(struct_id);
			}
			else {
				struct_idx = it->second;
			}
			return struct_idx;
		}

		void writeStructDefs() {
			pushArraySize(structIds.size());
			for (unsigned i = 0; i < structIds.size(); ++i) {
				pushArraySize(2);
				const StructDef & struct_def = RUNNER->GetStructDef(structIds[i]);
				pushInteger(struct_def.FieldsCount);
				pushString(struct_def.NameU);
			}
		}

		void writeBinaryValue(const StackSlot & value) {
			switch (value.GetType()) {
			case TVoid:
				buf.push_back(0xFFFF);
				break;
			case TBool:
				buf.push_back(value.GetBool() ? 0xFFFE : 0xFFFD);
				break;
			case TInt:
				pushInteger(value.GetInt());
				break;
			case TDouble:
			{
				const int *pdata = (const int*)&value.slot_private.DoubleVal;
				buf.push_back(0xFFFC);
				pushInt32(pdata[0]);
				pushInt32(pdata[1]);
				break;
			}
			case TString:
				pushString(RUNNER->GetStringPtr(value), RUNNER->GetStringSize(value));
				break;
			case TArray:
			{
				int len = RUNNER->GetArraySize(value);
				pushArraySize(len);
				for (int i = 0; i < len; ++i)
					writeBinaryValue(RUNNER->GetArraySlot(value, i));
				break;
			}
			case TStruct:
			{
				int size = RUNNER->GetStructSize(value);
				int struct_idx = registerStruct(value.GetStructId());

				buf.push_back(0xFFF4);
				buf.push_back(struct_idx);
				for (int i = 0; i < size; ++i)
					writeBinaryValue(RUNNER->GetStructSlot(value, i));
				break;
			}
			case TRefTo:
				buf.push_back(0xFFF6);
				writeBinaryValue(RUNNER->GetRefTarget(value));
				break;
			default:
				RUNNER->ReportError(InvalidArgument, "Cannot serialize flow value. Invalid DataTag: %d", value.GetType());
				break;
			}
		}

	public:
		BinarySerializer(RUNNER_VAR) : RUNNER(RUNNER) {
			//
		}

		void serialize(const StackSlot &value) {
			buf.clear();
			structIds.clear();
			structIdxs.clear();

			buf.push_back(0); buf.push_back(0); // Stub for footer offset
			writeBinaryValue(value);

			int struct_defs_offset = buf.length();
			writeStructDefs();

			buf[0] = struct_defs_offset & 0xFFFF;
			buf[1] = struct_defs_offset >> 16;
		}


		const unicode_string &output() { return buf; }
	};

	// Converts flow value to a binary stream as UTF-16 flow string
	StackSlot ByteCodeRunner::toBinary(RUNNER_ARGS) {
		RUNNER_PopArgs1(value);

		BinarySerializer worker(RUNNER);
		worker.serialize(value);

		return mem_pool.AllocateString(worker.output());
	}

	class BinaryDeserializer {
		RUNNER_VAR;

		std::vector<int> structIndex;
		std::vector<int> structSize;
		std::vector<StackSlot> structFixups;
		bool has_fixups;

		const StackSlot *pinput, *pdefault;
		unsigned char_idx, ssize;

		// A check for corrupted array sizes
		int slot_budget;

		bool error;

#ifdef FLOW_MMAP_HEAP
		typedef ByteCodeRunner::MappedAreaInfo MappedAreaInfo;

		bool mapped;
		FlowPtr hp, hplimit;
		FlowPtr rhp, rhplimit;
		MappedAreaInfo::Ptr area;
#endif

		StackSlot NewRef() {
			if (error || --slot_budget < 0)
			{
				error = true;
				return StackSlot::MakeVoid();
			}

#ifdef FLOW_MMAP_HEAP
			if (mapped)
			{
				if (rhp >= rhplimit)
				{
					int count = 1000;
					int bytes = count * sizeof(FlowHeapRef);

					FlowPtr ptr = NewBuffer(bytes);
					if (error) return StackSlot::MakeVoid();

					FlowHeapRef *refs = (FlowHeapRef*)MEMORY->GetRawPointer(ptr, bytes, true);

					for (int i = 0; i < count; i++)
					{
						refs[i].header.IntVal = 0;
						StackSlot::SetVoid(refs[i].data);
					}

					rhp = ptr;
					rhplimit = rhp + bytes;
					area->ref_roots.push_back(std::pair<FlowPtr, int>(rhp, count));
				}

				FlowPtr ptr = rhp;
				rhp += sizeof(FlowHeapRef);

				unsigned id = RUNNER->NextRefId++;
				bool big = (id & 0xffff0000u) != 0;

				MEMORY->SetInt32(ptr, id & 0xffffu);
				return StackSlot::InternalMakeRefTo(ptr, big ? id >> 16 : id, big);
			}
#endif

			return mem_pool.AllocateRef(StackSlot::MakeVoid());
		}
		FlowPtr NewBuffer(int size) {
#ifdef FLOW_MMAP_HEAP
			if (mapped)
			{
				FlowPtr cur = hp, end = hp + bytes;

				if (end > hplimit)
				{
					hplimit = FlowPtrAlignUp(end, 1024 * 1024);
					MEMORY->CommitRange(hp, hplimit);
				}

				hp = end;
				return cur;
			}
			else
#endif
				return mem_pool.allocate(size);
		}
		StackSlot NewArray(int size, bool map = true) {
			if (error || size < 0 || (slot_budget -= size) < 0)
			{
				error = true;
				return StackSlot::MakeVoid();
			}

			if (size == 0)
				return StackSlot::MakeEmptyArray();

#ifdef FLOW_MMAP_HEAP
			if (mapped && do_map)
			{
				int bytes = size * STACK_SLOT_SIZE;
				FlowPtr cur = NewBuffer(4 + bytes);

				MEMORY->SetInt32(cur, size & 0xffffu);
				MEMORY->FillBytes(cur + 4, -1, bytes);

				bool big = (size & 0xffff0000u) != 0;
				return StackSlot::InternalMakeArray(cur, big ? size >> 16 : size, big);
			}
#endif

			return mem_pool.AllocateArray(size);
		}

		void SetSlot(const StackSlot &arr, int index, const StackSlot &val) {
#ifdef FLOW_MMAP_HEAP
			if (mapped)
			{
				FlowPtr slot = arr.GetInternalArrayPtr() + index * STACK_SLOT_SIZE;
				MEMORY->SetStackSlot(slot, val);
				return;
			}
#endif

			RUNNER->SetArraySlot(arr, index, val);
		}
		void SetRefTarget(const StackSlot &ref, const StackSlot &val) {
#ifdef FLOW_MMAP_HEAP
			if (mapped)
			{
				MEMORY->SetStackSlot(ref.GetRawRefPtr(), val);
				return;
			}
#endif

			RUNNER->SetRefTarget(ref, val);
		}

		const unicode_char *readChars(int count) {
			unsigned new_idx = char_idx + count;
			if (new_idx < char_idx || new_idx > ssize) {
				error = true;
				return NULL;
			}
			unsigned cur_idx = char_idx;
			char_idx = new_idx;
			return RUNNER->GetStringPtr(*pinput) + cur_idx;
		}

		unicode_char readChar() {
			const unicode_char *data = readChars(1);
			return data ? *data : 0;
		}
		int readInt32() {
			const unicode_char *data = readChars(2);
			return data ? *(int*)data : 0;
		}

		int readInteger() {
			const unicode_char *pdata = readChars(1);
			if (!pdata) return 0;

			if (*pdata == 0xFFF5)
				return readInt32();
			if (*pdata == 0xFFF3)
				return readInt32() | readInt32();
			else if (*pdata <= 0x7FFF)
				return *pdata;
			else
			{
				error = true;
				return 0;
			}
		}

		int readArraySize() {
			const unicode_char *pdata = readChars(1);
			if (!pdata)
				return 0;

			switch (*pdata)
			{
			case 0xFFF7:
				return 0;
			case 0xFFF8:
				return readChar();
			case 0xFFF9:
				return readInt32();
			default:
				error = true;
				return 0;
			}
		}
		StackSlot readString() {
			StackSlot fail = StackSlot::MakeEmptyString();

			const unicode_char *pdata = readChars(1);
			if (!pdata)
				return fail;

			int len = 0;
			switch (*pdata)
			{
			case 0xFFFA:
				len = readChar();
				break;
			case 0xFFFB:
				len = readInt32();
				break;
			default:
				error = true;
				return fail;
			}

			unsigned start_idx = char_idx;

			if (!readChars(len))
				return fail;

			StackSlot rv;
			FlowPtr *pp;

#ifdef FLOW_MMAP_HEAP
			if (mapped)
			{
				if (len & 0xffff0000u)
				{
					FlowPtr ptr = NewBuffer(sizeof(FlowStringRef));
					FlowStringRef *ref = (FlowStringRef*)MEMORY->GetRawPointer(ptr, sizeof(FlowStringRef), true);

					ref->header.IntVal = (len & 0xffff);

					pp = &ref->dataptr;
					StackSlot::InternalSetString(rv, ptr, len >> 16, true);
				}
				else
				{
					pp = &rv.slot_private.PtrValue;
					StackSlot::InternalSetString(rv, MakeFlowPtr(0), len, false);
				}
			}
			else
#endif
			{
				pp = mem_pool.AllocateStringRef(&rv, len); // ALLOC
			}

			*pp = RUNNER->GetStringAddr(*pinput) + start_idx * FLOW_CHAR_SIZE;
			return rv;
		}

		void readStructIndex(const StackSlot &fixups) {
			structIndex.clear();

			unsigned offset = readInt32();

			// See UTF-16 surrogate pair workaround in binary.flow, getFooterOffset(s)
			if (offset == 1)
				offset = readInt32() | readInt32();

			if (error || offset < char_idx || offset >= ssize)
			{
				error = true;
				return;
			}

			unsigned old_pos = char_idx;
			char_idx = offset;

			int isize = readArraySize();

			structIndex.resize(isize);
			structSize.resize(isize);
			structFixups.resize(isize, StackSlot::MakeVoid());

			RUNNER_DefSlots2(name_str, tmp);

			for (int i = 0; i < isize; i++)
			{
				if (readArraySize() != 2)
				{
					error = true;
					return;
				}

				int fcount = readInteger();

				name_str = readString();
				unicode_string name = RUNNER->GetString(name_str);

				structIndex[i] = RUNNER->FindStructId(encodeUtf8(name), fcount);
				structSize[i] = fcount;

				if (!fixups.IsVoid()) {
					tmp = RUNNER->EvalFunction(fixups, 1, name_str);
					RUNNER_CheckTagVoid(TStruct, tmp);

					// Some(fixup_cb)
					if (RUNNER->GetStructSize(tmp) > 0) {
						structFixups[i] = RUNNER->GetStructSlot(tmp, 0);
						has_fixups = true;
					}
				}
			}

			char_idx = old_pos;
			ssize = offset;
		}

		StackSlot readValue() {
			const unicode_char *pdata = readChars(1);
			if (error)
				return *pdefault;

			switch (*pdata)
			{
			case 0xFFFF:
				return StackSlot::MakeVoid();
			case 0xFFFC:
				pdata = readChars(4);
				if (!pdata)
					return *pdefault;
#ifdef FLOW_EMBEDDED
				// workaraund for ARMv7 alignment problem (both iOS and Android)
				FlowDouble d;
				memcpy(&d, pdata, sizeof(FlowDouble));
				return StackSlot::MakeDouble(d);
#else
				return StackSlot::MakeDouble(*(FlowDouble*)pdata);
#endif
			case 0xFFFD:
				return StackSlot::MakeBool(false);
			case 0xFFFE:
				return StackSlot::MakeBool(true);
			case 0xFFFA:
			case 0xFFFB:
				char_idx--;
				return readString();
			case 0xFFF6:
			{
				RUNNER_DefSlots1(ref);
				ref = NewRef();
				if (error) return *pdefault;
				SetRefTarget(ref, readValue());
				return ref;
			}
			case 0xFFF4:
			{
				unsigned idx = readChar();

				if (error || idx >= structIndex.size())
				{
					error = true;
					return *pdefault;
				}

				unsigned size = structSize[idx];

				RUNNER_DefSlots1(arr);
#ifdef FLOW_COMPACT_STRUCTS
				arr = NewArray(size, false);
				if (error) return *pdefault;
				for (unsigned i = 0; i < size; i++)
					RUNNER->SetArraySlot(arr, i, readValue());
#else
				arr = NewArray(size);
				if (error) return *pdefault;
				for (unsigned i = 0; i < size; i++)
					SetSlot(arr, i, readValue());
#endif

				// Apply fixup if any
				if (!structFixups[idx].IsVoid())
					return RUNNER->EvalFunction(structFixups[idx], 1, arr);

				if (!RUNNER->VerifyStruct(arr, structIndex[idx])) {
					const StructDef &def = RUNNER->GetStructDef(structIndex[idx]);
					cout << "struct name" << def.Name;
					RUNNER->PrintData(RUNNER->flow_out, arr);

					return RUNNER->MakeStruct("IllegalStruct", 0, NULL);
				}

#ifdef FLOW_COMPACT_STRUCTS
				const StructDef &def = RUNNER->GetStructDef(structIndex[idx]);
				if (size == 0)
					arr = StackSlot::MakeStruct(def.EmptyPtr, def.StructId);
				else
				{
					StackSlot tmp = StackSlot::MakeStruct(NewBuffer(def.ByteSize), def.StructId);
					mem_pool.SetInt32(tmp.GetRawStructPtr(), def.StructId);
					RUNNER->StructSlotPack(tmp, RUNNER->GetArraySlotPtr(arr, size), 0, size);
					arr = tmp;
				}
#else
				arr.Type = TStruct;
				arr.IntValue2 = structIndex[idx];
#endif

				return arr;
			}
			case 0xFFF7:
			case 0xFFF8:
			case 0xFFF9:
			{
				char_idx--;
				unsigned size = readArraySize();
				if (error)
					return *pdefault;

				RUNNER_DefSlots1(arr);
				arr = NewArray(size);
				if (error) return *pdefault;
				for (unsigned i = 0; i < size; i++)
					SetSlot(arr, i, readValue());
				return arr;
			}
			case 0xFFF5:
				return StackSlot::MakeInt(readInt32());
			case 0xFFF3:
				return StackSlot::MakeInt(readInt32() | readInt32());
			default:
				if (*pdata <= 0x7FFF)
					return StackSlot::MakeInt(*pdata);
				error = true;
				return *pdefault;
			}
		}


	public:
		BinaryDeserializer(RUNNER_VAR) : RUNNER(RUNNER) {
			//
		}

		StackSlot deserialize(const StackSlot &input, const StackSlot &defval, const StackSlot &fixups) {
			pinput = &input;
			pdefault = &defval;
			char_idx = 0;
			ssize = RUNNER->GetStringSize(input);
			error = false;
			has_fixups = false;
#ifdef FLOW_MMAP_HEAP
			mapped = false;
#endif

			RUNNER_RegisterNativeRoot(std::vector<StackSlot>, structFixups);

			readStructIndex(fixups);
			if (error || RUNNER->IsErrorReported())
				return defval;

			slot_budget = ssize + 1000;

#ifdef FLOW_MMAP_HEAP
			bool input_mapped = RUNNER->IsMappedArea(RUNNER->GetStringAddr(input));
			bool enough_free = (RUNNER->MapStringPtr - RUNNER->MapAreaBase) >= STACK_SLOT_SIZE * slot_budget;

			if (input_mapped && enough_free && !has_fixups)
			{
				MappedAreaInfo::Ptr ptr = RUNNER->FindMappedArea(RUNNER->GetStringAddr(input));

				if (ptr)
				{
					mapped = true;
					hp = hplimit = rhp = rhplimit = RUNNER->MapAreaBase;
					area = MappedAreaInfo::Ptr(new MappedAreaInfo(hp, 0));
					area->depends.push_back(ptr);
				}
			}
#endif

			StackSlot rv = readValue();

#ifdef FLOW_MMAP_HEAP
			if (mapped)
			{
				RUNNER->MapAreaBase = hp = FlowPtrAlignUp(hp, MEMORY->PageSize());
				area->length = hp - area->start;
				if (hp < hplimit)
					MEMORY->DecommitRange(hp, hplimit);
				RUNNER->MappedAreas[area->start] = area;
			}
#endif

			if (char_idx < ssize)
				RUNNER->flow_out << "Did not understand all!";
			return rv;
		}

		bool success() { return !error; }
	};

	StackSlot ByteCodeRunner::fromBinary2(RUNNER_ARGS) {
		RUNNER_CopyArgArray(new_args, 2, 1);
		new_args[2] = StackSlot::MakeVoid();
		return fromBinary(RUNNER, new_args);
	}

	StackSlot ByteCodeRunner::fromBinary(RUNNER_ARGS)
	{
		RUNNER_PopArgs3(value, defval, fixups);

		BinaryDeserializer worker(RUNNER);

#if defined(DEBUG_FLOW) || defined(FLOW_EMBEDDED)
		double start_time = GetCurrentTime();
#endif

		StackSlot rv = worker.deserialize(value, defval, fixups);

#if defined(DEBUG_FLOW) || defined(FLOW_EMBEDDED)
		RUNNER->flow_err << "Deserialized in " << (GetCurrentTime() - start_time) << " seconds." << endl;
#endif

		return rv;
	}

	StackSlot ByteCodeRunner::loaderUrl(RUNNER_ARGS) {
		IGNORE_RUNNER_ARGS;
		return mem_pool.AllocateString(RUNNER->UrlString);
	}

	StackSlot ByteCodeRunner::getUrlParameter(RUNNER_ARGS) {
		RUNNER_PopArgs1(name);
		RUNNER_CheckTag(TString, name);

		return mem_pool.AllocateString(RUNNER->UrlParameters[RUNNER->GetString(name)]);
	}

	StackSlot ByteCodeRunner::getAllUrlParameters(RUNNER_ARGS) {
		IGNORE_RUNNER_ARGS;

		int i = 0;

		RUNNER_DefSlots1(array);
		array = mem_pool.AllocateArray(RUNNER->UrlParameters.size());
		for (T_UrlParameters::iterator it = RUNNER->UrlParameters.begin(); it != RUNNER->UrlParameters.end(); ++it) {
			RUNNER_DefSlots1(keyvalue);
			keyvalue = mem_pool.AllocateArray(2);
			RUNNER->SetArraySlot(keyvalue, 0, mem_pool.AllocateString((*it).first));
			RUNNER->SetArraySlot(keyvalue, 1, mem_pool.AllocateString((*it).second));

			RUNNER->SetArraySlot(array, i, keyvalue);
			i++;
		}

		return array;
	}

	StackSlot ByteCodeRunner::NativeGetTargetName(RUNNER_ARGS) {
		IGNORE_RUNNER_ARGS;
		//std::set<std::string> tokens(RUNNER->TargetTokens);

		//T_NativeHosts::iterator it;;
		//for (it = RUNNER->NativeHosts.begin(); it != RUNNER->NativeHosts.end(); ++it)
		//	(*it)->GetTargetTokens(tokens);

		stringstream ss;
		ss << "c++,native";
		//ss << "c++,native";
#if defined(WIN32)
		ss << ",windows";
#elif defined(__linux__)
		ss << ",linux";
#elif defined(__APPLE__)
#if TARGET_OS_IPHONE
		ss << ",iOS";
#elif TARGET_OS_MAC
		ss << ",macosx";
#else
		ss << ",apple";
#endif
#endif
#if defined(QT_VERSION)
		ss << ",qt";
#endif

		//for (std::set<std::string>::iterator it = tokens.begin(); it != tokens.end(); ++it)
		//	ss << "," << *it;
		return mem_pool.AllocateString(parseUtf8(ss.str()));
	}



#include "flow_rendersupport.hpp"

	StackSlot ByteCodeRunner::currentClip(RUNNER_ARGS) {
		IGNORE_RUNNER_ARGS;

		return StackSlot::MakeNative(::currentClip());
	}

	StackSlot ByteCodeRunner::makeTextField(RUNNER_ARGS) {
		RUNNER_PopArgs1(fontFamily);

		RUNNER->PrintData(RUNNER->flow_out, fontFamily); printf("\n");
		
		return ::makeTextfield(fontFamily);
	}

	StackSlot ByteCodeRunner::setTextAndStyle(RUNNER_ARGS) {
		RUNNER_PopArgs12(textfield, text, fontfamily, fontsize, fontweight, fontslope, fillcolour, fillopacity, letterspacing, backgroundcolour, backgroundopacity, forTextinput);
		
		RUNNER->PrintData(RUNNER->flow_out, textfield); printf("\n");
		RUNNER->PrintData(RUNNER->flow_out, text); printf("\n");
		RUNNER->PrintData(RUNNER->flow_out, fontfamily); printf("\n");
		RUNNER->PrintData(RUNNER->flow_out, fontsize); printf("\n");

		::setTextAndStyle(textfield, text, fontfamily, fontsize, fontweight, fontslope, fillcolour, fillopacity, letterspacing, backgroundcolour, backgroundopacity, forTextinput);
		RETVOID;
	}

	StackSlot ByteCodeRunner::removeEventListener(RUNNER_ARGS, void*) {
		debug_log(printf("StackSlot ByteCodeRunner::removeEventListener(RUNNER_ARGS, void*)\n"));
		const StackSlot *slot = RUNNER->GetClosureSlotPtr(RUNNER_CLOSURE, 2);
		RUNNER->PrintData(RUNNER->flow_out, slot[0]); printf("\n");
		RUNNER->PrintData(RUNNER->flow_out, slot[1]); printf("\n");
		::executeCallback(slot[0].GetInt());
		RUNNER->callbacks.erase(slot[1].GetInt());
		RETVOID;
	}

	StackSlot ByteCodeRunner::executeCallback(RUNNER_ARGS, void*) {
		debug_log(printf("StackSlot ByteCodeRunner::executeCallback(RUNNER_ARGS, void*)\n"));
		const StackSlot *slot = RUNNER->GetClosureSlotPtr(RUNNER_CLOSURE, 2);
		RUNNER->PrintData(RUNNER->flow_out, slot[0]); printf("\n");
		RUNNER->PrintData(RUNNER->flow_out, slot[1]); printf("\n");
		::executeCallback(slot[0].GetInt());
		RETVOID;
	}

	void ByteCodeRunner::callback_onevent(int _runner, int cb_id) {
		ByteCodeRunner* runner = (ByteCodeRunner*)_runner;
		debug_log(printf("void ByteCodeRunner::callback_onevent(ByteCodeRunner* runner, int cb_id)\n"));
		T_Callbacks::iterator cit = runner->callbacks.find(cb_id);
		if (cit != runner->callbacks.end()) {
			runner->EvalFunctionArr(cit->second, 0, NULL);
		}
	}

	void ByteCodeRunner::callback_onkeyevent(int _runner, int cb_id, int s_ptr, int s_len, int ctrl, int shift, int alt, int meta, int code, int prevent_fn) {
		ByteCodeRunner* runner = (ByteCodeRunner*)_runner;
		debug_log(printf("void ByteCodeRunner::callback_onkeyevent(ByteCodeRunner* runner, int cb_id)\n"));

		StackSlot arr = mem_pool.AllocateUninitializedArray(7);
		StackSlot* parr = mem_pool.GetArrayWritePtr(arr, 7);

		StackSlot s = mem_pool.AllocateString((unicode_char*)s_ptr, s_len);

		//StackSlot s;
		//mem_pool.
		//unicode_char *tmp = mem_pool.AllocateStringBuffer(&s, s_len); // ALLOC
		//memcpy(tmp, (void*)s_ptr, s_len * FLOW_CHAR_SIZE);

		parr[0] = s;
		parr[1] = StackSlot::MakeInt(ctrl);
		parr[2] = StackSlot::MakeInt(shift);
		parr[3] = StackSlot::MakeInt(alt);
		parr[4] = StackSlot::MakeInt(meta);
		parr[5] = StackSlot::MakeInt(code);
		parr[6] = runner->AllocateNativeClosure(removeEventListener, "callback_onkeyevent$prevent_default", 0, NULL, 1, StackSlot::MakeInt(prevent_fn));

		runner->PrintData(runner->flow_out, arr); printf("\n");

		T_Callbacks::iterator cit = runner->callbacks.find(cb_id);
		if (cit != runner->callbacks.end()) {
			runner->EvalFunctionArr(cit->second, 7, parr);
		}
	}

	int ByteCodeRunner::addEventCallback(ByteCodeRunner* runner, StackSlot& cb) {
//		printf("int ByteCodeRunner::addEventCallback(ByteCodeRunner* runner, StackSlot& cb)\n");
		int id = runner->next_cb_id++;
		runner->callbacks[id] = cb;
		return id;
	}

	StackSlot ByteCodeRunner::addEventListener(RUNNER_ARGS) {
		RUNNER_PopArgs3(clip, event, cb);

		debug_log(printf("StackSlot ByteCodeRunner::addEventListener(RUNNER_ARGS)\n"));

		RUNNER->PrintData(RUNNER->flow_out, clip); printf("\n");
		RUNNER->PrintData(RUNNER->flow_out, event); printf("\n");
		int cb_id = addEventCallback(RUNNER, cb);
		debug_log(printf("%d\n", cb_id));
		StackSlot s_cb = StackSlot::MakeInt((int)&RUNNER->callback_onevent);
		StackSlot s_runner = StackSlot::MakeInt((int)RUNNER);
		RUNNER->PrintData(RUNNER->flow_out, s_cb); printf(" (%p)\n", (void*)&RUNNER->callback_onevent);
		RUNNER->PrintData(RUNNER->flow_out, s_runner); printf(" (%p)\n", (void*)RUNNER);

		int disposerFnId = ::addEventListener(StackSlot::MakeInt(clip.GetNativeValId()), event, s_cb, s_runner, StackSlot::MakeInt(cb_id));

		return RUNNER->AllocateNativeClosure(removeEventListener, "addEventListener$disposer", 0, NULL, 2, StackSlot::MakeInt(disposerFnId), StackSlot::MakeInt(cb_id));
	}

	StackSlot ByteCodeRunner::Timer(RUNNER_ARGS) {
		RUNNER_PopArgs2(time_ms, cb);
		RUNNER_CheckTag(TInt, time_ms);

		debug_log(printf("StackSlot ByteCodeRunner::Timer(RUNNER_ARGS)\n"));

		RUNNER->PrintData(RUNNER->flow_out, time_ms); printf("\n");
		int cb_id = addEventCallback(RUNNER, cb);
		StackSlot s_cb = StackSlot::MakeInt((int)&RUNNER->callback_onevent);
		StackSlot s_runner = StackSlot::MakeInt((int)RUNNER);

		::timer(time_ms, s_cb, s_runner, StackSlot::MakeInt(cb_id));

		RETVOID;
	}

	StackSlot ByteCodeRunner::addKeyEventListener(RUNNER_ARGS) {
		RUNNER_PopArgs3(clip, event, cb);

		debug_log(printf("StackSlot ByteCodeRunner::addKeyEventListener(RUNNER_ARGS)\n"));

		RUNNER->PrintData(RUNNER->flow_out, clip); printf("\n");
		RUNNER->PrintData(RUNNER->flow_out, event); printf("\n");
		int cb_id = addEventCallback(RUNNER, cb);
		debug_log(printf("%d\n", cb_id));
		StackSlot s_cb = StackSlot::MakeInt((int)&RUNNER->callback_onkeyevent);
		StackSlot s_runner = StackSlot::MakeInt((int)RUNNER);
		RUNNER->PrintData(RUNNER->flow_out, s_cb); printf(" (%p)\n", (void*)&RUNNER->callback_onkeyevent);
		RUNNER->PrintData(RUNNER->flow_out, s_runner); printf(" (%p)\n", (void*)RUNNER);

		int disposerFnId = ::addKeyEventListener(StackSlot::MakeInt(clip.GetNativeValId()), event, s_cb, s_runner, StackSlot::MakeInt(cb_id));

		return RUNNER->AllocateNativeClosure(removeEventListener, "addKeyEventListener$disposer", 0, NULL, 2, StackSlot::MakeInt(disposerFnId), StackSlot::MakeInt(cb_id));
	}

	StackSlot ByteCodeRunner::getContent(RUNNER_ARGS) {
		RUNNER_PopArgs1(clip);
		debug_log(printf("StackSlot ByteCodeRunner::getContent(RUNNER_ARGS)\n"));
		RUNNER->PrintData(RUNNER->flow_out, clip); printf("\n");

		unicode_string s = ::getContent(clip.GetNativeValId());
		return mem_pool.AllocateString(s);
	}

	StackSlot ByteCodeRunner::getTextMetrics(RUNNER_ARGS) {
		RUNNER_PopArgs1(clip);
		RUNNER_DefSlots1(ret_array);

		debug_log(printf("StackSlot ByteCodeRunner::getTextMetrics(RUNNER_ARGS)\n"));
		RUNNER->PrintData(RUNNER->flow_out, clip); printf("\n");

		std::vector<double> v = ::getTextMetrics(clip.GetNativeValId());
		
		ret_array = mem_pool.AllocateArray(3);
		RUNNER->SetArraySlot(ret_array, 0, StackSlot::MakeDouble(v[0]));
		RUNNER->SetArraySlot(ret_array, 1, StackSlot::MakeDouble(v[1]));
		RUNNER->SetArraySlot(ret_array, 2, StackSlot::MakeDouble(v[2]));

		printf("ret_array: "); RUNNER->PrintData(RUNNER->flow_out, ret_array); printf("\n");

		return ret_array;
	}

	StackSlot ByteCodeRunner::getTextFieldWidth(RUNNER_ARGS) {
		RUNNER_PopArgs1(clip);

		debug_log(printf("StackSlot ByteCodeRunner::getTextFieldWidth(RUNNER_ARGS)\n"));
		RUNNER->PrintData(RUNNER->flow_out, clip); printf("\n");

		double v = ::getTextFieldWidth(clip.GetNativeValId());
		return StackSlot::MakeDouble(v);
	}

	StackSlot ByteCodeRunner::getTextFieldHeight(RUNNER_ARGS) {
		RUNNER_PopArgs1(clip);

		debug_log(printf("StackSlot ByteCodeRunner::getTextFieldHeight(RUNNER_ARGS)\n"));
		RUNNER->PrintData(RUNNER->flow_out, clip); printf("\n");

		double v = ::getTextFieldHeight(clip.GetNativeValId());
		return StackSlot::MakeDouble(v);
	}

	StackSlot ByteCodeRunner::setAdvancedText(RUNNER_ARGS) {
		RUNNER_PopArgs4(clip, sharpness, antialias, grid_fit);
		RUNNER_CheckTag3(TInt, sharpness, antialias, grid_fit);

		debug_log(printf("StackSlot ByteCodeRunner::setAdvancedText(RUNNER_ARGS)\n"));
		RUNNER->PrintData(RUNNER->flow_out, clip); RUNNER->flow_out << ": ";
		RUNNER->PrintData(RUNNER->flow_out, sharpness); RUNNER->flow_out << ", ";
		RUNNER->PrintData(RUNNER->flow_out, antialias); RUNNER->flow_out << ", ";
		RUNNER->PrintData(RUNNER->flow_out, grid_fit); RUNNER->flow_out << endl;

		::setAdvancedText(clip.GetNativeValId(), sharpness.GetInt(), antialias.GetInt(), grid_fit.GetInt());
		RETVOID;
	}

	StackSlot ByteCodeRunner::addChild(RUNNER_ARGS) {
		RUNNER_PopArgs2(parent, child);

		debug_log(printf("StackSlot ByteCodeRunner::addChild(RUNNER_ARGS): "));
		RUNNER->PrintData(RUNNER->flow_out, parent); RUNNER->flow_out << ", ";
		RUNNER->PrintData(RUNNER->flow_out, child); RUNNER->flow_out << endl;

		::addChild(parent.GetNativeValId(), child.GetNativeValId());
		RETVOID;
	}

	StackSlot ByteCodeRunner::addFilters(RUNNER_ARGS) {
		RUNNER_PopArgs2(clip, filters);
		RUNNER_CheckTag(TArray, filters);

		debug_log(printf("StackSlot ByteCodeRunner::addFilters(RUNNER_ARGS): "));
		RUNNER->PrintData(RUNNER->flow_out, clip); RUNNER->flow_out << ", ";
		RUNNER->PrintData(RUNNER->flow_out, filters); RUNNER->flow_out << endl;

		int length = RUNNER->GetArraySize(filters);
		StackSlot arr = (length > 0) ? mem_pool.AllocateArray(length) : StackSlot::MakeEmptyArray();

		for (int i=0; i < length; ++i) {
			RUNNER->SetArraySlot(arr, i, StackSlot::MakeInt(RUNNER->GetArraySlot(filters, i).GetNativeValId()));
		}

		::addFilters(clip.GetNativeValId(), arr);
		RETVOID;
	}

	StackSlot ByteCodeRunner::makeBlur(RUNNER_ARGS) {
		RUNNER_PopArgs2(radius, spread);
		RUNNER_CheckTag2(TDouble, radius, spread);

		return ::makeBlur(radius.GetDouble(), spread.GetDouble());
	}

	StackSlot ByteCodeRunner::makeBevel(RUNNER_ARGS) {
		RUNNER_PopArgs9(angle, distance, radius, spread, color1, alpha1, color2, alpha2, inner);
		RUNNER_CheckTag6(TDouble, angle, distance, radius, spread, alpha1, alpha2);
		RUNNER_CheckTag2(TInt, color1, color2);
		RUNNER_CheckTag(TBool, inner);

		return ::makeBevel(angle.GetDouble(), distance.GetDouble(), radius.GetDouble(), spread.GetDouble(), color1.GetInt(), alpha1.GetDouble(), color2.GetInt(), alpha2.GetDouble(), inner.GetBool());
	}

	StackSlot ByteCodeRunner::makeDropShadow(RUNNER_ARGS) {
		RUNNER_PopArgs7(angle, distance, radius, spread, color_val, alpha, inner);
		RUNNER_CheckTag5(TDouble, angle, distance, radius, spread, alpha);
		RUNNER_CheckTag(TInt, color_val);
		RUNNER_CheckTag(TBool, inner);

		return ::makeDropShadow(angle.GetDouble(), distance.GetDouble(), radius.GetDouble(), spread.GetDouble(), color_val.GetInt(), alpha.GetDouble(), inner.GetBool());
	}

	StackSlot ByteCodeRunner::makeGlow(RUNNER_ARGS) {
		RUNNER_PopArgs5(radius, spread, color_val, alpha, inner);
		RUNNER_CheckTag3(TDouble, radius, spread, alpha);
		RUNNER_CheckTag(TInt, color_val);
		RUNNER_CheckTag(TBool, inner);

		return ::makeGlow(radius.GetDouble(), spread.GetDouble(), color_val.GetInt(), alpha.GetDouble(), inner.GetBool());
	}

	StackSlot ByteCodeRunner::enableResize(RUNNER_ARGS) {
		IGNORE_RUNNER_ARGS;
		::enableResize();
		RETVOID;
	}

	StackSlot ByteCodeRunner::enumFromTo(RUNNER_ARGS) {
		RUNNER_PopArgs2(from_arg, to_arg);
		RUNNER_CheckTag2(TInt, from_arg, to_arg);

		int from = from_arg.GetInt();
		int to = to_arg.GetInt();
		int len = to - from + 1;

		if (len <= 0) {
			return StackSlot::MakeEmptyArray();
		}

		// Do not use safe wrappers for speed:
		StackSlot arrslot = mem_pool.AllocateUninitializedArray(len); // ALLOC

		if (RUNNER->IsErrorReported())
			return StackSlot::MakeVoid();

		StackSlot *arr = (StackSlot*)mem_pool.GetRawPointer(arrslot.GetInternalArrayPtr(), len * STACK_SLOT_SIZE, true);
		for (int j = 0; j < len; j++)
			arr[j] = StackSlot::MakeInt(from + j);

		return arrslot;
	}

	enum TreeFields {
		TreeKey = 0, TreeValue, TreeLeft, TreeRight, TreeDepth
	};

	StackSlot ByteCodeRunner::fast_lookupTree(RUNNER_ARGS) {
		RUNNER_PopArgs2(tree, key);

		for (;;) {
			RUNNER_CheckTag(TStruct, tree);

			if (RUNNER->IsTreeEmptyStruct(tree))
				return RUNNER->AllocateNoneStruct();

			RUNNER_CheckStructType(tree, TreeNode, "lookupTree");

			int cmpv = RUNNER->Compare(key, RUNNER->GetStructSlot(tree, TreeKey)); // k
			if (cmpv < 0)
				tree = RUNNER->GetStructSlot(tree, TreeLeft); // l
			else if (cmpv > 0)
				tree = RUNNER->GetStructSlot(tree, TreeRight); // r
			else
				return RUNNER->AllocateSomeStruct(RUNNER->GetStructSlot(tree, TreeValue)); // v
		}
	}

	static int treeDepth(RUNNER_VAR, const StackSlot &tree) {
		if (RUNNER->IsTreeNodeStruct(tree)) {
			const StackSlot depth = RUNNER->GetStructSlot(tree, TreeDepth);
			if (!depth.IsInt()) {
				RUNNER->ReportTagError(depth, TInt, "depth", "depth in binary tree");
				return -1;
			}
			return depth.GetInt();
		}

		return 0;
	}

	static StackSlot mkTreeNode(RUNNER_VAR, StackSlot *node, int depth = -1) {
		// TreeNode(k, v, left, right, max(treeDepth(left), treeDepth(right)) + 1);
		if (depth < 0) {
			int depth1 = treeDepth(RUNNER, node[TreeLeft]);
			int depth2 = treeDepth(RUNNER, node[TreeRight]);
			depth = std::max(depth1, depth2) + 1;
		}

		StackSlot rv = RUNNER->AllocateTreeNodeStruct();
		RUNNER->StructSlotPack(rv, node, 0, TreeDepth);
		RUNNER->SetStructSlot(rv, TreeDepth, StackSlot::MakeInt(depth));
		return rv;
	}

	// on-stack rotation
	static bool rotateRight(RUNNER_VAR, StackSlot *node) {
		if (!RUNNER->IsTreeNodeStruct(node[TreeLeft]))
			return false;

		// TreeNode(ck, cv, cleft, cright, cdepth):
		//const StackSlot *lnode = RUNNER->GetArraySlotPtr(node[TreeLeft], 5);

		// tmp = mkTreeNode(k, v, cright, right);
		RUNNER_DefSlotArray(newnode, 4);
		newnode[TreeKey] = node[TreeKey];
		newnode[TreeValue] = node[TreeValue];
		newnode[TreeLeft] = RUNNER->GetStructSlot(node[TreeLeft], TreeRight);
		newnode[TreeRight] = node[TreeRight];

		// mkTreeNode(ck, cv, cleft, tmp);
		node[TreeKey] = RUNNER->GetStructSlot(node[TreeLeft], TreeKey);
		node[TreeValue] = RUNNER->GetStructSlot(node[TreeLeft], TreeValue);
		node[TreeLeft] = RUNNER->GetStructSlot(node[TreeLeft], TreeLeft);
		node[TreeRight] = mkTreeNode(RUNNER, newnode);
		return true;
	}

	// on-stack rotation
	static bool rotateLeft(RUNNER_VAR, StackSlot *node) {
		if (!RUNNER->IsTreeNodeStruct(node[TreeRight]))
			return false;

		// TreeNode(ck, cv, cleft, cright, cdepth):
		//const StackSlot *rnode = RUNNER->GetArraySlotPtr(node[TreeRight], 5);

		// tmp = mkTreeNode(k, v, left, cleft)
		RUNNER_DefSlotArray(newnode, 4);
		newnode[TreeKey] = node[TreeKey];
		newnode[TreeValue] = node[TreeValue];
		newnode[TreeLeft] = node[TreeLeft];
		newnode[TreeRight] = RUNNER->GetStructSlot(node[TreeRight], TreeLeft);

		// mkTreeNode(ck, cv, tmp, cright);
		node[TreeKey] = RUNNER->GetStructSlot(node[TreeRight], TreeKey);
		node[TreeValue] = RUNNER->GetStructSlot(node[TreeRight], TreeValue);
		node[TreeRight] = RUNNER->GetStructSlot(node[TreeRight], TreeRight);
		node[TreeLeft] = mkTreeNode(RUNNER, newnode);
		return true;
	}

	StackSlot ByteCodeRunner::fast_treeRightRotation(RUNNER_ARGS) {
		RUNNER_PopArgs1(tree);
		RUNNER_CheckTag(TStruct, tree);

		if (RUNNER->IsTreeNodeStruct(tree)) {
			RUNNER_DefSlotArray(node, 4);
			RUNNER->StructSlotUnpack(tree, node, 0, 4);

			if (rotateRight(RUNNER, node))
				return mkTreeNode(RUNNER, node);
		}

		return tree;
	}

	StackSlot ByteCodeRunner::fast_treeLeftRotation(RUNNER_ARGS) {
		RUNNER_PopArgs1(tree);
		RUNNER_CheckTag(TStruct, tree);

		if (RUNNER->IsTreeNodeStruct(tree)) {
			RUNNER_DefSlotArray(node, 4);
			RUNNER->StructSlotUnpack(tree, node, 0, 4);

			if (rotateLeft(RUNNER, node))
				return mkTreeNode(RUNNER, node);
		}

		return tree;
	}

	StackSlot ByteCodeRunner::fast_rebalancedTree(RUNNER_ARGS) {
		StackSlot *newnode = &RUNNER_ARG(0);

		int leftDepth = treeDepth(RUNNER, newnode[TreeLeft]);
		int rightDepth = treeDepth(RUNNER, newnode[TreeRight]);
		int balance = leftDepth - rightDepth;

		if (balance <= -2) {
			RUNNER_CheckStructType(newnode[TreeRight], TreeNode, "lookupTree");

			//const StackSlot *rnode = RUNNER->GetArraySlotPtr(newnode[TreeRight], 5);
			int rld = treeDepth(RUNNER, RUNNER->GetStructSlot(newnode[TreeRight], TreeLeft));
			int rrd = treeDepth(RUNNER, RUNNER->GetStructSlot(newnode[TreeRight], TreeRight));
			if (rld >= rrd)
				newnode[TreeRight] = fast_treeRightRotation(RUNNER, &newnode[TreeRight]);

			rotateLeft(RUNNER, newnode);

			return mkTreeNode(RUNNER, newnode);
		} else if (balance >= 2) {
			RUNNER_CheckStructType(newnode[TreeLeft], TreeNode, "lookupTree");

			//const StackSlot *lnode = RUNNER->GetArraySlotPtr(newnode[TreeLeft], 5);
			int lld = treeDepth(RUNNER, RUNNER->GetStructSlot(newnode[TreeLeft], TreeLeft));
			int lrd = treeDepth(RUNNER, RUNNER->GetStructSlot(newnode[TreeLeft], TreeRight));
			if (lld <= lrd)
				newnode[TreeLeft] = fast_treeLeftRotation(RUNNER, &newnode[TreeLeft]);

			rotateRight(RUNNER, newnode);

			return mkTreeNode(RUNNER, newnode);
		} else {
			return mkTreeNode(RUNNER, newnode, std::max(leftDepth, rightDepth) + 1);
		}
	}

	StackSlot ByteCodeRunner::fast_setTree(RUNNER_ARGS) {
		RUNNER_PopArgs3(tree, key, value);
		RUNNER_DefSlotArray(newnode, 4);

		RUNNER_CheckTag(TStruct, tree);

		if (RUNNER->IsTreeEmptyStruct(tree)) {
			// TreeEmpty():
			newnode[TreeKey] = key;
			newnode[TreeValue] = value;
			newnode[TreeLeft] = newnode[TreeRight] = tree;

			return mkTreeNode(RUNNER, newnode, 1);
		} else {
			// TreeNode(k, v, l, r, depth):
			RUNNER_CheckStructType(tree, TreeNode, "lookupTree");
			RUNNER->StructSlotUnpack(tree, newnode, 0, 4);

			int cmpv = RUNNER->Compare(key, newnode[TreeKey]);
			if (cmpv < 0) {
				tree = newnode[TreeLeft]; // reuse initial argument memory
				newnode[TreeLeft] = fast_setTree(RUNNER, &RUNNER_ARG(0));

				return fast_rebalancedTree(RUNNER, newnode);
			} else if (cmpv > 0) {
				tree = newnode[TreeRight]; // reuse initial argument memory
				newnode[TreeRight] = fast_setTree(RUNNER, &RUNNER_ARG(0));

				return fast_rebalancedTree(RUNNER, newnode);
			} else {
				// Exact match => just replace
				StackSlot depth = RUNNER->GetStructSlot(tree, TreeDepth);
				RUNNER_CheckTag(TInt, depth);

				newnode[TreeValue] = value;

				return mkTreeNode(RUNNER, newnode, depth.GetInt());
			}
		}
	}

	StackSlot ByteCodeRunner::getStage(RUNNER_ARGS) {
		IGNORE_RUNNER_ARGS;
		return ::getStage();
	}

	StackSlot ByteCodeRunner::getStageWidth(RUNNER_ARGS) {
		IGNORE_RUNNER_ARGS;
		return StackSlot::MakeDouble(::getStageWidth());
	}

	StackSlot ByteCodeRunner::getStageHeight(RUNNER_ARGS) {
		IGNORE_RUNNER_ARGS;
		return StackSlot::MakeDouble(::getStageHeight());
	}

	StackSlot ByteCodeRunner::random(RUNNER_ARGS) {
		IGNORE_RUNNER_ARGS;
		return StackSlot::MakeDouble(FlowDouble(rand()) / (FlowDouble(RAND_MAX) + 1));
	}

#include <ctime>
	StackSlot ByteCodeRunner::NativeTimestamp(RUNNER_ARGS) {
		IGNORE_RUNNER_ARGS;
		
//		return StackSlot::MakeDouble(GetTickCount() * 1000.0);
		return StackSlot::MakeDouble(std::time(NULL));
	}

	StackSlot ByteCodeRunner::makeClip(RUNNER_ARGS) {
		IGNORE_RUNNER_ARGS;
		return ::makeClip();
	}
