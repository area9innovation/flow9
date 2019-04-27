using System;
using Windows.ApplicationModel.Activation;

namespace Area9Innovation.Flow
{
	public class RenderSupport : NativeHost
	{
		public virtual Object getStage() {
			return null;
		}
		public virtual double getStageWidth() {
			return 0;
		}
		public virtual double getStageHeight() {
			return 0;
		}
		public virtual Object setHitboxRadius(double val) {
			return null;
		}
		public virtual object setGlobalZoomEnabled(bool val) {
			return null;
		}
		public virtual Object setWindowTitle(String title) {
			return null;
		}
		public virtual Object setFavIcon(String url) {
			return null;
		}
		public virtual object setInterfaceOrientation(string p) {
			return null;
		}
		public virtual int getScreenPixelColor(double x, double y) {
			return 0;
		}
		public virtual Object enableResize() {
			return null;
		}
		public virtual Object makeClip() {
			return null;
		}
		public virtual Object currentClip() {
			return null;
		}
		public virtual Object makeWebClip(String url,String domain,bool useCache, bool reloadBlock, Func1 cb, Func1 ondone) {
			return null;
		}
		public virtual String webClipHostCall(Object clip,String fn,String[] args) {
			return null;
		}
		public virtual Object setWebClipSandBox(Object clip,String value) {
			return null;
		}
		public virtual Object setWebClipDisabled(Object clip,bool value) {
			return null;
		}
		public virtual Object webClipEvalJS(Object clip,String code) {
			return null;
		}
		public virtual Object setWebClipZoomable(Object clip,bool zoomable) {
			return null;
		}
		public virtual Object setWebClipDomains(Object clip, String[] domains) {
			return null;
		}
		public virtual Object addFilters(Object stg, Object[] filters) {
			return null;
		}
		public virtual Object setAccessAttributes(Object stg, Object[] attrs) {
			return null;
		}
		public virtual Object setAccessCallback(Object stg, Func0 fn) {
			return null;
		}
		public virtual Object addChild(Object stg, Object child) {
			return null;
		}
		public virtual Object removeChild(Object stg, Object child) {
			return null;
		}
		public virtual Object setClipMask(Object stg, Object mask) {
			return null;
		}
		public virtual Object setClipCallstack(Object stg, Object stack) {
			return null;
		}
		public virtual double getMouseX(Object stg) {
			return 0;
		}
		public virtual double getMouseY(Object stg) {
			return 0;
		}
		public virtual bool getClipVisible(Object stg) {
			return false;
		}
		public virtual Object setClipVisible(Object stg, bool on) {
			return null;
		}
		public virtual Object setClipX(Object stg, double val) {
			return null;
		}
		public virtual Object setClipY(Object stg, double val) {
			return null;
		}
		public virtual Object setClipScaleX(Object stg, double val) {
			return null;
		}
		public virtual Object setClipScaleY(Object stg, double val) {
			return null;
		}
		public virtual Object setClipAlpha(Object stg, double val) {
			return null;
		}
		public virtual Object setClipRotation(Object stg, double val) {
			return null;
		}
		public virtual Object setScrollRect(Object stg, double x, double y, double w, double h) {
			return null;
		}
		public virtual String getCursor() {
			return null;
		}
		public virtual Object setCursor(String val) {
			return null;
		}
		public virtual Func0 addEventListener(Object stg, String name, Func0 fn) {
			return null;
		}
		public virtual Func0 addFileDropListener(Object stg, int maxFilesCount, String mimeRegExFilter, Func1 onDone) {
			return null;
		}
		public virtual Func0 addVirtualKeyboardHeightListener(Func1 fn) {
			return null;
		}
		public virtual Func0 addKeyEventListener(Object stg, String name, Func7 fn) {
			return null;
		}
		public virtual Func0 addMouseWheelEventListener(Object stg, Func1 cb) {
			return null;
		}
		public virtual Func0 addFinegrainMouseWheelEventListener(Object stg, Func2 cb) {
			return null;
		}
		public virtual Func0 addGestureListener(String name, Func5 cb) {
			return null;
		}
		public virtual bool hittest(Object stg, double x, double y) {
			return false;
		}
		public virtual Object makeTextField(String fontFamily) {
			return null;
		}
		public virtual Object setTextInput(Object stg) {
			return null;
		}
		public virtual double getTextFieldWidth(Object stg) {
			return 0;
		}
		public virtual double getTextFieldHeight(Object stg) {
			return 0;
		}
		public virtual Object setTextFieldWidth(Object stg, double val) {
			return null;
		}
		public virtual Object setTextFieldHeight(Object stg, double val) {
			return null;
		}
		public virtual Object setAdvancedText(Object stg,int a,int o,int e) {
			return null;
		}
		public virtual Object setTextAndStyle(Object tf,String a,String o,double e,int u,double i,int d,int h,double t) {
			return null;
		}
		public virtual Object setTextDirection(Object stg, String val) {
			return null;
		}
		public virtual int getNumLines(Object stg) {
			return 0;
		}
		public virtual int getCursorPosition(Object stg) {
			return 0;
		}
		public virtual bool getFocus(Object stg) {
			return false;
		}
		public virtual Object setFocus(Object stg, bool val) {
			return null;
		}
		public virtual String getContent(Object stg) {
			return null;
		}
		public virtual Object setMultiline(Object stg, bool val) {
			return null;
		}
		public virtual Object setWordWrap(Object stg, bool val) {
			return null;
		}
		public Object setNumeric(Object stg, bool val) {
			return setTextInputType(stg, "number");
		}
		public virtual Object setReadOnly(Object stg, bool val) {
			return null;
		}
		public virtual Object setAutoAlign(Object stg, String val) {
			return null;
		}
		public virtual Object setTextInputType(Object stg, string type)
		{
			return null;
		}
		public Object setTextFieldPasswordMode(Object stg, bool val) {
			return setTextInputType(stg, "password");
		}
		public virtual Object setTabIndex(Object stg, int val) {
			return null;
		}
		public virtual int getScrollV(Object stg) {
			return 0;
		}
		public virtual int getBottomScrollV(Object stg) {
			return 0;
		}
		public virtual Object setScrollV(Object stg, int val) {
			return null;
		}
		public virtual Object setMaxChars(Object stg, int val) {
			return null;
		}
		public virtual Object[] getTextMetrics(Object stg) {
			return new Object[] { 0.0, 0.0, 0.0 };
		}
		public virtual int getSelectionStart(Object stg) {
			return 0;
		}
		public virtual int getSelectionEnd(Object stg) {
			return 0;
		}
		public virtual Object setSelection(Object stg, int start, int end) {
			return null;
		}
		public virtual Object[] makeVideo(int w,int h,Func2 cb1,Func1 cb2) {
			return null;
		}
		public virtual Object pauseVideo(Object stg) {
			return null;
		}
		public virtual Object resumeVideo(Object stg) {
			return null;
		}
		public virtual Object closeVideo(Object stg) {
			return null;
		}
		public virtual Object playVideo(Object obj, String name, bool pause) {
			return null;
		}
		public virtual double getVideoPosition(Object stg) {
			return 0;
		}
		public virtual Object seekVideo(Object stg, double val) {
			return null;
		}
		public virtual Object setVideoVolume(Object stg, double val) {
			return null;
		}
		public virtual Object setVideoLooping(Object stg, bool val) {
			return null;
		}
		public virtual Object setVideoControls(Object stg, Object[] info) {
			return null;
		}
		public virtual Object setVideoSubtitle(Object stg, String txt, double size, int color) {
			return null;
		}
		public virtual Func0 addStreamStatusListener(Object vid, Func1 cb) {
			return null;
		}
		public virtual bool isFullScreen() {
			return false;
		}
		public virtual Object toggleFullScreen(bool fs) {
			return null;
		}
		public virtual Func0 onFullScreen(Func1 cb) {
			return null;
		}
		public virtual Func0 setFullScreen(bool cb) {
			return null;
		}
		public virtual Object setFullScreenTarget(Object stg) {
			return null;
		}
		public virtual Object resetFullScreenTarget() {
			return null;
		}
		public virtual Object setFullScreenRectangle(double x, double y, double w, double h) {
			return null;
		}
		public virtual Object makeBevel(double a,double b,double c,double d,int e,double f,int g,double h,bool i) {
			return null;
		}
		public virtual Object makeDropShadow(double a1,double a2,double a3,double a4,int a5,double a6,bool a7) {
			return null;
		}
		public virtual Object makeBlur(double a,double b) {
			return null;
		}
		public virtual Object makeGlow(double a,double b,int c, double d,bool e) {
			return null;
		}
		public virtual Object makePicture(String a,bool b,Func2 c,Func1 d,bool e) {
			return null;
		}
		public virtual Object[] makeCamera(String a,int o,int e,int u,double i,int d,int h,int t,Func1 n,Func1 s) {
			return null;
		}
		public virtual Object startRecord(Object cm,String a,String o) {
			return null;
		}
		public virtual Object stopRecord(Object cm) {
			return null;
		}
		public virtual Object getGraphics(Object clip) {
			return null;
		}
		public virtual Object beginFill(Object gr,int c,double a) {
			return null;
		}
		public virtual Object setLineStyle(Object gr,double a,int o,double e) {
			return null;
		}
		public virtual Object setLineStyle2(Object gr, double a, int o, double e, bool h)
		{
			return null;
		}
		public virtual Object makeMatrix(double a, double o, double e, double u, double i)
		{
			return null;
		}
		public virtual Object beginGradientFill(Object gr,Object[] a,Object[] o,Object[] e,Object u,String i) {
			return null;
		}
		public virtual Object setLineGradientStroke(Object gr,Object[] a,Object[] o,Object[] e,Object u) {
			return null;
		}
		public virtual Object moveTo(Object gr,double x,double y) {
			return null;
		}
		public virtual Object lineTo(Object gr,double x,double y) {
			return null;
		}
		public virtual Object curveTo(Object gr,double x,double y,double cx, double cy) {
			return null;
		}
		public virtual Object endFill(Object gr) {
			return null;
		}
		public virtual Object cameraTakePhoto(int a, string b, int c, int d, int e, string f, int g) {
			return null;
		}

		public virtual void continueCameraTakePhoto(IContinuationActivatedEventArgs args)
		{
		}

		public virtual String getUrlHash()
		{
			return "";
		}

		public virtual Object setUrlHash(String hash)
		{
			return null;
		}
	}
}

