#pragma once

#include "flow_native_callback.hpp"

StackSlot makeTextfield(const StackSlot& fontFamily) {
	StackSlot arr = mem_pool.AllocateUninitializedArray(1);
	StackSlot* parr = mem_pool.GetArrayWritePtr(arr, 1);
	parr[0] = fontFamily;

	printf("makeTextfield\n");
	int id = EM_ASM_INT({
		var args = decode_flow_data($0, $1);
		Module.print('data: (' + args + ')');
		Module.print('makeTextfield(' + args[0] + ')');
		var v = IDHandler.createObjectId(RenderSupport.makeTextField(args[0]));
		Module.print('makeTextfield(' + args[0] + ') return: ' + v);
		return v;
	}, mem_pool.data_ptr(), &arr);
	return StackSlot::MakeNative(id);
}

void setTextAndStyle(const StackSlot& textfield, const StackSlot& text, const StackSlot& fontfamily, const StackSlot& fontsize, const StackSlot& fontweight,
	const StackSlot& fontslope, const StackSlot& fillcolour, const StackSlot& fillopacity, const StackSlot& letterspacing, const StackSlot& backgroundcolour, 
	const StackSlot& backgroundopacity, const StackSlot& forTextinput) {
	StackSlot arr = mem_pool.AllocateUninitializedArray(12);
	StackSlot* parr = mem_pool.GetArrayWritePtr(arr, 12);
	parr[0] = StackSlot::MakeInt(textfield.GetNativeValId());
	parr[1] = text;
	parr[2] = fontfamily;
	parr[3] = fontsize;
	parr[4] = fontweight;
	parr[5] = fontslope;
	parr[6] = fillcolour;
	parr[7] = fillopacity;
	parr[8] = letterspacing;
	parr[9] = backgroundcolour;
	parr[10] = backgroundopacity;
	parr[11] = forTextinput;

	EM_ASM_({
		var args = decode_flow_data($0, $1);
		Module.print('setTextAndStyle out: ' + args);
		//Module.print('    0: ' + $0 + ' ' + typeof($0));
		//Module.print('    1: ' + UTF16ToString($1));
		//Module.print('    2: ' + UTF16ToString($2));
		//Module.print('    3: ' + $3);
		//Module.print('    4: ' + $4);
		//Module.print('    5: ' + UTF16ToString($5));
		//Module.print('    6: ' + $6);
		//Module.print('    7: ' + $7);
		//Module.print('    8: ' + $8);
		//Module.print('    9: ' + $9);
		//Module.print('    10: ' + $10);
		//Module.print('    11: ' + $11);
		RenderSupport.setTextAndStyle(IDHandler.getObjectFromID(args[0]), args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11]);
	}, mem_pool.data_ptr(), &arr);
}

void addChild(int parentId, int childId) { 
	EM_ASM_({
		RenderSupport.addChild(IDHandler.getObjectFromID($0), IDHandler.getObjectFromID($1));
		Module.print('addChild');
	}, parentId, childId);
}

void executeCallback(int callbackFnId) {
	EM_ASM_({
		testApi.executeCallback($0, true);
		Module.print('Execute callbackFnId: ' + $0);
	}, callbackFnId);
}

void timer(const StackSlot& ms, const StackSlot& cbPtr, const StackSlot& runner, const StackSlot& callbackId) {
	StackSlot arr = mem_pool.AllocateUninitializedArray(4);
	StackSlot* parr = mem_pool.GetArrayWritePtr(arr, 4);
	parr[0] = ms;
	parr[1] = cbPtr;
	parr[2] = runner;
	parr[3] = callbackId;

	int id = EM_ASM_INT({
		var args = decode_flow_data($0, $1);
		Module.print('timer: ' + args);

		NativeHx.timer(args[0], function() {
			Module.print('Try to call timer callback: ms: ' + args[0] + ' ptr: ' + args[1] + ' args: ' + args[2] + ', ' + args[3]);
			Runtime.dynCall('vii', args[1], [args[2], args[3]]);
		});
	}, mem_pool.data_ptr(), &arr);
}

int addEventListener(const StackSlot& clip, const StackSlot& event, const StackSlot& cbPtr, const StackSlot& runner, const StackSlot& callbackId) {
	StackSlot arr = mem_pool.AllocateUninitializedArray(5);
	StackSlot* parr = mem_pool.GetArrayWritePtr(arr, 5);
	parr[0] = clip;
	parr[1] = event;
	parr[2] = cbPtr;
	parr[3] = runner;
	parr[4] = callbackId;

	int id = EM_ASM_INT({
		var args = decode_flow_data($0, $1);
		Module.print('addEventListener: ' + args);
		var disposer = RenderSupport.addEventListener(IDHandler.getObjectFromID(args[0]), args[1], function () {
			Module.print('Try to call event callback: event: ' + args[1] + ' ptr: ' + args[2] + ' args: ' + args[3] + ', ' + args[4]);
			Runtime.dynCall('vii', args[2], [args[3], args[4]]);
		});
		return IDHandler.createObjectId(disposer);
	}, mem_pool.data_ptr(), &arr);

	printf("addEventListener c part  %d\n", id);

	return id;
}

//const std::function<void(std::string, bool, bool, bool, bool, int, std::function<void()>)>& cb
int addKeyEventListener(const StackSlot& clip, const StackSlot& event, const StackSlot& cbPtr, const StackSlot& runner, const StackSlot& callbackId) {
	StackSlot arr = mem_pool.AllocateUninitializedArray(5);
	StackSlot* parr = mem_pool.GetArrayWritePtr(arr, 5);
	parr[0] = clip;
	parr[1] = event;
	parr[2] = cbPtr;
	parr[3] = runner;
	parr[4] = callbackId;

	int id = EM_ASM_INT({
		var args = decode_flow_data($0, $1);
		Module.print('addKeyEventListener: ' + args);
		var disposer = RenderSupport.addKeyEventListener(IDHandler.getObjectFromID(args[0]), args[1], function(s1, b1, b2, b3, b4, i1, fn) {
			Module.print('Try to call addKeyEventListener callback by pointer: ' + $2 + ' string: ' + s1 + ' bytes per char ' + $4);

			//var bufLen = s1.length * 2 + 2;
			//var strPtr = Module._malloc(bufLen);
			//Module.stringToUTF16(s1, strPtr, bufLen);

			var ptr = testApi.encodeString(s1);

			subFuncId = IDHandler.createObjectId(fn);

			Runtime.dynCall('viiiiiiiiii', args[2],[args[3], args[4], ptr, s1.length, b1, b2, b3, b4, i1, subFuncId]);

			IDHandler.revokeObjectId(subFuncId);
			_free(ptr);
		});
		return IDHandler.createObjectId(disposer);
	}, mem_pool.data_ptr(), &arr);

	return id;
}

unicode_string getContent(int textid) {
	int* buffer = (int*)EM_ASM_INT({
		var v = RenderSupport.getContent(IDHandler.getObjectFromID($0));
		Module.print('getContent return: ' + v);

		var strptr = testApi.encodeString(v, $1);

		var buffer = _malloc(2 * 4);
		HEAP32[buffer >> 2] = v.length;
		HEAP32[(buffer + 4)>> 2] = strptr;

		return buffer;
	}, textid);

	int strlen = buffer[0];
	int strptr = buffer[1];

	unicode_string ret = getStringFromJS(strptr, strlen);

	free((int*)strptr);
	free(buffer);

	return ret;
}

std::vector<double> getTextMetrics(int textid) {
	double* s = (double*)EM_ASM_INT({
		var arr = RenderSupport.getTextMetrics(IDHandler.getObjectFromID($0));
		arr.unshift(arr.length);
		var buffer = _malloc(arr.length * 8);

		HEAPF64.set(arr, buffer >> 3);

		return buffer;
	}, textid);

	std::vector<double> ret = extractArrayFromJSMem<double>(s);

	free(s);

	return ret;
}

double getTextFieldHeight(int textid) {
	double ret = EM_ASM_DOUBLE({
		v = RenderSupport.getTextFieldHeight(IDHandler.getObjectFromID($0));
		Module.print('getTextFieldHeight return: ' + v);
		return v;
	}, textid);
	return ret;
}

double getTextFieldWidth(int textid) {
	double ret = EM_ASM_DOUBLE({
		v = RenderSupport.getTextFieldWidth(IDHandler.getObjectFromID($0));
		Module.print('getTextFieldWidth return: ' + v);
		return v;
	}, textid);
	return ret;
}

void setAdvancedText(int textid, const int sharpness, const int antiAliasType, const int gridFitType) {
	EM_ASM_({
		Module.print('setAdvancedText: ' + $0 + ' ' + $1 + ' ' + $2 + ' ' + $3);
		RenderSupport.setAdvancedText(IDHandler.getObjectFromID($0), $1, $2, $3);
	}, textid, sharpness, antiAliasType, gridFitType);
}

// return native id
int currentClip() { 
	int id = EM_ASM_INT({
		var v = IDHandler.createObjectId(RenderSupport.currentClip());
		Module.print('currentClip return: ' + v);
		return v;
	});
	return id;
}

void addFilters(const int clipid, const StackSlot& filters) {
	//StackSlot arr = mem_pool.AllocateUninitializedArray(1);
	//StackSlot* parr = mem_pool.GetArrayWritePtr(arr, 1);
	//parr[0] = filters;
 
	EM_ASM_({
		var args = decode_flow_data($1, $2);
		Module.print('addFilters: ' + args);

		RenderSupport.addFilters(IDHandler.getObjectFromID($0), args.map(function(i) { IDHandler.getObjectFromID(i); }));
	}, clipid, mem_pool.data_ptr(), &filters);
}

StackSlot makeBevel(const double angle, const double distance, const double radius, const double spread, const int color1, const double alpha1, const int color2, const double alpha2, const bool inner) {
	int id = EM_ASM_INT({
		var v = IDHandler.createObjectId(RenderSupport.makeBevel($0, $1, $2, $3, $4, $5, $6, $7, $8));
		Module.print('makeBevel return: ' + v);
		return v;
	}, angle, distance, radius, spread, color1, alpha1, color2, alpha2, inner);

	return StackSlot::MakeNative(id);
}

StackSlot makeBlur(const double radius, const double spread) {
	int id = EM_ASM_INT({
		var v = IDHandler.createObjectId(RenderSupport.makeBlur($0, $1));
		Module.print('makeBlur return: ' + v);
		return v;
	}, radius, spread);

	return StackSlot::MakeNative(id);
}

StackSlot makeDropShadow(const double angle, const double distance, const double radius, const double spread, const int color, const double alpha, const bool inner) {
	int id = EM_ASM_INT({
		var v = IDHandler.createObjectId(RenderSupport.makeDropShadow($0, $1, $2, $3, $4, $5, $6));
		Module.print('makeDropShadow return: ' + v);
		return v;
	}, angle, distance, radius, spread, color, alpha, inner);
	return StackSlot::MakeNative(id);
}

StackSlot makeGlow(const double radius, const double spread, const int color, const double alpha, const bool inner) {
	int id = EM_ASM_INT({
		var v = IDHandler.createObjectId(RenderSupport.makeGlow($0, $1, $2, $3, $4));
		Module.print('makeGlow return: ' + v);
		return v;
	}, radius, spread, color, alpha, inner);
	return StackSlot::MakeNative(id);
}

void enableResize() { 
	EM_ASM({
		Module.print('enableResize');
		RenderSupport.enableResize();
	});
}

StackSlot getStage() { 
	int id = EM_ASM_INT({
		var v = IDHandler.createObjectId(RenderSupport.getStage());
		Module.print('getStage return: ' + v);
		return v;
	});
	return StackSlot::MakeNative(id);
}

double getStageHeight() {
	double ret = EM_ASM_DOUBLE({
		var v = RenderSupport.getStageHeight();
//		Module.print('getStageHeight return: ' + v);
		return v;
	});
	return ret;
}

double getStageWidth() {
	double ret = EM_ASM_DOUBLE({
		var v = RenderSupport.getStageWidth();
//		Module.print('getStageWidth return: ' + v);
		return v;
	});
	return ret;
}

StackSlot makeClip() {
	int id = EM_ASM_INT({
		var v = IDHandler.createObjectId(RenderSupport.makeClip());
		return v;
	});
	return StackSlot::MakeNative(id);
}


unicode_string getParameter(const StackSlot& name) {
	StackSlot arr = mem_pool.AllocateUninitializedArray(1);
	StackSlot* parr = mem_pool.GetArrayWritePtr(arr, 1);
	parr[0] = name;

	printf("getParameter\n");
	int* buffer = (int*)EM_ASM_INT({
		var args = decode_flow_data($0, $1);
		Module.print('getParameter(' + args[0] + ')');

		var v = Util.getParameter(args[0]);
		Module.print('getParameter return: ' + v);

		if (v != null) {
			var strptr = testApi.encodeString(v, $1);

			var buffer = _malloc(2 * 4);
			HEAP32[buffer >> 2] = v.length;
			HEAP32[(buffer + 4) >> 2] = strptr;

			return buffer;
		}

		return null;
	}, mem_pool.data_ptr(), &arr);

	if (buffer != NULL) {
		int strlen = buffer[0];
		int strptr = buffer[1];

		unicode_string ret = getStringFromJS(strptr, strlen);

		free((int*)strptr);
		free(buffer);

		return ret;
	}

	return unicode_string();
}

//
//std::function<void()> addFileDropListener(const native& clip, const int maxFilesCount, const std::string& mimeTypeRegExpFilter, const std::function<void(std::vector<native>)>& onDone) { 
//	Callback_VAN* CB = new Callback_VAN(onDone);
//
//	int id = EM_ASM_INT({
//		var disposer = RenderSupport.addFileDropListener(IDHandler.getObjectFromID($0), $1, UTF16ToString($2), function(data) {
//			Module.print('Try to call addFileDropListener callback by pointer: ' + $3);
//			var arr = data.map(function(i) { IDHandler.createObjectId(i) });
//			arr.unshift(arr.length);
//			var buffer = _malloc(arr.length * 4);
//
//			HEAPF32.set(arr, buffer >> 2);
//
//			Runtime.dynCall('vi', $3, [$4, arr]);
//		});
//		return IDHandler.createObjectId(disposer);
//	}, clip.data_, maxFilesCount, mimeTypeRegExpFilter.nullterm().ptr_->begin_, &(CB->Func), CB);
//
//	printf("addFileDropListener$0 c part  %d\n", id);
//
//	return [=]() {
//		EM_ASM_({
//			testApi.executeCallback($0, true);
//			Module.print('Call disposer: ' + $0);
//		}, id);
//		delete CB;
//	};
//}
//
//std::function<void()> addFinegrainMouseWheelEventListener(const native& clip, const std::function<void(double, double)>& cb) { 
//	// add listerner and got a callback function id
//	Callback_VDD* CB = new Callback_VDD(cb);
//
//	int id = EM_ASM_INT({
//		Module.print('addFinegrainMouseWheelEventListener ptr: ' + $1 + ' CB ptr: ' + $2);
//		var disposer = RenderSupport.addFinegrainMouseWheelEventListener(IDHandler.getObjectFromID($0), function(arg1, arg2) {
//			Module.print('Try to call addFinegrainMouseWheelEventListener callback by pointer: ' + callback);
//			Runtime.dynCall('vidd', $1, [$2, arg1, arg2]);
//		});
//		return IDHandler.createObjectId(disposer);
//	}, clip.data_, &(CB->Func), CB);
//
//	printf("addFinegrainMouseWheelEventListener c part  %d\n", id);
//
//	return [=]() {
//		EM_ASM_({
//			testApi.executeCallback($0, true);
//			Module.print('Call disposer: ' + $0);
//		}, id);
//		delete CB;
//	};
//}
//
//std::function<void()> addGestureListener(const std::string& event, const std::function<bool(int, double, double, double, double)>& cb) { 
//	// add listerner and got a callback function id
//	Callback_VIDDDD* CB = new Callback_VIDDDD(cb);
//	// we'll not register callback since it will be deleted on disposer call
//
//	int id = EM_ASM_INT({
//		Module.print('addGestureListener ' + UTF16ToString($0) + ' CB ptr: ' + $1);
//		var disposer = RenderSupport.addGestureListener(UTF16ToString($0), function(i1, d1, d2, d3, d4) {
//			Module.print('Try to call addFinegrainMouseWheelEventListener callback by pointer: ' + callback);
//			Runtime.dynCall('vi', $1, [$2, i1, d1, d2, d3, d4]);
//		});
//		return IDHandler.createObjectId(disposer);
//	}, event.nullterm().ptr_->begin_, &(CB->Func), CB);
//
//	printf("addGestureListener c part  %d\n", id);
//
//	return [=]() {
//		EM_ASM_({
//			testApi.executeCallback($0, true);
//			Module.print('Call disposer: ' + $0);
//		}, id);
//		delete CB;
//	};
//}
//
//std::function<void()> addMouseWheelEventListener(const native& clip, const std::function<void(double)>& cb) { 
//	// add listerner and got a callback function id
//	Callback_VD* CB = new Callback_VD(cb);
//
//	int id = EM_ASM_INT({
//		Module.print('addMouseWheelEventListener ptr: ' + $1 + ' CB ptr: ' + $2);
//		var disposer = RenderSupport.addMouseWheelEventListener(IDHandler.getObjectFromID($0), function(arg1) {
//			Module.print('Try to call addMouseWheelEventListener callback by pointer: ' + $1);
//			Runtime.dynCall('vid', $1,[$2, arg1]);
//		});
//		return IDHandler.createObjectId(disposer);
//	}, clip.data_, &(CB->Func), CB);
//
//	printf("addMouseWheelEventListener c part  %d\n", id);
//
//	return [=]() {
//		EM_ASM_({
//			testApi.executeCallback($0, true);
//			Module.print('Call disposer: ' + $0);
//		}, id);
//		delete CB;
//	};
//}
//
//std::function<void()> addStreamStatusListener(const native& clip, const std::function<void(std::string)>& cb) { 
//	// add listerner and got a callback function id
//	Callback_VS* CB = new Callback_VS(cb);
//
//	int id = EM_ASM_INT({
//		Module.print('addStreamStatusListener ptr: ' + $1 + ' CB ptr: ' + $2);
//		var disposer = RenderSupport.addStreamStatusListener(IDHandler.getObjectFromID($0), function(s1) {
//			Module.print('Try to call addStreamStatusListener callback by pointer: ' + $1);
//			var strptr = testApi.encodeString(s1, $3);
//			Runtime.dynCall('viii', $1, [$2, strptr, strptr.length]);
//			_free(strptr);
//		});
//		return IDHandler.createObjectId(disposer);
//	}, clip.data_, &(CB->Func), CB, sizeof(flow::char_t));
//
//	printf("addStreamStatusListener c part  %d\n", id);
//
//	return [=]() {
//		EM_ASM_({
//			testApi.executeCallback($0, true);
//			Module.print('Call disposer: ' + $0);
//		}, id);
//		delete CB;
//	};
//}
//
//void beginFill(const native& graphics, const int color, const double opacity) { 
//	EM_ASM_({
//		//Module.print('0: ' + $0);
//		//Module.print('1: ' + $1);
//		//Module.print('2: ' + $2);
//		RenderSupport.beginFill(IDHandler.getObjectFromID($0), $1, $2);
//	}, graphics.data_, color, opacity);
//}
//
//void beginGradientFill(const native& graphics, const std::vector<int>& colors, const std::vector<double>& alphas, const std::vector<double>& offsets, const native& matrix, const std::string& type) { 
//	EM_ASM_({
//		Module.print('beginGradientFill');
//		
//		colors = testApi.readArray($2, $1, 'i32');
//		alphas = testApi.readArray($4, $3, 'f64');
//		offsets = testApi.readArray($6, $5, 'f64');
//		matrix = IDHandler.getObjectFromID($7);
//		type = UTF16ToString($8);
//
//		RenderSupport.beginGradientFill(IDHandler.getObjectFromID($0), colors, alphas, offsets, matrix, type);
//	}, graphics.data_, 
//		colors.vec_->size(), colors.vec_->data(), 
//		alphas.vec_->size(), alphas.vec_->data(),
//		offsets.vec_->size(), offsets.vec_->data(),
//		matrix.data_, type.nullterm().ptr_->begin_);
//}
//
//native captureCallstackItem(const int index) { 
//	int id = EM_ASM_INT({
//		// TODO
//		return 0;
//		//var v = IDHandler.createObjectId(NativeHx.captureCallstackItem($0));
//		//Module.print('captureCallstackItem return: ' + v);
//		//return v;
//	}, index);
//	return native(id);
//}
//
//native captureCallstack() { 
//	int id = EM_ASM_INT({
//		// TODO
//		return 0;
//		//var v = IDHandler.createObjectId(NativeHx.captureCallstack());
//		//Module.print('captureCallstack return: ' + v);
//		//return v;
//	});
//	return native(id);
//}
//
//void closeVideo(const native& clip) { 
//	EM_ASM_({
//		Module.print('closeVideo: ' + $0);
//		RenderSupport.closeVideo(IDHandler.getObjectFromID($0));
//	}, clip.data_);
//}
//
//void curveTo(const native& graphics, const double x, const double y, const double cx, const double dy) { 
//	EM_ASM_({
////		Module.print('0: ' + $0 + ' 1: ' + $1 + ' 2: ' + $2 + ' 3: ' + $3 + ' 4: ' + $4);
//		// TODO: check parameter's order
//		RenderSupport.curveTo(IDHandler.getObjectFromID($0), $1, $2, $3, $4);
//	}, graphics.data_, x, y, cx, dy);
//}
//
//void endFill(const native& graphics) { 
//	EM_ASM_({
////		Module.print('endFill 0: ' + $0);
//		RenderSupport.endFill(IDHandler.getObjectFromID($0));
//	}, graphics.data_);
//}
//
//int getBottomScrollV(const native& textid) { 
//	int id = EM_ASM_INT({
//		var v = RenderSupport.getBottomScrollV(IDHandler.getObjectFromID($0));
//		Module.print('getBottomScrollV return: ' + v);
//		return v;
//	}, textid.data_);
//	return id;
//}
//
//bool getClipVisible(const native& clip) { 
//	int id = EM_ASM_INT({
//		var v = RenderSupport.getClipVisible(IDHandler.getObjectFromID($0));
////		Module.print('getClipVisible return: ' + v);
//		return v;
//	}, clip.data_);
//	return id;
//}
//
//int getCursorPosition(const native& textid) { 
//	int id = EM_ASM_INT({
//		var v = RenderSupport.getCursorPosition(IDHandler.getObjectFromID($0));
//		Module.print('getCursorPosition return: ' + v);
//		return v;
//	}, textid.data_);
//	return id;
//}
//
//bool getFocus(const native& textid) {
//	int id = EM_ASM_INT({
//		var v = RenderSupport.getFocus(IDHandler.getObjectFromID($0));
//		Module.print('getFocus return: ' + v);
//		return v;
//	}, textid.data_);
//	return id != 0;
//}
//
//native getGraphics(const native& clip) { 
//	int id = EM_ASM_INT({
//		var v = IDHandler.createObjectId(RenderSupport.getGraphics(IDHandler.getObjectFromID($0)));
//		Module.print('getGraphics return: ' + v);
//		return v;
//	}, clip.data_);
//	return native(id);
//}
//
//double getMouseX(const native& clip) { 
//	double id = EM_ASM_DOUBLE({
//		var v = RenderSupport.getMouseX(IDHandler.getObjectFromID($0));
////		Module.print('getMouseX return: ' + v);
//		return v;
//	}, clip.data_);
//	return id;
//}
//
//double getMouseY(const native& clip) { 
//	double id = EM_ASM_DOUBLE({
//		var v = RenderSupport.getMouseY(IDHandler.getObjectFromID($0));
////		Module.print('getMouseY return: ' + v);
//		return v;
//	}, clip.data_);
//	return id;
//}
//
//int getNumLines(const native& textid) {
//	int id = EM_ASM_INT({
//		var v = RenderSupport.getNumLines(IDHandler.getObjectFromID($0));
//		Module.print('getNumLines return: ' + v);
//		return v;
//	}, textid.data_);
//	return id;
//}
//
//int getScrollV(const native& textid) {
//	int id = EM_ASM_INT({
//		var v = RenderSupport.getScrollV(IDHandler.getObjectFromID($0));
//		Module.print('getScrollV return: ' + v);
//		return v;
//	}, textid.data_);
//	return id;
//}
//
//int getSelectionEnd(const native& textid) {
//	int id = EM_ASM_INT({
//		var v = RenderSupport.getSelectionEnd(IDHandler.getObjectFromID($0));
//		Module.print('getSelectionEnd return: ' + v);
//		return v;
//	}, textid.data_);
//	return id;
//}
//
//int getSelectionStart(const native& textid) { 
//	int id = EM_ASM_INT({
//		var v = RenderSupport.getSelectionStart(IDHandler.getObjectFromID($0));
//		Module.print('getSelectionStart return: ' + v);
//		return v;
//	}, textid.data_);
//	return id;
//}
//
//double getVideoPosition(const native& clip) { 
//	double ret = EM_ASM_DOUBLE({
//		v = RenderSupport.getVideoPosition(IDHandler.getObjectFromID($0));
//		Module.print('getVideoPosition return: ' + v);
//		return v;
//	}, clip.data_);
//	return ret;
//}
//
//bool hittest(const native& clip, const double x, const double y) { 
//	int id = EM_ASM_INT({
//		var v = RenderSupport.hittest(IDHandler.getObjectFromID($0), $1, $2);
////		Module.print('hittest return: ' + v);
//		return v;
//	}, clip.data_, x, y);
//	return id != 0;
//}
//
//void lineTo(const native& graphics, const double x, const double y) { 
//	EM_ASM_({
//		RenderSupport.lineTo(IDHandler.getObjectFromID($0), $1, $2);
////		Module.print('lineTo');
//	}, graphics.data_, x, y);
//}
//
//// TODO: absolutely not tested
//std::vector<native> makeCamera(const std::string& uri, const int camID, const int camWidth, const int camHeight, const double camFps, 
//	const int vidWidth, const int vidHeight, const int recordMode, 
//	const std::function<void(native)>& cbOnOk, const std::function<void(std::string)>& cbOnFailed) { 
//
//	Callback_VS* CB_cbOnFailed = new Callback_VS(cbOnFailed);
//	Callback_VN* CB_cbOnOk = new Callback_VN(cbOnOk);
//	// TODO: not sure how to register these callbacks (and how to delete them accordingly)
////	registerCallback(, CB_cbOnFailed);
//
//	int* arr_ptr = (int*)EM_ASM_INT({
//		var r = RenderSupport.makeCamera(UTF16ToString($0), $1, $2, $3, $4, $5, $6, $7, function(stream) {
//			Module.print('Try to call makeCamera cbOnOk callback by pointer: ' + $8);
//			Runtime.dynCall('vii', $8, [$9, IDHandler.createObjectId(stream)]);
//		}, function(errmsg) {
//			Module.print('Try to call makeCamera cbOnFailed callback by pointer: ' + $10);
//			var strptr = testApi.encodeString(errmsg, $12);
//			Runtime.dynCall('viii', $10, [$11, strptr, strptr.length]);
//			_free(strptr);
//		});
//
//		var ret = r.map(function(i) { IDHandler.createObjectId(i) });
//
//		ret.unshift(ret.length);
//		var buffer = _malloc(arr.length * 4);
//		HEAPF32.set(arr, buffer >> 2);
//
//		return buffer;
//	}, uri.nullterm().ptr_->begin_, camID, camWidth, camHeight, camFps, vidWidth, vidHeight, recordMode, &(CB_cbOnOk->Func), CB_cbOnOk, &(CB_cbOnFailed->Func), CB_cbOnFailed, sizeof(flow::char_t));
//
//	std::vector<int> tmp = extractArrayFromJSMem<int>(arr_ptr);
//	std::function<native(int)> convertFn = [](int a) { return native(a); };
//	return std::vector<native>(tmp, convertFn);
//}
//
//native makeMatrix(const double width, const double height, const double rotation, const double xOffset, const double yOffset) { 
//	int id = EM_ASM_INT({
//		var v = IDHandler.createObjectId(RenderSupport.makeMatrix($0, $1, $2, $3, $4));
//		Module.print('makeMatrix return: ' + v);
//		return v;
//	}, width, height, rotation, xOffset, yOffset);
//	return native(id);
//}
//
//native makePicture(const std::string& url, const bool cache, const std::function<void(double, double)>& metricsFn, const std::function<void(std::string)>& errorFn, const bool onlyDownload) { 
//	// add listerner and got a callback function id
//	Callback_VDD* CB1 = new Callback_VDD(metricsFn);
//	Callback_VS* CB2 = new Callback_VS(errorFn);
//
//	int id = EM_ASM_INT({
//		Module.print('makePicture url: ' + UTF16ToString($0));
//		var ret = RenderSupport.makePicture(UTF16ToString($0), $1, function(arg1, arg2) {
//			Module.print('Try to call metricsFn callback by pointer: ' + $2);
//			Runtime.dynCall('vidd', $2,[$3, arg1, arg2]);
//		}, function(s1) {
//			var strptr = testApi.encodeString(s1, $7);
//			Module.print('Try to call errorFn callback by pointer: ' + $4);
//			Runtime.dynCall('viii', $4,[$5, strptr, strptr.length]);
//			_free(strptr);
//		}, $6);
//		return IDHandler.createObjectId(ret);
//	}, url.nullterm().ptr_->begin_, cache, &(CB1->Func), CB1, &(CB2->Func), CB2, onlyDownload, sizeof(flow::char_t));
//
//	native ret = native(id);
//
//	registerCallback(ret, CB1);
//	registerCallback(ret, CB2);
//
//	printf("makePicture ret: %d\n", id);
//
//	return ret;
//}
//
//native makeVideo(const std::function<void(double, double)>& metricsFn, const std::function<void(bool)>& playFn, const std::function<void(double)>& durationFn, const std::function<void(double)>& positionFn) { 
//	// add listerner and got a callback function id
//	Callback_VDD* CB1 = new Callback_VDD(metricsFn);
//	Callback_VB* CB2 = new Callback_VB(playFn);
//	Callback_VD* CB3 = new Callback_VD(durationFn);
//	Callback_VD* CB4 = new Callback_VD(positionFn);
//
//	int id = EM_ASM_INT({
//		Module.print('makeVideo');
//		var disposer = RenderSupport.makeVideo(function(arg1, arg2) {
//			Module.print('Try to call metricsFn callbac');
//			Runtime.dynCall('vidd', $0,[$1, arg1, arg2]);
//		}, function(b1) {
//			Module.print('Try to call playFn callback');
//			Runtime.dynCall('vii', $2,[$3, b1]);
//		}, function(d1) {
//			Module.print('Try to call durationFn callback');
//			Runtime.dynCall('vid', $4,[$5, d1]);
//		}, function(d1) {
//			Module.print('Try to call positionFn callback');
//			Runtime.dynCall('vid', $6,[$7, d1]);
//		});
//		return IDHandler.createObjectId(disposer);
//	}, &(CB1->Func), CB1, &(CB2->Func), CB2, &(CB3->Func), CB3, &(CB4->Func), CB4);
//
//	native ret = native(id);
//
//	registerCallback(ret, CB1);
//	registerCallback(ret, CB2);
//	registerCallback(ret, CB3);
//	registerCallback(ret, CB4);
//
//	printf("makeVideo ret: %d\n", id);
//
//	return ret;
//}
//
//void moveTo(const native& graphics, const double x, const double y) { 
//	EM_ASM_({
//		RenderSupport.moveTo(IDHandler.getObjectFromID($0), $1, $2);
////		Module.print('moveTo');
//	}, graphics.data_, x, y);
//}
//
//void pauseVideo(const native& clip) {
//	EM_ASM_({
//		Module.print('pauseVideo 0: ' + $0);
//		RenderSupport.pauseVideo(IDHandler.getObjectFromID($0));
//	}, clip.data_);
//}
//
//void playVideo(const native& clip, const std::string& filename, const bool startPaused) { 
//	EM_ASM_({
//		Module.print('playVideo ' + UTF16ToString($1));
//		RenderSupport.playVideo(IDHandler.getObjectFromID($0), UTF16ToString($1), $2);
//	}, clip.data_, filename.nullterm().ptr_->begin_, startPaused);
//}
//
//void removeChild(const native& parent, const native& child) { 
//	EM_ASM_({
//		Module.print('removeChild');
//		RenderSupport.removeChild(IDHandler.getObjectFromID($0), IDHandler.getObjectFromID($1));
//	}, parent.data_, child.data_);
//}
//
//void resetFullWindowTarget() { 
//	EM_ASM({
//		Module.print('resetFullWindowTarget');
//		RenderSupport.resetFullScreenTarget();
//	});
//}
//
//void resumeVideo(const native& clip) { 
//	EM_ASM_({
//		Module.print('resumeVideo');
//		RenderSupport.resumeVideo(IDHandler.getObjectFromID($0));
//	}, clip.data_);
//}
//
//void seekVideo(const native& clip, const double frame) { 
//	EM_ASM_({
//		Module.print('seekVideo');
//		RenderSupport.seekVideo(IDHandler.getObjectFromID($0), $1);
//	}, clip.data_, frame);
//}
//
//void setAutoAlign(const native& clip, const std::string& autoalign) { 
//	EM_ASM_({
//		Module.print('setAutoAlign');
//		RenderSupport.setAutoAlign(IDHandler.getObjectFromID($0), UTF16ToString($1));
//	}, clip.data_, autoalign.nullterm().ptr_->begin_);
//}
//
//void setClipAlpha(const native& clip, const double y) { 
//	EM_ASM_({
//		Module.print('setClipAlpha');
//		RenderSupport.setClipAlpha(IDHandler.getObjectFromID($0), $1);
//	}, clip.data_, y);
//}
//
//void setClipCallstack(const native& clip, const native& callstack) { 
//	EM_ASM_({
//		Module.print('setClipCallstack');
//		RenderSupport.setClipCallstack(IDHandler.getObjectFromID($0), IDHandler.getObjectFromID($1));
//	}, clip.data_, callstack.data_);
//}
//
//void setClipMask(const native& clip, const native& mask) { 
//	EM_ASM_({
//		Module.print('setClipMask');
//		RenderSupport.setClipMask(IDHandler.getObjectFromID($0), IDHandler.getObjectFromID($1));
//	}, clip.data_, mask.data_);
//}
//
//void setClipRotation(const native& clip, const double x) { 
//	EM_ASM_({
//		Module.print('setClipRotation');
//		RenderSupport.setClipRotation(IDHandler.getObjectFromID($0), $1);
//	}, clip.data_, x);
//}
//
//void setClipScaleX(const native& clip, const double x) { 
//	EM_ASM_({
//		Module.print('setClipScaleX');
//		RenderSupport.setClipScaleX(IDHandler.getObjectFromID($0), $1);
//	}, clip.data_, x);
//}
//
//void setClipScaleY(const native& clip, const double y) { 
//	EM_ASM_({
//		Module.print('setClipScaleY');
//		RenderSupport.setClipScaleY(IDHandler.getObjectFromID($0), $1);
//	}, clip.data_, y);
//}
//
//void setClipVisible(const native& clip, const bool v) {
//	EM_ASM_({
//		Module.print('setClipVisible');
//		RenderSupport.setClipVisible(IDHandler.getObjectFromID($0), $1);
//	}, clip.data_, v);
//}
//
//void setClipX(const native& clip, const double x) { 
//	EM_ASM_({
//		Module.print('setClipX');
//		RenderSupport.setClipX(IDHandler.getObjectFromID($0), $1);
//	}, clip.data_, x);
//}
//
//void setClipY(const native& clip, const double y) { 
//	EM_ASM_({
//		Module.print('setClipY');
//		RenderSupport.setClipY(IDHandler.getObjectFromID($0), $1);
//	}, clip.data_, y);
//}
//
//void setCursor(const std::string& cursor) { 
//	EM_ASM_({
//		Module.print('setCursor');
//		RenderSupport.setCursor(UTF16ToString($0));
//	}, cursor.nullterm().ptr_->begin_);
//}
//
//void setFocus(const native& clip, const bool focus) { 
//	EM_ASM_({
//		Module.print('setFocus');
//		RenderSupport.setFocus(IDHandler.getObjectFromID($0), $1);
//	}, clip.data_, focus);
//}
//
//void setFullWindowTarget(const native& clip) { 
//	EM_ASM_({
//		Module.print('setFullScreenTarget');
//		RenderSupport.setFullScreenTarget(IDHandler.getObjectFromID($0));
//	}, clip.data_);
//}
//
//void setHitboxRadius(const double radius) { 
//	EM_ASM_({
//		Module.print('setHitboxRadius');
//		RenderSupport.setHitboxRadius($0);
//	}, radius);
//}
//
//void setLineGradientStroke(const native& graphics, const std::vector<int>& colors, const std::vector<double>& alphas, const std::vector<double>& offsets, const native& matrix) { 
//	EM_ASM_({
//		colors = testApi.readArray($2, $1, 'i32');
//		alphas = testApi.readArray($4, $3, 'f64');
//		offsets = testApi.readArray($6, $5, 'f64');
//		matrix = IDHandler.getObjectFromID($7);
//
//		RenderSupport.setLineGradientStroke(IDHandler.getObjectFromID($0), colors, alphas, offsets, matrix);
//	}, graphics.data_, 
//		colors.vec_->size(), colors.vec_->data(), 
//		alphas.vec_->size(), alphas.vec_->data(),
//		offsets.vec_->size(), offsets.vec_->data(),
//		matrix.data_);
//}
//
//void setLineStyle2(const native& graphics, const double width, const int color, const double opacity, const bool pixelHinting) { 
//	EM_ASM_({
//		Module.print('setLineStyle2');
//		RenderSupport.setLineStyle2(IDHandler.getObjectFromID($0), $1, $2, $3, $4);
//	}, graphics.data_, width, color, opacity, pixelHinting);
//}
//
//void setLineStyle(const native& graphics, const double width, const int color, const double opacity) { 
//	EM_ASM_({
////		Module.print('setLineStyle');
//		RenderSupport.setLineStyle(IDHandler.getObjectFromID($0), $1, $2, $3);
//	}, graphics.data_, width, color, opacity);
//}
//
//void setMaxChars(const native& clip, const int maxChars) {
//	EM_ASM_({
//		Module.print('setMaxChars');
//		RenderSupport.setMaxChars(IDHandler.getObjectFromID($0), $1);
//	}, clip.data_, maxChars);
//}
//
//void setMultiline(const native& clip, const bool multiline) {
//	EM_ASM_({
//		Module.print('setMultiline');
//		RenderSupport.setMultiline(IDHandler.getObjectFromID($0), $1);
//	}, clip.data_, multiline);
//}
//
//void setReadOnly(const native& clip, const bool readonly) {
//	EM_ASM_({
//		Module.print('setReadOnly');
//		RenderSupport.setReadOnly(IDHandler.getObjectFromID($0), $1);
//	}, clip.data_, readonly);
//}
//
//native setScrollRect(const native& clip, const double left, const double top, const double width, const double height) {
//	int id = EM_ASM_INT({
//		Module.print('setScrollRect');
//		RenderSupport.setScrollRect(IDHandler.getObjectFromID($0), $1, $2, $3, $4);
//	}, clip.data_, left, top, width, height);
//	return native(id);
//}
//
//void setScrollV(const native& clip, const int scrollV) {
//	EM_ASM_({
//		Module.print('setScrollV');
//		RenderSupport.setScrollV(IDHandler.getObjectFromID($0), $1);
//	}, clip.data_, scrollV);
//}
//
//void setSelection(const native& clip, const int start, const int end) {
//	EM_ASM_({
//		Module.print('setSelection');
//		RenderSupport.setSelection(IDHandler.getObjectFromID($0), $1);
//	}, clip.data_, start, end);
//}
//
//void setTabIndex(const native& clip, const int tabIndex) {
//	EM_ASM_({
//		Module.print('setTabIndex');
//		RenderSupport.setTabIndex(IDHandler.getObjectFromID($0), $1);
//	}, clip.data_, tabIndex);
//}
//
//void setTextFieldHeight(const native& clip, const double width) { 
//	EM_ASM_({
//		Module.print('setTextFieldHeight');
//		RenderSupport.setTextFieldHeight(IDHandler.getObjectFromID($0), $1);
//	}, clip.data_, width);
//}
//
//void setTextFieldWidth(const native& clip, const double width) { 
//	EM_ASM_({
//		Module.print('setTextFieldWidth');
//		RenderSupport.setTextFieldWidth(IDHandler.getObjectFromID($0), $1);
//	}, clip.data_, width);
//}
//
//void setTextInputType(const native& clip, const std::string& inputType) {
//	EM_ASM_({
//		Module.print('setTextInputType');
//		RenderSupport.setTextInputType(IDHandler.getObjectFromID($0), UTF16ToString($1));
//	}, clip.data_, inputType.nullterm().ptr_->begin_);
//}
//
//void setTextInput(const native& clip) {
//	EM_ASM_({
//		Module.print('setTextInput');
//		RenderSupport.setTextInput(IDHandler.getObjectFromID($0));
//	}, clip.data_);
//}
//
//struct PlayerControl;
//void setVideoControls(const native& clip, const std::vector<PlayerControl>& ctl) { FLOW_ABORT }
//void setVideoLooping(const native& clip, const bool looping) { 
//	EM_ASM_({
//		Module.print('setVideoLooping');
//		RenderSupport.setVideoLooping(IDHandler.getObjectFromID($0), $1);
//	}, clip.data_, looping);
//}
//
//void setVideoSubtitle(const native& clip, const std::string& text, const std::string& fontfamily, const double fontsize, const int fontweight, const std::string& fontslope, const int fillcolour, const double fillopacity, const int letterspacing, const int backgroundcolour, const double backgroundopacity) {
//	EM_ASM_({
//		Module.print('setVideoSubtitle');
//		RenderSupport.setVideoSubtitle(IDHandler.getObjectFromID($0), UTF16ToString($1), UTF16ToString($2), $3, $4, UTF16ToString($5), $6, $7, $8, $9, $10);
//	}, clip.data_, text.nullterm().ptr_->begin_, fontfamily.nullterm().ptr_->begin_, fontsize, fontweight, fontslope.nullterm().ptr_->begin_, fillcolour, fillopacity, letterspacing, backgroundcolour, backgroundopacity);
//}
//
//void setVideoVolume(const native& clip, const double volume) { 
//	EM_ASM_({
//		Module.print('setVideoVolume');
//		RenderSupport.setVideoVolume(IDHandler.getObjectFromID($0), $1);
//	}, clip.data_, volume);
//}
//
//void setWebClipDisabled(const native& clip, const bool disabled) {
//	EM_ASM_({
//		Module.print('setWebClipDisabled');
//		RenderSupport.setWebClipDisabled(IDHandler.getObjectFromID($0), $1);
//	}, clip.data_, disabled);
//}
//
//void setWebClipSandBox(const native& clip, const std::string& sandbox) {
//	EM_ASM_({
//		Module.print('setWebClipSandBox');
//		RenderSupport.setWebClipSandBox(IDHandler.getObjectFromID($0), UTF16ToString($1));
//	}, clip.data_, sandbox.nullterm().ptr_->begin_);
//}
//
//void setWebClipZoomable(const native& clip, const bool zoomable) {
//	EM_ASM_({
//		Module.print('setWebClipZoomable');
//		RenderSupport.setWebClipZoomable(IDHandler.getObjectFromID($0), $1);
//	}, clip.data_, zoomable);
//}
//
//void setWordWrap(const native& clip, const bool wordWrap) {
//	EM_ASM_({
//		Module.print('setWordWrap');
//		RenderSupport.setWordWrap(IDHandler.getObjectFromID($0), $1);
//	}, clip.data_, wordWrap);
//}
//
//void startRecord(const native& clip, const flow::string& filename, const flow::string& mode) { 
//	EM_ASM_({
//		Module.print('startRecord');
//		RenderSupport.startRecord(IDHandler.getObjectFromID($0), UTF16ToString($1), UTF16ToString($2));
//	}, clip.data_, filename.nullterm().ptr_->begin_, mode.nullterm().ptr_->begin_);
//}
//
//void stopRecord(const native& clip) { 
//	EM_ASM_({
//		Module.print('stopRecord');
//		RenderSupport.stopRecord(IDHandler.getObjectFromID($0));
//	}, clip.data_);
//}
//
//void toggleFullWindow(const bool fs) { 
//	EM_ASM_({
//		Module.print('stopRecord');
//		RenderSupport.toggleFullScreen(fs);
//	}, fs);
//}
//
//native makeWebClip(
//	const flow::string& url, 
//	const flow::string& domain, 
//	const bool useCache, 
//	const bool reloadBlock,
//	const std::function<flow::string(std::vector<flow::string>)>& cb,
//	const std::function<void(flow::string)>& ondone, 
//	const bool shrinkToFit) { FLOW_ABORT }
//
//void jsPrint(flow::char_t* str) {
//	EM_ASM_({
//		Module.print('' + UTF16ToString($0));
//	}, str);
//}
//
//void setAccessAttributes(const native& clip, const std::vector<std::vector<flow::string>>& properties) { 
//	std::vector<flow::string> tmp;	// this is temp storage for new (null terminated) strings
//	std::vector<int> ret;			// here we will keep pointers to strings
//	for (int i = 0; i < properties.vec_->size(); ++i) {
//		ret.push_back(properties[i].vec_->size());
//		for (int j = 0; j < properties[i].vec_->size(); ++j) {
//			tmp.push_back(properties[i][j].nullterm());
//			flow::char_t* ptr = tmp.back().ptr_->begin_;
//			ret.push_back((int)ptr);
//			jsPrint(ptr);
//		}
//	}
//
//	EM_ASM_({
//		var size = $1;
//		var ptr = $2;
//		arr = testApi.readArray(ptr, size, 'i32');
//
//		// now we have a [size, ptr] pairs in a
//		var A = [];
//		for (i = 0; i < size;) {
//			var s = arr[i];
//			Module.print('size: ' + s);
//
//			var B = [];
//			for (j = i + 1; j < i + s + 1; ++j) {
//				var str = UTF16ToString(arr[j]);
//				Module.print('str: ' + str);
//				B.push(str);
//			}
//
//			A.push(B);
//			i = i + s + 1;
//		}
//
//		Module.print('setAccessAttributes: ' + A);
//
//		RenderSupport.setAccessAttributes(IDHandler.getObjectFromID($0), A);
//	}, clip.data_, ret.size(), ret.data());
//}
//
//flow::string webClipEvalJS(const native& clip, const flow::string& code) { FLOW_ABORT }
//
//flow::string webClipHostCall(const native& clip, const flow::string& name, const std::vector<flow::string>& args) { FLOW_ABORT }
//
//void setAccessCallback(const native& clip, const std::function<void()> callback) { 
//	Callback_V* CB = new Callback_V(callback);
//	registerCallback(clip, CB);
//
//	EM_ASM_({
//		Module.print('setAccessCallback');
//
//		RenderSupport.setAccessCallback(IDHandler.getObjectFromID($0), function() {
//			Module.print('Try to call setAccessCallback callback: ' + CB + ' $2');
//			Runtime.dynCall('vi', $1, [$2]);
//		});
//	}, clip.data_, &(CB->Func), CB);
//}
