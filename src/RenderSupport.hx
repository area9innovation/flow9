import Flow;
import FlowArray;
import haxe.Timer;
import RenderSupportHx;

class RenderSupport {
	public function new(interpreter : Interpreter) {
		this.interpreter = interpreter;
	}

	var interpreter : Interpreter;

	public function addPasteEventListener(args : FlowArray<Flow>, pos : Position) : Flow {
		var callbackFn = interpreter.registerRoot(args[0]);
		var me = this;
		var callback = function(files : FlowArray<Dynamic>) {
			var fls = new FlowArray();
			for (file in files) {
				fls.push(ConstantNative(file, pos));
			}

			me.interpreter.eval(Call(
				me.interpreter.lookupRoot(callbackFn), 
				FlowArrayUtil.one(ConstantArray(fls, pos)), 
				pos
			));
		}

		var ndisp = RenderSupportHx.addPasteEventListener(callback);
		var disp = function(flow, pos) {
			ndisp();
			interpreter.releaseRoot(callbackFn);
			return ConstantVoid(pos);
		}
		return NativeClosure(0, disp, pos);
	}

	public function getPixelsPerCm(args : FlowArray<Flow>, pos : Position) : Flow  {
		return ConstantDouble(RenderSupportHx.getPixelsPerCm(), pos);
	}

	public function setHitboxRadius(args : FlowArray<Flow>, pos : Position) : Flow  {
		return ConstantBool(false, pos);
	}

	// native currentClip : () -> flow = FlashSupport.currentClip;
	public function currentClip(args : FlowArray<Flow>, pos : Position) : Flow  {
		return ConstantNative(RenderSupportHx.currentClip(), pos);
	}

	// native enableResize() -> void;
	public function enableResize(args : FlowArray<Flow>, pos : Position) : Flow  {
		RenderSupportHx.enableResize();
		return ConstantVoid(pos);
	}

	public function getStageWidth(args : FlowArray<Flow>, pos : Position) : Flow  {
		return ConstantDouble(RenderSupportHx.getStageWidth(), pos);
	}

	public function getStageHeight(args : FlowArray<Flow>, pos : Position) : Flow  {
		return ConstantDouble(RenderSupportHx.getStageHeight(), pos);
	}

	// native makeTextfield : (fontfamily : String) -> native
	public function makeTextField(args : FlowArray<Flow>, pos : Position) : Flow  {
		var fontfamily = FlowUtil.getString(args[0]);
		return ConstantNative(RenderSupportHx.makeTextField(fontfamily), pos);
	}

	public function makeVideo(args : FlowArray<Flow>, pos : Position) : Flow  {
		var width = FlowUtil.getInt(args[0]);
		var height = FlowUtil.getInt(args[1]);
		var metricsFn = interpreter.registerRoot(args[2]);
		var durationFn = interpreter.registerRoot(args[3]);
		var me = this;
		var setSize = function(w,h) {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(metricsFn), FlowArrayUtil.fromArray([
				ConstantDouble(w, pos),
				ConstantDouble(h, pos),
			]), pos));
			me.interpreter.releaseRoot(metricsFn);
		}
		var setDuration = function(len) {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(durationFn), FlowArrayUtil.fromArray([
				ConstantDouble(len, pos),
			]), pos));
			me.interpreter.releaseRoot(durationFn);
		}
		
		var res = RenderSupportHx.makeVideo(width, height, setSize, setDuration); 

		return ConstantArray(FlowArrayUtil.fromArray([ConstantNative(res[0], pos), ConstantNative(res[1], pos)]), pos);
	}
	
	public function setVideoVolume(args: FlowArray<Flow>, pos: Position): Flow {
		var stream : Dynamic = FlowUtil.getNative(args[0]);
		var volume : Float = FlowUtil.getDouble(args[1]);
		RenderSupportHx.setVideoVolume(stream, volume);
		return ConstantVoid(pos);
	}

	public function setVideoLooping(args: FlowArray<Flow>, pos: Position): Flow {
		// STUB; only implemented in C++/OpenGL
		return ConstantVoid(pos);
	}

	public function setVideoControls(args: FlowArray<Flow>, pos: Position): Flow {
		// STUB; only implemented in C++/OpenGL
		return ConstantVoid(pos);
	}

	public function setVideoSubtitle(args: FlowArray<Flow>, pos: Position): Flow {
		// STUB; only implemented in C++/OpenGL
		return ConstantVoid(pos);
	}

	public function playVideo(args : FlowArray<Flow>, pos : Position) : Flow  {
		var stream : Dynamic = FlowUtil.getNative(args[0]);
		var filename = FlowUtil.getString(args[1]);
		var startPaused : Bool = FlowUtil.getBool(args[2]);
		RenderSupportHx.playVideo(stream, filename, startPaused);
		return ConstantVoid(pos);
	}
	
	public function seekVideo(args : FlowArray<Flow>, pos : Position) : Flow  {
		var stream : Dynamic = FlowUtil.getNative(args[0]);
		var seek = FlowUtil.getDouble(args[1]);
		RenderSupportHx.seekVideo(stream, seek);
		return ConstantVoid(pos);
	}
	
	public function getVideoPosition(args : FlowArray<Flow>, pos : Position) : Flow  {
		var stream : Dynamic = FlowUtil.getNative(args[0]);
		return ConstantDouble(RenderSupportHx.getVideoPosition(stream), pos);
	}

	public function pauseVideo(args : FlowArray<Flow>, pos : Position) : Flow  {
		var stream : Dynamic = FlowUtil.getNative(args[0]);
		RenderSupportHx.pauseVideo(stream);
		return ConstantVoid(pos);
	}
	
	public function resumeVideo(args : FlowArray<Flow>, pos : Position) : Flow  {
		var stream : Dynamic = FlowUtil.getNative(args[0]);
		RenderSupportHx.resumeVideo(stream);
		return ConstantVoid(pos);
	}

	public function closeVideo(args : FlowArray<Flow>, pos : Position) : Flow  {
		var stream : Dynamic = FlowUtil.getNative(args[0]);
		RenderSupportHx.closeVideo(stream);
		return ConstantVoid(pos);
	}

	public function setTextAndStyle(args : FlowArray<Flow>, pos : Position) : Flow  {
		var textfield  = FlowUtil.getNative(args[0]);
		var text : String = FlowUtil.getString(args[1]);
		var fontfamily = FlowUtil.getString(args[2]);
		var fontsize = FlowUtil.getDouble(args[3]);
		var fontweight = FlowUtil.getInt(args[4]);
		var fontslope  = FlowUtil.getString(args[5]);
		var fillcolour = FlowUtil.getInt(args[4]);
		var fillopacity = FlowUtil.getDouble(args[5]);
		var letterspacing = FlowUtil.getInt(args[6]);
		var backgroundcolour = FlowUtil.getInt(args[7]);
		var backgroundopacity = FlowUtil.getDouble(args[8]);

		RenderSupportHx.setTextAndStyle(
			textfield, text, fontfamily, fontsize, fontweight, fontslope,
			fillcolour, fillopacity, letterspacing,
			backgroundcolour, backgroundopacity
		);

		return ConstantVoid(pos);
	}

	public function setTextDirection(args : FlowArray<Flow>, pos : Position) : Flow {
		var textfield : Dynamic = FlowUtil.getNative(args[0]);
		var dir = FlowUtil.getString(args[1]);
		RenderSupportHx.setTextDirection(textfield, dir);
		return ConstantVoid(pos);
	}

	public function setAdvancedText(args : FlowArray<Flow>, pos : Position) : Flow  {
		var textfield = FlowUtil.getNative(args[0]);
		var sharpness = FlowUtil.getInt(args[1]);
		var antialiastype = FlowUtil.getInt(args[2]);
		var gridfittype = FlowUtil.getInt(args[3]);

		RenderSupportHx.setAdvancedText(textfield, sharpness, antialiastype, gridfittype);

		return ConstantVoid(pos);
	}
	
	public function getTextFieldWidth(args : FlowArray<Flow>, pos : Position) : Flow  {
		var textfield : Dynamic = FlowUtil.getNative(args[0]);
		return ConstantDouble(RenderSupportHx.getTextFieldWidth(textfield), pos);
	}

	public function setTextFieldWidth(args : FlowArray<Flow>, pos : Position) : Flow  {
		var textfield : Dynamic = FlowUtil.getNative(args[0]);
		var width = FlowUtil.getDouble(args[1]);
		RenderSupportHx.setTextFieldWidth(textfield, width);
		return ConstantVoid(pos);
	}

	public function getTextFieldHeight(args : FlowArray<Flow>, pos : Position) : Flow  {
		var textfield : Dynamic = FlowUtil.getNative(args[0]);
		return ConstantDouble(RenderSupportHx.getTextFieldHeight(textfield), pos);
	}

	public function setTextFieldHeight(args : FlowArray<Flow>, pos : Position) : Flow  {
		var textfield : Dynamic = FlowUtil.getNative(args[0]);
		var height = FlowUtil.getDouble(args[1]);
		RenderSupportHx.setTextFieldWidth(textfield, height);
		return ConstantVoid(pos);
	}

	public function setAutoAlign(args : FlowArray<Flow>, pos : Position) : Flow {
		var textfield : Dynamic = FlowUtil.getNative(args[0]);
		var autoalign = FlowUtil.getString(args[1]);
		RenderSupportHx.setAutoAlign(textfield, autoalign);
		return ConstantVoid(pos);
	}

	public function setTextInput(args : FlowArray<Flow>, pos : Position) : Flow  {
		var textfield : Dynamic = FlowUtil.getNative(args[0]);
		RenderSupportHx.setTextInput(textfield);
		return ConstantVoid(pos);
	}

	public function setTextInputType(args : FlowArray<Flow>, pos : Position) : Flow {
		var textfield : Dynamic = FlowUtil.getNative(args[0]);
		var type : String = FlowUtil.getString(args[1]);
		RenderSupportHx.setTextInputType(textfield, type);
		return ConstantVoid(pos);
	}
	
	//[- Dry up -] There already is acess attribute for tabindex
	public function setTabIndex(args : FlowArray<Flow>, pos : Position) : Flow  {
		var textfield : Dynamic = FlowUtil.getNative(args[0]);
		var ti = FlowUtil.getInt(args[1]);
		RenderSupportHx.setTabIndex(textfield, ti);
		return ConstantVoid(pos);
	}

	public function setTabEnabled(args : FlowArray<Flow>, pos : Position) : Flow  {
		var textfield : Dynamic = FlowUtil.getNative(args[0]);
		var enabled = FlowUtil.getBool(args[1]);
		RenderSupportHx.setTabEnabled(textfield, enabled);
		return ConstantVoid(pos);
	}
	
	
	public function getContent(args : FlowArray<Flow>, pos : Position) : Flow  {
		var textfield : Dynamic = FlowUtil.getNative(args[0]);
		return ConstantString(RenderSupportHx.getContent(textfield), pos);
	}

	public function getCursorPosition(args : FlowArray<Flow>, pos : Position) : Flow  {
		var textfield : Dynamic = FlowUtil.getNative(args[0]);
		return ConstantI32((RenderSupportHx.getCursorPosition(textfield)), pos);
	}

	public function getFocus(args : FlowArray<Flow>, pos : Position) : Flow  {
		var clip = FlowUtil.getNative(args[0]);
		return ConstantBool(RenderSupportHx.getFocus(clip), pos);
	}

	public function getScrollV(args : FlowArray<Flow>, pos : Position) : Flow  {
		var textfield  = FlowUtil.getNative(args[0]);
		return ConstantI32((RenderSupportHx.getScrollV(textfield)), pos);
	}

	public function setScrollV(args : FlowArray<Flow>, pos : Position) : Flow  {
		var textfield = FlowUtil.getNative(args[0]);
		var suggestedPosition = FlowUtil.getInt(args[1]);
		RenderSupportHx.setScrollV(textfield, suggestedPosition);
		return ConstantVoid(pos);
	}

	public function getBottomScrollV(args : FlowArray<Flow>, pos : Position) : Flow  {
		var textfield  = FlowUtil.getNative(args[0]);
		return ConstantI32((RenderSupportHx.getBottomScrollV(textfield)), pos);
	}

	public function getNumLines(args : FlowArray<Flow>, pos : Position) : Flow  {
		var textfield = FlowUtil.getNative(args[0]);
		return ConstantI32((RenderSupportHx.getNumLines(textfield)), pos);
	}

	public function setFocus(args : FlowArray<Flow>, pos : Position) : Flow  {
		var clip = FlowUtil.getNative(args[0]);
		var focus = FlowUtil.getBool(args[1]);
		RenderSupportHx.setFocus(clip, focus);
		return ConstantVoid(pos);
	}

	public function setMultiline(args : FlowArray<Flow>, pos : Position) : Flow  {
		var clip = FlowUtil.getNative(args[0]);
		var multiline = FlowUtil.getBool(args[1]);
		RenderSupportHx.setMultiline(clip, multiline);
		return ConstantVoid(pos);
	}

	public function setWordWrap(args : FlowArray<Flow>, pos : Position) : Flow  {
		var clip = FlowUtil.getNative(args[0]);
		var wordWrap = FlowUtil.getBool(args[1]);
		RenderSupportHx.setWordWrap(clip, wordWrap);
		return ConstantVoid(pos);
	}

	public function getSelectionStart(args : FlowArray<Flow>, pos : Position) : Flow  {
		var textfield : Dynamic = FlowUtil.getNative(args[0]);
		return ConstantI32((RenderSupportHx.getSelectionStart(textfield)), pos);
	}

	public function getSelectionEnd(args : FlowArray<Flow>, pos : Position) : Flow  {
		var textfield : Dynamic = FlowUtil.getNative(args[0]);
		return ConstantI32((RenderSupportHx.getSelectionEnd(textfield)), pos);
	}

	public function setSelection(args : FlowArray<Flow>, pos : Position) : Flow  {
		var textfield : Dynamic = FlowUtil.getNative(args[0]);
		var start = FlowUtil.getInt(args[1]);
		var end = FlowUtil.getInt(args[2]);
		RenderSupportHx.setSelection(textfield, start, end);
		return ConstantVoid(pos);
	}

	// [- Dry up -] setReadonly(false) in fact is almost eq. setTextInput
	public function setReadOnly(args : FlowArray<Flow>, pos : Position) : Flow  {
		var textfield : Dynamic = FlowUtil.getNative(args[0]);			
		var readOnly = FlowUtil.getBool(args[1]);
		RenderSupportHx.setReadOnly(textfield, readOnly);
		return ConstantVoid(pos);
	}

	public function setMaxChars(args : FlowArray<Flow>, pos : Position) : Flow  {
		var textfield = FlowUtil.getNative(args[0]);
		var maxChars = FlowUtil.getInt(args[1]);
		RenderSupportHx.setMaxChars(textfield, maxChars);
		return ConstantVoid(pos);
	}

	// native addChild : (parent : native, child : native) -> void
	public function addChild(args : FlowArray<Flow>, pos : Position) : Flow  {
		var parent = FlowUtil.getNative(args[0]);
		var child = FlowUtil.getNative(args[1]);
		RenderSupportHx.addChild(parent, child);
		return ConstantVoid(pos);
	}

	// native removeChild : (parent : native, child : native) -> void
	public function removeChild(args : FlowArray<Flow>, pos : Position) : Flow  {
		var parent = FlowUtil.getNative(args[0]);
		var child = FlowUtil.getNative(args[1]);
		RenderSupportHx.removeChild(parent, child);
		return ConstantVoid(pos);
	}

	public function makeClip(args : FlowArray<Flow>, pos : Position) : Flow  {
		return ConstantNative(RenderSupportHx.makeClip(), pos);
	}

	public function makeWebClip(args : FlowArray<Flow>, pos : Position) : Flow  {
		// TODO: REPLACE STUB
		return ConstantNative(RenderSupportHx.makeClip(), pos);
	}

	public function setWebClipSandBox(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantVoid(pos);
	}

	public function setWebClipDisabled(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantVoid(pos);
	}

	public function webClipHostCall(args : FlowArray<Flow>, pos : Position) : Flow  {
		// TODO: REPLACE STUB
		return ConstantVoid(pos);
	}

	public function webClipEvalJS(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantVoid(pos);
	}

	public function setWebClipZoomable(args : FlowArray<Flow>, pos : Position) : Flow {
		// STUB
		return ConstantVoid(pos);
	}

	public function setWebClipDomains(args : FlowArray<Flow>, pos : Position) : Flow {
		// STUB
		return ConstantVoid(pos);
	}

    public function setClipCallstack(args : FlowArray<Flow>, pos : Position) : Flow  {
    	// Stub
    	return ConstantVoid(pos);
    }

	public function setClipX(args : FlowArray<Flow>, pos : Position) : Flow  {
		var clip = FlowUtil.getNative(args[0]);
		var x = FlowUtil.getDouble(args[1]);
		RenderSupportHx.setClipX(clip, x);
		return ConstantVoid(pos);
	}

	public function setClipY(args : FlowArray<Flow>, pos : Position) : Flow  {
		var clip = FlowUtil.getNative(args[0]);
		var y = FlowUtil.getDouble(args[1]);
		RenderSupportHx.setClipY(clip, y);
		return ConstantVoid(pos);
	}

	public function setClipScaleX(args : FlowArray<Flow>, pos : Position) : Flow  {
		var clip = FlowUtil.getNative(args[0]);
		var scalex = FlowUtil.getDouble(args[1]);
		RenderSupportHx.setClipScaleX(clip, scalex);
		return ConstantVoid(pos);
	}

	public function setClipScaleY(args : FlowArray<Flow>, pos : Position) : Flow  {
		var clip = FlowUtil.getNative(args[0]);
		var scaley = FlowUtil.getDouble(args[1]);
		RenderSupportHx.setClipScaleY(clip, scaley);
		return ConstantVoid(pos);
	}

	public function setClipRotation(args : FlowArray<Flow>, pos : Position) : Flow  {
		var clip = FlowUtil.getNative(args[0]);
		var rot = FlowUtil.getDouble(args[1]);
		RenderSupportHx.setClipRotation(clip, rot);
		return ConstantVoid(pos);
	}

	public function setClipAlpha(args : FlowArray<Flow>, pos : Position) : Flow  {
		var clip = FlowUtil.getNative(args[0]);
		var alpha = FlowUtil.getDouble(args[1]);
		RenderSupportHx.setClipAlpha(clip, alpha);
		return ConstantVoid(pos);
	}

	public function setClipMask(args : FlowArray<Flow>, pos : Position) : Flow  {
		var clip = FlowUtil.getNative(args[0]);
		var mask = FlowUtil.getNative(args[1]);
		RenderSupportHx.setClipMask(clip, mask);
		return ConstantVoid(pos);
	}

	public function getStage(args : FlowArray<Flow>, pos : Position) : Flow  {
		return ConstantNative(RenderSupportHx.getStage(), pos);
	}

	//[- Dry up =] it is used only for stage in flow code, clip arg is useless
	public function addKeyEventListener(args : FlowArray<Flow>, pos : Position) : Flow  {
		var clip = FlowUtil.getNative(args[0]);
		var event = FlowUtil.getString(args[1]);
		var fn = interpreter.registerRoot(args[2]);
		var me = this;
		var keycb = function(s : String, ctrl : Bool, shift : Bool, alt : Bool, meta : Bool, code : Int, preventDefault : Void -> Void) {
				me.interpreter.eval(Call(me.interpreter.lookupRoot(fn), FlowArrayUtil.fromArray([
					ConstantString(s, pos),
					ConstantBool(ctrl, pos),
					ConstantBool(shift, pos),
					ConstantBool(alt, pos),
					ConstantBool(meta, pos),
					ConstantI32((code), pos),
					NativeClosure(0, function(flow, pos) {
						preventDefault();
						return ConstantVoid(pos);
					}, pos)
				]), pos));
			}
		var ndisp = RenderSupportHx.addKeyEventListener(clip, event, keycb);
		var disp = function(flow, pos) {
			ndisp();
			interpreter.releaseRoot(fn);
			return ConstantVoid(pos);
		}
		return NativeClosure(0, disp, pos);
	}

	public function addStreamStatusListener(args : FlowArray<Flow>, pos : Position) : Flow  {
		var clip = FlowUtil.getNative(args[0]);
		var fn = interpreter.registerRoot(args[1]);
		var me = this;
		var cb = function(s : String) {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(fn), FlowArrayUtil.fromArray([
				ConstantString(s, pos)
			]), pos));
		};
		var disp = RenderSupportHx.addStreamStatusListener(clip, cb);
		return NativeClosure(0, function(flow, pos) {
			me.interpreter.releaseRoot(fn);
			disp();
			return ConstantVoid(pos);
		}, pos);
	}

	public function addEventListener(args : FlowArray<Flow>, pos : Position) : Flow  {
		var clip = FlowUtil.getNative(args[0]);
		var event = FlowUtil.getString(args[1]);
		var fn = interpreter.registerRoot(args[2]);
		var me = this;
		var cb = function() {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(fn), new FlowArray(), pos));
		};

		var disp = RenderSupportHx.addEventListener(clip, event, cb);
		return NativeClosure(0, function(flow, pos) {
			me.interpreter.releaseRoot(fn);
			disp();
			return ConstantVoid(pos);
		}, pos);
	}

	public function addFileDropListener(args : FlowArray<Flow>, pos : Position) : Flow {
		var clip = FlowUtil.getNative(args[0]);
		var maxFiles : Int = FlowUtil.getInt(args[1]);
		var filter : String = FlowUtil.getString(args[2]);
		var fnDone = interpreter.registerRoot(args[3]);
		
		var me = this;

		var onDone = function (files : Array<Dynamic>) {
			var fls = new FlowArray();
			for (file in files) {
				fls.push(ConstantNative(file, pos));
			}

			me.interpreter.eval(Call(me.interpreter.lookupRoot(fnDone), FlowArrayUtil.one(ConstantArray(fls, pos)), pos));
			return ConstantVoid(pos);
		};

		var disp = RenderSupportHx.addFileDropListener(clip, maxFiles, filter, onDone);
		return NativeClosure(0, function(flow, pos) {
			me.interpreter.releaseRoot(fnDone);
			disp();
			return ConstantVoid(pos);
		}, pos);
	}

	public function addVirtualKeyboardHeightListener(args : FlowArray<Flow>, pos : Position) : Flow  {
		// NOP
		return NativeClosure(0, function(flow, pos) {
			return ConstantVoid(pos);
		}, pos);
	}

	public function addMouseWheelEventListener(args : FlowArray<Flow>, pos : Position) : Flow  {
		var clip = FlowUtil.getNative(args[0]);
		var fn = interpreter.registerRoot(args[1]);
		var me = this;
		var cb = function(delta : Float) {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(fn), 
				FlowArrayUtil.one(ConstantDouble(delta, pos)), pos)
			);
		};
		var disp = RenderSupportHx.addMouseWheelEventListener(clip, cb);
		return NativeClosure(0, function(flow, pos) {
			me.interpreter.releaseRoot(fn);
			disp();
			return ConstantVoid(pos);
		}, pos);
	}
	public function addFinegrainMouseWheelEventListener(args : FlowArray<Flow>, pos : Position) : Flow {
		var clip = FlowUtil.getNative(args[0]);
		var f = interpreter.registerRoot(args[1]);
		var me = this;
		var cb = function(dx : Float, dy : Float) {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(f),
				FlowArrayUtil.two(ConstantDouble(dx, pos), 
								  ConstantDouble(dy, pos)), pos)
			);
		};
		var disp = RenderSupportHx.addFinegrainMouseWheelEventListener(clip, cb);
		return NativeClosure(0, function(flow, pos) {
			me.interpreter.releaseRoot(f);
			disp();
			return ConstantVoid(pos);
		}, pos);
	}

	public function getMouseX(args : FlowArray<Flow>, pos : Position) : Flow  {
		var clip = FlowUtil.getNative(args[0]);
		return ConstantDouble(RenderSupportHx.getMouseX(clip), pos);
	}

	public function getMouseY(args : FlowArray<Flow>, pos : Position) : Flow  {
		var clip = FlowUtil.getNative(args[0]);
		return ConstantDouble(RenderSupportHx.getMouseY(clip), pos);
	}
	public function hittest(args : FlowArray<Flow>, pos : Position) : Flow  {
		var clip = FlowUtil.getNative(args[0]);
		var x = FlowUtil.getDouble(args[1]);
		var y = FlowUtil.getDouble(args[2]);
		return ConstantBool(RenderSupportHx.hittest(clip, x, y), pos);
	}

	public function getGraphics(args : FlowArray<Flow>, pos : Position) : Flow  {
		var clip = FlowUtil.getNative(args[0]);
		return ConstantNative(RenderSupportHx.getGraphics(clip), pos);
	}

	public function setLineStyle(args : FlowArray<Flow>, pos : Position) : Flow  {
		var graphics = FlowUtil.getNative(args[0]);
		var width = FlowUtil.getDouble(args[1]);
		var colour = FlowUtil.getInt(args[2]);
		var opacity = FlowUtil.getDouble(args[3]);
		RenderSupportHx.setLineStyle(graphics, width, colour, opacity);
		return ConstantVoid(pos);
	}

	public function setLineStyle2(args : FlowArray<Flow>, pos : Position) : Flow  {
		var graphics = FlowUtil.getNative(args[0]);
		var width = FlowUtil.getDouble(args[1]);
		var colour = FlowUtil.getInt(args[2]);
		var opacity = FlowUtil.getDouble(args[3]);
		var pixelHinting = FlowUtil.getBool(args[4]);
		RenderSupportHx.setLineStyle2(graphics, width, colour, opacity, pixelHinting);
		return ConstantVoid(pos);
	}

	public function beginFill(args : FlowArray<Flow>, pos : Position) : Flow  {
		var graphics = FlowUtil.getNative(args[0]);
		var colour = FlowUtil.getInt(args[1]);
		var opacity = FlowUtil.getDouble(args[2]);
		RenderSupportHx.beginFill(graphics, colour, opacity);
		return ConstantVoid(pos);
	}

	// native beginLineGradientFill : (graphics : native, colors : [int], alphas: [double], offsets: [double], matrix : native) -> void = RenderSupport.beginFill;
	public function beginGradientFill(args : FlowArray<Flow>, pos : Position) : Flow {
		var graphics = FlowUtil.getNative(args[0]);
		var colours : FlowArray<Flow> = FlowUtil.getArray(args[1]);
		var alphas : FlowArray<Flow> = FlowUtil.getArray(args[2]);
		var offsets : FlowArray<Flow> = FlowUtil.getArray(args[3]);
		var matrix = FlowUtil.getNative(args[4]);
		var type = FlowUtil.getString(args[5]);					
		var cols : Array<Int> = [];
		var alps = [];
		var offs = [];
		for (i in 0...colours.length) {
			cols.push(FlowUtil.getInt(colours[i]));
			alps.push(FlowUtil.getDouble(alphas[i]));
			offs.push(FlowUtil.getDouble(offsets[i]));
		}
		RenderSupportHx.beginGradientFill(graphics, cols, alps, offs, matrix, type);
		return ConstantVoid(pos);
	}
	// native setLineGradientStroke : (graphics : native, colors : [int], alphas: [double], offsets: [double]) -> void = RenderSupport.beginFill;
	public function setLineGradientStroke(args : FlowArray<Flow>, pos : Position) : Flow {
		var graphics = FlowUtil.getNative(args[0]);
		var colours : FlowArray<Flow> = FlowUtil.getArray(args[1]);
		var alphas : FlowArray<Flow> = FlowUtil.getArray(args[2]);
		var offsets : FlowArray<Flow> = FlowUtil.getArray(args[3]);
		var matrix = FlowUtil.getNative(args[4]);
		var cols : Array<Int> = [];
		var alps = [];
		var offs = [];
		for (i in 0...colours.length) {
			cols.push(FlowUtil.getInt(colours[i]));
			alps.push(FlowUtil.getDouble(alphas[i]));
			offs.push(FlowUtil.getDouble(offsets[i]));
		}
		RenderSupportHx.setLineGradientStroke(graphics, cols, alps, offs, matrix);
		return ConstantVoid(pos);
	}

	public function makeMatrix(args : FlowArray<Flow>, pos : Position) : Flow {
		var width : Float = FlowUtil.getDouble(args[0]);
		var height : Float = FlowUtil.getDouble(args[1]);
		var rotation : Float = FlowUtil.getDouble(args[2]);
		var xOffset : Float = FlowUtil.getDouble(args[3]);
		var yOffset : Float = FlowUtil.getDouble(args[4]);
		return ConstantNative(RenderSupportHx.makeMatrix(width, height, rotation, xOffset, yOffset), pos);
	}

	public function moveTo(args : FlowArray<Flow>, pos : Position) : Flow  {
		var graphics = FlowUtil.getNative(args[0]);
		var x = FlowUtil.getDouble(args[1]);
		var y = FlowUtil.getDouble(args[2]);
		RenderSupportHx.moveTo(graphics, x, y);
		return ConstantVoid(pos);
	}

	public function lineTo(args : FlowArray<Flow>, pos : Position) : Flow  {
		var graphics = FlowUtil.getNative(args[0]);
		var x = FlowUtil.getDouble(args[1]);
		var y = FlowUtil.getDouble(args[2]);
		RenderSupportHx.lineTo(graphics, x, y);
		return ConstantVoid(pos);
	}

	public function curveTo(args : FlowArray<Flow>, pos : Position) : Flow  {
		var graphics = FlowUtil.getNative(args[0]);
		var cx = FlowUtil.getDouble(args[1]);
		var cy = FlowUtil.getDouble(args[2]);
		var x = FlowUtil.getDouble(args[3]);
		var y = FlowUtil.getDouble(args[4]);
		RenderSupportHx.curveTo(graphics, cx, cy, x, y);
		return ConstantVoid(pos);
	}

	public function endFill(args : FlowArray<Flow>, pos : Position) : Flow  {
		var graphics = FlowUtil.getNative(args[0]);
		RenderSupportHx.endFill(graphics);
		return ConstantVoid(pos);
	}

	//native makePicture : (url : string, cache : bool, metricsFn : (width : double, height : double) -> void, errorFn : (string) -> void, onlyDownload : bool) -> native = RenderSupport.makePicture;
	public function makePicture(args : FlowArray<Flow>, pos : Position) : Flow  {
		var url = FlowUtil.getString(args[0]);
		var cache = FlowUtil.getBool(args[1]);
		var metricsFn = interpreter.registerRoot(args[2]);
		var errorsFn = interpreter.registerRoot(args[3]);

		var me = this;
		var reportError = function(s) {
			var args = new FlowArray();
			args.push(ConstantString(s, pos));
			var e = me.interpreter.lookupRoot(errorsFn);
			me.interpreter.releaseRoot(metricsFn);
			me.interpreter.releaseRoot(errorsFn);
			me.interpreter.eval(Call(e, args, pos));
		}

		var setMetrics = function(w, h) {
			var args = new FlowArray();
			args.push(ConstantDouble(w, pos));
			args.push(ConstantDouble(h, pos));
			var l = me.interpreter.lookupRoot(metricsFn);
			if (l != null) me.interpreter.eval(Call(l, args, pos));
			me.interpreter.releaseRoot(metricsFn);
			me.interpreter.releaseRoot(errorsFn);
		}

		return ConstantNative(RenderSupportHx.makePicture(url, cache, setMetrics, reportError, false), pos);
	}

	public function setCursor(args : FlowArray<Flow>, pos : Position) : Flow  {
		var cursor = FlowUtil.getString(args[0]);
		RenderSupportHx.setCursor(cursor);
		return ConstantVoid(pos);
	}

	public function getCursor(args : FlowArray<Flow>, pos : Position) : Flow  {
		return ConstantString(RenderSupportHx.getCursor(), pos);
	}

	// native addFilters(native, [native]) -> void = RenderSupport.addFilters;
	public function addFilters(args : FlowArray<Flow>, pos : Position) : Flow  {
		var clip = FlowUtil.getNative(args[0]);
		var filters : FlowArray<Flow> = FlowUtil.getArray(args[1]);
		var fils = [];
		for (f in filters) {
			fils.push(FlowUtil.getNative(f));
		}
		RenderSupportHx.addFilters(clip, fils);
		return ConstantVoid(pos);
	}

	public function makeBevel(args : FlowArray<Flow>, pos : Position) : Flow  {
		var angle = FlowUtil.getDouble(args[0]);
		var distance = FlowUtil.getDouble(args[1]);
		var radius = FlowUtil.getDouble(args[2]);
		var spread = FlowUtil.getDouble(args[3]);
		var color1 = FlowUtil.getInt(args[4]);
		var alpha1 = FlowUtil.getDouble(args[5]);
		var color2 = FlowUtil.getInt(args[6]);
		var alpha2 = FlowUtil.getDouble(args[7]);
		var inside = FlowUtil.getBool(args[8]);
		return ConstantNative(RenderSupportHx.makeBevel(angle, distance, radius, spread, color1, alpha1, color2, alpha2, inside), pos);
	}

	public function makeBlur(args : FlowArray<Flow>, pos : Position) : Flow  {
		var radius = Std.int(FlowUtil.getDouble(args[0]));
		var spread = Std.int(FlowUtil.getDouble(args[1]));
		return ConstantNative(RenderSupportHx.makeBlur(radius, spread), pos);
	}

	public function makeDropShadow(args : FlowArray<Flow>, pos : Position) : Flow  {
		var angle = FlowUtil.getDouble(args[0]);
		var distance = FlowUtil.getDouble(args[1]);
		var radius = FlowUtil.getDouble(args[2]);
		var spread = FlowUtil.getDouble(args[3]);
		var color = FlowUtil.getInt(args[4]);
		var alpha = FlowUtil.getDouble(args[5]);
		var inside = FlowUtil.getBool(args[6]);
		return ConstantNative(RenderSupportHx.makeDropShadow(angle, distance, radius, spread, color, alpha, inside), pos);

	}

	public function makeGlow(args : FlowArray<Flow>, pos : Position) : Flow  {
		var radius : Float = FlowUtil.getDouble(args[0]);
		var spread : Float = FlowUtil.getDouble(args[1]);
		var color : Int = FlowUtil.getInt(args[2]);
		var alpha : Float = FlowUtil.getDouble(args[3]);
		var inside : Bool = FlowUtil.getBool(args[4]);
		return ConstantNative(RenderSupportHx.makeGlow(radius, spread, color, alpha, inside), pos);
	}

	public function setScrollRect(args : FlowArray<Flow>, pos : Position) : Flow  {
		var clip = FlowUtil.getNative(args[0]);
		var left = FlowUtil.getDouble(args[1]);
		var top = FlowUtil.getDouble(args[2]);
		var width = FlowUtil.getDouble(args[3]);
		var height = FlowUtil.getDouble(args[4]);
		RenderSupportHx.setScrollRect(clip, left, top, width, height);
		return ConstantVoid(pos);
	}

	public function getTextMetrics(args : FlowArray<Flow>, pos : Position) : Flow {
		var textfield  = FlowUtil.getNative(args[0]);
		var res = RenderSupportHx.getTextMetrics(textfield);

		return ConstantArray(FlowArrayUtil.fromArray([ConstantDouble(res[0], pos), ConstantDouble(res[1], pos), ConstantDouble(res[2], pos)]), pos);
	}

	public function makeBitmap(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantNative(RenderSupportHx.makeBitmap(), pos);
	}
	
	public function bitmapDraw(args : FlowArray<Flow>, pos : Position) : Flow {
		var bitmap = FlowUtil.getNative(args[0]);
		var clip = FlowUtil.getNative(args[1]);
		var width = FlowUtil.getInt(args[2]);
		var height = FlowUtil.getInt(args[3]);

		RenderSupportHx.bitmapDraw(bitmap, clip, width, height);
		return ConstantVoid(pos);
	}

	// setAccessAttributes(clip, attrs) 
	public function setAccessAttributes(args : FlowArray<Flow>, pos : Position) : Flow {
		var clip : Dynamic = FlowUtil.getNative(args[0]);
		var attributes : FlowArray<Flow> = FlowUtil.getArray(args[1]);
		var attrs : Array< Array<String> > = [];

		for (pair in attributes) {
			var pa = FlowUtil.getArray(pair);
			var key = FlowUtil.getString(pa[0]);
			var value = FlowUtil.getString(pa[1]);
			attrs.push([key, value]); 
		}

		RenderSupportHx.setAccessAttributes(clip, attrs);
		return ConstantVoid(pos);
	}

	public function setAccessCallback(args : FlowArray<Flow>, pos : Position) : Flow {
		var clip : Dynamic = FlowUtil.getNative(args[0]);
		var fn = interpreter.registerRoot(args[1]);
		var me = this;
		var cb = function() {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(fn), new FlowArray(), pos));
		};
		RenderSupportHx.setAccessCallback(clip, cb);
		return ConstantVoid(pos);
	}

	public function setClipVisible(args : FlowArray<Flow>, pos : Position) : Flow {
		var clip  = FlowUtil.getNative(args[0]);
		var vis = FlowUtil.getBool(args[1]);
		RenderSupportHx.setClipVisible(clip, vis);
		return ConstantVoid(pos);
	}

	public function getClipVisible(args : FlowArray<Flow>, pos : Position) : Flow {
		var clip  = FlowUtil.getNative(args[0]);
		return ConstantBool(RenderSupportHx.getClipVisible(clip), pos);
	}

	public function setFullScreenTarget(args: FlowArray<Flow>, pos : Position) : Flow {
		var target = FlowUtil.getNative(args[0]);
		RenderSupportHx.setFullScreenTarget(target);
		return ConstantVoid(pos);
	}
	
	public function setFullScreenRectangle(args: FlowArray<Flow>, pos : Position) : Flow {
		var x: Float = FlowUtil.getDouble(args[0]);
		var y: Float = FlowUtil.getDouble(args[1]);
		var w: Float = FlowUtil.getDouble(args[2]);
		var h: Float = FlowUtil.getDouble(args[3]);
		RenderSupportHx.setFullScreenRectangle(x, y, w, h);
		return ConstantVoid(pos);
	}
	
	public function resetFullScreenTarget(args: FlowArray<Flow>, pos : Position) : Flow {
		RenderSupportHx.resetFullScreenTarget();
		return ConstantVoid(pos);
	}
	
	public function toggleFullScreen(args: FlowArray<Flow>, pos : Position) : Flow {
		RenderSupportHx.toggleFullScreen(FlowUtil.getBool(args[0]));
		return ConstantVoid(pos);
	}
	
	
	public function onFullScreen(args: FlowArray<Flow>, pos : Position) : Flow {
		var fn = interpreter.registerRoot(args[0]);
		var me = this;
		var cb = function(fs) {
			me.interpreter.eval(
				Call(
					me.interpreter.lookupRoot(fn), 
					FlowArrayUtil.fromArray([
						ConstantBool(fs, pos),
					]), 
					pos
				)
			);
		}
		var disp = RenderSupportHx.onFullScreen(cb);
		return NativeClosure(0, 
			function(flow, pos) {
				disp();
				me.interpreter.releaseRoot(fn);
				return ConstantVoid(pos);
			}, 
			pos
		);
	}
	
	public function isFullScreen(args: FlowArray<Flow>, pos : Position) : Flow {
		return ConstantBool(RenderSupportHx.isFullScreen(), pos);
	}

	public function setFullScreen(args: FlowArray<Flow>, pos : Position) : Flow {
		RenderSupportHx.setFullScreen(FlowUtil.getBool(args[0]));
		return ConstantVoid(pos);
	}
	
	public function setWindowTitle(args: FlowArray<Flow>, pos : Position) : Flow {
		var title = FlowUtil.getString(args[0]);
		RenderSupportHx.setWindowTitle(title);
		return ConstantVoid(pos);
	}

	public function setFavIcon(args: FlowArray<Flow>, pos : Position) : Flow {
		var url = FlowUtil.getString(args[0]);
		RenderSupportHx.setFavIcon(url);
		return ConstantVoid(pos);
	}

	public function takeSnapshot(args: FlowArray<Flow>, pos : Position) : Flow {
		var path = FlowUtil.getString(args[0]);
		RenderSupportHx.takeSnapshot(path);
		return ConstantVoid(pos);
	}

	public function getScreenPixelColor(args: FlowArray<Flow>, pos : Position) : Flow {
		var x = FlowUtil.getInt(args[0]);
		var y = FlowUtil.getInt(args[1]);
		var c = RenderSupportHx.getScreenPixelColor(x, y);
		return ConstantI32(c, pos);
	}

	public function getNumberOfCameras(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantI32(RenderSupportHx.getNumberOfCameras(), pos);
	}

	public function getCameraInfo(args : FlowArray<Flow>, pos : Position) : Flow {
		var id = FlowUtil.getInt(args[0]);
		return ConstantString(RenderSupportHx.getCameraInfo(id), pos);
	}

	public function makeCamera(args : FlowArray<Flow>, pos : Position) : Flow  {
		var uri = FlowUtil.getString(args[0]);
		var camID = FlowUtil.getInt(args[1]);
		var camWidth = FlowUtil.getInt(args[2]);
		var camHeight = FlowUtil.getInt(args[3]);
		var camFps = FlowUtil.getDouble(args[4]);
		var vidWidth = FlowUtil.getInt(args[5]);
		var vidHeight = FlowUtil.getInt(args[6]);
		var recordMode = FlowUtil.getInt(args[7]);
		var cbOnReadyForRecording = interpreter.registerRoot(args[8]);
		var cbOnFailed = interpreter.registerRoot(args[9]);
		var me = this;
		var setcbOnReadyForRecording = function(stream) {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(cbOnReadyForRecording), FlowArrayUtil.fromArray([
				ConstantNative(stream, pos),
			]), pos));
			me.interpreter.releaseRoot(cbOnReadyForRecording);
		}
		var setcbOnFailed = function(msg) {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(cbOnFailed), FlowArrayUtil.fromArray([
				ConstantString(msg, pos),
			]), pos));
			me.interpreter.releaseRoot(cbOnFailed);
		}

		var res = RenderSupportHx.makeCamera(uri, camID, camWidth, camHeight, camFps, vidWidth, vidHeight, recordMode, setcbOnReadyForRecording, setcbOnFailed);

		return ConstantArray(FlowArrayUtil.fromArray([ConstantNative(res[0], pos), ConstantNative(res[1], pos)]), pos);
	}

	public function startRecord(args : FlowArray<Flow>, pos : Position) : Flow {
		var stream : Dynamic = FlowUtil.getNative(args[0]);
		var filename = FlowUtil.getString(args[1]);
		var mode = FlowUtil.getString(args[2]);
		RenderSupportHx.startRecord(stream, filename, mode);
		return ConstantVoid(pos);
	}

	public function stopRecord(args : FlowArray<Flow>, pos : Position) : Flow {
		var stream : Dynamic = FlowUtil.getNative(args[0]);
		RenderSupportHx.stopRecord(stream);
		return ConstantVoid(pos);
	}

	public function cameraTakePhoto(args : FlowArray<Flow>, pos : Position) : Flow {
		// not implemented yet for js/flash
		return ConstantVoid(pos);
	}

	public function cameraTakeVideo(args : FlowArray<Flow>, pos : Position) : Flow {
		// not implemented yet for js/flash
		return ConstantVoid(pos);
	}

	public function addGestureListener(args : FlowArray<Flow>, pos : Position) : Flow {
		// NOP
		return NativeClosure(0, function(flow, pos) {
			return ConstantVoid(pos);
		}, pos);
	}

	public function setInterfaceOrientation(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantVoid(pos);
	}

	public function setUrlHash(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantVoid(pos);
	}

	public function getUrlHash(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantString(RenderSupportHx.getUrlHash(), pos);
	}

	public function addUrlHashListener(args : FlowArray<Flow>, pos : Position) : Flow {
		// NOP
		return NativeClosure(0, function(flow, pos) {
			return ConstantVoid(pos);
		}, pos);
	}

	public function setGlobalZoomEnabled(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantVoid(pos);
	}
}
