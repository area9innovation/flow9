#if js
import js.Browser;

private enum GraphOp {
	MoveTo(x : Float, y : Float);
	LineTo(x : Float, y : Float);
	CurveTo(x : Float, y : Float, cx : Float, cy : Float);
}

private class FlowClip {
	private static var curGlobalTransform : Dynamic;
	private static var zBuffer : Array<FlowClip>;
	private static var TreeChanged : Bool;

	public static var MouseRadius : Float;

	public var x : Float;
	public var y : Float;
	public var scaleX : Float;
	public var scaleY : Float;
	public var rot : Float;
	public var alpha : Float; // TODO : calculate global vis and alpha
	public var visible : Bool;

	private var scrollTop : Float;
	private var scrollLeft : Float;
	private var scrollWidth : Float;
	private var scrollHeight : Float;
	private var isClipped : Bool;

	private var children : Array<FlowClip>;
	private var graphics : FlowGraphics;
	private var globalTransform : Dynamic;

	private var isMask : Bool;
	private var mask : FlowClip;

	public static function __init__() {
		curGlobalTransform = {x : 0.0, y : 0.0, sx : 1.0, sy : 1.0};
		zBuffer = new Array<FlowClip>();
		TreeChanged = true;
		MouseRadius = 0.0;
	}

	public static function makeCSSColor(color : Int, alpha : Float) : Dynamic
	{
		return "rgba(" + ((color >> 16) & 255)  + "," + ((color >> 8) & 255) + "," + (color & 255) + "," + (alpha) + ")" ;
	}

	public function new() {
		children = new Array<FlowClip>();

		x = y = rot = 0.0;
		scaleX = scaleY = 1.0;

		globalTransform = {x : 0.0, y : 0.0, sx : 1.0, sy : 1.0};

		alpha = 1.0;
		visible = true;

		scrollLeft = scrollTop = scrollWidth = scrollHeight = 0.0;
		isClipped = false;

		isMask = false;
		mask = null;
	}

	public static function beginDrawing() {
		if (TreeChanged) { // zBuffer should be updated
			zBuffer = new Array<FlowClip>();
		}
	}

	public static function endDrawing() {
		TreeChanged = false;
	}

	public static function getClipByGlobalPoint(global_x : Float, global_y : Float) : FlowClip {
		for (i in 1...zBuffer.length) {
			if (zBuffer[zBuffer.length - i].hittestInner(global_x, global_y)) return zBuffer[zBuffer.length - i];
		}
		return null;
	}

	private function removed() {
		for (c in children) c.removed();
	}

	public function getGraphics() {
		if (graphics == null) graphics = new FlowGraphics();
		return graphics;
	}

	public function addChild(child : FlowClip) : Void {
		children.push(child);
		TreeChanged = true;
	}

	public function removeChild(child : FlowClip) : Void {
		children.remove(child);
		child.removed();
		TreeChanged = true;
	}

	public function draw(context : Dynamic) : Void {
		if (alpha <= 0.01 || !visible || isMask) return;

		if (TreeChanged) zBuffer.push(this);

		var savedCurGlobalTransform = {x: curGlobalTransform.x, y : curGlobalTransform.y, sx : curGlobalTransform.sx, sy : curGlobalTransform.sy};
		context.save();

		context.translate(x, y); context.scale(scaleX, scaleY); context.rotate(rot);

		// calculate current global transformation
		curGlobalTransform.x = curGlobalTransform.x + curGlobalTransform.sx * (x - scrollLeft);
		curGlobalTransform.y = curGlobalTransform.y + curGlobalTransform.sy * (y - scrollTop);
		curGlobalTransform.sx = curGlobalTransform.sx * scaleX;
		curGlobalTransform.sy = curGlobalTransform.sy * scaleY;
		globalTransform = { x: curGlobalTransform.x, y : curGlobalTransform.y, sx : curGlobalTransform.sx, sy : curGlobalTransform.sy};

		if (isClipped) {
			context.beginPath();
			context.strokeStyle = "rgba(0,0,0,0)"; // transparent clipping path
			context.rect(0.0, 0.0, scrollWidth, scrollHeight);
			context.stroke();
			context.clip();
			context.translate(-scrollLeft, -scrollTop); // TO DO : fix hittest for clipped
		}

		context.globalAlpha = alpha; // * 0.5;

		drawInner(context);

		context.restore();
		curGlobalTransform = savedCurGlobalTransform;
	}

	private function drawInner(context : Dynamic) : Void {
		if (graphics != null) // Assume clip either has grahics or childs
			graphics.draw(context);
		else
			for (c in children) c.draw(context);
	}

	public function global2local(global_x : Float, global_y : Float) : Dynamic {
		return { x : (global_x - globalTransform.x) / globalTransform.sx,
			y : (global_y - globalTransform.y ) / globalTransform.sy };
	}

	private function local2global(local_x : Float, local_y : Float) : Dynamic {
		return { x : local_x * globalTransform.sx + globalTransform.x,
			y : local_y * globalTransform.sy + globalTransform.y };
	}

	public function hittest(global_x : Float, global_y : Float) : Bool {
		if (alpha <= 0.01 || !visible) return false;
		
		if ( hittestInner(global_x, global_y) ) return true;

		for (c in children) {
			if (c.hittest(global_x, global_y)) return true;
		}

		return false;
	}

	private function hittestRectWithMouseRadius(x : Float, y : Float, left : Float, top : Float, right : Float, bottom : Float) : Bool {
		return (x + MouseRadius) >= left && (y + MouseRadius >= top) && (x - MouseRadius) <= right && (y - MouseRadius) <= bottom;
	}

	private function hittestInner(global_x : Float, global_y : Float) : Bool {
		if (graphics != null) {
			var local : Dynamic = global2local(global_x, global_y);
			var metrics : Dynamic = graphics.getMetrics();
			return hittestRectWithMouseRadius(local.x, local.y, metrics.left, metrics.top, metrics.right, metrics.bottom);
		}

		return false;
	}


	public function setScrollRect(left : Float, top : Float, width : Float, height : Float) : Void {
		isClipped = true;
		scrollLeft = left;
		scrollTop = top;
		scrollWidth = width;
		scrollHeight = height;
	}

	public function setMask(m : FlowClip) : Void {
		mask = m;
		m.isMask = true;
	}
}

private class FlowGraphics {
	private var graphOps : Array<GraphOp>;

	var strokeWidth : Float;
	var strokeColor : Int;
	var strokeOpacity : Float;

	var fillColor : Int;
	var fillOpacity : Float;
	var fillGradientColors : Array<Int>;
	var fillGradientAlphas : Array<Float>;
	var fillGradientOffsets : Array<Float>;
	var fillGradientMatrix : Dynamic;
	var fillGradientType : String;
	var wh : Dynamic;

	public function new() {
		graphOps = new Array<GraphOp>();
		strokeOpacity = fillOpacity = 0.0;
		strokeWidth = 0.0;
	}

	public function addGraphOp(op : GraphOp) {
		graphOps.push(op);
	}

	public function setLineStyle(width : Float, color : Int, opacity : Float) {
		strokeWidth = width; strokeColor = color; strokeOpacity = opacity;
	}

	public function setSolidFill(color : Int, opacity : Float) {
		fillColor = color; fillOpacity = opacity;
	}

	public function setGradientFill(colors : Array<Int>, alphas : Array<Float>, offsets: Array<Float>, matrix : Dynamic, type : String) {
		fillGradientColors = colors; fillGradientAlphas = alphas; fillGradientOffsets = offsets;
		fillGradientMatrix = matrix; fillGradientType = type;
	}

	public function getMetrics() : Dynamic {
		var max_x = Math.NEGATIVE_INFINITY, max_y = Math.NEGATIVE_INFINITY;
		var min_x = Math.POSITIVE_INFINITY, min_y = Math.POSITIVE_INFINITY;

		for (op in graphOps) {
			switch (op) {
				case MoveTo(x, y):
					if (x > max_x) max_x = x; else if (x < min_x) min_x = x; if (y > max_y) max_y = y; else if (y < min_y) min_y = y;
				case LineTo(x, y):
					if (x > max_x) max_x = x; else if (x < min_x) min_x = x; if (y > max_y) max_y = y; else if (y < min_y) min_y = y;
				case CurveTo(x, y, cx, cy):
					if (x > max_x) max_x = x; else if (x < min_x) min_x = x; if (y > max_y) max_y = y; else if (y < min_y) min_y = y;
					if (cx > max_x) max_x = cx; else if (cx < min_x) min_x = cx; if (cy > max_y) max_y = cy; else if (cy < min_y) min_y = cy;
			}
		}
		return {left : min_x, top : min_y, right : max_x + strokeWidth, bottom : max_y + strokeWidth};
	}

	public function draw(ctx : Dynamic) {
		if (strokeOpacity != 0.0) {
			ctx.lineWidth = strokeWidth;
			ctx.strokeStyle = FlowClip.makeCSSColor(strokeColor, strokeOpacity);
		}

		if (fillOpacity != 0.0) {
			ctx.fillStyle = FlowClip.makeCSSColor(fillColor, fillOpacity);
		}

		if (fillGradientColors != null) {
			var width : Float = fillGradientMatrix[0]; var height : Float = fillGradientMatrix[1];
			var rotation : Float = fillGradientMatrix[2]; var xOffset : Float = fillGradientMatrix[3];
			var yOffset : Float = fillGradientMatrix[4];

			var gradient = ctx.createLinearGradient(xOffset, yOffset, width * Math.cos(rotation / 180.0 * Math.PI), height * Math.sin(rotation / 180.0 * Math.PI));

			for (i in 0...fillGradientColors.length)
				gradient.addColorStop(fillGradientOffsets[i], FlowClip.makeCSSColor(fillGradientColors[i], fillGradientAlphas[i]) );

			ctx.fillStyle = gradient;
		}

		// Render path
		ctx.beginPath();
		ctx.moveTo(0.0, 0.0);
		for (op in graphOps) {
			switch (op) {
				case MoveTo(x, y): ctx.moveTo(x, y);
				case LineTo(x, y): ctx.lineTo(x, y);
				case CurveTo(x, y, cx, cy): ctx.quadraticCurveTo(cx, cy, x, y);
			}
		}

		if (fillOpacity != 0.0 || fillGradientColors != null) {
			ctx.closePath();
			ctx.fill();
		}

		if (strokeOpacity != 0.0) ctx.stroke();	
	}
}

private class FlowTextClip extends FlowClip {
	private var text : String;
	private var font : String;
	private var fillStyle : String;
	private var fontSize : Float;

	private var height : Float;
	private var width : Float;

	private var nativeWidget : Dynamic;

	private static var pwdTemplate : String = "***************************************";

	private static var activeNativeWidget : Dynamic;

	// Show native widget on click
	public static function onStageMouseDown(global_x : Float, global_y : Float) {	
		var clip : Dynamic = FlowClip.getClipByGlobalPoint(global_x, global_y);
		if (clip != null && clip.nativeWidget != null) {
			clip.nativeWidget.style.display = "block"; // show it
			activeNativeWidget = clip.nativeWidget;
			haxe.Timer.delay( function() { clip.nativeWidget.focus(); }, 200);
		} else if (activeNativeWidget != null) {
			activeNativeWidget.blur();
			activeNativeWidget.style.display = "none";
			activeNativeWidget = null;
		}
	}

	public function new() {
		super();
		text =  "";

		fontSize = 15.0; // Defaults
		font = "15px";
		fillStyle = "#000000";

		height = width = 0.0;
		nativeWidget = null;
		activeNativeWidget = null;
	}

	private override function removed() {
		if (nativeWidget != null) {
			js.Browser.document.body.removeChild(nativeWidget);
		}
	}

	public function setTextAndStyle(txt : String, family : String, size : Float, fontweight : Int, fontslope : String, color : Int) : Void {
		text = txt;
		font = "" + size + "px " + family;
		fontSize = size;
		fillStyle = FlowClip.makeCSSColor(color, 1.0);
	}

	private override function drawInner(context : Dynamic) : Void {
		if (nativeWidget != null) {
			if (nativeWidget.style.display == "none") {// native textbox hidden
				context.fillStyle = fillStyle;
				context.font = font;
				if (nativeWidget.type == "password")
					context.fillText(pwdTemplate.substring(0, untyped nativeWidget.value.length - 1), 0.0, fontSize * 1.15);
				else
 					context.fillText(nativeWidget.value, 0.0, fontSize * 1.15);
			} else {
				var wid_xy = local2global(0.0, 0.0);
				var wid_width = width * globalTransform.sx;
				var wid_height = height * globalTransform.sy;
				nativeWidget.style.left = "" + wid_xy.x + "px"; nativeWidget.style.top = "" + wid_xy.y + "px";
				nativeWidget.height = wid_height; nativeWidget.width = wid_width;
			}
		} else {
			context.fillStyle = fillStyle;
			context.font = font;
 			context.fillText(text, 0.0, fontSize * 1.15); // left, bottom expected
 		}
	}

	public function getWidth(context : Dynamic) : Float {
		if (width > 0.0) {
			return width;
		} else {
			context.font = font;
			return context.measureText(text).width;
		}
	}

	public function getHeight(context : Dynamic) : Float {
		return (height > 0.0) ? height : fontSize * 1.15; // TO DO: ???
	}

	public function getFontSize() : Float {
		return fontSize;
	}

	public function setTextInput() : Void {
		nativeWidget = js.Browser.document.createElement('INPUT');
		nativeWidget.style.position = "absolute";
		nativeWidget.style.display = "none";
		nativeWidget.onblur = function() { nativeWidget.style.display = "none"; activeNativeWidget = null; };
		js.Browser.document.body.appendChild(nativeWidget);
	}

	public function addOnChangeListener(cb : Void -> Void) : Void -> Void {
		nativeWidget.addEventListener("input", cb, true);
		return function() { nativeWidget.removeEventListener("input", cb); };
	}

	public function setWidth(w : Float) : Void {
		width = w;
	}

	public function setHeight(h : Float) : Void {
		height = h;
	}

	public function getContent() : String {
		if (nativeWidget != null) 
			return nativeWidget.value;
		else
			return "";
	}

	private override function hittestInner(global_x : Float, global_y : Float) : Bool {
		var local = global2local(global_x, global_y);
		return hittestRectWithMouseRadius(local.x, local.y, 0, 0, width, height);
	}

	public function setPasswordMode(is_password : Bool) : Void {
		if (nativeWidget != null) nativeWidget.type = is_password ? "password" : "text";
	}
}

private class FlowPictureClip extends FlowClip {
	private var url: String;
	private var dom_image : Dynamic;
	private var height : Float;
	private var width : Float;
	private var OnlyDownload : Bool;

	public function new(image_url : String, on_error : String -> Void, metrics_fn : Float -> Float -> Void, onlyDownload) {
		super();

		width = height = 0.0;
		url = StringTools.replace(image_url, ".swf", ".png");

		dom_image = untyped __js__ ("new Image()");
		dom_image.src = url;

		if (dom_image.height > 0.0 && dom_image.width > 0.0) { // cached before by browser
				width = dom_image.width; height = dom_image.height;
				metrics_fn(width, height);
		} else {
			dom_image.onload = function() {
				width = dom_image.width; height = dom_image.height;
				metrics_fn(width, height);
			};

			dom_image.onerror = function() {
				on_error("Cannot load image \"" + url + "\"");
			};
		}

		OnlyDownload = onlyDownload;
	}

	private override function drawInner(context : Dynamic) : Void {
		if (OnlyDownload) return;
		try {
			context.drawImage(dom_image, 0.0, 0.0);
		} catch (e : Dynamic) {
			// InvalidStateError when image data is not ready yet
		}
	}

	private override function hittestInner(global_x : Float, global_y : Float) : Bool {
		var local = global2local(global_x, global_y);
		return hittestRectWithMouseRadius(local.x, local.y, 0, 0, width, height);
	}
}

class RenderSupportJS {
	private static var CurrentClip : FlowClip;
	private static var StageCanvas : Dynamic;
	private static var Context;
	private static var StageWidth : Float;
	private static var StageHeight : Float;
	private static var FrameCount : Int;
	private static var MouseX : Float;
	private static var MouseY : Float;

	public static function Nop() {} // Empty functioon for return values

	public function new() {}

	public static function init() {
		Errors.print("Using custom 2D canvas rendering");
		js.Browser.document.body.style.backgroundImage = "none"; // Hide splash
		CurrentClip = new FlowClip();

		StageCanvas = js.Browser.document.createElement("CANVAS");
		StageCanvas.id = "Stage";
		js.Browser.document.body.appendChild(StageCanvas);	
		updateStageCanvasWH();

		if (!isTouchScreen()) {
			StageCanvas.onmousemove = function(e : Dynamic) {
				MouseX = untyped e.clientX; MouseY = untyped e.clientY;
				//Errors.print("MM: " + MouseX + " " + MouseY);
			}

			StageCanvas.onmousedown = function(e : Dynamic) {
				ShowMousePosition = true;
				FlowTextClip.onStageMouseDown(e.clientX, e.clientY);
			}

			StageCanvas.onmouseup = function(e : Dynamic) {
				ShowMousePosition = false;
			}
		} else {
			FlowClip.MouseRadius = 10.0;

			StageCanvas.ontouchmove = function(e : Dynamic) {
				MouseX = untyped e.touches[0].clientX;
				MouseY = untyped e.touches[0].clientY + untyped Browser.window.pageYOffset; // pageYOffset by screen kbd 
				//Errors.print("TM: " + MouseX + " " + MouseY);
				e.preventDefault(); // Dont scroll window
			}

			StageCanvas.ontouchstart = function(e : Dynamic) {

				ShowMousePosition = true;
				MouseX = untyped e.touches[0].clientX;
				MouseY = untyped e.touches[0].clientY + untyped Browser.window.pageYOffset;
				FlowTextClip.onStageMouseDown(MouseX, MouseY);
			}

			StageCanvas.ontouchend = function( e : Dynamic) {
				ShowMousePosition = false;
			}
		}

		js.Browser.window.onresize = function(e) { updateStageCanvasWH(); };

		FrameCount = 0;
		ShowMousePosition = false;
		renderStage(0);		
	}

	private static function isTouchScreen() : Bool {
		return untyped __js__("typeof document.documentElement.ontouchstart != 'undefined'"); 
	}

	private static function updateStageCanvasWH() : Void {
		StageWidth = js.Browser.window.innerWidth;
		StageHeight = js.Browser.window.innerHeight;
		untyped StageCanvas.width = StageWidth;
		untyped StageCanvas.height = StageHeight;	
		Context = untyped StageCanvas.getContext("2d");
	}

	private static var PrevTimestamp : Int;
	private static var ShowMousePosition : Bool;
	private static function drawMousePosition() : Void {
		/*Context.beginPath();
		Context.arc(MouseX, MouseY, 30.0, 0, 2 * Math.PI, false);
		Context.fillStyle = "rgba(0,255,0, 0.3)";
		Context.fill();

		if (FlowClip.MouseRadius > 0.0) {
			Context.beginPath();
			Context.arc(MouseX, MouseY, FlowClip.MouseRadius, 0, 2 * Math.PI, false);
			Context.fillStyle = "rgba(255,0,0, 0.7)";
			Context.fill();
		}*/
	}

	public static function renderStage(timestamp : Int) {
		++FrameCount;
		if (FrameCount % 300 == 0 && timestamp != 0) {
			Errors.print("Frame #: " + FrameCount + " fps: " + (300 / (timestamp - PrevTimestamp) * 1000) );
			PrevTimestamp = timestamp;
		}

		if (FrameCount % 10 == 0) {// 30 fps is enough?
			Context.clearRect(0.0, 0.0, StageWidth, StageHeight);

			FlowClip.beginDrawing();
			CurrentClip.draw(Context);
			FlowClip.endDrawing();

			if (ShowMousePosition) drawMousePosition();
		}

		if (untyped Browser.window.webkitRequestAnimationFrame != null)
			untyped webkitRequestAnimationFrame(renderStage);
		else if (untyped Browser.window.requestAnimationFrame != null)
			untyped requestAnimationFrame(renderStage);
		else
			haxe.Timer.delay( function() { renderStage(0); }, 50);
	}

	public static function getPixelsPerCm() : Float {
		return 96.0/2.54;
	}

	public static function setHitboxRadius(radius : Float) : Bool {
		return false;
	}

	static public function setAccessAttributes(clip : Dynamic, properties : Array<Array<Dynamic>>) : Void {
	}

	static public function setAccessCallback(clip : Dynamic, cb : Void -> Void) : Void {
	}

	// native currentClip : () -> flow = FlashSupport.currentClip;
	public static function currentClip() : Dynamic  {
		return CurrentClip;
	}

	// native enableResize() -> void;
	public static function enableResize() : Void {
	}

	public static function getStageWidth() : Float {
		return StageWidth;
	}

	public static function getStageHeight() : Float {
		return StageHeight;
	}

	// native makeTextfield : () -> native
	public static function makeTextField() : Dynamic  {
		return new FlowTextClip();
	}

	public static function setTextAndStyle(
		textfield : FlowTextClip, text : String, fontfamily : String,
		fontsize : Float, fontweight : Int, fontslope : String,
		fillcolour : Int, fillopacity : Float, letterspacing : Float,
		backgroundcolour : Int, backgroundopacity : Float, forTextinput : Bool
	) : Void  {

		textfield.setTextAndStyle(text, fontfamily, fontsize, fontweight, fontslope, fillcolour);
	}

	public static function setTextDirection(textfield : Dynamic, direction : String) : Void {
	}

	public static function setAdvancedText(textfield : Dynamic, sharpness : Int, antialiastype : Int, gridfittype : Int) : Void  {
	}

	public static function makeVideo(width : Int, height : Int, metricsFn : Int -> Int -> Void, durationFn : Float -> Void) : Array<Dynamic> {
			return [null, null];
	}

	public static function setVideoVolume(str: Dynamic, volume : Float) : Void {
	}

	public static function setVideoLooping(str: Dynamic, loop : Bool) : Void {
	}

	public static function setVideoControls(str: Dynamic, controls : Dynamic) : Void {
	}

	public static function setVideoSubtitle(str: Dynamic, text : String, size : Float, color : Int) : Void {
	}

	public static function playVideo(str : Dynamic, filename : String, startPaused : Bool) : Void {
	}

	public static function seekVideo(str : Dynamic, seek : Float) : Void  {
	}

	public static function getVideoPosition(str : Dynamic) : Float  {
		return 0.0;
	}

	public static function pauseVideo(str : Dynamic) : Void {
	}

	public static function resumeVideo(str : Dynamic) : Void {
	}

	public static function closeVideo(str : Dynamic) : Void {
	}

	public static function getTextFieldWidth(textfield : FlowTextClip) : Float {
		return textfield.getWidth(Context);
	}

	public static function setTextFieldWidth(textfield : FlowTextClip, width : Float) : Void {
		textfield.setWidth(width);
	}

	public static function getTextFieldHeight(textfield : FlowTextClip) : Float {
		return textfield.getHeight(Context);
	}

	public static function setTextFieldHeight(textfield : FlowTextClip, height : Float) : Void {
		textfield.setHeight(height);
	}

	public static function setAutoAlign(textfield : Dynamic, autoalign : String) : Void {
	}

	public static function setTextInput(textfield : FlowTextClip) : Void {
		textfield.setTextInput();
	}

	public static function setTabIndex(textfield : Dynamic, index : Int) : Void {
	}

	public static function getContent(textfield : FlowTextClip) : String {
		return textfield.getContent();
	}

	public static function getCursorPosition(textfield : Dynamic) : Int {
		return 0;
	}

	public static function getFocus(clip : Dynamic) : Bool {
		return false;
	}

	public static function getScrollV(textfield : Dynamic) : Int {
		return 0;
	}

    public static function setScrollV(textfield : Dynamic, suggestedPosition : Int) : Void {
	}

	public static function getBottomScrollV(textfield : Dynamic) : Int {
		return 0;
	}

	public static function getNumLines(textfield : Dynamic) : Int {
		return 0;
	}

	public static function setFocus(clip : Dynamic, focus : Bool) : Void {
	}

	public static function setMultiline(clip : Dynamic, multiline : Bool) : Void {
	}

	public static function setWordWrap(clip : Dynamic, wordWrap : Bool) : Void {
		Errors.print("setWordWrap");
	}

	public static function getSelectionStart(textfield : Dynamic) : Int {
		return 0;
	}

	public static function getSelectionEnd(textfield : Dynamic) : Int {
		return 0;
	}

	public static function setSelection(textfield : Dynamic, start : Int, end : Int) : Void {
	}

	public static function setNumeric(textfield : Dynamic, numeric : Bool) : Void {
	}

	public static function setReadOnly(textfield: Dynamic, readOnly: Bool) : Void {
	}

	public static function setMaxChars(textfield : Dynamic, maxChars : Int) : Void {
	}

	// native addChild : (parent : native, child : native) -> void
	public static function addChild(parent : FlowClip, child : FlowClip) : Void {
		parent.addChild(child);
	}

	// native removeChild : (parent : native, child : native) -> void
	public static function removeChild(parent : FlowClip, child : FlowClip) : Void {
		parent.removeChild(child);
	}

	public static function makeClip() : Dynamic  {
		return new FlowClip();
	}

    public static function setClipCallstack(clip : Dynamic, callstack : Dynamic) : Void {
        // stub
    }

	public static function setClipX(clip : FlowClip, x : Float) : Void {
		clip.x = x;
	}

	public static function setClipY(clip : FlowClip, y : Float) : Void {
		clip.y = y;
	}

	public static function setClipScaleX(clip : FlowClip, scale_x : Float) : Void {
		clip.scaleX = scale_x;
	}

	public static function setClipScaleY(clip : FlowClip, scale_y : Float) : Void {
		clip.scaleY = scale_y;
	}

	public static function setClipRotation(clip : FlowClip, r : Float) : Void {
		clip.rot = r / 180.0 * Math.PI;
	}

	public static function setClipAlpha(clip : FlowClip, a : Float) : Void {
		clip.alpha = a;
	}

	public static function setClipMask(clip : FlowClip, mask : FlowClip) : Void {
		clip.setMask(mask);
	}

	public static function getStage() : Dynamic  { // CurrentClip == Stage for this renderer
		return CurrentClip;
	}

	public static function addKeyEventListener(clip : Dynamic, event : String, fn : String -> Bool -> Bool -> Bool -> Int -> Void) : Void -> Void {
		return function() {};
	}

	public static function addStreamStatusListener(clip : Dynamic, fn : String -> Void) : Void -> Void {
		return function() {};
	}

	public static function addEventListener(clip : FlowClip, event : String, fn : Void -> Void) : Void -> Void {
		if (clip != CurrentClip && event != "change") return Nop; // Only stage and textbox events for this renderer

		if (event == "change") return (untyped clip.addOnChangeListener(fn));
		
		if (event == "resize") {
			if (untyped js.Browser.window.onorientationchange != null) event = "orientationchange"; // Mobile device
//			untyped js.Browser.window.addEventListener(event, fn);
//			return function() { untyped js.Browser.window.removeEventListener(event, fn); };
		}

		if (event != "mousemove" && event != "mouseup" && event != "mousedown") return Nop;

		if (!isTouchScreen()) {
			StageCanvas.addEventListener(event, fn);
			return function() { StageCanvas.removeEventListener(event, fn); };
		} else {
			var event_name = "";

			if (event == "mousemove") event_name = "touchmove";
			else if (event == "mousedown") event_name = "touchstart";
			else if (event == "mouseup") event_name = "touchend";

			StageCanvas.addEventListener(event_name, fn);

			return function() { StageCanvas.removeEventListener(event_name, fn); };
		}
	}

	public static function addFileDropListener(clip : FlowClip, maxFiles : Int, mimeTypeRegExFilter : String, onDone : Array<Dynamic> -> Void) : Void -> Void {
		return function() {};
	}

	public static function addVirtualKeyboardHeightListener(fn : Float -> Void) : Void -> Void {
		return function() {};
	}

	public static function addMouseWheelEventListener(clip : Dynamic, fn : Float -> Void) : Void -> Void {
		return function() {};
	}

	public static function addFinegrainMouseWheelEventListener(clip : Dynamic, f : Float->Float->Void) : Void->Void {
		return function() {};
	}

	public static function getMouseX(clip : FlowClip) : Float {
		return clip.global2local(MouseX, MouseY).x;
	}

	public static function getMouseY(clip : FlowClip) : Float {
		return clip.global2local(MouseX, MouseY).y;
	}

	public static function hittest(clip : FlowClip, global_x : Float, global_y : Float) : Bool {
		return clip.hittest(global_x, global_y);
	}

	public static function getGraphics(clip : FlowClip) : Dynamic  {
		return clip.getGraphics();
	}

	public static function setLineStyle(graphics : FlowGraphics, width : Float, color : Int, opacity : Float) : Void {
		graphics.setLineStyle(width, color, opacity);
	}

	public static function beginFill(graphics : FlowGraphics, color : Int, opacity : Float) : Void {
		graphics.setSolidFill(color, opacity);
	}

	// native beginLineGradientFill : (graphics : native, colors : [int], alphas: [double], offsets: [double], matrix : native) -> void = RenderSupport.beginFill;
	public static function beginGradientFill(graphics : FlowGraphics, colors : Array<Int>, alphas : Array<Float>, offsets: Array<Float>, matrix : Dynamic, type : String) : Void {
		graphics.setGradientFill(colors, alphas, offsets, matrix, "");
	}

	// native setLineGradientStroke : (graphics : FlowGraphics, colors : [int], alphas: [double], offsets: [double]) -> -void = RenderSupport.beginFill;
	public static function setLineGradientStroke(graphics : Dynamic, colours : Array<Int>, alphas : Array<Float>, offsets : Array<Float>, matrix : Dynamic) : Void {
	}

	public static function makeMatrix(width : Float, height : Float, rotation : Float, xOffset : Float, yOffset : Float) : Dynamic {
		return [ width, height, rotation, xOffset, yOffset ];
	}

	public static function moveTo(graphics : FlowGraphics, x : Float, y : Float) : Void {
		graphics.addGraphOp(MoveTo(x, y));
	}

	public static function lineTo(graphics : FlowGraphics, x : Float, y : Float) : Void {
		graphics.addGraphOp(LineTo(x, y));
	}

	public static function curveTo(graphics : FlowGraphics, cx : Float, cy : Float, x : Float, y : Float) : Void {
		graphics.addGraphOp(CurveTo(x, y, cx, cy));
	}

	public static function endFill(graphics : FlowGraphics) : Void {
	}

	//native makePicture : (url : string, cache : bool, metricsFn : (width : double, height : double) -> void,
	// errorFn : (string) -> void, onlyDownload : bool) -> native = RenderSupport.makePicture;
	public static function makePicture(url : String, cache : Bool, metricsFn : Float -> Float -> Void, errorFn : String -> Void, onlyDownload : Bool) : Dynamic {
		return new FlowPictureClip(url, errorFn, metricsFn, onlyDownload);
	}

	public static function setCursor(cursor : String) : Void {
	}

	public static function getCursor() : String {
		return "";
	}

	// native addFilters(native, [native]) -> void = RenderSupport.addFilters;
	public static function addFilters(clip : Dynamic, filters : Array<Dynamic>) : Void {
	}

	public static function makeBevel(angle : Float, distance : Float, radius : Float, spread : Float,
							color1 : Int, alpha1 : Float, color2 : Int, alpha2 : Float, inside : Bool) : Dynamic  {
      return null;
	}

	public static function makeBlur(radius : Float, spread : Float) : Dynamic {
      return null;
	}

	public static function makeDropShadow(angle : Float, distance : Float, radius : Float, spread : Float,
							color : Int, alpha : Float, inside : Bool) : Dynamic  {
      return null;
	}

	public static function makeGlow(radius : Float, spread : Float, color : Int, alpha : Float, inside : Bool) : Dynamic  {
      return null;
	}

	public static function setScrollRect(clip : FlowClip, left : Float, top : Float, width : Float, height : Float) : Void  {
		clip.setScrollRect(left, top, width, height);
	}

	public static function getTextMetrics(textfield : FlowTextClip) : Array<Float> {
		var font_size = textfield.getFontSize(); // TO DO : Use canvas context to get metrics???
		var ascent = 0.9 * font_size;
		var descent = 0.1 * font_size;
		var leading = 0.15 * font_size;
		return [ascent, descent, leading];
	}

	public static function makeBitmap() : Dynamic  {
      return null;
	}

	public static function bitmapDraw(bitmap : Dynamic, clip : Dynamic, width : Int, height : Int) : Void {
	}

	public static function setTextFieldPasswordMode(textfield : FlowTextClip, password : Bool) : Void {
		textfield.setPasswordMode(password);
	}

	public static function getClipVisible(clip : Dynamic) : Bool {
		return true;
	}

	public static function setClipVisible(clip : FlowClip, vis : Bool) : Void {
		clip.visible = vis;
	}

	public static function setFullScreenTarget(clip:Dynamic) : Void {
	}

	public static function setFullScreenRectangle(x:Float, y:Float, w:Float, h:Float) : Void {
	}

	public static function resetFullScreenTarget() : Void {
	}

	public static function toggleFullScreen(fs : Bool) : Void {
	}

	public static function onFullScreen(fn : Bool -> Void) : Void -> Void {
		return function() {};
	}

	public static function setFullScreen(fs : Bool) : Void {
		// Not implemented
	}

	public static function isFullScreen() : Bool {
		return false;
	}

	public static function setWindowTitle(title : String) : Void {
	}

	public static function setFavIcon(url : String) : Void {
	}

	public static function takeSnapshot(path : String) : Void {
	}

	public static function makeWebClip(url : String, domain : String, useCache : Bool, reloadBlock : Bool, cb : Array<String> -> String, shrinkToFit : Bool) : Dynamic {
		return null;
	}

	public static function webClipHostCall(clip : Dynamic, name : String, args : Array<String>) : String {
      return "";
	}

	public static function setWebClipSandBox(clip : Dynamic, value : String) : Void {
      return null;
	}

	public static function setWebClipDisabled(clip : Dynamic, value : Bool) : Void {
      return null;
	}

	public static function webClipEvalJS(clip : Dynamic, code : String) : Dynamic {
      return null;
	}

	public static function getNumberOfCameras() : Int {
	  return 0;
	}

	public static function getCameraInfo(id : Int) : String {
	  return "";
	}

	public static function makeCamera(uri : String, camID : Int, camWidth : Int, camHeight : Int, camFps : Float, vidWidth : Int, vidHeight : Int, recordMode : Int, cbOnReadyForRecording : Dynamic -> Void, cbOnFailed : String -> Void) :  Array<Dynamic> {
		return [];
	}

	public static function startRecord(str : Dynamic, filename : String, mode : String) : Void {
	}

	public static function stopRecord(str : Dynamic) : Void {
	}

	public static function cameraTakePhoto(cameraId : Int, additionalInfo : String, desiredWidth : Int, desiredHeight : Int, compressQuality : Int, fileName : String, fitMode : Int) : Void {
		// not implemented yet for js/flash
	}


	public static function addGestureListener(event : String, cb : Int -> Float -> Float -> Float -> Float -> Bool) : Void -> Void {
		// NOP
		return function() {};
	}

	public static function setWebClipZoomable(clip : Dynamic, zoomable : Bool) : Void {
		// NOP for these targets
	}

	public static function setWebClipDomains(clip : Dynamic, domains : Array<String>) : Void {
		// NOP for these targets
	}

	public static function setInterfaceOrientation(orientation : String) : Void {
		// NOP
	}

	public static function setGlobalZoomEnabled(enabled : Bool) : Void {
		// NOP
	}
}
#end