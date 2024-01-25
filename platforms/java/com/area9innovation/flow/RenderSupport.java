package com.area9innovation.flow;

import java.util.*;
import java.nio.charset.Charset;

@SuppressWarnings("unchecked")
public class RenderSupport extends NativeHost {
	private static Func0<Object> no_op = new Func0<Object>() {
		public Object invoke() { return null; }
	};

	public static Object getStage() {
		System.out.println("Warning: Empty getStage called");
		return null;
	}
	public static double getStageWidth() {
		System.out.println("Warning: Empty getStageWidth called");
		return 0;
	}
	public static double getStageHeight() {
		System.out.println("Warning: Empty getStageHeight called");
		return 0;
	}
	public static Object setHitboxRadius(double val) {
		System.out.println("Warning: Empty setHitboxRadius called");
		return null;
	}
	public static Object setWindowTitle(String title) {
		System.out.println("Warning: Empty setWindowTitle called");
		return null;
	}
	public static Object setFavIcon(String url) {
		System.out.println("Warning: Empty setFavIcon called");
		return null;
	}
	public static int getScreenPixelColor(double x, double y) {
		System.out.println("Warning: Empty getScreenPixelColor called");
		return 0;
	}
	public static Object enableResize() {
		System.out.println("Warning: Empty enableResize called");
		return null;
	}
	public static Object makeClip() {
		System.out.println("Warning: Empty makeClip called");
		return null;
	}
	public static Object assignClip(Object stage, String className, Object clip) {
		System.out.println("Warning: Empty assignClip called");
		return null;
	}
	public static Object makeGraphics() {
		System.out.println("Warning: Empty makeGraphics called");
		return null;
	}
	public static Object currentClip() {
		System.out.println("Warning: Empty currentClip called");
		return null;
	}
	public static Object makeWebClip(String url,String domain,Boolean useCache, Boolean reloadBlock, Func1<String,Object[]> cb, Func1<Object,String> ondone, Boolean shrinkToFit) {
		System.out.println("Warning: Empty makeWebClip called");
		return null;
	}
	public static String webClipHostCall(Object clip,String fn,Object[] args) {
		System.out.println("Warning: Empty webClipHostCall called");
		return null;
	}
	public static Object setWebClipSandBox(Object clip,String value) {
		System.out.println("Warning: Empty setWebClipSandBox called");
		return null;
	}
	public static Object setWebClipDisabled(Object clip,boolean value) {
		System.out.println("Warning: Empty setWebClipDisabled called");
		return null;
	}
	public static Object webClipEvalJS(Object clip,String code, Func1<Object,String> cb) {
		System.out.println("Warning: Empty webClipEvalJS called");
		return null;
	}
	public static Object setWebClipZoomable(Object clip,Boolean zoomable) {
		System.out.println("Warning: Empty setWebClipZoomable called");
		return null;
	}
	public static Object setWebClipDomains(Object clip, Object[] domains) {
		System.out.println("Warning: Empty setWebClipDomains called");
		return null;
	}
	public static Object makeHTMLStage(double width, double height) {
		System.out.println("Warning: Empty makeHTMLStage called");
		return null;
	}
	public static Object createElement(String tagName) {
		System.out.println("Warning: Empty createElement called");
		return null;
	}
	public static Object createTextNode(String text) {
		System.out.println("Warning: Empty createTextNode called");
		return null;
	}
	public static Object setAttribute(Object element, String name, String value, Boolean safe) {
		System.out.println("Warning: Empty setAttribute called");
		return null;
	}
	public static Object appendChild(Object element, Object child) {
		System.out.println("Warning: Empty appendChild called");
		return null;
	}
	public static Object insertBefore(Object element, Object child, Object reference) {
		System.out.println("Warning: Empty insertBefore called");
		return null;
	}
	public static Object removeElementChild(Object element, Object child) {
		System.out.println("Warning: Empty removeElementChild called");
		return null;
	}
	public static Object addFilters(Object stg, Object[] filters) {
		System.out.println("Warning: Empty addFilters called");
		return null;
	}
	public static Object setAccessAttributes(Object stg, Object[] attrs) {
		System.out.println("Warning: Empty setAccessAttributes called");
		return null;
	}
	public static Object setAccessCallback(Object stg, Func0<Object> fn) {
		System.out.println("Warning: Empty setAccessCallback called");
		return null;
	}
	public static Object addChild(Object stg, Object child) {
		System.out.println("Warning: Empty addChild called");
		return null;
	}
	public static Object addChildAt(Object stg, Object child, Integer at) {
		System.out.println("Warning: Empty addChildAt called");
		return null;
	}
	public static Object removeChild(Object stg, Object child) {
		System.out.println("Warning: Empty removeChild called");
		return null;
	}
	public static Object setClipMask(Object stg, Object mask) {
		System.out.println("Warning: Empty setClipMask called");
		return null;
	}
	public static Object setClipCallstack(Object stg, Object stack) {
		System.out.println("Warning: Empty setClipCallstack called");
		return null;
	}
	public static double getMouseX(Object stg) {
		System.out.println("Warning: Empty getMouseX called");
		return 0;
	}
	public static double getMouseY(Object stg) {
		System.out.println("Warning: Empty getMouseY called");
		return 0;
	}
	public static boolean getClipVisible(Object stg) {
		System.out.println("Warning: Empty getClipVisible called");
		return false;
	}
	public static Object setClipVisible(Object stg, boolean on) {
		System.out.println("Warning: Empty setClipVisible called");
		return null;
	}
	public static Object setClipX(Object stg, double val) {
		System.out.println("Warning: Empty setClipX called");
		return null;
	}
	public static Object setClipY(Object stg, double val) {
		System.out.println("Warning: Empty setClipY called");
		return null;
	}
	public static Object setClipScaleX(Object stg, double val) {
		System.out.println("Warning: Empty setClipScaleX called");
		return null;
	}
	public static Object setClipScaleY(Object stg, double val) {
		System.out.println("Warning: Empty setClipScaleY called");
		return null;
	}
	public static Object setClipAlpha(Object stg, double val) {
		System.out.println("Warning: Empty setClipAlpha called");
		return null;
	}
	public static Object setClipRotation(Object stg, double val) {
		System.out.println("Warning: Empty setClipRotation called");
		return null;
	}
	public static Object setClipWidth(Object clip, double width) {
		System.out.println("Warning: Empty setClipWidth called");
		return null;
	}
	public static double getClipHeight(Object clip) {
		System.out.println("Warning: Empty getClipHeight called");
		return 0;
	}
	public static double getClipWidth(Object clip) {
		System.out.println("Warning: Empty getClipWidth called");
		return 0;
	}
	public static Object setClipHeight(Object clip, double height) {
		System.out.println("Warning: Empty setClipHeight called");
		return null;
	}
	public static Object setClipResolution(Object clip, double resolution) {
		System.out.println("Warning: Empty setClipResolution called");
		return null;
	}
	public static Object setScrollRect(Object stg, double x, double y, double w, double h) {
		System.out.println("Warning: Empty setScrollRect called");
		return null;
	}
	public static String getCursor() {
		System.out.println("Warning: Empty getCursor called");
		return null;
	}
	public static Object setCursor(String val) {
		System.out.println("Warning: Empty setCursor called");
		return null;
	}
	public static Func0<Object> addEventListener(Object stg, String name, Func0<Object> fn) {
		System.out.println("Warning: Empty addEventListener called");
		return null;
	}
	public static Func0<Object> addFileDropListener(Object clib, Integer maxFilesCount, String mimeTypeRegExFilter, Func1<Object,Object[]> onDone) {
		System.out.println("Warning: Empty addFileDropListener called");
		return null;
	}
	public static Func0<Object> addVirtualKeyboardHeightListener(Func1<Object, Double> fn) {
		System.out.println("Warning: Empty addVirtualKeyboardHeightListener called");
		return null;
	}
	public static Func0<Object> addKeyEventListener(Object stg, String event, Func7<Object,String,Boolean,Boolean,Boolean,Boolean,Integer,Func0<Object>> cb) {
		System.out.println("Warning: Empty addKeyEventListener called");
		return null;
	}
	public static Object emitKeyEvent(Object stg, String name, String key, Boolean ctrl, Boolean shift, Boolean alt, Boolean meta, Integer code) {
		System.out.println("Warning: Empty emitKeyEvent called");
		return null;
	}
	public static Func0<Object> addMouseWheelEventListener(Object stg, Func1<Object,Double> cb) {
		System.out.println("Warning: Empty addMouseWheelEventListener called");
		return null;
	}
	public static Func0<Object> addFinegrainMouseWheelEventListener(Object stg, Func2<Object,Double,Double> cb) {
		System.out.println("Warning: Empty addFinegrainMouseWheelEventListener called");
		return null;
	}
	public static Func0<Object> addGestureListener(String name, Func5<Boolean,Integer,Double,Double,Double,Double> cb) {
		System.out.println("Warning: Empty addGestureListener called");
		return null;
	}
	public static boolean hittest(Object stg, double x, double y) {
		System.out.println("Warning: Empty hittest called");
		return false;
	}
	public static String getFontStylesConfigString() {
		System.out.println("Warning: Empty getFontStylesConfigString called");
		return null;
	}
	public static Object makeTextField(String fontfamily) {
		System.out.println("Warning: Empty makeTextField called");
		return null;
	}
	public static Object setTextInput(Object stg) {
		System.out.println("Warning: Empty setTextInput called");
		return null;
	}
	public static double getTextFieldWidth(Object stg) {
		System.out.println("Warning: Empty getTextFieldWidth called");
		return 0;
	}
	public static double getTextFieldHeight(Object stg) {
		System.out.println("Warning: Empty getTextFieldHeight called");
		return 0;
	}
	public static Object setTextFieldWidth(Object stg, double val) {
		System.out.println("Warning: Empty setTextFieldWidth called");
		return null;
	}
	public static Object setTextFieldHeight(Object stg, double val) {
		System.out.println("Warning: Empty setTextFieldHeight called");
		return null;
	}
	public static Object setTextFieldCropWords(Object stg, boolean val) {
		System.out.println("Warning: Empty setTextFieldCropWords called");
		return null;
	}
	public static Object setAdvancedText(Object stg,int a,int o,int e) {
		System.out.println("Warning: Empty setAdvancedText called");
		return null;
	}
	public static Object setTextInputType(Object stg, String type) {
		System.out.println("Warning: Empty setTextInputType called");
		return null;
	}
	public static Object setTextAndStyle(Object tf, String text, String fontFamily, double fontSize, int fontWeight,
								  String fontSlope, int fillColour, double fillOpacity, double letterSpacing,
								  int backgroundColour,double backgroundOpacity) {
		System.out.println("Warning: Empty setTextAndStyle called");
		return null;
	}
	public static Object setTextFieldInterlineSpacing(Object stg, double val) {
		System.out.println("Warning: Empty setTextFieldInterlineSpacing called");
		return null;
	}
	public static Object setTextDirection(Object stg, String val) {
		System.out.println("Warning: Empty setTextDirection called");
		return null;
	}
	public static int getNumLines(Object stg) {
		System.out.println("Warning: Empty getNumLines called");
		return 0;
	}
	public static int getCursorPosition(Object stg) {
		System.out.println("Warning: Empty getCursorPosition called");
		return 0;
	}
	public static boolean getFocus(Object stg) {
		System.out.println("Warning: Empty getFocus called");
		return false;
	}
	public static Object setFocus(Object stg, boolean val) {
		System.out.println("Warning: Empty setFocus called");
		return null;
	}
	public static String getContent(Object stg) {
		System.out.println("Warning: Empty getContent called");
		return null;
	}
	public static Object setMultiline(Object stg, boolean val) {
		System.out.println("Warning: Empty setMultiline called");
		return null;
	}
	public static Object setWordWrap(Object stg, boolean val) {
		System.out.println("Warning: Empty setWordWrap called");
		return null;
	}
	public static Object setReadOnly(Object stg, boolean val) {
		System.out.println("Warning: Empty setReadOnly called");
		return null;
	}
	public static Object setAutoAlign(Object stg, String val) {
		System.out.println("Warning: Empty setAutoAlign called");
		return null;
	}
	public static Object setTabIndex(Object stg, int val) {
		System.out.println("Warning: Empty setTabIndex called");
		return null;
	}
	public static int getScrollV(Object stg) {
		System.out.println("Warning: Empty getScrollV called");
		return 0;
	}
	public static int getBottomScrollV(Object stg) {
		System.out.println("Warning: Empty getBottomScrollV called");
		return 0;
	}
	public static Object setScrollV(Object stg, int val) {
		System.out.println("Warning: Empty setScrollV called");
		return null;
	}
	public static Object setMaxChars(Object stg, int val) {
		System.out.println("Warning: Empty setMaxChars called");
		return null;
	}
	public static Object[] getTextMetrics(Object stg) {
		System.out.println("Warning: Empty getTextMetrics called");
		return new Object[] { 0.0, 0.0, 0.0 };
	}
	public static int getSelectionStart(Object stg) {
		System.out.println("Warning: Empty getSelectionStart called");
		return 0;
	}
	public static int getSelectionEnd(Object stg) {
		System.out.println("Warning: Empty getSelectionEnd called");
		return 0;
	}
	public static Object setSelection(Object stg, int start, int end) {
		System.out.println("Warning: Empty setSelection called");
		return null;
	}
	public static Object makeVideo(Func2<Object,Double,Double> mfn, Func1<Object, Boolean> pfn, Func1<Object, Double> dfn, Func1<Object, Double> posfn) {
		System.out.println("Warning: Empty makeVideo called");
		return null;
	}
	public static Object pauseVideo(Object stg) {
		System.out.println("Warning: Empty pauseVideo called");
		return null;
	}
	public static Object resumeVideo(Object stg) {
		System.out.println("Warning: Empty resumeVideo called");
		return null;
	}
	public static Object closeVideo(Object stg) {
		System.out.println("Warning: Empty closeVideo called");
		return null;
	}
	public static Object playVideo(Object obj, String name, boolean pause, Object[] headers) {
		System.out.println("Warning: Empty playVideo called");
		return null;
	}
	public static double getVideoPosition(Object stg) {
		System.out.println("Warning: Empty getVideoPosition called");
		return 0;
	}
	public static Object seekVideo(Object stg, double val) {
		System.out.println("Warning: Empty seekVideo called");
		return null;
	}
	public static Object setVideoVolume(Object stg, double val) {
		System.out.println("Warning: Empty setVideoVolume called");
		return null;
	}
	public static Object setVideoLooping(Object stg, boolean val) {
		System.out.println("Warning: Empty setVideoLooping called");
		return null;
	}
	public static Object setVideoControls(Object stg, Object[] info) {
		System.out.println("Warning: Empty setVideoControls called");
		return null;
	}
	public static Object setVideoSubtitle(Object tf, String text, String fontFamily, double fontSize, int fontWeight,
								  String fontSlope, int fillColour, double fillOpacity, double letterSpacing,
								  int backgroundColour, double backgroundOpacity, boolean alignBottom,
								  double bottomBorder, boolean scaleMode, double scaleModeMin, double scaleModeMax, boolean escapeHTML) {
		System.out.println("Warning: Empty setVideoSubtitle called");
		return null;
	}
	public static Object setVideoPlaybackRate(Object tf, Double rate) {
		System.out.println("Warning: Empty setVideoPlaybackRate called");
		return null;
	}
	public static Func0<Object> addStreamStatusListener(Object vid, Func1<Object,String> cb) {
		System.out.println("Warning: Empty addStreamStatusListener called");
		return null;
	}
	public static boolean isFullScreen() {
		System.out.println("Warning: Empty isFullScreen called");
		return false;
	}
	public static Object toggleFullScreen(Boolean fs) {
		System.out.println("Warning: Empty toggleFullScreen called");
		return null;
	}
	public static Object toggleFullWindow(Boolean fs) {
		System.out.println("Warning: Empty toggleFullWindow called");
		return null;
	}
	public static Func0<Object> onFullScreen(Func1<Object,Boolean> cb) {
		System.out.println("Warning: Empty onFullScreen called");
		return null;
	}
	public static Object setFullScreen(Boolean fs) {
		System.out.println("Warning: Empty setFullScreen called");
		return null;
	}
	public static Object setFullWindowTarget(Object stg) {
		System.out.println("Warning: Empty setFullWindowTarget called");
		return null;
	}
	public static Object resetFullWindowTarget() {
		System.out.println("Warning: Empty resetFullWindowTarget called");
		return null;
	}
	public static Object setFullScreenRectangle(double x, double y, double w, double h) {
		System.out.println("Warning: Empty setFullScreenRectangle called");
		return null;
	}
	public static Object makeBevel(double a,double b,double c,double d,int e,double f,int g,double h,boolean i) {
		System.out.println("Warning: Empty makeBevel called");
		return null;
	}
	public static Object makeDropShadow(double a1,double a2,double a3,double a4,int a5,double a6,boolean a7) {
		System.out.println("Warning: Empty makeDropShadow called");
		return null;
	}
	public static Object makeBlur(double a,double b) {
		System.out.println("Warning: Empty makeBlur called");
		return null;
	}
	public static Object makeBackdropBlur(double a) {
		System.out.println("Warning: Empty makeBackdropBlur called");
		return null;
	}
	public static Object makeGlow(double a,double b,int c, double d,boolean e) {
		System.out.println("Warning: Empty makeGlow called");
		return null;
	}
	public static Object makePicture(String a,boolean b,Func2<Object,Double,Double> c,Func1<Object,String> d,boolean e, String alt, Object[] headers) {
		Native.println(">> EMPTY !!! makePicture");
		return null;
	}
	public static Object[] makeCamera(String a,int o,int e,int u,double i,int d,int h,int t,Func1<Object,Object> n,Func1<Object,String> s) {
		System.out.println("Warning: Empty makeCamera called");
		return null;
	}
	public static Object startRecord(Object cm,String a,String o) {
		System.out.println("Warning: Empty startRecord called");
		return null;
	}
	public static Object stopRecord(Object cm) {
		System.out.println("Warning: Empty stopRecord called");
		return null;
	}
	public static Object getGraphics(Object clip) {
		System.out.println("Warning: Empty getGraphics called");
		return null;
	}
	public static Object beginFill(Object gr,int c,double a) {
		System.out.println("Warning: Empty beginFill called");
		return null;
	}
	public static Object setLineStyle(Object gr,double a,int o,double e) {
		System.out.println("Warning: Empty setLineStyle called");
		return null;
	}
	public static Object setLineStyle2(Object gr,double a,int o,double e, boolean b) {
		System.out.println("Warning: Empty setLineStyle2 called");
		return null;
	}
	public static Object makeMatrix(double a,double o,double e,double u,double i) {
		System.out.println("Warning: Empty makeMatrix called");
		return null;
	}
	public static Object beginGradientFill(Object gr,Object[] a,Object[] o,Object[] e,Object u,String i) {
		System.out.println("Warning: Empty beginGradientFill called");
		return null;
	}
	public static Object setLineGradientStroke(Object gr,Object[] a,Object[] o,Object[] e,Object u) {
		System.out.println("Warning: Empty setLineGradientStroke called");
		return null;
	}
	public static Object moveTo(Object gr,double x,double y) {
		System.out.println("Warning: Empty moveTo called");
		return null;
	}
	public static Object lineTo(Object gr,double x,double y) {
		System.out.println("Warning: Empty lineTo called");
		return null;
	}
	public static Object curveTo(Object gr,double x,double y,double cx, double cy) {
		System.out.println("Warning: Empty curveTo called");
		return null;
	}
	public static Object endFill(Object gr) {
		System.out.println("Warning: Empty endFill called");
		return null;
	}
	public static Object cameraTakePhoto(int cameraId, String additionalInfo, int desiredWidth, int desiredHeight, int compressQuality, String fileName, int fitMode) {
		System.out.println("Warning: Empty cameraTakePhoto called");
		return null;
	}
	public static Object cameraTakeVideo(int cameraId, String additionalInfo, int duration, int size, int quality, String fileName) {
		System.out.println("Warning: Empty cameraTakeVideo called");
		return null;
	}
	public static Integer getNumberOfCameras() {
		System.out.println("Warning: Empty getNumberOfCameras called");
		return -1;
	}
	public static Object makeShader(Object[] vertex, Object[] fragment, Object[] uniform) {
		System.out.println("Warning: Empty makeShader called");
		return null;
	}
	public static Object setClipViewBounds(Object cl, double minX, double minY, double maxX, double maxY) {
		System.out.println("Warning: Empty setClipViewBounds called");
		return null;
	}
	public static String getVideoCurrentFrame(Object cl) {
		System.out.println("Warning: Empty getVideoCurrentFrame called");
		return "";
	}
	public static Func0<Object> addDrawFrameEventListener(final Func1<Object,Double> cb) {
		System.out.println("Warning: Empty addDrawFrameEventListener called");
		return no_op;
	}
	public static Object playVideoFromMediaStream(Object clip, Object stream, Boolean startPaused) {
		System.out.println("Warning: Empty playVideoFromMediaStream called");
		return null;
	}
	public static Object compareImages(String image1, String image2, Func1<Object, String> cb) {
		System.out.println("Warning: Empty compareImages called");
		return null;
	}
	public static Func0<Object> addUrlHashListener(Func1<Object,String> cb) {
		System.out.println("Warning: Empty addUrlHashListener called");
		return no_op;
	}
	public static Object takeSnapshot(String path) {
		System.out.println("Warning: Empty takeSnapshot called");
		return null;
	}
}
