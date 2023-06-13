#ifndef GLRENDERSUPPORT_H
#define GLRENDERSUPPORT_H

#include "core/ByteCodeRunner.h"
#include "font/TextFont.h"
#include "utils/AbstractHttpSupport.h"

#include <set>
#ifdef linux
#include <math.h>
#endif

enum FlowEvent {
    FlowUnknownEvent = 0,
    FlowMouseMiddleDown = 6,
    FlowMouseMiddleUp = 7,
    FlowMouseRightDown = 8,
    FlowMouseRightUp = 9,
    FlowMouseDown = 10,
    FlowMouseUp = 11,
    FlowMouseMove = 12,
    FlowMouseEnter = 13,
    FlowMouseLeave = 14,
    FlowMouseClick = 15,
    FlowMouseCancel = 16,
    FlowMouseWheel = 17,
    FlowFineGrainMouseWheel = 18,
    FlowKeyDown = 20,
    FlowKeyUp = 22,
    FlowSceneResize = 30,
    FlowVideoSizeNotify = 40,
    FlowVideoStreamEvent = 41,
    FlowVideoDurationNotify = 42,
    FlowVideoPositionNotify = 43,
    FlowVideoPlayNotify = 44,
    FlowFocusIn = 50,
    FlowFocusOut = 51,
    FlowTextChange = 52,
    FlowTextScroll = 53,
    FlowRecordReady = 60,
    FlowRecordFailed = 61,
    FlowRecordStreamEvent = 62,
    FlowPinchEvent = 63,
    FlowSwipeEvent = 64,
    FlowPanEvent = 65,
    FlowMouseDownInTextEdit = 66,
    FlowMouseRightDownInTextEdit = 67,
    FlowMouseMiddleDownInTextEdit = 68,
    FlowTransformChange = 69
};

enum FlowGestureState {
    FlowGestureStateBegin = 0,
    FlowGestureStateProgress,
    FlowGestureStateEnd
};

enum FlowKeyCode {
    FlowKey_Null = 0,
    FlowKey_Backspace = 8,
    FlowKey_Tab = 9,
    FlowKey_Enter = 13,
    FlowKey_Shift = 16,
    FlowKey_Ctrl = 17,
    FlowKey_Alt = 18,
    FlowKey_Escape = 27,
    FlowKey_Space = 32,
    FlowKey_PageUp = 33,
    FlowKey_PageDown = 34,
    FlowKey_End = 35,
    FlowKey_Home = 36,
    FlowKey_Left = 37,
    FlowKey_Up = 38,
    FlowKey_Right = 39,
    FlowKey_Down = 40,
    FlowKey_Insert = 45,
    FlowKey_Delete = 46,

    FlowKey_0 = 48,
    FlowKey_1 = 49,
    FlowKey_2 = 50,
    FlowKey_3 = 51,
    FlowKey_4 = 52,
    FlowKey_5 = 53,
    FlowKey_6 = 54,
    FlowKey_7 = 55,
    FlowKey_8 = 56,
    FlowKey_9 = 57,

    FlowKey_A = 65,
    FlowKey_B = 66,
    FlowKey_C = 67,
    FlowKey_D = 68,
    FlowKey_E = 69,
    FlowKey_F = 70,
    FlowKey_G = 71,
    FlowKey_H = 72,
    FlowKey_I = 73,
    FlowKey_J = 74,
    FlowKey_K = 75,
    FlowKey_L = 76,
    FlowKey_M = 77,
    FlowKey_N = 78,
    FlowKey_O = 79,
    FlowKey_P = 80,
    FlowKey_Q = 81,
    FlowKey_R = 82,
    FlowKey_S = 83,
    FlowKey_T = 84,
    FlowKey_U = 85,
    FlowKey_V = 86,
    FlowKey_W = 87,
    FlowKey_X = 88,
    FlowKey_Y = 89,
    FlowKey_Z = 90,

    FlowKey_BracketLeft = 91,
    FlowKey_BracketRight = 93,

    FlowKey_Numpad_0 = 96, // up to 9
    FlowKey_Numpad_Multiply = 106,
    FlowKey_Numpad_Add = 107,
    FlowKey_Numpad_Subtract = 109,
    FlowKey_Numpad_Decimal = 110,
    FlowKey_Numpad_Divide = 111,
    FlowKey_F1 = 112, // up to F15
    FlowKey_F2, FlowKey_F3, FlowKey_F4,
    FlowKey_F5, FlowKey_F6, FlowKey_F7,
    FlowKey_F8, FlowKey_F9, FlowKey_F10,
    FlowKey_F11, FlowKey_F12, FlowKey_F13,
    FlowKey_F14, FlowKey_F15,

    FlowKey_BackTab = 0x01000002,
    FlowKey_Meta    = 0x01000022,
};

enum FlowScreenRotation {
    // Angle is clockwise
    FlowRotation0 = 0,
    FlowRotation90,
    FlowRotation180,
    FlowRotation270
};

class GLTextureImage;
class GLTextureBitmap;
class GLClip;
class GLRenderer;
class GLPictureClip;
class GLTextClip;
class GLVideoClip;
class GLWebClip;
class GLCamera;

class GLFont;
class GLFontLibrary;

struct GLBoundingBox;

struct FontHeader;
struct GlyphHeader;

struct FlowKeyEvent {
    FlowEvent event;
    unicode_string key;
    bool ctrl;
    bool shift;
    bool alt;
    bool meta;
    FlowKeyCode code;

    FlowKeyEvent() {
        event = FlowUnknownEvent;
        key = parseUtf8("");
        ctrl = false;
        shift = false;
        alt = false;
        meta = false;
        code = FlowKey_Null;
    }

    FlowKeyEvent(FlowEvent event, unicode_string key, bool ctrl,  bool shift,
        bool alt, bool meta, FlowKeyCode code) {
        this->event = event;
        this->key = key;
        this->ctrl = ctrl;
        this->shift = shift;
        this->alt = alt;
        this->meta = meta;
        this->code = code;
    }
};

class GLRenderSupport : public NativeMethodHost
{
    friend class GLClip;
    friend class GLTextClip;
    friend class GLVideoClip;
    friend class GLPictureClip;
    friend class GLWebClip;
    friend class GLCamera;
    friend class GLFilter;
    friend class GLFont; // To give access to FallbackFont

protected:
    int Width, Height, RealWidth, RealHeight;
    int MouseX, MouseY;
    int MouseDownX, MouseDownY;
    double lastUserAction;
    bool gl_transparent;

    GLClip *getCurrentFocus();
private:
    FlowEvent CurEvent;

    FlowScreenRotation ScreenRotation;
    float ScaleCenterX, ScaleCenterY;
    float ScaleFactor;
    bool GlobalZoomEnabled;

    unicode_string cursor, user_cursor;

    GLRenderer *Renderer;

    bool RedrawPending, FullWindowPending, IsFullWindow, DropFocusOnDown;

    typedef STL_HASH_MAP<unicode_string, std::vector<GLPictureClip*> > T_PendingPictures;
    typedef std::map<FlowEvent, std::set<GLClip*> > T_EventListeners;
    typedef std::set<GLClip*> T_ClipSet;
    typedef std::vector<int> T_Listeners;
    typedef std::set<GLClip*> T_TabIndexClips;
    typedef std::vector<GLClip*> T_AccessibleClips;

    // ROOTS
    GLClip *Stage, *FullWindowTarget;
    T_PendingPictures PendingPictures;
    T_ClipSet HoveredClips, PressedClips;
    T_ClipSet NativeWidgetClips;
    GLClip *DebugHighlightClip;
    T_TabIndexClips tabIndexedClips;

    GLTextClip *TextFocus, *PressTextFocus;
    GLClip *CurrentFocus;

    T_Listeners SwipeListeners, PinchListeners, PanListeners;
    T_Listeners RenderDeferredFunctions;

    // WEAK ROOTS
    T_EventListeners EventListeners;

    T_Listeners VirtualKeyboardHeightListeners;
    T_Listeners DrawFrameListeners;
    T_Listeners FullWindowListeners;

    void addEventListener(FlowEvent event, GLClip *clip);
    void removeEventListener(FlowEvent event, GLClip *clip);
    void removeEventListener(GLClip *clip);

    void checkNativeWidgets(bool resize);
    bool createNativeWidget(GLClip *clip);
    void destroyNativeWidget(GLClip *clip);

    void updateHoveredClips();

    void updateGlobalScale(bool resized = false);

    void dispatchEventCallbacks(FlowEvent event, int num_args, StackSlot *args);
    void dispatchEventCallbacks(const std::vector<GLClip*> &clips, FlowEvent event, int num_args, StackSlot *args);

    void setFullWindowTarget(GLClip *clip);
    void toggleFullWindow(bool fw);
    void notifyFullWindow(bool fw);

    // Pictures
    typedef STL_HASH_MAP<unicode_string, weak_ptr<GLTextureBitmap> > T_PictureCache;
    T_PictureCache PictureCache;
    STL_HASH_SET<unicode_string> DownloadedPictures;
    STL_HASH_MAP<unicode_string, std::string> PictureFiles;

    // Fonts
    shared_ptr<GLFontLibrary> FontLibrary;

    shared_ptr<GLFont> FallbackFont;
    shared_ptr<GLFont> DefaultFont;
    STL_HASH_MAP<TextFont, shared_ptr<GLFont> > Fonts;

    shared_ptr<GLFont> lookupFont(TextFont textFont);

    void doUpdateAccessibleClips(GLClip * clip, std::vector<GLClip*> & accessible_clips, bool parent_enabled);

public:
    GLRenderSupport(ByteCodeRunner *owner);
    ~GLRenderSupport();

#ifdef FLOW_INSTRUCTION_PROFILING
    int ProfilingInsnCost;
#endif

    GLClip *getStage() { return Stage; }

    bool needsRendering();

    // Read a resource bundled with the program
    virtual bool loadAssetData(StaticBuffer *buffer, std::string name, size_t size);

    virtual bool loadSystemFont(FontHeader* /*header*/, TextFont /*textFont*/) { return false; }
    virtual bool loadSystemGlyph(const FontHeader* /*header*/, GlyphHeader* /*info*/, StaticBuffer* /*pixels*/, TextFont /*textFont*/, ucs4_char /*code*/) { return false; }

    void setDebugHighlight(GLClip *clip);

    int getDPI() { return DisplayDPI; }
    int getScreenWidth() { return RealWidth; }
    int getScreenHeight() { return RealHeight; }

    void removeUrlFromPicturesCache(unicode_string url);

    virtual void addFileDropClip(GLClip* /*clip*/) {}
    virtual void eraseFileDropClip(GLClip* /*clip*/) {}

    //true if font_alias was found, false - DefaultFont is used
    bool setFallbackFont(unicode_string name);

    void setDisplayDensity(double density) { DisplayDensity = density; }
protected:
    GLRenderer *getRenderer() { return Renderer; }

    T_AccessibleClips accessible_clips;

    bool initGLContext(unsigned root_fb_id = 0);
    void resizeGLContext(int w, int h);
    void paintGLContext(unsigned ad_hoc_fb = 0);

    void loadFont(std::string filename, std::vector<unicode_string> aliases, bool set_default = false);

    bool NoHoverMouse, DrawMouseRect;
    float MouseRadius; // Degree of confidence radius

    float PixelsPerCm;
    int DisplayDPI;
    double DisplayDensity;
    void setDPI(int dpi) { DisplayDPI = dpi; PixelsPerCm = dpi/2.54f; }

    bool isScreenRotated() { return (ScreenRotation&1) != 0; }
    FlowScreenRotation getScreenRotation() { return ScreenRotation; }
    void setScreenRotation(FlowScreenRotation newRotation);

    void dispatchMouseEvent(FlowEvent, int x, int y);
    void dispatchKeyEvent(FlowEvent, unicode_string key, bool ctrl, bool shift, bool alt, bool meta, FlowKeyCode code);
    void dispatchFlowKeyEvent(FlowKeyEvent event);
    bool dispatchGestureEvent(FlowEvent, FlowGestureState, float, float, float, float);
    void dispatchWheelEvent(float delta);
    void dispatchFineGrainWheelEvent(float deltax, float deltay);
    void dispatchVirtualKeyboardCallbacks(double height);

    bool isVirtualKeyboardListenerAttached();

    void adjustGlobalScale(float shift_x, float shift_y, float center_x, float center_y, float df);
    void setGlobalScale(float scale_center_x, float scale_center_y, float scale_factor);
    bool isScreenScaled() { return fabsf(ScaleFactor - 1.0f) > 0.01f; }

    void flowGCObject(GarbageCollectorFn ref);

    void OnHostEvent(HostEvent);
    void OnRunnerReset(bool inDestructor);
    void GetTargetTokens(std::set<std::string> &tokens);
    NativeFunction *MakeNativeFunction(const char *name, int num_args);

    void adviseCursor(unicode_string name);

    bool hasNativeWidget(GLClip *clip);
    void dispatchEditStateUpdate(GLClip *clip, int cursor, int sel_start, int sel_end, bool set_text, unicode_string text);
    void dispatchVideoNotFound(GLClip *clip);
    void dispatchVideoDuration(GLClip *clip, int64_t duration);
    void dispatchVideoPosition(GLClip *clip, int64_t position);
    void dispatchVideoSize(GLClip *clip, int width, int height);
    void dispatchVideoPlayStatus(GLClip *clip, /*GLVideoClip::Event*/int event);
    void dispatchCameraError(GLClip *clip);
    void dispatchCameraStatus(GLClip *clip, /*GLCamera::Event*/int event);
    void dispatchPageLoaded(GLClip *clip);
    void dispatchPageError(GLClip *clip, const std::string &message);
    void dispatchPageCall(GLClip *clip, const StackSlot &args);

#ifdef FLOW_DEBUGGER
    virtual void onClipDataChanged(GLClip* /*clip*/) {}
    virtual void onClipBeginSetParent(GLClip* /*child*/, GLClip* /*parent*/, GLClip* /*oldparent*/) {}
    virtual void onClipEndSetParent(GLClip* /*child*/, GLClip* /*parent*/, GLClip* /*oldparent*/) {}
#endif

    virtual bool doCreateNativeWidget(GLClip*, bool /*new*/) { return false; }
    virtual void doDestroyNativeWidget(GLClip*) {}
    virtual void doReshapeNativeWidget(GLClip* /*owner*/, const GLBoundingBox& /*bbox*/, float /*scale*/, float /*alpha*/) {}
    virtual StackSlot webClipHostCall(GLWebClip* /*clip*/, const unicode_string& /*name*/, const StackSlot& /*args*/) { return StackSlot::MakeVoid(); }
    virtual StackSlot webClipEvalJS(GLWebClip* /*clip*/, const unicode_string& /*name*/, StackSlot& /*cb*/) { return StackSlot::MakeVoid(); }
    virtual StackSlot setWebClipZoomable(GLWebClip* /*clip*/, const StackSlot& /*args*/) { return StackSlot::MakeVoid(); }
    virtual StackSlot setWebClipDomains(GLWebClip* /*clip*/, const StackSlot& /*args*/) { return StackSlot::MakeVoid(); }

    virtual void doRequestRedraw() {}
    virtual void doEnableResize(bool) {}
    virtual void doSetCursor(std::string) {}
    virtual bool hasCursorSupport() { return false; }
    virtual void doOpenUrl(unicode_string, unicode_string) {}

    virtual bool loadPicture(unicode_string url, bool cache) = 0;
    virtual bool loadPicture(unicode_string url, HttpRequest::T_SMap& headers, bool cache) = 0;

    virtual void abortPictureLoading(unicode_string /*url*/) {}

    virtual void onTextClipStateChanged(GLTextClip* /*clip*/) = 0;

    virtual void doUpdateVideoPlay(GLVideoClip * /*clip*/) {}
    virtual void doUpdateVideoPosition(GLVideoClip * /*clip*/) {}
    virtual void doUpdateVideoVolume(GLVideoClip * /*clip*/) {}
    virtual void doUpdateVideoPlaybackRate(GLVideoClip * /*clip*/) {}
    virtual void doUpdateVideoFocus(GLVideoClip * /*clip*/, bool /*focus*/) {}

    virtual int doGetNumberOfCameras() {return 0;}
    virtual std::string doGetCameraInfo(int /*id*/) { return std::string(""); }
    virtual void doUpdateCameraState(GLCamera* /*clip*/) {}
    virtual void doCameraTakePhoto(int /*cameraId*/, std::string /*additionalInfo*/, int /*desiredWidth*/, int /*desiredHeight*/, int /*compressQuality*/, std::string /*fileName*/, int /*fitMode*/) {}
    virtual void doCameraTakeVideo(int /*cameraId*/, std::string /*additionalInfo*/, int /*duration*/, int /*size*/, int /*quality*/, std::string /*fileName*/) {}
    virtual void doStartRecordAudio(std::string /*additionalInfo*/, std::string /*fileName*/, int /*duration*/) {}
    virtual void doStopRecordAudio() {}
    virtual void doTakeAudioRecord() {}

    virtual void doSetInterfaceOrientation(std::string) {}

    // The url must be exactly the same string as was passed to loadPicture
    bool resolvePictureError(unicode_string url, unicode_string error);

    bool resolvePicture(unicode_string url, std::string filename);
    bool resolvePicture(unicode_string url, const uint8_t *data, unsigned size);
    bool resolvePicture(unicode_string url, shared_ptr<GLTextureBitmap> image);

    // If all pending instances are download_only, resolves them and returns true
    bool resolvePictureDownloaded(unicode_string url);

    void removePictureFromPending(GLPictureClip *clip);

    virtual bool loadStubPicture(unicode_string url, shared_ptr<GLTextureBitmap> &img);

    static StackSlot removeListener(ByteCodeRunner*, StackSlot*, void*);

    void tryFocusNextClip(GLClip *focused, bool direct);

    void updateAccessibleClips();

    static StackSlot removeDrawFrameListener(ByteCodeRunner*, StackSlot*, void*);
    static StackSlot removeFullWindowListener(ByteCodeRunner*, StackSlot*, void*);
    static StackSlot removeDeferredFunction(ByteCodeRunner*, StackSlot*, void*);

    void updateLastUserAction();
private:
    DECLARE_NATIVE_METHOD(NativeGetUrl)

    DECLARE_NATIVE_METHOD(getPixelsPerCm)
    DECLARE_NATIVE_METHOD(setHitboxRadius)

    DECLARE_NATIVE_METHOD(makeClip)
    DECLARE_NATIVE_METHOD(makeTextField)
    DECLARE_NATIVE_METHOD(makePicture)
    DECLARE_NATIVE_METHOD(makePicture4)
    DECLARE_NATIVE_METHOD(makeVideo)

    DECLARE_NATIVE_METHOD(makeBlur)
    DECLARE_NATIVE_METHOD(makeBevel)
    DECLARE_NATIVE_METHOD(makeDropShadow)
    DECLARE_NATIVE_METHOD(makeGlow)
    DECLARE_NATIVE_METHOD(makeShader)

    DECLARE_NATIVE_METHOD(getStage)
    DECLARE_NATIVE_METHOD(getStageWidth)
    DECLARE_NATIVE_METHOD(getStageHeight)
    DECLARE_NATIVE_METHOD(currentClip)
    DECLARE_NATIVE_METHOD(enableResize)

    DECLARE_NATIVE_METHOD(setCursor)
    DECLARE_NATIVE_METHOD(getCursor)

    DECLARE_NATIVE_METHOD(makeWebClip)

    DECLARE_NATIVE_METHOD(makeCamera)
    DECLARE_NATIVE_METHOD(getNumberOfCameras)
    DECLARE_NATIVE_METHOD(getCameraInfo)
    DECLARE_NATIVE_METHOD(cameraTakePhoto)
    DECLARE_NATIVE_METHOD(cameraTakeVideo)
    DECLARE_NATIVE_METHOD(startRecordAudio)
    DECLARE_NATIVE_METHOD(stopRecordAudio)
    DECLARE_NATIVE_METHOD(takeAudioRecord)

    DECLARE_NATIVE_METHOD(addGestureListener)
    DECLARE_NATIVE_METHOD(setInterfaceOrientation)
    DECLARE_NATIVE_METHOD(setGlobalZoomEnabled)
    DECLARE_NATIVE_METHOD(deferUntilRender)
    DECLARE_NATIVE_METHOD(interruptibleDeferUntilRender)

    DECLARE_NATIVE_METHOD(resetFullWindowTarget)
    DECLARE_NATIVE_METHOD(toggleFullWindow)
    DECLARE_NATIVE_METHOD(onFullWindow)
    DECLARE_NATIVE_METHOD(isFullWindow)

    DECLARE_NATIVE_METHOD(addDrawFrameEventListener)
    DECLARE_NATIVE_METHOD(setDropCurrentFocusOnDown)

    DECLARE_NATIVE_METHOD(addVirtualKeyboardHeightListener)
};

#endif // GLRENDERSUPPORT_H
