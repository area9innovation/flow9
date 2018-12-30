package com.area9innovation.flow;

import java.util.*;
import java.nio.charset.Charset;

@SuppressWarnings("unchecked")
public class RenderSupport extends NativeHost {
	public Object getStage() {
		return null;
	}
	public double getStageWidth() {
		return 0;
	}
	public double getStageHeight() {
		return 0;
	}
	public Object setHitboxRadius(double val) {
		return null;
	}
	public Object setWindowTitle(String title) {
		return null;
	}
	public Object setFavIcon(String url) {
		return null;
	}
	public int getScreenPixelColor(double x, double y) {
		return 0;
	}
	public Object enableResize() {
		return null;
	}
	public Object makeClip() {
		return null;
	}
	public Object makeGraphics() {
		return null;
	}
	public Object currentClip() {
		return null;
	}
	public Object makeWebClip(String url,String domain,Boolean useCache, Boolean reloadBlock, Func1<String,Object[]> cb, Func1<Object,String> ondone, Boolean shrinkToFit) {
		return null;
	}
	public String webClipHostCall(Object clip,String fn,Object[] args) {
		return null;
	}
	public Object setWebClipSandBox(Object clip,String value) {
		return null;
	}
	public Object setWebClipDisabled(Object clip,boolean value) {
		return null;
	}
	public String webClipEvalJS(Object clip,String code) {
		return null;
	}
	public Object setWebClipZoomable(Object clip,Boolean zoomable) {
		return null;
	}
	public Object setWebClipDomains(Object clip, Object[] domains) {
		return null;
	}
	public Object addFilters(Object stg, Object[] filters) {
		return null;
	}
	public Object setAccessAttributes(Object stg, Object[] attrs) {
		return null;
	}
	public Object setAccessCallback(Object stg, Func0<Object> fn) {
		return null;
	}
	public Object addChild(Object stg, Object child) {
		return null;
	}
	public Object addChildAt(Object stg, Object child, Integer at) {
		return null;
	}
	public Object removeChild(Object stg, Object child) {
		return null;
	}
	public Object setClipMask(Object stg, Object mask) {
		return null;
	}
	public Object setClipCallstack(Object stg, Object stack) {
		return null;
	}
	public double getMouseX(Object stg) {
		return 0;
	}
	public double getMouseY(Object stg) {
		return 0;
	}
	public boolean getClipVisible(Object stg) {
		return false;
	}
	public Object setClipVisible(Object stg, boolean on) {
		return null;
	}
	public Object setClipX(Object stg, double val) {
		return null;
	}
	public Object setClipY(Object stg, double val) {
		return null;
	}
	public Object setClipScaleX(Object stg, double val) {
		return null;
	}
	public Object setClipScaleY(Object stg, double val) {
		return null;
	}
	public Object setClipAlpha(Object stg, double val) {
		return null;
	}
	public Object setClipRotation(Object stg, double val) {
		return null;
	}
	public Object setScrollRect(Object stg, double x, double y, double w, double h) {
		return null;
	}
	public String getCursor() {
		return null;
	}
	public Object setCursor(String val) {
		return null;
	}
	public Func0<Object> addEventListener(Object stg, String name, Func0<Object> fn) {
		return null;
	}
	public Func0<Object> addFileDropListener(Object clib, Integer maxFilesCount, String mimeTypeRegExFilter, Func1<Object,Object[]> onDone) {
		return null;
	}
	public Func0<Object> addVirtualKeyboardHeightListener(Func0<Object> fn) {
		return null;
	}
	public Func0<Object> addKeyEventListener(Object stg, String event, Func7<Object,String,Boolean,Boolean,Boolean,Boolean,Integer,Func0<Object>> cb) {
		return null;
	}
	public Object emitKeyEvent(Object stg, String name, String key, Boolean ctrl, Boolean shift, Boolean alt, Boolean meta, Integer code) {
		return null;
	}
	public Func0<Object> addMouseWheelEventListener(Object stg, Func1<Object,Double> cb) {
		return null;
	}
	public Func0<Object> addFinegrainMouseWheelEventListener(Object stg, Func2<Object,Double,Double> cb) {
		return null;
	}
	public Func0<Object> addGestureListener(String name, Func5<Boolean,Integer,Double,Double,Double,Double> cb) {
		return null;
	}
	public boolean hittest(Object stg, double x, double y) {
		return false;
	}
	public Object makeTextField(String fontfamily) {
		return null;
	}
	public Object setTextInput(Object stg) {
		return null;
	}
	public double getTextFieldWidth(Object stg) {
		return 0;
	}
	public double getTextFieldHeight(Object stg) {
		return 0;
	}
	public Object setTextFieldWidth(Object stg, double val) {
		return null;
	}
	public Object setTextFieldHeight(Object stg, double val) {
		return null;
	}
	public Object setAdvancedText(Object stg,int a,int o,int e) {
		return null;
	}
	public Object setTextInputType(Object stg, String type) {
		return null;
	}
	public Object setTextAndStyle(Object tf, String text, String fontFamily, double fontSize, int fontWeight, 
								  String fontSlope, int fillColour, double fillOpacity, double letterSpacing, 
								  int backgroundColour,double backgroundOpacity) {
		return null;
	}
	public Object setTextDirection(Object stg, String val) {
		return null;
	}
	public int getNumLines(Object stg) {
		return 0;
	}
	public int getCursorPosition(Object stg) {
		return 0;
	}
	public boolean getFocus(Object stg) {
		return false;
	}
	public Object setFocus(Object stg, boolean val) {
		return null;
	}
	public String getContent(Object stg) {
		return null;
	}
	public Object setMultiline(Object stg, boolean val) {
		return null;
	}
	public Object setWordWrap(Object stg, boolean val) {
		return null;
	}
	public Object setNumeric(Object stg, boolean val) {
		return null;
	}
	public Object setReadOnly(Object stg, boolean val) {
		return null;
	}
	public Object setAutoAlign(Object stg, String val) {
		return null;
	}
	public Object setTextFieldPasswordMode(Object stg, boolean val) {
		return null;
	}
	public Object setTabIndex(Object stg, int val) {
		return null;
	}
	public int getScrollV(Object stg) {
		return 0;
	}
	public int getBottomScrollV(Object stg) {
		return 0;
	}
	public Object setScrollV(Object stg, int val) {
		return null;
	}
	public Object setMaxChars(Object stg, int val) {
		return null;
	}
	public Object[] getTextMetrics(Object stg) {
		return new Object[] { 0.0, 0.0, 0.0 };
	}
	public int getSelectionStart(Object stg) {
		return 0;
	}
	public int getSelectionEnd(Object stg) {
		return 0;
	}
	public Object setSelection(Object stg, int start, int end) {
		return null;
	}
	public Object makeVideo(Func2<Object,Double,Double> mfn, Func1<Object, Boolean> pfn, Func1<Object, Double> dfn, Func1<Object, Double> posfn) {
		return null;
	}
	public Object pauseVideo(Object stg) {
		return null;
	}
	public Object resumeVideo(Object stg) {
		return null;
	}
	public Object closeVideo(Object stg) {
		return null;
	}
	public Object playVideo(Object obj, String name, boolean pause) {
		return null;
	}
	public double getVideoPosition(Object stg) {
		return 0;
	}
	public Object seekVideo(Object stg, double val) {
		return null;
	}
	public Object setVideoVolume(Object stg, double val) {
		return null;
	}
	public Object setVideoLooping(Object stg, boolean val) {
		return null;
	}
	public Object setVideoControls(Object stg, Object[] info) {
		return null;
	}
	public Object setVideoSubtitle(Object tf, String text, String fontFamily, double fontSize, int fontWeight, 
								  String fontSlope, int fillColour, double fillOpacity, double letterSpacing, 
								  int backgroundColour,double backgroundOpacity) {
		return null;
	}
	public Object setVideoPlaybackRate(Object tf, Double rate) {
		return null;
	}
	public Func0<Object> addStreamStatusListener(Object vid, Func1<Object,String> cb) {
		return null;
	}
	public boolean isFullScreen() {
		return false;
	}
	public Object toggleFullScreen(Boolean fs) {
		return null;
	}
	public Object toggleFullWindow(Boolean fs) {
		return null;
	}
	public Func0<Object> onFullScreen(Func1<Object,Boolean> cb) {
		return null;
	}
	public Object setFullScreen(Boolean fs) {
		return null;
	}
	public Object setFullWindowTarget(Object stg) {
		return null;
	}
	public Object resetFullWindowTarget() {
		return null;
	}
	public Object setFullScreenRectangle(double x, double y, double w, double h) {
		return null;
	}
	public Object makeBevel(double a,double b,double c,double d,int e,double f,int g,double h,boolean i) {
		return null;
	}
	public Object makeDropShadow(double a1,double a2,double a3,double a4,int a5,double a6,boolean a7) {
		return null;
	}
	public Object makeBlur(double a,double b) {
		return null;
	}
	public Object makeGlow(double a,double b,int c, double d,boolean e) {
		return null;
	}
	public Object makePicture(String a,boolean b,Func2<Object,Double,Double> c,Func1<Object,String> d,boolean e) {
		return null;
	}
	public Object[] makeCamera(String a,int o,int e,int u,double i,int d,int h,int t,Func1<Object,Object> n,Func1<Object,String> s) {
		return null;
	}
	public Object startRecord(Object cm,String a,String o) {
		return null;
	}
	public Object stopRecord(Object cm) {
		return null;
	}
	public Object getGraphics(Object clip) {
		return null;
	}
	public Object beginFill(Object gr,int c,double a) {
		return null;
	}
	public Object setLineStyle(Object gr,double a,int o,double e) {
		return null;
	}
	public Object setLineStyle2(Object gr,double a,int o,double e, boolean b) {
		return null;
	}
	public Object makeMatrix(double a,double o,double e,double u,double i) {
		return null;
	}
	public Object beginGradientFill(Object gr,Object[] a,Object[] o,Object[] e,Object u,String i) {
		return null;
	}
	public Object setLineGradientStroke(Object gr,Object[] a,Object[] o,Object[] e,Object u) {
		return null;
	}
	public Object moveTo(Object gr,double x,double y) {
		return null;
	}
	public Object lineTo(Object gr,double x,double y) {
		return null;
	}
	public Object curveTo(Object gr,double x,double y,double cx, double cy) {
		return null;
	}
	public Object endFill(Object gr) {
		return null;
	}

	public Object cameraTakePhoto(int cameraId, String additionalInfo, int desiredWidth, int desiredHeight, int compressQuality, String fileName, int fitMode) {
		return null;
	}

	public Object cameraTakeVideo(int cameraId, String additionalInfo, int duration, int size, int quality, String fileName) {
		return null;
	}
    public Integer getNumberOfCameras() {
	return -1;
    }
}
