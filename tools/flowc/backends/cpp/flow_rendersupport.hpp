#pragma once

using flow::flow_t;

void addChild(const native& parent, const native& child) { FLOW_ABORT }
std::function<void()> addEventListener(const native& clip, const flow::string& event, const std::function<void()>& cb) { FLOW_ABORT }
std::function<void()> addFileDropListener(const native& clip, const int maxFilesCount, const flow::string& mimeTypeRegExpFilter, const std::function<void(flow::array<native>)>& onDone) { FLOW_ABORT }
void addFilters(const native& , const flow::array<native>& ) { FLOW_ABORT }
std::function<void()> addFinegrainMouseWheelEventListener(const native& clip, const std::function<void(double, double)>& cb) { FLOW_ABORT }
std::function<void()> addGestureListener(const flow::string& event, const std::function<bool(int, double, double, double, double)>& cb) { FLOW_ABORT }
std::function<void()> addKeyEventListener(const native& clip, const flow::string& event, const std::function<void(flow::string, bool, bool, bool, bool, int, std::function<void()>)>& cb) { FLOW_ABORT }
std::function<void()> addMouseWheelEventListener(const native& clip, const std::function<void(double)>& cb) { FLOW_ABORT }
std::function<void()> addStreamStatusListener(const native& clip, const std::function<void(flow::string)>& cb) { FLOW_ABORT }
void beginFill(const native& graphics, const int color, const double opacity) { FLOW_ABORT }
void beginGradientFill(const native& graphics, const flow::array<int>& colors, const flow::array<double>& alphas, const flow::array<double>& offsets, const native& matrix, const flow::string& type) { FLOW_ABORT }
native captureCallstackItem(const int index) { return native(); }
native captureCallstack() { FLOW_ABORT }
void closeVideo(const native& clip) { FLOW_ABORT }
native currentClip() { FLOW_ABORT }
void curveTo(const native& graphics, const double x, const double y, const double cx, const double dy) { FLOW_ABORT }
void enableResize() { FLOW_ABORT }
void endFill(const native& graphics) { FLOW_ABORT }
int getBottomScrollV(const native& ) { FLOW_ABORT }
bool getClipVisible(const native& ) { FLOW_ABORT }
flow::string getContent(const native& ) { FLOW_ABORT }
int getCursorPosition(const native& ) { FLOW_ABORT }
bool getFocus(const native& ) { FLOW_ABORT }
native getGraphics(const native& clip) { FLOW_ABORT }
double getMouseX(const native& clip) { FLOW_ABORT }
double getMouseY(const native& clip) { FLOW_ABORT }
int getNumLines(const native& ) { FLOW_ABORT }
int getScrollV(const native& ) { FLOW_ABORT }
int getSelectionEnd(const native& ) { FLOW_ABORT }
int getSelectionStart(const native& ) { FLOW_ABORT }
native getStage() { FLOW_ABORT }
double getTextFieldHeight(const native& clip) { FLOW_ABORT }
double getTextFieldWidth(const native& clip) { FLOW_ABORT }
flow::array<double> getTextMetrics(const native& text) { FLOW_ABORT }
double getVideoPosition(const native& clip) { FLOW_ABORT }
bool hittest(const native& clip, const double x, const double y) { FLOW_ABORT }
void lineTo(const native& graphics, const double x, const double y) { FLOW_ABORT }
native makeBevel(const double angle, const double distance, const double radius, const double spread, const int color1, const double alpha1, const int color2, const double alpha2, const bool inner) { FLOW_ABORT }
native makeBlur(const double radius, const double spread) { FLOW_ABORT }
flow::array<native> makeCamera(const flow::string& uri, const int camID, const int camWidth, const int camHeight, const double camFps, const int vidWidth, const int vidHeight, const int recordMode, const std::function<void(native)>& cbOnOk, const std::function<void(flow::string)>& cbOnFailed) { FLOW_ABORT }
native makeClip() { FLOW_ABORT }
native makeDropShadow(const double angle, const double distance, const double radius, const double spread, const int color, const double alpha, const bool inner) { FLOW_ABORT }
native makeGlow(const double radius, const double spread, const int color, const double alpha, const bool inner) { FLOW_ABORT }
native makeMatrix(const double width, const double height, const double rotation, const double xOffset, const double yOffset) { FLOW_ABORT }
native makePicture(const flow::string& url, const bool cache, const std::function<void(double, double)>& metricsFn, const std::function<void(flow::string)>& errorFn, const bool onlyDownload) { FLOW_ABORT }
native makeTextfield(const flow::string& fontFamily) { FLOW_ABORT }
native makeVideo(const std::function<void(double, double)>& metricsFn, const std::function<void(bool)>& playFn, const std::function<void(double)>& durationFn, const std::function<void(double)>& positionFn) { FLOW_ABORT }
void moveTo(const native& graphics, const double x, const double y) { FLOW_ABORT }
void pauseVideo(const native& clip) { FLOW_ABORT }
void playVideo(const native& clip, const flow::string& filename, const bool startPaused) { FLOW_ABORT }
void removeChild(const native& parent, const native& child) { FLOW_ABORT }
void resetFullWindowTarget() { FLOW_ABORT }
void resumeVideo(const native& clip) { FLOW_ABORT }
void seekVideo(const native& clip, const double frame) { FLOW_ABORT }
void setAdvancedText(const native& textfield, const int sharpness, const int antiAliasType, const int gridFitType) { FLOW_ABORT }
void setAutoAlign(const native& clip, const flow::string& autoalign) { FLOW_ABORT }
void setClipAlpha(const native& clip, const double y) { FLOW_ABORT }
void setClipCallstack(const native& clip, const native& callstack) { FLOW_ABORT }
void setClipMask(const native& clip, const native& mask) { FLOW_ABORT }
void setClipRotation(const native& clip, const double x) { FLOW_ABORT }
void setClipScaleX(const native& clip, const double x) { FLOW_ABORT }
void setClipScaleY(const native& clip, const double y) { FLOW_ABORT }
void setClipVisible(const native& , const bool ) { FLOW_ABORT }
void setClipX(const native& clip, const double x) { FLOW_ABORT }
void setClipY(const native& clip, const double y) { FLOW_ABORT }
void setCursor(const flow::string& ) { FLOW_ABORT }
void setFocus(const native& , const bool ) { FLOW_ABORT }
void setFullWindowTarget(const native& clip) { FLOW_ABORT }
void setHitboxRadius(const double radius) { FLOW_ABORT }
void setLineGradientStroke(const native& graphics, const flow::array<int>& colors, const flow::array<double>& alphas, const flow::array<double>& offsets, const native& matrix) { FLOW_ABORT }
void setLineStyle2(const native& graphics, const double width, const int color, const double opacity, const bool pixelHinting) { FLOW_ABORT }
void setLineStyle(const native& graphics, const double width, const int color, const double opacity) { FLOW_ABORT }
void setMaxChars(const native& , const int ) { FLOW_ABORT }
void setMultiline(const native& , const bool ) { FLOW_ABORT }
void setReadOnly(const native& , const bool ) { FLOW_ABORT }
native setScrollRect(const native& , const double left, const double top, const double width, const double height) { FLOW_ABORT }
void setScrollV(const native& , const int ) { FLOW_ABORT }
void setSelection(const native& , const int start, const int end) { FLOW_ABORT }
void setTabIndex(const native& , const int ) { FLOW_ABORT }
void setTextDirection(const native& clip, const flow::string& direction) { FLOW_ABORT }
void setTextAndStyle(const native& textfield, const flow::string& text, const flow::string& fontfamily, const double fontsize,
	const int fontweight, const flow::string& fontslope, 
	const int fillcolour, const double fillopacity, const int letterspacing, 
	const int backgroundcolour, const double backgroundopacity, const bool forTextinput) { FLOW_ABORT }
void setTextFieldHeight(const native& clip, const double width) { FLOW_ABORT }
void setTextFieldWidth(const native& clip, const double width) { FLOW_ABORT }
void setTextInputType(const native& , const flow::string& ) { FLOW_ABORT }
void setTextInput(const native& ) { FLOW_ABORT }
struct PlayerControl;
void setVideoControls(const native& clip, const flow::array<PlayerControl>& ctl) { FLOW_ABORT }
void setVideoLooping(const native& clip, const bool looping) { FLOW_ABORT }
void setVideoSubtitle(const native& clip, const flow::string& text, const flow::string& fontfamily, const double fontsize, 
	const int fontweight, const flow::string& fontslope, 
	const int fillcolour, const double fillopacity, const int letterspacing, const int backgroundcolour, const double backgroundopacity) { FLOW_ABORT }
void setVideoVolume(const native& clip, const double volume) { FLOW_ABORT }
void setWebClipDisabled(const native& , const bool ) { FLOW_ABORT }
void setWebClipSandBox(const native& , const flow::string& ) { FLOW_ABORT }
void setWebClipZoomable(const native& , const bool ) { FLOW_ABORT }
void setWordWrap(const native& , const bool ) { FLOW_ABORT }
void startRecord(const native& clip, const flow::string& filename, const flow::string& mode) { FLOW_ABORT }
void stopRecord(const native& clip) { FLOW_ABORT }
void timer(const int , const std::function<void()>& ) { FLOW_ABORT }
void toggleFullWindow(const bool fs) { FLOW_ABORT }

void impersonateCallstackItem(const native& item, const int flags) { /*FLOW_ABORT*/ }
native makeWebClip(const flow::string&, const flow::string&, const bool, const bool, const std::function<flow_t(flow::array<flow_t>)>&, const std::function<void(flow::string)>&, const bool) { FLOW_ABORT }
void setAccessAttributes(const native& clip, const flow::array<flow::array<flow_t>>& properties) { FLOW_ABORT }
flow_t webClipEvalJS(const native& , const flow::string& ) { FLOW_ABORT }
flow_t webClipHostCall(const native& , const flow::string& , const flow::array<flow_t>& ) { FLOW_ABORT }

void setAccessCallback(const native& clip, const std::function<void()> callback) { FLOW_ABORT }
void toggleFullScreen(const bool fs) { FLOW_ABORT }
void setVideoPlaybackRate(const native& clip, const double rate) { FLOW_ABORT }
