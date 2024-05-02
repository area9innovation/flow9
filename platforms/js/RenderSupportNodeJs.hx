class RenderSupport {
	public function new() {}

	public static function getPixelsPerCm() : Float  {
		return 0.0;
	}

	public static function setHitboxRadius(radius : Float) : Bool {
		return false;
	}

	// native currentClip : () -> flow = FlashSupport.currentClip;
	public static function currentClip() : Dynamic  {
		return null;
	}

	// native enableResize() -> void;
	public static function enableResize() : Void  {
	}

	public static function getStageWidth() : Float  {
		return 0.0;
	}

	public static function getStageHeight() : Float  {
		return 0.0;
	}

	// native makeTextfield : (fontfamily : String) -> native
	public static function makeTextField(fontfamily : String) : Dynamic  {
		return null;
	}

	public static function makeVideo(width : Int, height : Int, metricsFn : Int -> Int -> Void, durationFn : Float -> Void) : Array<Dynamic>  {
		return [];
	}

	public static function setVideoVolume(stream : Dynamic, volume : Float): Void {}

	public static function setVideoLooping(str: Dynamic, loop : Bool) : Void {}

	public static function setVideoControls(str: Dynamic, controls : Dynamic) : Void {}

	public static function setVideoSubtitle(str: Dynamic, text : String, size : Float, color : Int) : Void {}

	public static function playVideo(str : Dynamic, filename : String, startPaused : Bool) : Void {}

	public static function seekVideo(str : Dynamic, seek : Float) : Void {}

	public static function getVideoPosition(str : Dynamic) : Float {
		return 0.0;
	}

	public static function pauseVideo(str : Dynamic) : Float {
		return 0.0;
	}

	public static function resumeVideo(str : Dynamic) : Float {
		return 0.0;
	}

	public static function closeVideo(str : Dynamic) : Float {
		return 0.0;
	}

	public static function setTextAndStyle(
		textfield : Dynamic, text : String, fontfamily : String,
		fontsize : Float, fontweight : Int, fontslope : String,
		fillcolour : Int, fillopacity : Float, letterspacing : Float,
		backgroundcolour : Int, backgroundopacity : Float
	) : Dynamic {

		return null;
	}

	public static function setTextDirection(textfield : Dynamic, direction : String) : Void {}

	public static function setAdvancedText(textfield : Dynamic, sharpness : Int, antialiastype : Int, gridfittype : Int) : Void {}

	public static function getTextFieldWidth(textfield : Dynamic) : Float {
		return 0.0;
	}

	public static function setTextFieldWidth(textfield : Dynamic, width : Float) : Void {}

	public static function getTextFieldHeight(textfield : Dynamic) : Float {
		return 0.0;
	}

	public static function setTextFieldHeight(textfield : Dynamic, height : Float) : Void {}

	public static function setAutoAlign(textfield : Dynamic, autoalign : String) : Void {}

	public static function setTextInput(textfield : Dynamic) : Void {}

	public static function setTextInputType(textfield : Dynamic, type : String) : Void {}

	//[- Dry up -] There already is acess attribute for tabindex
	public static function setTabIndex(textfield : Dynamic, index : Int) : Void {}

	public static function setTabEnabled(textfield : Dynamic, enabled : Bool) : Void {}

	public static function getContent(textfield : Dynamic) : String {
		return "";
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

	public static function setScrollV(textfield : Dynamic, suggestedPosition : Int) : Void {}

	public static function getBottomScrollV(textfield : Dynamic) : Int {
		return 0;
	}

	public static function getNumLines(textfield : Dynamic) : Int {
		return 0;
	}

	public static function setFocus(clip : Dynamic, focus : Bool) : Void {}

	public static function setMultiline(clip : Dynamic, multiline : Bool) : Void {}

	public static function setWordWrap(clip : Dynamic, wordWrap : Bool) : Void {}

	public static function setDoNotInvalidateStage(clip : Dynamic, value : Bool) : Void {}

	public static function getSelectionStart(textfield : Dynamic) : Int {
		return 0;
	}

	public static function getSelectionEnd(textfield : Dynamic) : Int {
		return 0;
	}

	public static function setSelection(textfield : Dynamic, start : Int, end : Int) : Void {}

	// [- Dry up -] setReadonly(false) in fact is almost eq. setTextInput
	public static function setReadOnly(textfield: Dynamic, readOnly: Bool) : Void {}

	public static function setMaxChars(textfield : Dynamic, maxChars : Int) : Void {}

	public static function setAutofillBackgroundColor(textfield : Dynamic, autofillBackgroundColor : Int) : Void {}

	// native addChild : (parent : native, child : native) -> void
	public static function addChild(parent : Dynamic, child : Dynamic) : Void {}

	// native removeChild : (parent : native, child : native) -> void
	public static function removeChild(parent : Dynamic, child : Dynamic) : Void {}

	public static function makeClip() : Dynamic  {
		return null;
	}

	public static function makeWebClip(url : String, domain : String, useCache : Bool, reloadBlock : Bool, cb : Array<String> -> String, ondone : String -> Void, shrinkToFit : Bool) : Dynamic {
		return null;
	}

	public static function setWebClipSandBox(clip : Dynamic, value : String) : Void {}

	public static function setWebClipDisabled(clip : Dynamic, value : Bool) : Void {}

	public static function webClipHostCall(clip : Dynamic, name : String, args : Array<String>) : String {
		return "";
	}

	public static function webClipEvalJS(clip : Dynamic, code : String, cb : Dynamic -> Void) : Void {}

	public static function setWebClipDomains(clip : Dynamic, domains : Array<String>) : Void {}

	public static function setClipCallstack(clip : Dynamic, callstack : Dynamic) : Void {}

	public static function setClipX(clip : Dynamic, x : Float) : Void {}

	public static function setClipY(clip : Dynamic, y : Float) : Void {}

	public static function setClipScaleX(clip : Dynamic, scale_x : Float) : Void {}

	public static function setClipScaleY(clip : Dynamic, scale_y : Float) : Void {}

	public static function setClipRotation(clip : Dynamic, r : Float) : Void {}

	public static function setClipAlpha(clip : Dynamic, a : Float) : Void {}

	public static function setClipMask(clip : Dynamic, mask : Dynamic) : Void {}

	public static function getStage() : Dynamic {
		return null;
	}

	//[- Dry up =] it is used only for stage in flow code, clip arg is useless
	public static function addKeyEventListener(
		clip : Dynamic,
		event : String,
		fn : String -> Bool -> Bool -> Bool -> Bool -> Int -> (Void -> Void) -> Void) : Void -> Void {
		return function() {};
	}

	public static function addStreamStatusListener(clip : Dynamic, fn : String -> Void) : Void -> Void {
		return function() {};
	}

	public static function addEventListener(clip : Dynamic, event : String, fn : Void -> Void) : Void -> Void {
		return function() {};
	}

	public static function addFileDropListener(clip : Dynamic, maxFilesCount : Int, mimeTypeRegExFilter : String, onDone : Array<Dynamic> -> Void) : Void -> Void {
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

	public static function getMouseX(clip : Dynamic) : Float {
		return 0.0;
	}

	public static function getMouseY(clip : Dynamic) : Float {
		return 0.0;
	}
	public static function hittest(clip : Dynamic, x : Float, y : Float) : Bool {
		return false;
	}

	public static function getGraphics(clip : Dynamic) : Dynamic {
		return null;
	}

	public static function setLineStyle(graphics : Dynamic, width : Float, color : Int, opacity : Float) : Void {}

	public static function setLineStyle2(graphics : Dynamic, width : Float, color : Int, opacity : Float, pixelHinting : Bool) : Void {}

	public static function beginFill(graphics : Dynamic, color : Int, opacity : Float) : Void {}

	// native beginLineGradientFill : (graphics : native, colors : [int], alphas: [double], offsets: [double], matrix : native) -> void = RenderSupport.beginFill;
	public static function beginGradientFill(graphics : Dynamic, colors : Array<Int>, alphas : Array<Float>, offsets: Array<Float>, matrix : Dynamic, type : String) : Void {}
	// native setLineGradientStroke : (graphics : native, colors : [int], alphas: [double], offsets: [double]) -> void = RenderSupport.beginFill;

	public static function setLineGradientStroke(graphics : Dynamic, colours : Array<Int>, alphas : Array<Float>, offsets : Array<Float>, matrix : Dynamic) : Void {}

	public static function makeMatrix(width : Float, height : Float, rotation : Float, xOffset : Float, yOffset : Float) : Dynamic {
		return null;
	}

	public static function moveTo(graphics : Dynamic, x : Float, y : Float) : Void {}

	public static function lineTo(graphics : Dynamic, x : Float, y : Float) : Void {}

	public static function curveTo(graphics : Dynamic, cx : Float, cy : Float, x : Float, y : Float) : Void {}

	public static function endFill(graphics : Dynamic) : Void {}

	//native makePicture : (url : string, cache : bool, metricsFn : (width : double, height : double) -> void, errorFn : (string) -> void, onlyDownload : bool, altText : string) -> native = RenderSupport.makePicture;
	public static function makePicture(url : String, cache : Bool, metricsFn : Float -> Float -> Void, errorFn : String -> Void, onlyDownload : Bool, altText : String) : Dynamic {
		return null;
	}

	public static function setCursor(cursor : String) : Void {}

	public static function getCursor() : String {
		return "";
	}

	// native addFilters(native, [native]) -> void = RenderSupport.addFilters;
	public static function addFilters(clip : Dynamic, filters : Array<Dynamic>) : Void {}

	public static function makeBevel(angle : Float, distance : Float, radius : Float, spread : Float,
							color1 : Int, alpha1 : Float, color2 : Int, alpha2 : Float, inside : Bool) : Dynamic {
		return null;
	}

	public static function makeBlur(radius : Float, spread : Float) : Dynamic {
		return null;
	}

	public static function makeDropShadow(angle : Float, distance : Float, radius : Float, spread : Float,
							color : Int, alpha : Float, inside : Bool) : Dynamic {
		return null;
	}

	public static function makeGlow(radius : Float, spread : Float, color : Int, alpha : Float, inside : Bool) : Dynamic {
		return null;
	}

	public static function setScrollRect(clip : Dynamic, left : Float, top : Float, width : Float, height : Float) : Void {}

	public static function getTextMetrics(textfield : Dynamic) : Array<Float> {
		return [];
	}

	public static function makeBitmap() : Dynamic {
		return null;
	}

	public static function bitmapDraw(bitmap : Dynamic, clip : Dynamic, width : Int, height : Int) : Void {}

	public static function addPasteEventListener(cb : Array<Dynamic> -> Void) : (Void -> Void) {
		return function() {};
	}

	// setAccessAttributes(clip, attrs)
	public static function setAccessAttributes(clip : Dynamic, properties : Array<Array<Dynamic>>) : Void {}

	public static function setAccessCallback(clip : Dynamic, cb : Void -> Void) : Void {}

	public static function setClipVisible(clip : Dynamic, vis : Bool) : Void {}

	public static function getClipVisible(clip : Dynamic) : Bool {
		return false;
	}

	public static function setFullScreenTarget(clip:Dynamic) : Void {}

	public static function setFullScreenRectangle(x:Float, y:Float, w:Float, h:Float) : Void {}

	public static function resetFullScreenTarget() : Void {}

	public static function toggleFullScreen(fs:Bool) : Void {}


	public static function onFullScreen(fn : Bool -> Void) : Void -> Void {
		return function() {};
	}

	public static function isFullScreen() : Bool {
		return false;
	}

	public static function setFullScreen(fs : Bool) : Void {}

	public static function setWindowTitle(title : String) : Void {}

	public static function setFavIcon(url : String) : Void {}

	public static function takeSnapshot(path : String) : Void {}

	public static function getScreenPixelColor(x : Int, y : Int) : Int {
		return 0;
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

	public static function startRecord(str : Dynamic, filename : String, mode : String) : Void {}

	public static function stopRecord(str : Dynamic) : Void {}

	public static function cameraTakePhoto(cameraId : Int, additionalInfo : String, desiredWidth : Int, desiredHeight : Int, compressQuality : Int, fileName : String, fitMode : Int) : Void {}

	public static function cameraTakeVideo(cameraId : Int, additionalInfo : String, duration : Int, size : Int, quality : Int, fileName : String) : Void {}

	public static function addGestureListener(event : String, cb : Int -> Float -> Float -> Float -> Float -> Bool) : Void -> Void {
		return function() {};
	}

	public static function setInterfaceOrientation(orientation : String) : Void {}

	public static function setUrlHash(hash : String) : Void {}

	public static function getUrlHash() : String {
		return "";
	}

	public static function addUrlHashListener(cb : String -> Void) : Void -> Void {
		return function() {};
	}

	public static function setGlobalZoomEnabled(enabled : Bool) : Void {}
}
