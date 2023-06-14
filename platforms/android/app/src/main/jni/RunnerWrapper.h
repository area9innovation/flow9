#ifndef RUNNERWRAPPER_H_
#define RUNNERWRAPPER_H_

#include "gl-gui/GLRenderSupport.h"
#include "gl-gui/GLRenderer.h"

#include "utils/AbstractHttpSupport.h"
#include "utils/AbstractSoundSupport.h"
#include "utils/AbstractInAppPurchase.h"
#include "utils/AbstractNotificationsSupport.h"
#include "utils/AbstractLocalyticsSupport.h"
#include "utils/AbstractGeolocationSupport.h"
#include "utils/FileLocalStore.h"
#include "utils/FileSystemInterface.h"
#include "utils/MediaStreamSupport.h"
#include "utils/WebRTCSupport.h"
#include "utils/MediaRecorderSupport.h"
#include "utils/AbstractWebSocketSupport.h"
#include "utils/PrintingSupport.h"

#include <jni.h>

class AndroidRunnerWrapper;

class AndroidTextureImage : public GLTextureBitmap {
    AndroidRunnerWrapper *owner;
    jobject bitmap;

protected:
    virtual void loadData();

public:
    AndroidTextureImage(AndroidRunnerWrapper *owner, ivec2 size, jobject bmp);
    virtual ~AndroidTextureImage();
};

class AndroidRenderSupport : public GLRenderSupport {
    AndroidRunnerWrapper *owner;

    int dpi;
    float density;

    int next_timer_id;
    STL_HASH_MAP<int, StackSlot> timers; // ROOT
    std::vector<int> keyboardEventListenersRoots;

public:
    AndroidRenderSupport(AndroidRunnerWrapper *owner);

    void init() { initGLContext(); }
    void resize(int w, int h) { resizeGLContext(w, h); }
    void paint() { paintGLContext(); }

    void deliverMouseEvent(jint type, jint x, jint y) {
        dispatchMouseEvent(FlowEvent(type), x, y);
    }

    bool deliverGestureEvent(FlowEvent e, FlowGestureState s, float p1, float p2, float p3, float p4) {
        return dispatchGestureEvent(e, s, p1, p2, p3, p4);
    }

    void deliverKeyEvent(FlowEvent event, unicode_string key, bool ctrl, bool shift, bool alt, bool meta, FlowKeyCode code) {
        dispatchKeyEvent(event, key, ctrl, shift, alt, meta, code);
    }

    void deliverVirtualKeyboardCallbacks(double height) {
        dispatchVirtualKeyboardCallbacks(height);
    }

    bool deliverIsVirtualKeyboardListenerAttached(){
        return isVirtualKeyboardListenerAttached();
    }

    void deliverTimer(jint id);

    void attachFont(jstring file, jobjectArray aliases, jboolean setdef);

    jboolean resolvePictureBitmap(jstring url, jobject bitmap, jint w, jint h);
    jboolean resolvePictureFile(jstring url, jstring filename);
    jboolean resolvePictureData(jstring url, jbyteArray data);
    jboolean resolvePictureError(jstring url, jstring error);

    void setDPI(int v);
    void setDensity(float v);
    void setScreenWidthHeight(int w, int h);
    void adjustScale(jfloat dx, jfloat dy, jfloat cx, jfloat cy, jfloat df);

    bool loadAssetData(StaticBuffer *buffer, std::string name, size_t size);

    void deliverEditStateUpdate(jlong clip, jint cursor, jint sel_start, jint sel_end, jstring text);
    jstring textIsAcceptedByFlowFilters(jlong clip, jstring text);
    jboolean keyEventFilteredByFlowFilters(
        jlong clip, jint event, jstring key, jboolean ctrl,
        jboolean shift, jboolean alt, jboolean meta, jint code);

    void deliverVideoNotFound(jlong clip);
    void deliverVideoSize(jlong clip, jint width, jint height);
    void deliverVideoDuration(jlong clip, jlong duration);
    void deliverVideoPosition(jlong clip, jlong length);
    void deliverVideoPlayStatus(jlong clip, jint event);
    void setVideoExternalTextureId(jlong clip, jint id);

    void deliverCameraError(jlong clip_id);
    void deliverCameraStatus(jlong clip, jint event);
    int doGetNumberOfCameras();
    std::string doGetCameraInfo(int id);
    void doCameraTakePhoto(int cameraId, std::string additionalInfo, int desiredWidth , int desiredHeight, int compressQuality, std::string fileName, int fitMode);
    void doCameraTakeVideo(int cameraId, std::string additionalInfo, int duration , int size, int quality, std::string fileName);
    void doStartRecordAudio(std::string additionalInfo, std::string fileName, int duration);
    void doStopRecordAudio();
    void doTakeAudioRecord();
    void callFlowFromWebView(jlong clip, jobjectArray args);
    void notifyPageLoaded(jlong clip);
    void notifyPageError(jlong clip, jstring msg);

    bool loadSystemFont(FontHeader *header, TextFont textFont);
    bool loadSystemGlyph(const FontHeader *header, GlyphHeader *info, StaticBuffer *pixels, TextFont textFont, ucs4_char code);

    jobjectArray fetchAccessibleClips();
protected:
    void OnHostEvent(HostEvent);
    void doRequestRedraw();

    void OnRunnerReset(bool inDestructor);
    void flowGCObject(GarbageCollectorFn ref);

    void GetTargetTokens(std::set<std::string> &);

    bool doCreateNativeWidget(GLClip *clip, bool neww);
    void doDestroyNativeWidget(GLClip *clip);
    void doReshapeNativeWidget(GLClip *clip, const GLBoundingBox &bbox, float scale, float alpha);
    virtual StackSlot webClipHostCall(GLWebClip */*clip*/, const unicode_string &/*name*/, const StackSlot &/*args*/);
    virtual StackSlot setWebClipZoomable(GLWebClip */*clip*/, const StackSlot &/*args*/);
    virtual StackSlot setWebClipDomains(GLWebClip */*clip*/, const StackSlot &/*args*/);

    void doUpdateVideoPlay(GLVideoClip *video_clip);
    void doUpdateVideoPosition(GLVideoClip *video_clip);
    void doUpdateVideoVolume(GLVideoClip *video_clip);
    void doUpdateCameraState(GLCamera *clip);

    void onTextClipStateChanged(GLTextClip* clip);

    NativeFunction *MakeNativeFunction(const char *name, int num_args);

    void doSetInterfaceOrientation(std::string orientation);

    bool loadPicture(unicode_string url, bool cache);
    bool loadPicture(unicode_string url, HttpRequest::T_SMap& headers, bool cache);
    void abortPictureLoading(unicode_string url);
    void doOpenUrl(unicode_string url, unicode_string target);

    int ScreenWidth, ScreenHeight;
private:
    DECLARE_NATIVE_METHOD(timer);
    DECLARE_NATIVE_METHOD(showSoftKeyboard);
    DECLARE_NATIVE_METHOD(hideSoftKeyboard);
};

class AndroidHttpSupport : public AbstractHttpSupport {
    AndroidRunnerWrapper *owner;

public:
    AndroidHttpSupport(AndroidRunnerWrapper *owner);

    void deliverData(jint id, jbyteArray data, jboolean last);
    void deliverError(jint id, jbyteArray buffer);
    void deliverProgress(jint id, jfloat loaded, jfloat total);

protected:
    void doRequest(HttpRequest &rq);
    void doRemoveUrlFromCache(const unicode_string & url);
    int doGetAvailableCacheSpaceMb();
    void doSystemDownloadFile(const unicode_string & url);
    void doDeleteAppCookies();
};

class AndroidSoundSupport : public AbstractSoundSupport {
    AndroidRunnerWrapper *owner;

public:
    AndroidSoundSupport(AndroidRunnerWrapper *owner);

    void deliverResolveReady(jlong sound);
    void deliverResolveError(jlong sound, jstring error);

    void deliverNotifyDone(jlong channel);

protected:
    virtual void doBeginLoad(AbstractSound *sound);

    virtual void doBeginPlay(AbstractSoundChannel *channel, float start_pos, bool loop);

    virtual void doSetVolume(AbstractSoundChannel *channel, float value);
    virtual void doStopSound(AbstractSoundChannel *channel);
    virtual float doGetSoundPosition(AbstractSoundChannel *channel);
    virtual float doComputeSoundLength(AbstractSound *);
};

class AndroidInAppPurchase : public AbstractInAppPurchase {
    AndroidRunnerWrapper *owner;

public:
    AndroidInAppPurchase(AndroidRunnerWrapper *owner);
protected:
    void loadProductsInfo(std::vector<unicode_string> pids);
    
    void paymentRequest(unicode_string _id, int count);
    void restoreRequest();
};

class AndroidNotificationsSupport : public AbstractNotificationsSupport {
    AndroidRunnerWrapper *owner;

public:
    AndroidNotificationsSupport(AndroidRunnerWrapper *owner);
protected:
    virtual bool doHasPermissionLocalNotification();
    virtual void doRequestPermissionLocalNotification(int cb_root);
    virtual void doScheduleLocalNotification(double time, int notificationId, std::string notificationCallbackArgs, std::string notificationTitle, std::string notificationText, bool withSound, bool pinned);
    virtual void doCancelLocalNotification(int notificationId);

    virtual void doGetFBToken(int cb_root);
    virtual void doSubscribeToFBTopic(unicode_string name);
    virtual void doUnsubscribeFromFBTopic(unicode_string name);
};

class AndroidLocalyticsSupport : public AbstractLocalyticsSupport {
    AndroidRunnerWrapper *owner;

public:
    AndroidLocalyticsSupport(AndroidRunnerWrapper *owner);
protected:
    void doTagEventWithAttributes(const unicode_string &event_name, const std::map<unicode_string, unicode_string> &event_attributes);
};

class AndroidGeolocationSupport : public AbstractGeolocationSupport {
    AndroidRunnerWrapper *owner;

public:
    AndroidGeolocationSupport(AndroidRunnerWrapper *owner);
private:
    virtual void doGeolocationGetCurrentPosition(int callbacksRoot, bool enableHighAccuracy, double timeout, double maximumAge, std::string turnOnGeolocationMessage, std::string okButtonText, std::string cancelButtonText);
    virtual void doGeolocationWatchPosition(int callbacksRoot, bool enableHighAccuracy, double timeout, double maximumInterval, std::string turnOnGeolocationMessage, std::string okButtonText, std::string cancelButtonText);
    virtual void afterWatchDispose(int callbacksRoot);
};

class AndroidMediaStreamSupport : public MediaStreamSupport {
    AndroidRunnerWrapper *owner;

public:
    AndroidMediaStreamSupport(AndroidRunnerWrapper *owner);

    class FlowNativeMediaStream : public FlowNativeObject
    {
        AndroidRunnerWrapper *owner;
    public:

        FlowNativeMediaStream(AndroidRunnerWrapper* owner);
        ~FlowNativeMediaStream();

        jobject mediaStream;

        jint width;
        jint height;

        DEFINE_FLOW_NATIVE_OBJECT(FlowNativeMediaStream, FlowNativeObject)
    };

    void deliverInitializeDeviceInfoCallback(jint cb_root);
    void deliverDevices(jint cb_root, jobjectArray ids, jobjectArray names);
    void deliverMediaStream(jint cb_root, jobject mediaStream);
    void deliverError(jint cb_root, jstring error);

private:
    virtual void initializeDeviceInfo(int callbackRoot);
    virtual void getAudioInputDevices(int callbackRoot);
    virtual void getVideoInputDevices(int callbackRoot);

    virtual void makeStream(bool recordAudio, bool recordVideo, unicode_string audioDeviceId, unicode_string videoDeviceId, int onReadyRoot, int onErrorRoot);
    virtual void stopStream(StackSlot mediaStream);

};

class AndroidWebRTCSupport : public WebRTCSupport {
    AndroidRunnerWrapper *owner;

public:
    AndroidWebRTCSupport(AndroidRunnerWrapper *owner);

    class FlowNativeMediaSender : public FlowNativeObject
    {
        AndroidWebRTCSupport *owner;
    public:

        FlowNativeMediaSender(AndroidWebRTCSupport* owner);
        ~FlowNativeMediaSender();

        jobject mediaSender;

        DEFINE_FLOW_NATIVE_OBJECT(FlowNativeMediaSender, FlowNativeObject)
    };

    void deliverOnMediaSenderReadyCallback(jint cb_root, jobject sender);
    void deliverOnNewParticipantCallback(jint cb_root, jstring id, jobject mediaStream);
    void deliverOnParticipantLeaveCallback(jint cb_root, jstring id);
    void deliverOnErrorCallback(jint cb_root, jstring error);

private:
    virtual void makeSenderFromStream(unicode_string serverUrl, unicode_string roomId, std::vector<unicode_string> stunUrls, std::vector<std::vector<unicode_string> > turnServers,
                                                       StackSlot stream, int onMediaSenderReadyRoot, int onNewParticipantRoot, int onParticipantLeaveRoot, int onErrorRoot);
    virtual void stopSender(StackSlot sender);

};

class AndroidMediaRecorderSupport : public MediaRecorderSupport {
    AndroidRunnerWrapper *owner;

public:
    AndroidMediaRecorderSupport(AndroidRunnerWrapper *owner);

    class FlowNativeMediaRecorder : public FlowNativeObject
    {
        AndroidMediaRecorderSupport *owner;
    public:

        FlowNativeMediaRecorder(AndroidMediaRecorderSupport* owner);
        ~FlowNativeMediaRecorder();

        jobject mediaRecorder;

        DEFINE_FLOW_NATIVE_OBJECT(FlowNativeMediaRecorder, FlowNativeObject)
    };

    void deliverMediaRecorder(jint cb_root, jobject recorder);
    void deliverError(jint cb_root, jstring error);
private:
    virtual void makeMediaRecorder(unicode_string websocketUri, unicode_string filePath, StackSlot mediaStream, int timeslice, int onReadyRoot, int onErrorRoot);
    virtual void startMediaRecorder(StackSlot recorder, int timeslice);
    virtual void resumeMediaRecorder(StackSlot recorder);
    virtual void pauseMediaRecorder(StackSlot recorder);
    virtual void stopMediaRecorder(StackSlot recorder);
};

class AndroidWebSocketSupport : public AbstractWebSocketSupport {
    AndroidRunnerWrapper *owner;
public:
    AndroidWebSocketSupport(AndroidRunnerWrapper *owner);

    class FlowNativeWebSocket : public FlowNativeObject
    {
        AndroidWebSocketSupport *owner;
    public:
        FlowNativeWebSocket(AndroidWebSocketSupport* owner);
        ~FlowNativeWebSocket();
        jobject websocket;
        DEFINE_FLOW_NATIVE_OBJECT(FlowNativeWebSocket, FlowNativeObject)
    };

    void deliverOnClose(jint callbacksKey, jint closeCode, jstring reason, jboolean wasClean);
    void deliverOnError(jint callbacksKey, jstring error);
    void deliverOnMessage(jint callbacksKey, jstring message);
    void deliverOnOpen(jint callbacksKey);

protected:
    virtual StackSlot doOpen(unicode_string url, int callbacksKey);
    virtual StackSlot doSend(StackSlot websocket, unicode_string message);
    virtual StackSlot doHasBufferedData(StackSlot websocket);
    virtual void doClose(StackSlot websocket, int code, unicode_string reason);
};

class AndroidFileSystemInterface : public FileSystemInterface {
    AndroidRunnerWrapper *owner;
public:
    AndroidFileSystemInterface(AndroidRunnerWrapper *owner);

    void deliverOpenFileDialogCallback(jint callbackKey, jobjectArray filePaths);
protected:
    void doOpenFileDialog(int maxFilesCount, std::vector<std::string> fileTypes, StackSlot callback);
    std::string doFileType(const StackSlot &file);
};

class AndroidPrintingSupport : public PrintingSupport {
    AndroidRunnerWrapper *owner;
public:
    AndroidPrintingSupport(AndroidRunnerWrapper *owner);

protected:
    void doPrintHTMLDocument(unicode_string html);
    void doPrintDocumentFromURL(unicode_string url);
};

class AndroidRunnerWrapper {
    friend class AndroidRenderSupport;
    friend class AndroidHttpSupport;
    friend class AndroidSoundSupport;
    friend class AndroidInAppPurchase;
    friend class AndroidNotificationsSupport;
    friend class AndroidLocalyticsSupport;
    friend class AndroidGeolocationSupport;
    friend class AndroidTextureImage;
    friend class AndroidMediaStreamSupport;
    friend class AndroidWebRTCSupport;
    friend class AndroidMediaRecorderSupport;
    friend class AndroidWebSocketSupport;
    friend class AndroidFileSystemInterface;
    friend class AndroidPrintingSupport;

    // These must be updated on every outermost java->c++ boundary
    JNIEnv *env;
    jobject owner;

    bool bytecode_ok, main_ok;
    bool flow_time_profiling_enabled;
    short flow_time_profile_trace_per;
    ByteCodeRunner runner;
    AndroidRenderSupport renderer;
    AndroidHttpSupport http;
    AndroidSoundSupport sound;
    AndroidInAppPurchase purchase;
    AndroidNotificationsSupport notifications;
    AndroidLocalyticsSupport localytics;
    AndroidGeolocationSupport geolocation;
    AndroidMediaStreamSupport mediaStream;
    AndroidWebRTCSupport webrtcSupport;
    AndroidMediaRecorderSupport mediaRecorder;
    AndroidWebSocketSupport websockets;
    FileLocalStore store;
    AndroidFileSystemInterface fsinterface;
    AndroidPrintingSupport printing;

    jboolean finishLoadBytecode();

    void notifyNeedsRepaint();
    void notifyError();
    void notifyRunnerReset();
    void notifyNewTimer(int id, int delay_ms);
    void notifyBrowseUrl(unicode_string str, unicode_string target);

    void notifyBindTextureBitmap(jobject bitmap);

    bool eatExceptions(std::string *msg = NULL);

public:
    AndroidRunnerWrapper(JNIEnv *env, jobject owner_obj);
    ~AndroidRunnerWrapper();

    JNIEnv *getEnv() { return env; }

    ByteCodeRunner *getRunner() { return &runner; }
    AndroidRenderSupport *getRenderer() { return &renderer; }
    AndroidHttpSupport *getHttp() { return &http; }
    AndroidSoundSupport *getSound() { return &sound; }
    AndroidInAppPurchase *getInAppPurchase() { return &purchase; }
    AndroidNotificationsSupport *getNotifications() { return &notifications; }
    AndroidGeolocationSupport *getGeolocation() { return &geolocation; }
    AndroidMediaStreamSupport *getMediaStream() { return &mediaStream; }
    AndroidWebRTCSupport *getWebRTCSupport() { return &webrtcSupport; }
    AndroidMediaRecorderSupport *getMediaRecorder() { return &mediaRecorder; }
    AndroidWebSocketSupport *getWebSockets() { return &websockets; }
    AndroidFileSystemInterface *getFSInterface() { return &fsinterface; }
    AndroidPrintingSupport *getPrinting() { return &printing; }

    void setStorePath(jstring fname);
    void setTmpPath(jstring fname);

    void reset();
    jboolean loadBytecode(jstring fname);
    jboolean loadBytecodeData(jbyteArray data);
    jboolean runMain();

    jstring getRunnerError();
    jstring getRunnerErrorInfo();

    void setUrlParameters(jstring url, jobjectArray data);
    void setFlowTimeProfile(jboolean flow_time_profile, jshort flow_time_profile_trace_per);

    static void destroy(JNIEnv *env, jobject owner, AndroidRunnerWrapper *obj) {
        // During destruction, bitmaps will want to delete global java roots
        obj->env = env;
        obj->owner = owner;
        delete obj;
    }

    class REF {
        bool topmost;
        AndroidRunnerWrapper *p;
    public:
        REF(JNIEnv *env, jobject owner, jlong lv);
        ~REF();

        bool isTopmost() { return topmost; }

        AndroidRunnerWrapper* operator ->() { return p; }
    };
};



#endif /* RUNNERWRAPPER_H_ */
