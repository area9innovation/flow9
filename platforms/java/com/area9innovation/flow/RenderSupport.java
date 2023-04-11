package com.area9innovation.flow;

import java.util.*;
import java.nio.charset.Charset;

@SuppressWarnings("unchecked")
public class RenderSupport extends NativeHost {
	private static Func0<Object> no_op = new Func0<Object>() {
		public Object invoke() { return null; }
	};

	public static Object getStage() {
		return null;
	}
	public static double getStageWidth() {
		return 0;
	}
	public static double getStageHeight() {
		return 0;
	}
	public static Object setHitboxRadius(double val) {
		return null;
	}
	public static Object setWindowTitle(String title) {
		return null;
	}
	public static Object setFavIcon(String url) {
		return null;
	}
	public static int getScreenPixelColor(double x, double y) {
		return 0;
	}
	public static Object enableResize() {
		return null;
	}
	public static Object makeClip() {
		return null;
	}
	public static Object assignClip(Object stage, String className, Object clip) {
		return null;
	}
	public static Object makeGraphics() {
		return null;
	}
	public static Object currentClip() {
		return null;
	}
	public static Object makeWebClip(String url,String domain,Boolean useCache, Boolean reloadBlock, Func1<String,Object[]> cb, Func1<Object,String> ondone, Boolean shrinkToFit) {
		return null;
	}
	public static String webClipHostCall(Object clip,String fn,Object[] args) {
		return null;
	}
	public static Object setWebClipSandBox(Object clip,String value) {
		return null;
	}
	public static Object setWebClipDisabled(Object clip,boolean value) {
		return null;
	}
	public static Object webClipEvalJS(Object clip,String code, Func1<Object,String> cb) {
		return null;
	}
	public static Object setWebClipZoomable(Object clip,Boolean zoomable) {
		return null;
	}
	public static Object setWebClipDomains(Object clip, Object[] domains) {
		return null;
	}
	public static Object makeHTMLStage(double width, double height) {
		return null;
	}
	public static Object createElement(String tagName) {
		return null;
	}
	public static Object createTextNode(String text) {
		return null;
	}
	public static Object setAttribute(Object element, String name, String value, Boolean safe) {
		return null;
	}
	public static Object appendChild(Object element, Object child) {
		return null;
	}
	public static Object insertBefore(Object element, Object child, Object reference) {
		return null;
	}
	public static Object removeElementChild(Object element, Object child) {
		return null;
	}
	public static Object addFilters(Object stg, Object[] filters) {
		return null;
	}
	public static Object setAccessAttributes(Object stg, Object[] attrs) {
		return null;
	}
	public static Object setAccessCallback(Object stg, Func0<Object> fn) {
		return null;
	}
	public static Object addChild(Object stg, Object child) {
		return null;
	}
	public static Object addChildAt(Object stg, Object child, Integer at) {
		return null;
	}
	public static Object removeChild(Object stg, Object child) {
		return null;
	}
	public static Object setClipMask(Object stg, Object mask) {
		return null;
	}
	public static Object setClipCallstack(Object stg, Object stack) {
		return null;
	}
	public static double getMouseX(Object stg) {
		return 0;
	}
	public static double getMouseY(Object stg) {
		return 0;
	}
	public static boolean getClipVisible(Object stg) {
		return false;
	}
	public static Object setClipVisible(Object stg, boolean on) {
		return null;
	}
	public static Object setClipX(Object stg, double val) {
		return null;
	}
	public static Object setClipY(Object stg, double val) {
		return null;
	}
	public static Object setClipScaleX(Object stg, double val) {
		return null;
	}
	public static Object setClipScaleY(Object stg, double val) {
		return null;
	}
	public static Object setClipAlpha(Object stg, double val) {
		return null;
	}
	public static Object setClipRotation(Object stg, double val) {
		return null;
	}
	public static Object setClipWidth(Object clip, double width) {
		return null;
	}
	public static double getClipHeight(Object clip) {
		return 0;
	}
	public static double getClipWidth(Object clip) {
		return 0;
	}
	public static Object setClipHeight(Object clip, double height) {
		return null;
	}
	public static Object setClipResolution(Object clip, double resolution) {
		return null;
	}
	public static Object setScrollRect(Object stg, double x, double y, double w, double h) {
		return null;
	}
	public static String getCursor() {
		return null;
	}
	public static Object setCursor(String val) {
		return null;
	}
	public static Func0<Object> addEventListener(Object stg, String name, Func0<Object> fn) {
		return null;
	}
	public static Func0<Object> addFileDropListener(Object clib, Integer maxFilesCount, String mimeTypeRegExFilter, Func1<Object,Object[]> onDone) {
		return null;
	}
	public static Func0<Object> addVirtualKeyboardHeightListener(Func1<Object, Double> fn) {
		return null;
	}
	public static Func0<Object> addKeyEventListener(Object stg, String event, Func7<Object,String,Boolean,Boolean,Boolean,Boolean,Integer,Func0<Object>> cb) {
		return null;
	}
	public static Object emitKeyEvent(Object stg, String name, String key, Boolean ctrl, Boolean shift, Boolean alt, Boolean meta, Integer code) {
		return null;
	}
	public static Func0<Object> addMouseWheelEventListener(Object stg, Func1<Object,Double> cb) {
		return null;
	}
	public static Func0<Object> addFinegrainMouseWheelEventListener(Object stg, Func2<Object,Double,Double> cb) {
		return null;
	}
	public static Func0<Object> addGestureListener(String name, Func5<Boolean,Integer,Double,Double,Double,Double> cb) {
		return null;
	}
	public static boolean hittest(Object stg, double x, double y) {
		return false;
	}
	public static String getFontStylesConfigString() {
		return null;
	}
	public static Object makeTextField(String fontfamily) {
		return null;
	}
	public static Object setTextInput(Object stg) {
		return null;
	}
	public static double getTextFieldWidth(Object stg) {
		return 0;
	}
	public static double getTextFieldHeight(Object stg) {
		return 0;
	}
	public static Object setTextFieldWidth(Object stg, double val) {
		return null;
	}
	public static Object setTextFieldHeight(Object stg, double val) {
		return null;
	}
	public static Object setTextFieldCropWords(Object stg, boolean val) {
		return null;
	}
	public static Object setAdvancedText(Object stg,int a,int o,int e) {
		return null;
	}
	public static Object setTextInputType(Object stg, String type) {
		return null;
	}
	public static Object setTextAndStyle(Object tf, String text, String fontFamily, double fontSize, int fontWeight,
								  String fontSlope, int fillColour, double fillOpacity, double letterSpacing,
								  int backgroundColour,double backgroundOpacity) {
		return null;
	}
	public static Object setTextFieldInterlineSpacing(Object stg, double val) {
		return null;
	}
	public static Object setTextDirection(Object stg, String val) {
		return null;
	}
	public static int getNumLines(Object stg) {
		return 0;
	}
	public static int getCursorPosition(Object stg) {
		return 0;
	}
	public static boolean getFocus(Object stg) {
		return false;
	}
	public static Object setFocus(Object stg, boolean val) {
		return null;
	}
	public static String getContent(Object stg) {
		return null;
	}
	public static Object setMultiline(Object stg, boolean val) {
		return null;
	}
	public static Object setWordWrap(Object stg, boolean val) {
		return null;
	}
	public static Object setReadOnly(Object stg, boolean val) {
		return null;
	}
	public static Object setAutoAlign(Object stg, String val) {
		return null;
	}
	public static Object setTabIndex(Object stg, int val) {
		return null;
	}
	public static int getScrollV(Object stg) {
		return 0;
	}
	public static int getBottomScrollV(Object stg) {
		return 0;
	}
	public static Object setScrollV(Object stg, int val) {
		return null;
	}
	public static Object setMaxChars(Object stg, int val) {
		return null;
	}
	public static Object[] getTextMetrics(Object stg) {
		return new Object[] { 0.0, 0.0, 0.0 };
	}
	public static int getSelectionStart(Object stg) {
		return 0;
	}
	public static int getSelectionEnd(Object stg) {
		return 0;
	}
	public static Object setSelection(Object stg, int start, int end) {
		return null;
	}
	public static Object makeVideo(Func2<Object,Double,Double> mfn, Func1<Object, Boolean> pfn, Func1<Object, Double> dfn, Func1<Object, Double> posfn) {
		return null;
	}
	public static Object pauseVideo(Object stg) {
		return null;
	}
	public static Object resumeVideo(Object stg) {
		return null;
	}
	public static Object closeVideo(Object stg) {
		return null;
	}
	public static Object playVideo(Object obj, String name, boolean pause) {
		return null;
	}
	public static double getVideoPosition(Object stg) {
		return 0;
	}
	public static Object seekVideo(Object stg, double val) {
		return null;
	}
	public static Object setVideoVolume(Object stg, double val) {
		return null;
	}
	public static Object setVideoLooping(Object stg, boolean val) {
		return null;
	}
	public static Object setVideoControls(Object stg, Object[] info) {
		return null;
	}
	public static Object setVideoSubtitle(Object tf, String text, String fontFamily, double fontSize, int fontWeight,
								  String fontSlope, int fillColour, double fillOpacity, double letterSpacing,
								  int backgroundColour, double backgroundOpacity, boolean alignBottom,
								  double bottomBorder, boolean scaleMode, double scaleModeMin, double scaleModeMax, boolean escapeHTML) {
		return null;
	}
	public static Object setVideoPlaybackRate(Object tf, Double rate) {
		return null;
	}
	public static Func0<Object> addStreamStatusListener(Object vid, Func1<Object,String> cb) {
		return null;
	}
	public static boolean isFullScreen() {
		return false;
	}
	public static Object toggleFullScreen(Boolean fs) {
		return null;
	}
	public static Object toggleFullWindow(Boolean fs) {
		return null;
	}
	public static Func0<Object> onFullScreen(Func1<Object,Boolean> cb) {
		return null;
	}
	public static Object setFullScreen(Boolean fs) {
		return null;
	}
	public static Object setFullWindowTarget(Object stg) {
		return null;
	}
	public static Object resetFullWindowTarget() {
		return null;
	}
	public static Object setFullScreenRectangle(double x, double y, double w, double h) {
		return null;
	}
	public static Object makeBevel(double a,double b,double c,double d,int e,double f,int g,double h,boolean i) {
		return null;
	}
	public static Object makeDropShadow(double a1,double a2,double a3,double a4,int a5,double a6,boolean a7) {
		return null;
	}
	public static Object makeBlur(double a,double b) {
		return null;
	}
	public static Object makeBackdropBlur(double a) {
		return null;
	}
	public static Object makeGlow(double a,double b,int c, double d,boolean e) {
		return null;
	}
	public static Object makePicture(String a,boolean b,Func2<Object,Double,Double> c,Func1<Object,String> d,boolean e, String alt) {
		return null;
	}
	public static Object[] makeCamera(String a,int o,int e,int u,double i,int d,int h,int t,Func1<Object,Object> n,Func1<Object,String> s) {
		return null;
	}
	public static Object startRecord(Object cm,String a,String o) {
		return null;
	}
	public static Object stopRecord(Object cm) {
		return null;
	}
	public static Object getGraphics(Object clip) {
		return null;
	}
	public static Object beginFill(Object gr,int c,double a) {
		return null;
	}
	public static Object setLineStyle(Object gr,double a,int o,double e) {
		return null;
	}
	public static Object setLineStyle2(Object gr,double a,int o,double e, boolean b) {
		return null;
	}
	public static Object makeMatrix(double a,double o,double e,double u,double i) {
		return null;
	}
	public static Object beginGradientFill(Object gr,Object[] a,Object[] o,Object[] e,Object u,String i) {
		return null;
	}
	public static Object setLineGradientStroke(Object gr,Object[] a,Object[] o,Object[] e,Object u) {
		return null;
	}
	public static Object moveTo(Object gr,double x,double y) {
		return null;
	}
	public static Object lineTo(Object gr,double x,double y) {
		return null;
	}
	public static Object curveTo(Object gr,double x,double y,double cx, double cy) {
		return null;
	}
	public static Object endFill(Object gr) {
		return null;
	}

	public static Object cameraTakePhoto(int cameraId, String additionalInfo, int desiredWidth, int desiredHeight, int compressQuality, String fileName, int fitMode) {
		return null;
	}

	public static Object cameraTakeVideo(int cameraId, String additionalInfo, int duration, int size, int quality, String fileName) {
		return null;
	}
    public static Integer getNumberOfCameras() {
	return -1;
    }
    public static Object makeShader(Object[] vertex, Object[] fragment, Object[] uniform) {
    	 return null;
    }
    public static Object setClipViewBounds(Object cl, double minX, double minY, double maxX, double maxY) {
    	return null;
    }
    public static String getVideoCurrentFrame(Object cl) {
    	return "";
    }

    public static Func0<Object> addDrawFrameEventListener(final Func1<Object,Double> cb) {
    	return no_op;
    }
	public static Object playVideoFromMediaStream(Object clip, Object stream, Boolean startPaused) {
		return null;
	}
	public static Object compareImages(String image1, String image2, Func1<Object, String> cb) {
		return null;
	}

	public static Func0<Object> addUrlHashListener(Func1<Object,String> cb) {
		return no_op;
	}

	public static Object takeSnapshot(String path) {
		return null;
	}
}
