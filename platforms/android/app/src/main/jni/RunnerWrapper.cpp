#include "RunnerWrapper.h"

#include <jni.h>

#include "AndroidUtils.h"

#include <GLES2/gl2.h>

#include <stdio.h>
#include <stdlib.h>

#include "core/RunnerMacros.h"
#include "core/GarbageCollector.h"

#include "gl-gui/GLTextClip.h"
#include "gl-gui/GLVideoClip.h"
#include "gl-gui/GLWebClip.h"
#include "gl-gui/GLCamera.h"

#include <sstream>

#include <sys/vfs.h>

#ifdef ANDROID_GPROF
#include "prof.h"
#endif

static jclass cString = NULL;

static std::string jni2string(JNIEnv *env, jstring str) {
    const char *utf_chars = str ? env->GetStringUTFChars(str, NULL) : NULL;
    if (!utf_chars) return std::string();
    std::string rv(utf_chars, (unsigned) env->GetStringUTFLength(str));
    env->ReleaseStringUTFChars(str, utf_chars);
    return rv;
}

static unicode_string jni2unicode(JNIEnv *env, jstring str) {
    const jchar *chars = str ? env->GetStringChars(str, NULL) : NULL;
    if (!chars) return unicode_string();
    unicode_string rv(chars, (unsigned) env->GetStringLength(str));
    env->ReleaseStringChars(str, chars);
    return rv;
}

static jstring string2jni(JNIEnv *env, const std::string &str) {
    return env->NewStringUTF(str.c_str());
}

static jstring string2jni(JNIEnv *env, const unicode_string &str) {
    return env->NewString(str.data(), str.size());
}

template<class T>
void jni2unicode_map(JNIEnv *env, T *pmap, jobjectArray data)
{
    int anum = env->GetArrayLength(data)/2;
    for (int i = 0; i < anum; i++) {
        jstring key = (jstring)env->GetObjectArrayElement(data, 2*i);
        jstring val = (jstring)env->GetObjectArrayElement(data, 2*i+1);

        (*pmap)[jni2unicode(env,key)] = jni2unicode(env,val);

        env->DeleteLocalRef(key);
        env->DeleteLocalRef(val);
    }
}

template<class T>
void jni2string_map(JNIEnv *env, T *pmap, jobjectArray data)
{
    int anum = env->GetArrayLength(data)/2;
    for (int i = 0; i < anum; i++) {
        jstring key = (jstring)env->GetObjectArrayElement(data, 2*i);
        jstring val = (jstring)env->GetObjectArrayElement(data, 2*i+1);

        (*pmap)[jni2string(env,key)] = jni2string(env,val);

        env->DeleteLocalRef(key);
        env->DeleteLocalRef(val);
    }
}

template<class T>
jobjectArray string_map2jni(JNIEnv *env, const T &pmap)
{
    jobjectArray rv = env->NewObjectArray(pmap.size()*2, cString, NULL);

    int i = 0;
    for (typename T::const_iterator it = pmap.begin(); it != pmap.end(); ++it, ++i) {
        jstring key = string2jni(env, it->first);
        jstring val = string2jni(env, it->second);

        env->SetObjectArrayElement(rv, 2*i, key);
        env->SetObjectArrayElement(rv, 2*i+1, val);

        env->DeleteLocalRef(key);
        env->DeleteLocalRef(val);
    }

    return rv;
}

template<class T>
jobjectArray string_array2jni(JNIEnv *env, const T &array)
{
    jobjectArray rv = env->NewObjectArray(array.size(), cString, NULL);

    int i = 0;
    for (typename T::const_iterator it = array.begin(); it != array.end(); ++it, ++i) {
        jstring val = string2jni(env, *it);
        env->SetObjectArrayElement(rv, i, val);
        env->DeleteLocalRef(val);
    }

    return rv;
}

static void jni2bytes(JNIEnv *env, std::vector<uint8_t> *buffer, jbyteArray arr, bool auto_size = true)
{
    size_t size = (size_t) (arr ? env->GetArrayLength(arr) : 0);

    if (auto_size)
        buffer->resize(size);
    else if (size < buffer->size())
        memset(&(*buffer)[size], 0, buffer->size()-size);

    if (size)
        env->GetByteArrayRegion(arr, 0, std::min(size, buffer->size()), (jbyte*)&(*buffer)[0]);
}

static void jni2bytes(JNIEnv *env, StaticBuffer *buffer, jbyteArray arr, size_t bsize)
{
    size_t size = (size_t) (arr ? env->GetArrayLength(arr) : 0);
    if (bsize == StaticBuffer::AUTO_SIZE)
        bsize = size;

    buffer->allocate(bsize);

    if (size < buffer->size())
        memset(buffer->writable_data(), 0, buffer->size()-size);

    if (size)
        env->GetByteArrayRegion(arr, 0, std::min(size, buffer->size()), (jbyte*)buffer->data());
}

static void printGLString(const char *name, GLenum s) {
    const char *v = (const char *) glGetString(s);
    cout << "GL " << name << " = " << v << endl;
}

bool setupGraphics(int w, int h) {
    printGLString("Version", GL_VERSION);
    printGLString("Vendor", GL_VENDOR);
    printGLString("Renderer", GL_RENDERER);
    printGLString("Extensions", GL_EXTENSIONS);
    return true;
}

void renderFrame() {
    static float grey;
    grey += 0.01f;
    if (grey > 1.0f) {
        grey = 0.0f;
    }
    glClearColor(grey, grey, grey, 1.0f);
    glClear( GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT);
}

#include "JniNatives.inc"
#include "font/Headers.h"

#define NATIVE(type) extern "C" JNIEXPORT type JNICALL

static jclass cFlowRunnerWrapper = NULL;
static jclass cRuntimeException = NULL;
static jclass cIllegalStateException = NULL;

static jfieldID c_ptr_field = NULL;

#define CALLBACKS \
    CALLBACK(cbNeedsRepaint, "()V") \
    CALLBACK(cbRunnerError, "()V") \
    CALLBACK(cbRunnerReset, "()V") \
    CALLBACK(cbNewTimer, "(II)V") \
    CALLBACK(cbLoadPicture, "(Ljava/lang/String;[Ljava/lang/String;Z)V") \
    CALLBACK(cbAbortPictureLoading, "(Ljava/lang/String;)V") \
    CALLBACK(cbBindTextureBitmap, "(Landroid/graphics/Bitmap;)V") \
    CALLBACK(cbBrowseUrl, "(Ljava/lang/String;Ljava/lang/String;)V") \
    CALLBACK(cbLoadAssetData, "(Ljava/lang/String;)[B") \
    CALLBACK(cbDestroyWidget, "(J)V") \
    CALLBACK(cbResizeWidget, "(JZFFFFFF)V") \
    CALLBACK(cbCreateTextWidget, "(JLjava/lang/String;Ljava/lang/String;FIZZFLjava/lang/String;Ljava/lang/String;IIII)V") \
    CALLBACK(cbCreateVideoWidget, "(JLjava/lang/String;[Ljava/lang/String;ZZIF)V") \
    CALLBACK(cbCreateVideoWidgetFromMediaStream, "(JLdk/area9/flowrunner/FlowMediaStreamSupport$FlowMediaStreamObject;)V") \
    CALLBACK(cbUpdateVideoPlay, "(JZ)V") \
    CALLBACK(cbUpdateVideoPosition, "(JJ)V") \
    CALLBACK(cbUpdateVideoVolume, "(JF)V") \
    CALLBACK(cbCreateWebWidget, "(JLjava/lang/String;)V") \
    CALLBACK(cbWebClipHostCall, "(JLjava/lang/String;)V") \
    CALLBACK(cbSetWebClipZoomable, "(JZ)V") \
    CALLBACK(cbSetWebClipDomains, "(J[Ljava/lang/String;)V") \
    CALLBACK(cbStartHttpRequest, "(ILjava/lang/String;Ljava/lang/String;[Ljava/lang/String;[B)V") \
    CALLBACK(cbStartMediaPreload, "(ILjava/lang/String;)V") \
    CALLBACK(cbRemoveUrlFromCache, "(Ljava/lang/String;)V") \
    CALLBACK(cbBeginLoadSound, "(JLjava/lang/String;)V") \
    CALLBACK(cbBeginPlaySound, "(JLjava/lang/String;FZ)V") \
    CALLBACK(cbStopSound, "(J)V") \
    CALLBACK(cbSetSoundVolume, "(JF)V") \
    CALLBACK(cbGetSoundPosition, "(J)F") \
    CALLBACK(cbGetSoundLength, "(Ljava/lang/String;)F") \
    CALLBACK(cbGetNumberOfCameras, "()I") \
    CALLBACK(cbGetCameraInfo, "(I)Ljava/lang/String;") \
    CALLBACK(cbOpenCameraAppPhotoMode, "(ILjava/lang/String;IIILjava/lang/String;I)V") \
    CALLBACK(cbOpenCameraAppVideoMode, "(ILjava/lang/String;IIILjava/lang/String;)V") \
    CALLBACK(cbStartRecordAudio, "(Ljava/lang/String;Ljava/lang/String;I)V") \
    CALLBACK(cbStopRecordAudio, "()V") \
    CALLBACK(cbTakeAudioRecord, "()V") \
    CALLBACK(cbCreateCameraWidget, "(JIIIII)V") \
    CALLBACK(cbUpdateCameraWidget, "(JLjava/lang/String;Z)V") \
    CALLBACK(cbLoadSystemFont, "([FLjava/lang/String;I)Z") \
    CALLBACK(cbLoadSystemGlyph, "([FLjava/lang/String;[CIF)[I") \
    CALLBACK(cbSetInterfaceOrientation, "(Ljava/lang/String;)V") \
    CALLBACK(cbLoadPurchaseProductInfo, "([Ljava/lang/String;)V") \
    CALLBACK(cbPaymentRequest, "(Ljava/lang/String;I)V") \
    CALLBACK(cbRestorePaymentRequest, "()V") \
    CALLBACK(cbTagLocalyticsEventWithAttributes, "(Ljava/lang/String;[Ljava/lang/String;)V") \
    CALLBACK(cbHasPermissionLocalNotification, "()Z") \
    CALLBACK(cbRequestPermissionLocalNotification, "(I)V") \
    CALLBACK(cbScheduleLocalNotification, "(DILjava/lang/String;Ljava/lang/String;Ljava/lang/String;ZZ)V") \
    CALLBACK(cbCancelLocalNotification, "(I)V") \
    CALLBACK(cbGetFBToken, "(I)V") \
    CALLBACK(cbSubscribeToFBTopic, "(Ljava/lang/String;)V") \
    CALLBACK(cbUnsubscribeFromFBTopic, "(Ljava/lang/String;)V") \
    CALLBACK(cbGeolocationGetCurrentPosition, "(IZDDLjava/lang/String;Ljava/lang/String;Ljava/lang/String;)V") \
    CALLBACK(cbGeolocationWatchPosition, "(IZDDLjava/lang/String;Ljava/lang/String;Ljava/lang/String;)V") \
    CALLBACK(cbGeolocationAfterWatchDispose, "(I)V") \
    CALLBACK(cbDeleteAppCookies, "()V") \
    CALLBACK(cbUsesNativeVideo, "()Z") \
    CALLBACK(cbDeviceInfoUpdated, "(I)V") \
    CALLBACK(cbGetAudioDevices, "(I)V") \
    CALLBACK(cbGetVideoDevices, "(I)V") \
    CALLBACK(cbMakeMediaStream, "(ZZLjava/lang/String;Ljava/lang/String;II)V") \
    CALLBACK(cbStopMediaStream, "(Ldk/area9/flowrunner/FlowMediaStreamSupport$FlowMediaStreamObject;)V") \
    CALLBACK(cbMakeMediaSender, "(Ljava/lang/String;Ljava/lang/String;[Ljava/lang/String;[[Ljava/lang/String;Ldk/area9/flowrunner/FlowMediaStreamSupport$FlowMediaStreamObject;IIII)V") \
    CALLBACK(cbStopMediaSender, "(Ldk/area9/flowrunner/FlowWebRTCSupport$FlowMediaSenderObject;)V") \
    CALLBACK(cbMakeMediaRecorder, "(Ljava/lang/String;Ljava/lang/String;Ldk/area9/flowrunner/FlowMediaStreamSupport$FlowMediaStreamObject;III)V") \
    CALLBACK(cbStartMediaRecorder, "(Ldk/area9/flowrunner/FlowMediaRecorderSupport$FlowMediaRecorderObject;)V") \
    CALLBACK(cbResumeMediaRecorder, "(Ldk/area9/flowrunner/FlowMediaRecorderSupport$FlowMediaRecorderObject;)V") \
    CALLBACK(cbPauseMediaRecorder, "(Ldk/area9/flowrunner/FlowMediaRecorderSupport$FlowMediaRecorderObject;)V") \
    CALLBACK(cbStopMediaRecorder, "(Ldk/area9/flowrunner/FlowMediaRecorderSupport$FlowMediaRecorderObject;)V") \
	CALLBACK(cbSystemDownloadFile, "(Ljava/lang/String;)V") \
	CALLBACK(cbOpenWSClient, "(Ljava/lang/String;I)Lorg/java_websocket/client/WebSocketClient;") \
	CALLBACK(cbHasBufferedDataWSClient, "(Lorg/java_websocket/client/WebSocketClient;)Z") \
	CALLBACK(cbSendMessageWSClient, "(Lorg/java_websocket/client/WebSocketClient;Ljava/lang/String;)Z") \
	CALLBACK(cbCloseWSClient, "(Lorg/java_websocket/client/WebSocketClient;ILjava/lang/String;)V") \
	CALLBACK(cbOpenFileDialog, "(I[Ljava/lang/String;I)V") \
	CALLBACK(cbGetFileType, "(Ljava/lang/String;)Ljava/lang/String;") \
	CALLBACK(cbPrintHTML, "(Ljava/lang/String;)V") \
	CALLBACK(cbPrintURL, "(Ljava/lang/String;)V") \
	CALLBACK(cbShowSoftKeyboard, "()V") \
	CALLBACK(cbHideSoftKeyboard, "()V")

#define CALLBACK(id, type) static jmethodID id = NULL;
CALLBACKS
#undef CALLBACK

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_initLibrary
  (JNIEnv *env, jclass wclass, jboolean logStreams)
{
    jclass cls;

    if (logStreams) {
        cout.rdbuf(log_info.rdbuf());
        cout.unsetf(std::ios_base::unitbuf);
        cout << "cout redirected to log" << endl;

        cerr.rdbuf(log_error.rdbuf());
        cerr.unsetf(std::ios_base::unitbuf);
        cerr << "cerr redirected to log" << endl;
    }

#define CHECK(name) if (!name) { log_error << #name " init failed" << endl; goto error; }

    // Init fields
    cls = env->FindClass("java/lang/String");
    if (cls)
        cString = (jclass)env->NewGlobalRef(cls);
    CHECK(cString);

    cls = env->FindClass("java/lang/RuntimeException");
    if (cls)
        cRuntimeException = (jclass)env->NewGlobalRef(cls);
    CHECK(cRuntimeException);

    cls = env->FindClass("java/lang/IllegalStateException");
    if (cls)
        cIllegalStateException = (jclass)env->NewGlobalRef(cls);
    CHECK(cIllegalStateException);

    cFlowRunnerWrapper = (jclass)env->NewGlobalRef(wclass);
    CHECK(cFlowRunnerWrapper);

    c_ptr_field = env->GetFieldID(wclass, "c_ptr", "J");
    CHECK(c_ptr_field);

#define CALLBACK(name, type) \
    name = env->GetMethodID(wclass, #name, type); CHECK(name);
CALLBACKS
#undef CALLBACK

#undef CHECK

    if (logStreams)
        cout << "FlowRunnerWrapper.initLibrary ok" << endl;
    return;

error:
    if (env->ExceptionCheck()) return;
    if (cRuntimeException)
        env->ThrowNew(cRuntimeException, "FlowRunnerWrapper JNI init failed");
    else
        abort(); // completely screwed for some reason
}

#define WRAPPER(expr) { AndroidRunnerWrapper::REF _ref(env,obj,ptr); _ref->expr; }
#define WRAPPER_RET(expr) { AndroidRunnerWrapper::REF _ref(env,obj,ptr); return _ref->expr; }

namespace {
    struct FlushDeferred {
        AndroidRunnerWrapper::REF &ref;
        FlushDeferred(AndroidRunnerWrapper::REF &ref) : ref(ref) {}
        ~FlushDeferred() {
            if (ref.isTopmost())
                ref->getRunner()->RunDeferredActions();
        }
    };
}

#define WRAPPER_FLUSH(expr) { \
    AndroidRunnerWrapper::REF _ref(env,obj,ptr); \
    FlushDeferred _flush(_ref); \
    _ref->expr; \
  }

#define WRAPPER_RET_FLUSH(expr) { \
    AndroidRunnerWrapper::REF _ref(env,obj,ptr); \
    FlushDeferred _flush(_ref); \
    return _ref->expr; \
  }

AndroidRunnerWrapper::REF::REF(JNIEnv *env, jobject owner, jlong lv)
    : p((AndroidRunnerWrapper*)lv)
{
    topmost = (p->env == NULL);
    if (topmost) {
        p->env = env;
        p->owner = owner;
    }
}

AndroidRunnerWrapper::REF::~REF() {
    if (topmost) {
        p->env = NULL;
        p->owner = NULL;
    }
}

NATIVE(jlong) Java_dk_area9_flowrunner_FlowRunnerWrapper_allocBackend
  (JNIEnv *env, jobject obj)
{
#ifdef ANDROID_GPROF
    monstartup("libflowrunner.so");
#endif

    return (jlong)new AndroidRunnerWrapper(env, obj);
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_deleteBackend
  (JNIEnv *env, jobject obj, jlong ptr)
{
    AndroidRunnerWrapper *ref = (AndroidRunnerWrapper*)ptr;

    if (ref) {
        if (ref->getEnv()) {
            env->ThrowNew(cIllegalStateException, "Attempt to destroy FlowRunnerWrapper from a callback");
            return;
        }

        AndroidRunnerWrapper::destroy(env, obj, ref);

#ifdef ANDROID_GPROF
        moncleanup();
        exit(0);
#endif
    }
}


NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nSetTmpPath
  (JNIEnv *env, jobject obj, jlong ptr, jstring path)
{
    WRAPPER(setTmpPath(path));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nSetStorePath
  (JNIEnv *env, jobject obj, jlong ptr, jstring path)
{
    WRAPPER(setStorePath(path));
}


NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nReset
  (JNIEnv *env, jobject obj, jlong ptr)
{
    WRAPPER(reset());
}


NATIVE(jboolean) Java_dk_area9_flowrunner_FlowRunnerWrapper_nLoadBytecode
  (JNIEnv *env, jobject obj, jlong ptr, jstring fname)
{
    WRAPPER_RET(loadBytecode(fname));
}

NATIVE(jboolean) JNICALL Java_dk_area9_flowrunner_FlowRunnerWrapper_nLoadBytecodeData
  (JNIEnv *env, jobject obj, jlong ptr, jbyteArray data)
{
    WRAPPER_RET(loadBytecodeData(data));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nSetDPI
  (JNIEnv *env, jobject obj, jlong ptr, jint dpi)
{
    WRAPPER(getRenderer()->setDPI(dpi));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nSetDensity
        (JNIEnv *env, jobject obj, jlong ptr, jfloat density)
{
    WRAPPER(getRenderer()->setDensity(density));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nSetScreenWidthHeight
  (JNIEnv *env, jobject obj, jlong ptr, jint width, jint height)
{
    WRAPPER(getRenderer()->setScreenWidthHeight(width, height));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nSetUrlParameters
  (JNIEnv *env, jobject obj, jlong ptr, jstring url, jobjectArray data)
{
    WRAPPER(setUrlParameters(url, data));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nSetFlowTimeProfile
  (JNIEnv *env, jobject obj, jlong ptr, jboolean flow_time_profile, jshort flow_time_profile_trace_per)
{
    WRAPPER(setFlowTimeProfile(flow_time_profile, flow_time_profile_trace_per));
}

NATIVE(jboolean) JNICALL Java_dk_area9_flowrunner_FlowRunnerWrapper_nRunMain
  (JNIEnv *env, jobject obj, jlong ptr)
{
    WRAPPER_RET(runMain());
}

NATIVE(jstring) Java_dk_area9_flowrunner_FlowRunnerWrapper_nGetRunnerError
  (JNIEnv *env, jobject obj, jlong ptr)
{
    WRAPPER_RET(getRunnerError());
}

NATIVE(jstring) Java_dk_area9_flowrunner_FlowRunnerWrapper_nGetRunnerErrorInfo
  (JNIEnv *env, jobject obj, jlong ptr)
{
    WRAPPER_RET(getRunnerErrorInfo());
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nAttachFontFile
  (JNIEnv *env, jobject obj, jlong ptr, jstring name, jobjectArray aliases, jboolean def)
{
    WRAPPER(getRenderer()->attachFont(name, aliases, def));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nRendererInit
  (JNIEnv *env, jobject obj, jlong ptr)
{
    printGLString("Version", GL_VERSION);
    printGLString("Vendor", GL_VENDOR);
    printGLString("Renderer", GL_RENDERER);
    printGLString("Extensions", GL_EXTENSIONS);

    WRAPPER(getRenderer()->init());
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nRendererResize
  (JNIEnv *env, jobject obj, jlong ptr, jint w, jint h)
{
    WRAPPER(getRenderer()->resize(w, h));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nRendererPaint
  (JNIEnv *env, jobject obj, jlong ptr)
{
    WRAPPER(getRenderer()->paint());
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverTimer
  (JNIEnv *env, jobject obj, jlong ptr, jint id)
{
    WRAPPER(getRenderer()->deliverTimer(id));
}

NATIVE(jboolean) Java_dk_area9_flowrunner_FlowRunnerWrapper_nResolvePictureBitmap
  (JNIEnv *env, jobject obj, jlong ptr, jstring url, jobject bmp, jint w, jint h)
{
    WRAPPER_RET_FLUSH(getRenderer()->resolvePictureBitmap(url, bmp, w, h));
}

NATIVE(jboolean) Java_dk_area9_flowrunner_FlowRunnerWrapper_nResolvePictureError
  (JNIEnv *env, jobject obj, jlong ptr, jstring url, jstring error)
{
    WRAPPER_RET_FLUSH(getRenderer()->resolvePictureError(url, error));
}

NATIVE(jboolean) Java_dk_area9_flowrunner_FlowRunnerWrapper_nResolvePictureBitmapFile
  (JNIEnv *env, jobject obj, jlong ptr, jstring url, jstring filename)
{
    WRAPPER_RET_FLUSH(getRenderer()->resolvePictureFile(url, filename));
}

NATIVE(jboolean) Java_dk_area9_flowrunner_FlowRunnerWrapper_nResolvePictureBitmapData
  (JNIEnv *env, jobject obj, jlong ptr, jstring url, jbyteArray data)
{
    WRAPPER_RET_FLUSH(getRenderer()->resolvePictureData(url, data));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverHttpError
  (JNIEnv *env, jobject obj, jlong ptr, jint id, jbyteArray data)
{
    WRAPPER_FLUSH(getHttp()->deliverError(id, data));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverHttpResponse
        (JNIEnv *env, jobject obj, jlong ptr, jint id, jint status, jobjectArray headers)
{
    AbstractHttpSupport::HeadersMap headersMap;
    jni2unicode_map(env, &headersMap, headers);
    WRAPPER_FLUSH(getHttp()->deliverResponse(id, status, headersMap));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverHttpData
  (JNIEnv *env, jobject obj, jlong ptr, jint id, jbyteArray data, jboolean last)
{
    WRAPPER_FLUSH(getHttp()->deliverData(id, data, last));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverHttpProgress
  (JNIEnv *env, jobject obj, jlong ptr, jint id, jfloat loaded, jfloat total)
{
    WRAPPER_FLUSH(getHttp()->deliverProgress(id, loaded, total));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverHttpStatus
  (JNIEnv *env, jobject obj, jlong ptr, jint id, jint status)
{
    WRAPPER_FLUSH(getHttp()->deliverStatus(id, status));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverMouseEvent
  (JNIEnv *env, jobject obj, jlong ptr, jint type, jint x, jint y)
{
    WRAPPER(getRenderer()->deliverMouseEvent(type, x, y));
}

NATIVE(jboolean) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverGestureEvent
  (JNIEnv *env, jobject obj, jlong ptr, jint type, jint state, jfloat p1, jfloat p2, jfloat p3, jfloat p4)
{
    WRAPPER_RET(getRenderer()->deliverGestureEvent(FlowEvent(type), FlowGestureState(state), p1, p2, p3, p4));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nAdjustGlobalScale
  (JNIEnv *env, jobject obj, jlong ptr, jfloat dx, jfloat dy, jfloat cx, jfloat cy, jfloat fct)
{
    WRAPPER(getRenderer()->adjustScale(dx, dy, cx, cy, fct));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverEditStateUpdate
  (JNIEnv *env, jobject obj, jlong ptr, jlong id, jint cursor, jint sel_start, jint sel_end, jstring text)
{
    WRAPPER(getRenderer()->deliverEditStateUpdate(id, cursor, sel_start, sel_end, text));
}

NATIVE(jstring) Java_dk_area9_flowrunner_FlowRunnerWrapper_nTextIsAcceptedByFlowFilters
  (JNIEnv *env, jobject obj, jlong ptr, jlong id, jstring text)
{
    WRAPPER_RET(getRenderer()->textIsAcceptedByFlowFilters(id, text));
}

NATIVE(jboolean) Java_dk_area9_flowrunner_FlowRunnerWrapper_nKeyEventFilteredByFlowFilters
  (JNIEnv *env, jobject obj, jlong ptr, jlong id, jint event, jstring key, jboolean ctrl,
    jboolean shift, jboolean alt, jboolean meta, jint code)
{
    WRAPPER_RET(
        getRenderer()->keyEventFilteredByFlowFilters(
            id,
            event,
            key,
            ctrl,
            shift,
            alt,
            meta,
            code
        )
    );
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverVideoNotFound
  (JNIEnv *env, jobject obj, jlong ptr, jlong id)
{
    WRAPPER_FLUSH(getRenderer()->deliverVideoNotFound(id));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverVideoSize
  (JNIEnv *env, jobject obj, jlong ptr, jlong id, jint width, jint height)
{
    WRAPPER(getRenderer()->deliverVideoSize(id, width, height));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverVideoDuration
  (JNIEnv *env, jobject obj, jlong ptr, jlong id, jlong length)
{
    WRAPPER(getRenderer()->deliverVideoDuration(id, length));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverVideoPosition
        (JNIEnv *env, jobject obj, jlong ptr, jlong id, jlong position)
{
    WRAPPER(getRenderer()->deliverVideoPosition(id, position));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverVideoPlayStatus
  (JNIEnv *env, jobject obj, jlong ptr, jlong id, jint event)
{
    WRAPPER(getRenderer()->deliverVideoPlayStatus(id, event));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nSetVideoExternalTextureId
  (JNIEnv *env, jobject obj, jlong ptr, jlong id, jint texture_id)
{
    WRAPPER(getRenderer()->setVideoExternalTextureId(id, texture_id));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverCameraError
  (JNIEnv *env, jobject obj, jlong ptr, jlong id)
{
    WRAPPER_FLUSH(getRenderer()->deliverCameraError(id));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverCameraStatus
  (JNIEnv *env, jobject obj, jlong ptr, jlong id, jint event)
{
	WRAPPER(getRenderer()->deliverCameraStatus(id, event));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nNotifyCameraEvent
  (JNIEnv *env, jobject obj, jlong ptr, jint code, jstring message, jstring additionalInfo, jint width, jint height)
{
    WRAPPER(getRunner()->NotifyCameraEvent(code, jni2string(env, message), jni2string(env, additionalInfo), width, height));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nNotifyCameraEventVideo
  (JNIEnv *env, jobject obj, jlong ptr, jint code, jstring message, jstring additionalInfo, jint width, jint height, jint duration, jint size)
{
    WRAPPER(getRunner()->NotifyCameraEventVideo(code, jni2string(env, message), jni2string(env, additionalInfo), width, height, duration, size));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nNotifyCameraEventAudio
  (JNIEnv *env, jobject obj, jlong ptr, jint code, jstring message, jstring additionalInfo, jint duration, jint size)
{
    WRAPPER(getRunner()->NotifyCameraEventAudio(code, jni2string(env, message), jni2string(env, additionalInfo), duration, size));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverSoundResolveReady
  (JNIEnv *env, jobject obj, jlong ptr, jlong sound)
{
    WRAPPER(getSound()->deliverResolveReady(sound));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverSoundResolveError
  (JNIEnv *env, jobject obj, jlong ptr, jlong sound, jstring msg)
{
    WRAPPER(getSound()->deliverResolveError(sound, msg));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverSoundNotifyDone
  (JNIEnv *env, jobject obj, jlong ptr, jlong channel)
{
    WRAPPER(getSound()->deliverNotifyDone(channel));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nCallFlowFromWebView
  (JNIEnv *env, jobject obj, jlong ptr, jlong id, jobjectArray args)
{
	WRAPPER(getRenderer()->callFlowFromWebView(id, args));
}

NATIVE(jboolean) Java_dk_area9_flowrunner_FlowRunnerWrapper_nNotifyPlatformEvent
  (JNIEnv *env, jobject obj, jlong ptr, jint event)
{
	WRAPPER_RET(getRunner()->NotifyPlatformEvent((PlatformEvent)event));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nNotifyCustomFileTypeOpened
  (JNIEnv *env, jobject obj, jlong ptr, jstring path)
{
	WRAPPER(getRunner()->NotifyCustomFileTypeOpened(jni2unicode(env, path)));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nNotifyWebViewLoaded
  (JNIEnv *env, jobject obj, jlong ptr, jlong clip_id)
{
	WRAPPER(getRenderer()->notifyPageLoaded(clip_id));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nNotifyWebViewError
  (JNIEnv *env, jobject obj, jlong ptr, jlong clip_id, jstring msg)
{
	WRAPPER(getRenderer()->notifyPageError(clip_id, msg));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDispatchKeyEvent
  (JNIEnv *env, jobject obj, jlong ptr, jint event, jstring key,
		  jboolean ctrl, jboolean shift, jboolean alt, jboolean meta, jint code)
{
	WRAPPER(getRenderer()->deliverKeyEvent((FlowEvent)event, jni2unicode(env, key), ctrl, shift, alt, meta, (FlowKeyCode)code));
}

NATIVE(jobjectArray) Java_dk_area9_flowrunner_FlowRunnerWrapper_nFetchAccessibleClips
  (JNIEnv *env, jobject obj, jlong ptr)
{
	WRAPPER_RET(getRenderer()->fetchAccessibleClips());
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nCallbackPurchaseProduct
  (JNIEnv *env, jobject obj, jlong ptr, jstring _id, jstring title, jstring description, jdouble price, jstring priceLocale)
{
    WRAPPER(getInAppPurchase()->callbackProduct(jni2unicode(env, _id), jni2unicode(env, title), jni2unicode(env, description), price, jni2unicode(env, priceLocale)));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nCallbackPurchasePayment
  (JNIEnv *env, jobject obj, jlong ptr, jstring _id, jstring status, jstring errorMsg)
{
    WRAPPER(getInAppPurchase()->callbackPayment(jni2unicode(env, _id), jni2unicode(env, status), jni2unicode(env, errorMsg)));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nCallbackPurchaseRestore
  (JNIEnv *env, jobject obj, jlong ptr, jstring _id, jint quantity, jstring errorMsg)
{
    WRAPPER(getInAppPurchase()->callbackRestore(jni2unicode(env, _id), quantity, jni2unicode(env, errorMsg)));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nRequestPermissionLocalNotificationResult
  (JNIEnv *env, jobject obj, jlong ptr, jboolean result, jint cb_root)
{
    WRAPPER(getNotifications()->executeRequestPermissionLocalNotificationCallback(result, cb_root));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nExecuteNotificationCallbacks
  (JNIEnv *env, jobject obj, jlong ptr, jint notificationId, jstring notificationCallbackArgs)
{
    WRAPPER(getNotifications()->executeNotificationCallbacks(notificationId, jni2string(env, notificationCallbackArgs)));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverFBMessage
  (JNIEnv *env, jobject obj, jlong ptr, jstring id, jstring body, jstring title, jstring from, jlong stamp, jobjectArray data)
{
    STL_HASH_MAP<unicode_string, unicode_string> dataMap;
    jni2unicode_map(env, &dataMap, data);

    WRAPPER(getNotifications()->deliverFBMessage(
        jni2unicode(env, id),
        jni2unicode(env, body),
        jni2unicode(env, title),
        jni2unicode(env, from),
        stamp,
        dataMap
    ));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverFBToken
   (JNIEnv *env, jobject obj, jlong ptr, jstring token)
 {
     WRAPPER(getNotifications()->deliverFBToken(jni2unicode(env, token)));
 }

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverFBTokenTo
   (JNIEnv *env, jobject obj, jlong ptr, jint cb_root, jstring token)
 {
     WRAPPER(getNotifications()->deliverFBTokenTo(cb_root, jni2unicode(env, token)));
 }

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nGeolocationExecuteOnOkCallback
  (JNIEnv *env, jobject obj, jlong ptr, jint callbacksRoot, jboolean removeAfterCall, jdouble latitude, jdouble longitude, jdouble altitude,
   jdouble accuracy, jdouble altitudeAccuracy, jdouble heading, jdouble speed, jdouble time)
{
    WRAPPER(getGeolocation()->executeOnOkCallback(callbacksRoot, removeAfterCall, latitude, longitude, altitude, accuracy,
                                                             altitudeAccuracy, heading, speed, time));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nGeolocationExecuteOnErrorCallback
  (JNIEnv *env, jobject obj, jlong ptr, jint callbacksRoot, jboolean removeAfterCall, jint code, jstring message)
{
    WRAPPER(getGeolocation()->executeOnErrorCallback(callbacksRoot, removeAfterCall, code, jni2string(env, message)));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nVirtualKeyboardHeightCallback
        (JNIEnv *env, jobject obj, jlong ptr, jdouble height)
{
    WRAPPER(getRenderer()->deliverVirtualKeyboardCallbacks(height));
}

NATIVE(bool) Java_dk_area9_flowrunner_FlowRunnerWrapper_nIsVirtualKeyboardListenerAttached
        (JNIEnv *env, jobject obj, jlong ptr)
{
    WRAPPER_RET(getRenderer()->deliverIsVirtualKeyboardListenerAttached());
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeviceInfoUpdated
        (JNIEnv *env, jobject obj, jlong ptr, jint cb_root)
{
    WRAPPER(getMediaStream()->deliverInitializeDeviceInfoCallback(cb_root));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nGetMediaDevices
        (JNIEnv *env, jobject obj, jlong ptr, jint cb_root, jobjectArray ids, jobjectArray names)
{
    WRAPPER(getMediaStream()->deliverDevices(cb_root, ids, names));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nOnMediaStreamReady
        (JNIEnv *env, jobject obj, jlong ptr, jint cb_root, jobject mediaStream)
{
    WRAPPER(getMediaStream()->deliverMediaStream(cb_root, mediaStream));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nOnMediaSenderReady
        (JNIEnv *env, jobject obj, jlong ptr, jint cb_root, jobject sender)
{
    WRAPPER(getWebRTCSupport()->deliverOnMediaSenderReadyCallback(cb_root, sender));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nOnMediaSenderNewParticipant
        (JNIEnv *env, jobject obj, jlong ptr, jint cb_root, jstring id, jobject mediaStream)
{
    WRAPPER(getWebRTCSupport()->deliverOnNewParticipantCallback(cb_root, id, mediaStream));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nOnMediaSenderParticipantLeave
        (JNIEnv *env, jobject obj, jlong ptr, jint cb_root, jstring id)
{
    WRAPPER(getWebRTCSupport()->deliverOnParticipantLeaveCallback(cb_root, id));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nOnMediaSenderError
        (JNIEnv *env, jobject obj, jlong ptr, jint cb_root, jstring error)
{
    WRAPPER(getWebRTCSupport()->deliverOnErrorCallback(cb_root, error));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nOnRecorderReady
        (JNIEnv *env, jobject obj, jlong ptr, jint cb_root, jobject recorder)
{
    WRAPPER(getMediaRecorder()->deliverMediaRecorder(cb_root, recorder));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nOnRecorderError
        (JNIEnv *env, jobject obj, jlong ptr, jint cb_root, jstring error)
{
    WRAPPER(getMediaRecorder()->deliverError(cb_root, error));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverWebSocketOnClose
        (JNIEnv *env, jobject obj, jlong ptr, jint callbacksKey, jint closeCode, jstring reason, jboolean wasClean)
{
    WRAPPER(getWebSockets()->deliverOnClose(callbacksKey, closeCode, reason, wasClean));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverWebSocketOnError
        (JNIEnv *env, jobject obj, jlong ptr, jint callbacksKey, jstring error)
{
    WRAPPER(getWebSockets()->deliverOnError(callbacksKey, error));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverWebSocketOnMessage
        (JNIEnv *env, jobject obj, jlong ptr, jint callbacksKey, jstring message)
{
    WRAPPER(getWebSockets()->deliverOnMessage(callbacksKey, message));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverWebSocketOnOpen
        (JNIEnv *env, jobject obj, jlong ptr, jint callbacksKey)
{
    WRAPPER(getWebSockets()->deliverOnOpen(callbacksKey));
}

NATIVE(void) Java_dk_area9_flowrunner_FlowRunnerWrapper_nDeliverOpenFileDialogResult
        (JNIEnv *env, jobject obj, jlong ptr, jint callbackRoot, jobjectArray filePaths)
{
    WRAPPER(getFSInterface()->deliverOpenFileDialogCallback(callbackRoot, filePaths));
}

AndroidRunnerWrapper::AndroidRunnerWrapper(JNIEnv *env, jobject owner_obj)
    : env(env), owner(owner_obj),
      runner(), renderer(this), http(this), sound(this), localytics(this), purchase(this), notifications(this), store(&runner),
      geolocation(this), fsinterface(this), printing(this), mediaStream(this), webrtcSupport(this), mediaRecorder(this), websockets(this)
{
    bytecode_ok = main_ok = false;
    flow_time_profiling_enabled = false;
    // Reset the context back to free
    this->env = NULL;
    this->owner = NULL;
}

AndroidRunnerWrapper::~AndroidRunnerWrapper()
{
}

void AndroidRunnerWrapper::reset()
{
    runner.Init(NULL, 0);

    bytecode_ok = main_ok = false;
}

void AndroidRunnerWrapper::setStorePath(jstring fname)
{
    store.SetBasePath(jni2string(env, fname));
}

void AndroidRunnerWrapper::setTmpPath(jstring fname)
{
    temp_file_path = jni2string(env, fname);
}

jboolean AndroidRunnerWrapper::loadBytecode(jstring fname)
{
    std::string sfname = jni2string(env, fname);

    runner.Init(sfname);

    return finishLoadBytecode();
}

NativeProgram *load_native_program();

jboolean AndroidRunnerWrapper::loadBytecodeData(jbyteArray data)
{
#ifdef ANDROID_FLOWGEN
    runner.Init(load_native_program());
#else
    std::vector<uint8_t> dbytes;
    jni2bytes(env, &dbytes, data);

    runner.Init((char*)dbytes.data(), dbytes.size());
#endif

    return finishLoadBytecode();
}

jboolean AndroidRunnerWrapper::finishLoadBytecode()
{
    bytecode_ok = main_ok = false;

    if (runner.IsErrorReported() || runner.CodeSize() == 0) {
        log_error << "Failed to load bytecode" << endl;
        return (jboolean) false;
    }

    return (jboolean) (bytecode_ok = true);
}

jboolean AndroidRunnerWrapper::runMain()
{
    if (runner.IsErrorReported())
        return (jboolean) false;

    if (main_ok)
        return (jboolean) true;

    if (flow_time_profiling_enabled)
        runner.BeginTimeProfile("/sdcard/flowprof-android.time", (unsigned) flow_time_profile_trace_per);

    STL_HASH_MAP<unicode_string, unicode_string> & params = runner.getUrlParameterMap();
    //params[parseUtf8("source")] = parseUtf8("nejm_knowledge");
    //params[parseUtf8("prod")] = parseUtf8("IM");
    runner.RunMain();
    return (jboolean) (main_ok = !runner.IsErrorReported());
}

jstring AndroidRunnerWrapper::getRunnerError()
{
    if (!runner.IsErrorReported())
        return NULL;

    return string2jni(env, runner.GetLastErrorMsg());
}

jstring AndroidRunnerWrapper::getRunnerErrorInfo()
{
    if (!runner.IsErrorReported())
        return NULL;

    return string2jni(env, runner.GetLastErrorInfo());
}

void AndroidRunnerWrapper::setUrlParameters(jstring url, jobjectArray data)
{
    runner.getUrlString() = jni2unicode(env, url);

    STL_HASH_MAP<unicode_string,unicode_string> &pmap = runner.getUrlParameterMap();

    pmap.clear();

    jni2unicode_map(env, &pmap, data);
}

void AndroidRunnerWrapper::setFlowTimeProfile(jboolean flow_time_profile, jshort flow_time_profile_trace_per)
{
	flow_time_profiling_enabled = (flow_time_profile == JNI_TRUE);
	this->flow_time_profile_trace_per = flow_time_profile_trace_per;
}

bool AndroidRunnerWrapper::eatExceptions(std::string *msg)
{
    jthrowable exc = env->ExceptionOccurred();
    if (!exc) return false;

    env->ExceptionClear();

    {
        std::string my_msg;

        jclass cls = env->GetObjectClass(exc);
        jmethodID id = env->GetMethodID(cls, "toString", "()Ljava/lang/String;");

        if (id) {
            jstring str = (jstring)env->CallObjectMethod(exc, id);
            env->ExceptionClear();

            my_msg = jni2string(env, str);

            env->DeleteLocalRef(str);
        }

        if (msg)
            *msg = my_msg;
        else
            cerr << "Java exception occurred: " << my_msg << endl;

        env->DeleteLocalRef(cls);
    }

    env->DeleteLocalRef(exc);
    return true;
}

void AndroidRunnerWrapper::notifyNeedsRepaint()
{
    env->CallVoidMethod(owner, cbNeedsRepaint);
    eatExceptions();
}

void AndroidRunnerWrapper::notifyError()
{
    env->CallVoidMethod(owner, cbRunnerError);
    eatExceptions();
}

void AndroidRunnerWrapper::notifyRunnerReset()
{
    env->CallVoidMethod(owner, cbRunnerReset);
    eatExceptions();
}

void AndroidRunnerWrapper::notifyBrowseUrl(unicode_string url, unicode_string target)
{
    jstring url_s = string2jni(env, url);
    jstring target_s = string2jni(env, target);

    env->CallVoidMethod(owner, cbBrowseUrl, url_s, target_s);

    env->DeleteLocalRef(url_s);
    env->DeleteLocalRef(target_s);

    eatExceptions();
}

void AndroidRunnerWrapper::notifyNewTimer(int id, int delay)
{
    env->CallVoidMethod(owner, cbNewTimer, id, delay);

    std::string msg;
    if (eatExceptions(&msg))
        runner.ReportError(InvalidCall, "cbNewTimer failed: %s", msg.c_str());
}

void AndroidRunnerWrapper::notifyBindTextureBitmap(jobject bitmap)
{
    env->CallVoidMethod(owner, cbBindTextureBitmap, bitmap);
    eatExceptions();
}

AndroidRenderSupport::AndroidRenderSupport(AndroidRunnerWrapper *owner)
    : GLRenderSupport(&owner->runner), owner(owner)
{
    NoHoverMouse = true;
    next_timer_id = 1;
    setDPI(120);
    setScreenWidthHeight(100.0, 100.0);

#ifndef ANDROID_GPROF
    getFlowRunner()->DeferredQueueTimeout = 0.5;
#endif
}

void AndroidRenderSupport::setDPI(int v)
{
    GLRenderSupport::setDPI(v);

    dpi = v;

    float radius_mm = 0.7f;
    MouseRadius = dpi * (radius_mm / 25.4f);
}

void AndroidRenderSupport::setDensity(float v)
{
    density = v;
}

void AndroidRenderSupport::setScreenWidthHeight(int w, int h) {
	RealWidth = w; RealHeight = h;
	if (isScreenRotated()) {
		Width = RealHeight; Height = RealWidth;
	} else {
		Height = RealHeight; Width = RealWidth;
	}
}

void AndroidRenderSupport::attachFont(jstring file, jobjectArray aliases, jboolean setdef)
{
    JNIEnv *env = owner->env;
    std::string fname = jni2string(env, file);
    std::vector<unicode_string> avector;

    int anum = env->GetArrayLength(aliases);
    for (int i = 0; i < anum; i++) {
        jstring str = (jstring)env->GetObjectArrayElement(aliases, i);
        avector.push_back(jni2unicode(env, str));
        env->DeleteLocalRef(str);
    }

    loadFont(fname, avector, setdef);
}

bool AndroidRenderSupport::loadAssetData(StaticBuffer *buffer, std::string name, size_t size)
{
    JNIEnv *env = owner->env;
    jstring jname = string2jni(env, name);
    jbyteArray arr = (jbyteArray)env->CallObjectMethod(owner->owner, cbLoadAssetData, jname);
    env->DeleteLocalRef(jname);

    if (owner->eatExceptions(NULL) || !arr)
        return false;

    jni2bytes(env, buffer, arr, size);
    env->DeleteLocalRef(arr);
    return true;
}

void AndroidRenderSupport::adjustScale(jfloat dx, jfloat dy, jfloat cx, jfloat cy, jfloat df)
{
    adjustGlobalScale(dx, dy, cx, cy, df);
}

void AndroidRenderSupport::OnHostEvent(HostEvent event)
{
    GLRenderSupport::OnHostEvent(event);

    switch (event) {
    case HostEventError:
        owner->notifyError();
        break;

    case HostEventDeferredActionTimeout:
        // Queue a real timer to ensure a callback after rendering has a chance to happen
        owner->notifyNewTimer(-1, 10);
        break;

    default:
        break;
    }
}

void AndroidRenderSupport::doRequestRedraw()
{
    owner->notifyNeedsRepaint();
}

void AndroidRenderSupport::flowGCObject(GarbageCollectorFn ref)
{
    GLRenderSupport::flowGCObject(ref);
    ref << timers;
}

NativeFunction *AndroidRenderSupport::MakeNativeFunction(const char *name, int num_args)
{
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "Native."

    TRY_USE_NATIVE_METHOD(AndroidRenderSupport, timer, 2);

    TRY_USE_NATIVE_METHOD(AndroidRenderSupport, showSoftKeyboard, 0);
    TRY_USE_NATIVE_METHOD(AndroidRenderSupport, hideSoftKeyboard, 0);

    return GLRenderSupport::MakeNativeFunction(name, num_args);
}

void AndroidRenderSupport::OnRunnerReset(bool inDestructor)
{
    GLRenderSupport::OnRunnerReset(inDestructor);

    timers.clear();

    if (!inDestructor)
        owner->notifyRunnerReset();
}

StackSlot AndroidRenderSupport::timer(RUNNER_ARGS)
{
    RUNNER_PopArgs2(time_ms, cb);
    RUNNER_CheckTag(TInt, time_ms);

    //cout << time_ms.IntValue << endl;

    if (time_ms.GetInt() <= 5) {
        RUNNER->AddDeferredAction(cb);
    } else {
        int id = next_timer_id++;
        timers[id] = cb;

        owner->notifyNewTimer(id, time_ms.GetInt());
    }

    RETVOID;
}

void AndroidRenderSupport::deliverTimer(jint id)
{
    STL_HASH_MAP<int, StackSlot>::iterator it = timers.find(id);

    // Lock deferred, and process the queue after returning.
    // This is kept outside of the if to work in the case of the
    // fake timeout caused by HostEventDeferredActionTimeout.
    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    if (it != timers.end()) {
        StackSlot cb = it->second;
        timers.erase(it);

        getFlowRunner()->EvalFunction(cb, 0);
        getFlowRunner()->NotifyHostEvent(HostEventTimer);
    }
}

StackSlot AndroidRenderSupport::showSoftKeyboard(RUNNER_ARGS)
{
    JNIEnv *env = owner->env;
    env->CallVoidMethod(owner->owner, cbShowSoftKeyboard);
    owner->eatExceptions();
    RETVOID;
}

StackSlot AndroidRenderSupport::hideSoftKeyboard(RUNNER_ARGS)
{
    JNIEnv *env = owner->env;
    env->CallVoidMethod(owner->owner, cbHideSoftKeyboard);
    owner->eatExceptions();
    RETVOID;
}

void AndroidRenderSupport::GetTargetTokens(std::set<std::string> &tokens)
{
    GLRenderSupport::GetTargetTokens(tokens);
    tokens.insert("android");
    tokens.insert("mobile");

    // Get SDK version:
    JNIEnv *env = owner->env;
    // VERSION is a nested class within android.os.Build (hence "$" rather than "/")
    jclass versionClass = env->FindClass("android/os/Build$VERSION" );
    jfieldID sdkIntFieldID = env->GetStaticFieldID(versionClass, "SDK_INT", "I" );
    int sdkInt = env->GetStaticIntField(versionClass, sdkIntFieldID );
    tokens.insert(stl_sprintf("android_api_level=%d", sdkInt));

    tokens.insert(stl_sprintf("dpi=%d", dpi));
    tokens.insert(stl_sprintf("density=%f", density));

  	jboolean native_video = env->CallBooleanMethod(owner->owner, cbUsesNativeVideo);
  	if (native_video) tokens.insert("nativevideo");
}

void AndroidRenderSupport::doOpenUrl(unicode_string url, unicode_string target)
{
    owner->notifyBrowseUrl(url, target);
}

void AndroidRenderSupport::doSetInterfaceOrientation(std::string orientation)
{
    JNIEnv *env = owner->env;
	jstring jorientation = string2jni(env, orientation);

    env->CallVoidMethod(owner->owner, cbSetInterfaceOrientation, jorientation);
}

bool AndroidRenderSupport::loadPicture(unicode_string url, bool cache)
{
    HttpRequest::T_SMap headers = HttpRequest::T_SMap();
    return loadPicture(url, headers, cache);
}

bool AndroidRenderSupport::loadPicture(unicode_string url, HttpRequest::T_SMap& headers, bool cache)
{
    JNIEnv *env = owner->env;

    jstring url_string = string2jni(env, url);
    jobjectArray headers_arr = string_map2jni(env, headers);

    env->CallVoidMethod(owner->owner, cbLoadPicture, url_string, headers_arr, jboolean(cache));
    env->DeleteLocalRef(url_string);
    env->DeleteLocalRef(headers_arr);

    std::string msg;
    if (owner->eatExceptions(&msg))
        GLRenderSupport::resolvePictureError(url, parseUtf8(msg));

    return true;
}

void AndroidRenderSupport::abortPictureLoading(unicode_string url)
{
    JNIEnv *env = owner->env;

    jstring url_string = string2jni(env, url);
    env->CallVoidMethod(owner->owner, cbAbortPictureLoading, url_string);
    env->DeleteLocalRef(url_string);

    std::string msg;
    if (owner->eatExceptions(&msg))
        GLRenderSupport::resolvePictureError(url, parseUtf8(msg));
}

jboolean AndroidRenderSupport::resolvePictureError(jstring url, jstring msg)
{
    JNIEnv *env = owner->env;
    return GLRenderSupport::resolvePictureError(jni2unicode(env, url), jni2unicode(env, msg));
}

void AndroidTextureImage::loadData() {
    owner->notifyBindTextureBitmap(bitmap);
}

AndroidTextureImage::AndroidTextureImage(AndroidRunnerWrapper *owner, ivec2 size, jobject bmp)
    : GLTextureBitmap(size, GL_RGBA, false, false), owner(owner), bitmap(owner->env->NewGlobalRef(bmp))
{
}

AndroidTextureImage::~AndroidTextureImage()
{
    owner->env->DeleteGlobalRef(bitmap);
}

jboolean AndroidRenderSupport::resolvePictureBitmap(jstring url, jobject bitmap, jint w, jint h)
{
    JNIEnv *env = owner->env;
    GLTextureBitmap::Ptr ptr(new AndroidTextureImage(owner, ivec2(w,h), bitmap));
    return (jboolean) resolvePicture(jni2unicode(env, url), ptr);
}

jboolean AndroidRenderSupport::resolvePictureFile(jstring url, jstring filename)
{
    JNIEnv *env = owner->env;
    return (jboolean) resolvePicture(jni2unicode(env, url), jni2string(env, filename));
}

jboolean AndroidRenderSupport::resolvePictureData(jstring url, jbyteArray data)
{
    JNIEnv *env = owner->env;
    std::vector<uint8_t> buffer;
    jni2bytes(env, &buffer, data);
    return (jboolean) resolvePicture(jni2unicode(env, url), buffer.data(), buffer.size());
}

void AndroidRenderSupport::deliverEditStateUpdate(jlong clip, jint cursor, jint sel_start, jint sel_end, jstring text)
{
    unicode_string t_str = jni2unicode(owner->env, text);
    dispatchEditStateUpdate((GLClip*)clip, cursor, sel_start, sel_end, text!=NULL, t_str);
}

jstring AndroidRenderSupport::textIsAcceptedByFlowFilters(jlong clip, jstring text)
{
    unicode_string t_str = jni2unicode(owner->env, text);
    return string2jni(owner->env, ((GLTextClip*)clip)->textFilteredByFlowFilters(t_str));
}

jboolean AndroidRenderSupport::keyEventFilteredByFlowFilters(
    jlong clip, jint event, jstring key, jboolean ctrl,
    jboolean shift, jboolean alt, jboolean meta, jint code)
{
    JNIEnv *env = owner->env;
    FlowKeyEvent keyEvent =
        FlowKeyEvent(
            static_cast<FlowEvent>(event),
            jni2unicode(env, key),
            ctrl,
            shift,
            alt,
            meta,
            static_cast<FlowKeyCode>(code)
        );
    return (jboolean) ((GLTextClip*)clip)->keyEventFilteredByFlowFilters(keyEvent);
}

void AndroidRenderSupport::deliverVideoNotFound(jlong clip_id)
{
    dispatchVideoNotFound((GLClip*)clip_id);
}

void AndroidRenderSupport::deliverVideoSize(jlong clip_id, jint width, jint height)
{
    dispatchVideoSize((GLClip*)clip_id, width, height);
}

void AndroidRenderSupport::deliverVideoDuration(jlong clip_id, jlong duration)
{
    dispatchVideoDuration((GLClip*)clip_id, duration);
}

void AndroidRenderSupport::deliverVideoPosition(jlong clip_id, jlong position)
{
    doRequestRedraw();
    dispatchVideoPosition((GLClip*)clip_id, (int64_t)position);
}

void AndroidRenderSupport::deliverVideoPlayStatus(jlong clip_id, jint event)
{
    dispatchVideoPlayStatus((GLClip*)clip_id, event);
}

void AndroidRenderSupport::setVideoExternalTextureId(jlong clip_id, jint texture_id)
{
	GLVideoClip * clip = (GLVideoClip*)clip_id;
	GLExternalTextureImage::Ptr texture_image = GLExternalTextureImage::Ptr(new GLExternalTextureImage(clip->getSize(), texture_id));
	clip->setVideoTextureImage(texture_image);
}

void AndroidRenderSupport::deliverCameraError(jlong clip_id)
{
    dispatchCameraError((GLClip*)clip_id);
}

void AndroidRenderSupport::deliverCameraStatus(jlong clip_id, jint event)
{
    dispatchCameraStatus((GLClip*)clip_id, event);
}

bool AndroidRenderSupport::doCreateNativeWidget(GLClip* clip, bool neww)
{
    JNIEnv *env = owner->env;

    if (neww)
        env->CallVoidMethod(owner->owner, cbDestroyWidget, (jlong)clip);

    if (GLTextClip *text_clip = flow_native_cast<GLTextClip>(clip)) {
        jstring text = string2jni(env, text_clip->getPlainText());
        jstring font = string2jni(env, text_clip->getFontName());
        jstring inputType = string2jni(env, text_clip->inputType());

        std::string align = "none";
        switch (text_clip->getAlignment()) {
            case GLTextClip::AlignCenter:
                align = "center";
                break;
            case GLTextClip::AlignLeft:
                align = "left";
                break;
            case GLTextClip::AlignRight:
                align = "right";
                break;
            case GLTextClip::AlignNone:
                break;
        }

        jstring alignment = string2jni(env, align);

        env->CallVoidMethod(
            owner->owner, cbCreateTextWidget,
            (jlong)clip, text,
            font, (jfloat)text_clip->getFontSize(),
            (jint)colorToInt(text_clip->getFontColor()),
            (jboolean)text_clip->isMultiline(),
            (jboolean)text_clip->isReadonly(),
            (jfloat)text_clip->getInterlineSpacing(),
            inputType,
            alignment,
            text_clip->getMaxChars(),
            text_clip->getCursorPos(),
            text_clip->getSelectionStart(),
            text_clip->getSelectionEnd()
        );

        env->DeleteLocalRef(text);
        env->DeleteLocalRef(font);

        return !owner->eatExceptions();
    } else if (GLVideoClip *video_clip = flow_native_cast<GLVideoClip>(clip)) {
        if (video_clip->useMediaStream()) {
            AndroidMediaStreamSupport::FlowNativeMediaStream* flowMediaStream = getFlowRunner()->GetNative<AndroidMediaStreamSupport::FlowNativeMediaStream*>(
                getFlowRunner()->LookupRoot(video_clip->getMediaStreamId()));
            env->CallVoidMethod(
                owner->owner, cbCreateVideoWidgetFromMediaStream,
                (jlong)clip,
                flowMediaStream->mediaStream
            );
        } else {
            jstring url = string2jni(env, video_clip->getName());
            jobjectArray headers_arr = string_map2jni(env, video_clip->getHeaders());

            env->CallVoidMethod(
                owner->owner, cbCreateVideoWidget,
                (jlong)clip,
                url,
                headers_arr,
                (jboolean)video_clip->isPlaying(),
                (jboolean)video_clip->isLooping(),
                (jint)video_clip->getControls(),
                (jfloat)video_clip->getVolume()
            );

            env->DeleteLocalRef(url);
            env->DeleteLocalRef(headers_arr);
        }

        if (owner->eatExceptions())
            return false;

        return true;
    } else if (GLWebClip *web_clip = flow_native_cast<GLWebClip>(clip)) {
    	jstring url = string2jni(env, web_clip->getUrl());

    	env->CallVoidMethod(
    		owner->owner, cbCreateWebWidget,
    		(jlong)clip, url
    	);

        return !owner->eatExceptions();
    } else if (GLCamera *camera = flow_native_cast<GLCamera>(clip)) {

    	env->CallVoidMethod(
    		owner->owner, cbCreateCameraWidget,
    		(jlong)clip, (jboolean)neww, (jint)camera->getCamID(),
            (jint)camera->getCamWidth(), (jint)camera->getCamHeight(),
            (jint)camera->getCamFps(), (jint)camera->getRecordMode()
    	);

        return !owner->eatExceptions();
    }

    return false;
}

void AndroidRenderSupport::onTextClipStateChanged(GLTextClip* clip) {
    // Calls configure for already existing widget
    doCreateNativeWidget(clip, false);
}

void AndroidRenderSupport::doDestroyNativeWidget(GLClip *clip)
{
    JNIEnv *env = owner->env;

    env->CallVoidMethod(owner->owner, cbDestroyWidget, (jlong)clip);

    owner->eatExceptions();
}

void AndroidRenderSupport::doReshapeNativeWidget(GLClip *clip, const GLBoundingBox &bbox, float scale, float alpha)
{
    JNIEnv *env = owner->env;

    env->CallVoidMethod(
        owner->owner, cbResizeWidget,
        (jlong)clip, (jboolean)(!bbox.isEmpty && alpha > 0),
        bbox.min_pt.x, bbox.min_pt.y, bbox.max_pt.x, bbox.max_pt.y,
        scale, alpha
    );

    owner->eatExceptions();
}

StackSlot AndroidRenderSupport::webClipHostCall(GLWebClip *clip, const unicode_string &name, const StackSlot &args) {
    JNIEnv *env = owner->env;

    std::stringstream ss;
    getFlowRunner()->PrintData(ss, args);
    std::string args_list = ss.str();
    args_list = args_list.substr(1, args_list.length() - 2); // remove '[' ']'

    env->CallVoidMethod(
        owner->owner, cbWebClipHostCall,
        (jlong)clip, (jstring)string2jni(env, encodeUtf8(name) + "(" + args_list +")")
    );

    owner->eatExceptions();

    RETVOID;
}

StackSlot AndroidRenderSupport::setWebClipZoomable(GLWebClip *clip, const StackSlot &args) {
    JNIEnv *env = owner->env;

    bool zoomable = args.GetBool();

    env->CallVoidMethod(
        owner->owner, cbSetWebClipZoomable,
        (jlong)clip, (jboolean)zoomable);   

    owner->eatExceptions();

    RETVOID;
}

StackSlot AndroidRenderSupport::setWebClipDomains(GLWebClip *clip, const StackSlot &args) {
    JNIEnv *env = owner->env;

    int length = getFlowRunner()->GetArraySize(args);
    jobjectArray domains = env->NewObjectArray(length, cString, NULL);

    for (int i = 0; i < length; i++) {
        jstring domain = string2jni(env, getFlowRunner()->GetString(getFlowRunner()->GetArraySlot(args, i)));

        env->SetObjectArrayElement(domains, i, domain);

        env->DeleteLocalRef(domain);
    }

    env->CallVoidMethod(
        owner->owner, cbSetWebClipDomains,
        (jlong)clip, domains);

    owner->eatExceptions();

    RETVOID;
}

void AndroidRenderSupport::doUpdateVideoPlay(GLVideoClip *video_clip)
{
    owner->env->CallVoidMethod(
            owner->owner, cbUpdateVideoPlay,
            (jlong)video_clip, (jboolean)video_clip->isPlaying()
    );

    owner->eatExceptions();
}

void AndroidRenderSupport::doUpdateVideoPosition(GLVideoClip *video_clip)
{
    owner->env->CallVoidMethod(
            owner->owner, cbUpdateVideoPosition,
            (jlong)video_clip, (jlong)video_clip->getPosition()
    );

    owner->eatExceptions();
}

void AndroidRenderSupport::doUpdateVideoVolume(GLVideoClip *video_clip)
{
    owner->env->CallVoidMethod(
            owner->owner, cbUpdateVideoVolume,
            (jlong)video_clip, video_clip->getVolume()
    );

    owner->eatExceptions();
}

int AndroidRenderSupport::doGetNumberOfCameras()
{
    int cams = owner->env->CallIntMethod(owner->owner, cbGetNumberOfCameras);
    owner->eatExceptions();
    return cams;
}

std::string AndroidRenderSupport::doGetCameraInfo(int id)
{
	jstring info = (jstring) owner->env->CallObjectMethod(owner->owner, cbGetCameraInfo, id);
	const char *js = owner->env->GetStringUTFChars(info, NULL);
	std::string cs(js);
	owner->env->ReleaseStringUTFChars(info, js);

    owner->eatExceptions();
    return cs;
}

void AndroidRenderSupport::doUpdateCameraState(GLCamera *camera)
{
	jstring filename = string2jni(owner->env, camera->getName());

    owner->env->CallVoidMethod(
        owner->owner, cbUpdateCameraWidget,
        (jlong)camera, filename, (jboolean)camera->isRecord()
    );

    owner->eatExceptions();
}

void AndroidRenderSupport::doCameraTakePhoto(int cameraId, std::string additionalInfo, int desiredWidth , int desiredHeight, int compressQuality, std::string fileName, int fitMode)
{
    jstring additionalInfo_str = string2jni(owner->env, additionalInfo);
    jstring fileName_str = string2jni(owner->env, fileName);

    owner->env->CallVoidMethod(owner->owner, cbOpenCameraAppPhotoMode, cameraId, additionalInfo_str, desiredWidth , desiredHeight, compressQuality, fileName_str, fitMode);

    owner->eatExceptions();
}

void AndroidRenderSupport::doCameraTakeVideo(int cameraId, std::string additionalInfo, int duration , int size, int quality, std::string fileName)
{
    jstring additionalInfo_str = string2jni(owner->env, additionalInfo);
    jstring fileName_str = string2jni(owner->env, fileName);

    owner->env->CallVoidMethod(owner->owner, cbOpenCameraAppVideoMode, cameraId, additionalInfo_str, duration , size, quality, fileName_str);

    owner->eatExceptions();
}

void AndroidRenderSupport::doStartRecordAudio(std::string additionalInfo, std::string fileName, int duration)
{
    jstring additionalInfo_str = string2jni(owner->env, additionalInfo);
    jstring fileName_str = string2jni(owner->env, fileName);

    owner->env->CallVoidMethod(owner->owner, cbStartRecordAudio, additionalInfo_str, fileName_str, duration);

    owner->eatExceptions();
}

void AndroidRenderSupport::doStopRecordAudio()
{

    owner->env->CallVoidMethod(owner->owner, cbStopRecordAudio);

    owner->eatExceptions();
}

void AndroidRenderSupport::doTakeAudioRecord()
{

    owner->env->CallVoidMethod(owner->owner, cbTakeAudioRecord);

    owner->eatExceptions();
}

void AndroidRenderSupport::callFlowFromWebView(jlong clip, jobjectArray args)
{
    JNIEnv *env = owner->env;

    int anum = env->GetArrayLength(args);
    RUNNER_VAR = getFlowRunner();
    RUNNER_DefSlots1(arr);
    arr = RUNNER->AllocateArray(anum);

    for (int i = 0; i < anum; i++) {
        jobject obj = env->GetObjectArrayElement(args, i);
        jstring str = (jstring)obj;
        StackSlot s = RUNNER->AllocateString(jni2unicode(env, str));
        RUNNER->SetArraySlot(arr, i, s);
        env->DeleteLocalRef(str);
    }

    dispatchPageCall((GLClip*)clip, arr);
}

void AndroidRenderSupport::notifyPageLoaded(jlong clip)
{
    dispatchPageLoaded((GLClip*)clip);
}

void AndroidRenderSupport::notifyPageError(jlong clip, jstring msg)
{
    std::string msg_str = jni2string(owner->env, msg);
    dispatchPageError((GLClip*)clip, msg_str);
}

bool AndroidRenderSupport::loadSystemFont(FontHeader *header, TextFont textFont)
{
    JNIEnv *env = owner->env;

    std::string fontFamily = textFont.family;
    std::string fontSuffix = textFont.suffix();
    if (fontSuffix.size() != 0) {
        fontFamily = fontFamily + "-" + fontSuffix;
    }

    jfloatArray rvdata = env->NewFloatArray(8);
    jstring jname = string2jni(env, fontFamily);

    header->tile_size = 64;
    header->grid_size = 4;

    jboolean ok = env->CallBooleanMethod(
            owner->owner, cbLoadSystemFont, rvdata, jname, (jint)header->tile_size
    );

    if (!ok || owner->eatExceptions())
        return false;

    jfloat *data = env->GetFloatArrayElements(rvdata, 0);

    header->render_em_size = data[0];
    header->active_tile_size = (header->tile_size-2)/header->render_em_size;

    float coeff = 1.0f / header->render_em_size;

    header->dist_scale = 1 / data[1];

    header->ascender = data[2] * coeff;
    header->descender = data[3] * coeff;
    header->line_height = data[4] * coeff;
    header->max_advance = data[5] * coeff;

    header->underline_position = data[6] * coeff;
    header->underline_thickness = data[7] * coeff;

    env->ReleaseFloatArrayElements(rvdata, data, 0);

    return true;
}

double GetCurrentTime();

bool AndroidRenderSupport::loadSystemGlyph(const FontHeader *header, GlyphHeader *info, StaticBuffer *pixels, TextFont textFont, ucs4_char code)
{
    JNIEnv *env = owner->env;

    std::string fontFamily = textFont.family;
    std::string fontSuffix = textFont.suffix();
    if (fontSuffix.size() != 0) {
        fontFamily = fontFamily + "-" + fontSuffix;
    }

    if (env->PushLocalFrame(10) < 0) {
        cerr << "Cannot allocate local frame for glyph generation" << endl;
    	return false;
    }

    double tv = GetCurrentTime();

    bool isUtf32Glyph = code > 0xFFFF;

    jfloatArray rvdata = env->NewFloatArray(7);
    jstring jname = string2jni(env, fontFamily);

    jcharArray codes = env->NewCharArray(1 + isUtf32Glyph);
    jchar* _codes = env->GetCharArrayElements(codes, 0);
    if (isUtf32Glyph){
        _codes[0] = (jchar)((code - 0x10000) / 0x400 + 0xD800);
        _codes[1] = (jchar)(((code - 0x10000) % 0x400) + 0xDC00);
    } else {
        _codes[0] = code;
    }

    env->SetCharArrayRegion(codes, 0, 1 + isUtf32Glyph, _codes);

    jintArray rvimg = (jintArray)env->CallObjectMethod(
            owner->owner, cbLoadSystemGlyph, rvdata, jname, codes,
            (jint)header->tile_size, (jfloat)header->render_em_size
    );

    env->ReleaseCharArrayElements(codes, _codes, 0);

    if (!rvimg || owner->eatExceptions()) {
        env->PopLocalFrame(NULL);
        return false;
    }

    int imglength = env->GetArrayLength(rvimg);
    int scale = 1;

    for(;;) {
        int ssize = scale * scale * header->tile_size * header->tile_size;
        if (ssize == imglength)
            break;

        if (ssize > imglength)
        {
            cerr << "Invalid character data size: " << imglength << endl;
            env->PopLocalFrame(NULL);
            return false;
        }

        scale++;
    }

    jfloat *data = env->GetFloatArrayElements(rvdata, 0);

    float coeff = 1.0f / header->render_em_size;

    float xoff = data[0];
    float yoff = data[1];

    info->advance = data[2] * coeff;
    info->bearing_x = data[3] * coeff;
    info->bearing_y = data[4] * coeff;
    info->size_x = data[5] * coeff;
    info->size_y = data[6] * coeff;
    info->field_bearing_x = (data[3] - xoff + 1) * coeff;
    info->field_bearing_y = (data[4] - yoff + 1) * coeff;

    env->ReleaseFloatArrayElements(rvdata, data, 0);

    double tv2 = GetCurrentTime();

    if (getFlowRunner()->NotifyStubs)
        cout << "Glyph generated in " << (tv2-tv) << endl;

    jint *img = env->GetIntArrayElements(rvimg, 0);

    std::vector<uint8_t> rgbaBytes(imglength * 4);
    uint8_t* rgbaBuf = rgbaBytes.data();

    bool isGreyGlyph = true;
    for (int i = 0; i < imglength; rgbaBuf += 4, i++) {
        uint32_t pixel = 0;
        memcpy(&pixel, &img[i], 4);
        uint8_t a = uint8_t((pixel & 0xFF000000) >> 24);
        uint8_t r = uint8_t((pixel & 0x00FF0000) >> 16);
        uint8_t g = uint8_t((pixel & 0x0000FF00) >> 8);
        uint8_t b = uint8_t(pixel & 0x000000FF);

        isGreyGlyph = isGreyGlyph && a == r && r == g && g == b;

        rgbaBuf[0] = b;
        rgbaBuf[1] = g;
        rgbaBuf[2] = r;
        rgbaBuf[3] = a;
    }

    info->unicode_char = isGreyGlyph ? 0xD800 : 0x10000;

    if (!isGreyGlyph) {
        pixels->allocate(rgbaBytes.size());
        memcpy(pixels->writable_data(), rgbaBytes.data(), rgbaBytes.size());
    } else {
        std::vector<uint8_t> bytes(imglength);
        uint8_t* buf = bytes.data();

        for (int i = 0; i < imglength; i++)
            buf[i] = uint8_t(rgbaBytes[i*4] & 0xFF);

        smoothFontBitmap(header, pixels, bytes.data(), scale);

        if (getFlowRunner()->NotifyStubs)
            cout << "Glyph smoothed in " << (GetCurrentTime()-tv2) << endl;
    }

    env->ReleaseIntArrayElements(rvimg, img, 0);
    env->PopLocalFrame(NULL);

    return true;
}

jobjectArray AndroidRenderSupport::fetchAccessibleClips() {
    JNIEnv *env = owner->env;

	updateAccessibleClips();
    std::vector<GLClip*> clips = GLRenderSupport::accessible_clips;

    jclass clip_class = env->FindClass("dk/area9/flowrunner/FlowAccessibleClip");
    jobjectArray rv = env->NewObjectArray(clips.size(), clip_class, NULL);

    for (int i = 0; i < clips.size(); ++ i) {
    	GLClip * clip = clips[i];
        const std::map<std::string, std::string> & attributes = clip->getAccessibilityAttributes();

        std::map<std::string, std::string>::const_iterator ait = attributes.find( "role" );
        std::string role = ait == attributes.end() ? "" : ait->second;
        ait = attributes.find("description");
        std::string description = (ait == attributes.end() || ait->second == "") ? (role == "button" ? "Flow Button" : "Flow Widget") : ait->second;

        const GLBoundingBox bbox = clip->getGlobalBBox();
        int left = bbox.min_pt.x; int top = bbox.min_pt.y;
        int right = bbox.max_pt.x; int bottom = bbox.max_pt.y;

        jmethodID constructorID = env->GetMethodID(clip_class, "<init>", "(Ljava/lang/String;Ljava/lang/String;IIII)V");
    	jobject obj = env->NewObject(clip_class, constructorID, string2jni(env, role), string2jni(env, description), left, top, right, bottom);

    	env->SetObjectArrayElement(rv, i, obj);

    	env->DeleteLocalRef(obj);
    }

    return rv;
}


AndroidHttpSupport::AndroidHttpSupport(AndroidRunnerWrapper *owner)
    : AbstractHttpSupport(&owner->runner), owner(owner)
{
}

void AndroidHttpSupport::deliverData(jint id, jbyteArray data, jboolean last)
{
    std::vector<uint8_t> buffer;
    jni2bytes(owner->env, &buffer, data);
    AbstractHttpSupport::deliverPartialData(id, buffer.data(), buffer.size(), last);
}

void AndroidHttpSupport::deliverError(jint id, jbyteArray data)
{
    std::vector<uint8_t> buffer;
    jni2bytes(owner->env, &buffer, data);
    AbstractHttpSupport::deliverError(id, buffer.data(), buffer.size());
}

void AndroidHttpSupport::deliverProgress(jint id, jfloat loaded, jfloat total)
{
    AbstractHttpSupport::deliverProgress(id, loaded, total);
}

void AndroidHttpSupport::doRequest(HttpRequest &rq)
{
    JNIEnv *env = owner->env;

    int id = rq.req_id;
    jstring url_str = string2jni(env, rq.url);

    rq.headers.erase(parseUtf8("Content-Length"));

    if (rq.is_media_preload) {
        env->CallVoidMethod(owner->owner, cbStartMediaPreload, id, url_str);
    } else {
        jstring method_str = string2jni(env, rq.method);

        jbyteArray payload = env->NewByteArray(rq.payload.size());
        env->SetByteArrayRegion(payload, 0, rq.payload.size(), reinterpret_cast<jbyte*>(rq.payload.data()));

        jobjectArray header_arr = string_map2jni(env, rq.headers);

        env->CallVoidMethod(owner->owner, cbStartHttpRequest, id, url_str, method_str,
                            header_arr, payload);
    }

    std::string msg;
    if (owner->eatExceptions(&msg))
        AbstractHttpSupport::deliverError(id, msg.data(), msg.size());
}

void AndroidHttpSupport::doRemoveUrlFromCache(const unicode_string & url)
{
    JNIEnv *env = owner->env;
    jstring url_str = string2jni(env, url);

    env->CallVoidMethod(owner->owner, cbRemoveUrlFromCache, url_str);
    owner->eatExceptions();

    owner->getRenderer()->removeUrlFromPicturesCache(url);
}

int AndroidHttpSupport::doGetAvailableCacheSpaceMb()
{
    struct statfs sfs;
    statfs("/data/data", &sfs);
    unsigned long long available_bytes = sfs.f_bfree * sfs.f_bsize;
    return int(available_bytes / (1024 * 1024));
}

void AndroidHttpSupport::doSystemDownloadFile(const unicode_string & url)
{
    JNIEnv *env = owner->env;
    jstring url_str = string2jni(env, url);

    env->CallVoidMethod(owner->owner, cbSystemDownloadFile, url_str);

    owner->eatExceptions();
}

void AndroidHttpSupport::doDeleteAppCookies()
{
    JNIEnv *env = owner->env;

    env->CallVoidMethod(owner->owner, cbDeleteAppCookies);

}

AndroidSoundSupport::AndroidSoundSupport(AndroidRunnerWrapper *owner)
    : AbstractSoundSupport(&owner->runner), owner(owner)
{
}

void AndroidSoundSupport::deliverResolveReady(jlong sound)
{
    resolveReady((AbstractSound*)sound);
}

void AndroidSoundSupport::deliverResolveError(jlong sound, jstring error)
{
    unicode_string e_str = jni2unicode(owner->env, error);
    resolveError((AbstractSound*)sound, e_str);
}

void AndroidSoundSupport::deliverNotifyDone(jlong channel)
{
    notifyDone((AbstractSoundChannel*)channel);
}

void AndroidSoundSupport::doBeginLoad(AbstractSound *sound)
{
    AbstractSoundSupport::doBeginLoad(sound);

    JNIEnv *env = owner->env;
    jstring url = string2jni(env, sound->getUrl());

    env->CallVoidMethod(owner->owner, cbBeginLoadSound, (jlong)sound, url);
    env->DeleteLocalRef(url);

    std::string msg;
    if (owner->eatExceptions(&msg))
        resolveError(sound, parseUtf8(msg));
}

void AndroidSoundSupport::doBeginPlay(AbstractSoundChannel *channel, float start_pos, bool loop)
{
    AbstractSoundSupport::doBeginPlay(channel, start_pos, loop);

    JNIEnv *env = owner->env;
    jstring url = string2jni(env, channel->getSound()->getUrl());

    env->CallVoidMethod(owner->owner, cbBeginPlaySound, (jlong)channel, url, start_pos, (jboolean)loop);
    env->DeleteLocalRef(url);

    if (owner->eatExceptions())
        notifyDone(channel);
}

void AndroidSoundSupport::doStopSound(AbstractSoundChannel *channel)
{
    AbstractSoundSupport::doStopSound(channel);

    owner->env->CallVoidMethod(owner->owner, cbStopSound, (jlong)channel);
    owner->eatExceptions();
}

void AndroidSoundSupport::doSetVolume(AbstractSoundChannel *channel, float value)
{
    owner->env->CallVoidMethod(owner->owner, cbSetSoundVolume, (jlong)channel, value);
    owner->eatExceptions();
}

float AndroidSoundSupport::doGetSoundPosition(AbstractSoundChannel *channel)
{
    float rv = owner->env->CallFloatMethod(owner->owner, cbGetSoundPosition, (jlong)channel);
    owner->eatExceptions();
    return rv;
}

float AndroidSoundSupport::doComputeSoundLength(AbstractSound *sound)
{
    jstring url_string = string2jni(owner->env, sound->getUrl());
	float rv = owner->env->CallFloatMethod(owner->owner, cbGetSoundLength, url_string);
	owner->env->DeleteLocalRef(url_string);

	owner->eatExceptions();
    return rv;
}

AndroidInAppPurchase::AndroidInAppPurchase(AndroidRunnerWrapper *owner)
    : AbstractInAppPurchase(&owner->runner), owner(owner)
{
}

void AndroidInAppPurchase::loadProductsInfo(std::vector<unicode_string> pids)
{
	jobjectArray pids_array = owner->env->NewObjectArray(pids.size(), cString, NULL);

	for (int i = 0; i < pids.size(); ++i) {
		jstring el = string2jni(owner->env, pids[i]);

		owner->env->SetObjectArrayElement(pids_array, i, el);
	}

    owner->env->CallVoidMethod(owner->owner, cbLoadPurchaseProductInfo, pids_array);

    owner->eatExceptions();
}

void AndroidInAppPurchase::paymentRequest(unicode_string _id, int count) 
{
    jstring id_string = string2jni(owner->env, _id);
    owner->env->CallVoidMethod(owner->owner, cbPaymentRequest, id_string, (jint)count);
    owner->env->DeleteLocalRef(id_string);

    owner->eatExceptions();
}

void AndroidInAppPurchase::restoreRequest()
{
    owner->env->CallVoidMethod(owner->owner, cbRestorePaymentRequest);
}

AndroidNotificationsSupport::AndroidNotificationsSupport(AndroidRunnerWrapper *owner)
    : AbstractNotificationsSupport(&owner->runner), owner(owner)
{
}

bool AndroidNotificationsSupport::doHasPermissionLocalNotification()
{
    jboolean result = owner->env->CallBooleanMethod(owner->owner, cbHasPermissionLocalNotification);
    return (result && !owner->eatExceptions());
}

void AndroidNotificationsSupport::doRequestPermissionLocalNotification(int cb_root)
{
    owner->env->CallVoidMethod(owner->owner, cbRequestPermissionLocalNotification, cb_root);
    owner->eatExceptions();
}

void AndroidNotificationsSupport::doScheduleLocalNotification(double time, int notificationId, std::string notificationCallbackArgs, std::string notificationTitle, std::string notificationText, bool withSound, bool pinned)
{
    JNIEnv *env = owner->env;

    jstring notificationCallbackArgs_string = string2jni(env, notificationCallbackArgs);
    jstring notificationTitle_string = string2jni(env, notificationTitle);
    jstring notificationText_string = string2jni(env, notificationText);

    env->CallVoidMethod(owner->owner, cbScheduleLocalNotification, time, notificationId, notificationCallbackArgs_string, notificationTitle_string, notificationText_string, withSound, pinned);
    owner->eatExceptions();
}

void AndroidNotificationsSupport::doCancelLocalNotification(int notificationId)
{
    owner->env->CallVoidMethod(owner->owner, cbCancelLocalNotification, notificationId);
    owner->eatExceptions();
}

void AndroidNotificationsSupport::doGetFBToken(int cb_root)
{
    JNIEnv* env = owner->env;
    env->CallVoidMethod(owner->owner, cbGetFBToken, cb_root);
    owner->eatExceptions();
}

void AndroidNotificationsSupport::doSubscribeToFBTopic(unicode_string name)
{
    JNIEnv* env = owner->env;
    env->CallVoidMethod(owner->owner, cbSubscribeToFBTopic, string2jni(env, name));
    owner->eatExceptions();
}

void AndroidNotificationsSupport::doUnsubscribeFromFBTopic(unicode_string name)
{
    JNIEnv* env = owner->env;
    env->CallVoidMethod(owner->owner, cbUnsubscribeFromFBTopic, string2jni(env, name));
    owner->eatExceptions();
}

AndroidLocalyticsSupport::AndroidLocalyticsSupport(AndroidRunnerWrapper *owner)
    : AbstractLocalyticsSupport(&owner->runner), owner(owner)
{
}

void AndroidLocalyticsSupport::doTagEventWithAttributes(const unicode_string &event_name, const std::map<unicode_string, unicode_string> &event_attributes)
{
    JNIEnv *env = owner->env;
    jstring event_name_str = string2jni(env, event_name);

    jobjectArray attributes_arr = string_map2jni(env, event_attributes);
    env->CallVoidMethod(owner->owner, cbTagLocalyticsEventWithAttributes, event_name_str, attributes_arr);

    owner->eatExceptions();
}

AndroidGeolocationSupport::AndroidGeolocationSupport(AndroidRunnerWrapper *owner)
    : AbstractGeolocationSupport(&owner->runner), owner(owner)
{
}

void AndroidGeolocationSupport::doGeolocationGetCurrentPosition(int callbacksRoot, bool enableHighAccuracy, double timeout, double maximumAge, std::string turnOnGeolocationMessage, std::string okButtonText, std::string cancelButtonText)
{
    JNIEnv *env = owner->env;
    jstring turnOnGeolocationMessage_str = string2jni(env, turnOnGeolocationMessage);
    jstring okButtonText_str = string2jni(env, okButtonText);
    jstring cancelButtonText_str = string2jni(env, cancelButtonText);

    env->CallVoidMethod(owner->owner, cbGeolocationGetCurrentPosition, callbacksRoot, enableHighAccuracy, timeout, maximumAge, turnOnGeolocationMessage_str, okButtonText_str, cancelButtonText_str);
    owner->eatExceptions();
}

void AndroidGeolocationSupport::doGeolocationWatchPosition(int callbacksRoot, bool enableHighAccuracy, double timeout, double maximumInterval, std::string turnOnGeolocationMessage, std::string okButtonText, std::string cancelButtonText)
{
    JNIEnv *env = owner->env;
    jstring turnOnGeolocationMessage_str = string2jni(env, turnOnGeolocationMessage);
    jstring okButtonText_str = string2jni(env, okButtonText);
    jstring cancelButtonText_str = string2jni(env, cancelButtonText);

    env->CallVoidMethod(owner->owner, cbGeolocationWatchPosition, callbacksRoot, enableHighAccuracy, timeout, maximumInterval, turnOnGeolocationMessage_str, okButtonText_str, cancelButtonText_str);
    owner->eatExceptions();
}

void AndroidGeolocationSupport::afterWatchDispose(int callbacksRoot)
{
    owner->env->CallVoidMethod(owner->owner, cbGeolocationAfterWatchDispose, callbacksRoot);
    owner->eatExceptions();
}


AndroidMediaStreamSupport::AndroidMediaStreamSupport(AndroidRunnerWrapper *owner)
    : MediaStreamSupport(&owner->runner), owner(owner)
{
}

IMPLEMENT_FLOW_NATIVE_OBJECT(AndroidMediaStreamSupport::FlowNativeMediaStream, FlowNativeObject)

AndroidMediaStreamSupport::FlowNativeMediaStream::FlowNativeMediaStream(AndroidRunnerWrapper *owner) : owner(owner), FlowNativeObject(owner->getRunner()) {}

AndroidMediaStreamSupport::FlowNativeMediaStream::~FlowNativeMediaStream()
{
    owner->env->DeleteGlobalRef(mediaStream);
}

void AndroidMediaStreamSupport::initializeDeviceInfo(int callbackRoot)
{
    owner->env->CallVoidMethod(owner->owner, cbDeviceInfoUpdated, callbackRoot);
    owner->eatExceptions();
}

void AndroidMediaStreamSupport::getAudioInputDevices(int callbackRoot)
{
    owner->env->CallVoidMethod(owner->owner, cbGetAudioDevices, callbackRoot);
    owner->eatExceptions();
}

void AndroidMediaStreamSupport::getVideoInputDevices(int callbackRoot)
{
    owner->env->CallVoidMethod(owner->owner, cbGetVideoDevices, callbackRoot);
    owner->eatExceptions();
}

void AndroidMediaStreamSupport::deliverInitializeDeviceInfoCallback(jint cb_root)
{
     getFlowRunner()->EvalFunction(getFlowRunner()->LookupRoot(cb_root), 0);
}

void AndroidMediaStreamSupport::deliverDevices(jint cb_root, jobjectArray ids, jobjectArray names)
{
    JNIEnv *env = owner->env;
    RUNNER_VAR = getFlowRunner();

    int length = env->GetArrayLength(ids);
    StackSlot devicesArray = RUNNER->AllocateArray(length);
    for (int i = 0; i < length; i++) {
        jstring id = (jstring)env->GetObjectArrayElement(ids, i);
        jstring name = (jstring)env->GetObjectArrayElement(names, i);

        StackSlot device = RUNNER->AllocateArray(2);
        RUNNER->SetArraySlot(device, 0, RUNNER->AllocateString(jni2unicode(env, id)));
        RUNNER->SetArraySlot(device, 1, RUNNER->AllocateString(jni2unicode(env, name)));

        RUNNER->SetArraySlot(devicesArray, i, device);
    }
    RUNNER->EvalFunction(RUNNER->LookupRoot(cb_root), 1, devicesArray);
}

void AndroidMediaStreamSupport::makeStream(bool recordAudio, bool recordVideo, unicode_string audioDeviceId, unicode_string videoDeviceId, int onReadyRoot, int onErrorRoot)
{
    owner->env->CallVoidMethod(owner->owner, cbMakeMediaStream, recordAudio, recordVideo, string2jni(owner->env, videoDeviceId), string2jni(owner->env, audioDeviceId),
        onReadyRoot, onErrorRoot);
    owner->eatExceptions();
}

void AndroidMediaStreamSupport::stopStream(StackSlot mediaStream)
{
    FlowNativeMediaStream* flowMediaStream = getFlowRunner()->GetNative<FlowNativeMediaStream*>(mediaStream);
    owner->env->CallVoidMethod(owner->owner, cbStopMediaStream, flowMediaStream->mediaStream);
    owner->eatExceptions();
}

void AndroidMediaStreamSupport::deliverMediaStream(jint cb_root, jobject mediaStream)
{
    JNIEnv *env = owner->env;
    RUNNER_VAR = getFlowRunner();

    FlowNativeMediaStream* flowMediaStream = new FlowNativeMediaStream(owner);
    flowMediaStream->mediaStream = (jobject)env->NewGlobalRef(mediaStream);

    RUNNER->EvalFunction(RUNNER->LookupRoot(cb_root), 1, flowMediaStream->getFlowValue());
}

void AndroidMediaStreamSupport::deliverError(jint cb_root, jstring error)
{
    JNIEnv *env = owner->env;
    RUNNER_VAR = getFlowRunner();
    RUNNER->EvalFunction(RUNNER->LookupRoot(cb_root), 1, RUNNER->AllocateString(jni2unicode(env, error)));
}

AndroidWebRTCSupport::AndroidWebRTCSupport(AndroidRunnerWrapper *owner)
    : WebRTCSupport(&owner->runner), owner(owner)
{
}

IMPLEMENT_FLOW_NATIVE_OBJECT(AndroidWebRTCSupport::FlowNativeMediaSender, FlowNativeObject)

AndroidWebRTCSupport::FlowNativeMediaSender::FlowNativeMediaSender(AndroidWebRTCSupport *owner) : owner(owner), FlowNativeObject(owner->getFlowRunner()) {}

AndroidWebRTCSupport::FlowNativeMediaSender::~FlowNativeMediaSender()
{
    owner->owner->env->DeleteGlobalRef(mediaSender);
}

void AndroidWebRTCSupport::makeSenderFromStream(unicode_string serverUrl, unicode_string roomId,
    std::vector<unicode_string> stunUrls, std::vector<std::vector<unicode_string> > turnServers,
    StackSlot stream, int onMediaSenderReadyRoot, int onNewParticipantRoot, int onParticipantLeaveRoot, int onErrorRoot)
{

    jobjectArray stun = string_array2jni(owner->env, stunUrls);

    jobjectArray turn = owner->env->NewObjectArray(turnServers.size(), owner->env->GetObjectClass(stun), NULL);

    for (int i = 0; i < turnServers.size(); i++) {
        jobjectArray server = string_array2jni(owner->env, turnServers[i]);
        owner->env->SetObjectArrayElement(turn, i, server);
        owner->env->DeleteLocalRef(server);
    }

    AndroidMediaStreamSupport::FlowNativeMediaStream* flowMediaStream = getFlowRunner()->GetNative<AndroidMediaStreamSupport::FlowNativeMediaStream*>(stream);

    owner->env->CallVoidMethod(owner->owner, cbMakeMediaSender, string2jni(owner->env, serverUrl), string2jni(owner->env, roomId),
        stun, turn, flowMediaStream->mediaStream, onMediaSenderReadyRoot, onNewParticipantRoot, onParticipantLeaveRoot, onErrorRoot);
    owner->eatExceptions();
}

void AndroidWebRTCSupport::stopSender(StackSlot sender)
{
    FlowNativeMediaSender* flowSender = getFlowRunner()->GetNative<FlowNativeMediaSender*>(sender);
    owner->env->CallVoidMethod(owner->owner, cbStopMediaSender, flowSender->mediaSender);
    owner->eatExceptions();
}

void AndroidWebRTCSupport::deliverOnMediaSenderReadyCallback(jint cb_root, jobject sender)
{
    JNIEnv *env = owner->env;
    RUNNER_VAR = getFlowRunner();

    FlowNativeMediaSender* flowMediaSender = new FlowNativeMediaSender(this);
    flowMediaSender->mediaSender = (jobject)env->NewGlobalRef(sender);

    RUNNER->EvalFunction(RUNNER->LookupRoot(cb_root), 1, flowMediaSender->getFlowValue());
}

void AndroidWebRTCSupport::deliverOnNewParticipantCallback(jint cb_root, jstring id, jobject mediaStream)
{
    JNIEnv *env = owner->env;
    RUNNER_VAR = getFlowRunner();

    AndroidMediaStreamSupport::FlowNativeMediaStream* flowMediaStream = new AndroidMediaStreamSupport::FlowNativeMediaStream(owner);
    flowMediaStream->mediaStream = (jobject)env->NewGlobalRef(mediaStream);

    RUNNER->EvalFunction(RUNNER->LookupRoot(cb_root), 2, RUNNER->AllocateString(jni2unicode(env, id)), flowMediaStream->getFlowValue());
}

void AndroidWebRTCSupport::deliverOnParticipantLeaveCallback(jint cb_root, jstring id)
{
    JNIEnv *env = owner->env;
    RUNNER_VAR = getFlowRunner();
    RUNNER->EvalFunction(RUNNER->LookupRoot(cb_root), 1, RUNNER->AllocateString(jni2unicode(env, id)));
}

void AndroidWebRTCSupport::deliverOnErrorCallback(jint cb_root, jstring error)
{
    JNIEnv *env = owner->env;
    RUNNER_VAR = getFlowRunner();
    RUNNER->EvalFunction(RUNNER->LookupRoot(cb_root), 1, RUNNER->AllocateString(jni2unicode(env, error)));
}

AndroidMediaRecorderSupport::AndroidMediaRecorderSupport(AndroidRunnerWrapper *owner)
    : MediaRecorderSupport(&owner->runner), owner(owner)
{
}

IMPLEMENT_FLOW_NATIVE_OBJECT(AndroidMediaRecorderSupport::FlowNativeMediaRecorder, FlowNativeObject)

AndroidMediaRecorderSupport::FlowNativeMediaRecorder::FlowNativeMediaRecorder(AndroidMediaRecorderSupport *owner) : owner(owner), FlowNativeObject(owner->getFlowRunner()) {}

AndroidMediaRecorderSupport::FlowNativeMediaRecorder::~FlowNativeMediaRecorder()
{
    owner->owner->env->DeleteGlobalRef(mediaRecorder);
}

void AndroidMediaRecorderSupport::makeMediaRecorder(unicode_string websocketUri, unicode_string filePath, StackSlot mediaStream, int timeslice, int onReadyRoot, int onErrorRoot)
{
    AndroidMediaStreamSupport::FlowNativeMediaStream* flowMediaStream = getFlowRunner()->GetNative<AndroidMediaStreamSupport::FlowNativeMediaStream*>(mediaStream);
    owner->env->CallVoidMethod(owner->owner, cbMakeMediaRecorder, string2jni(owner->env, websocketUri), string2jni(owner->env, filePath), flowMediaStream->mediaStream,
        timeslice, onReadyRoot, onErrorRoot);
    owner->eatExceptions();
}

void AndroidMediaRecorderSupport::startMediaRecorder(StackSlot recorder, int timeslice)
{
    FlowNativeMediaRecorder* flowRecorder = (FlowNativeMediaRecorder*)getFlowRunner()->GetNative<FlowNativeMediaRecorder*>(recorder);
    owner->env->CallVoidMethod(owner->owner, cbStartMediaRecorder, flowRecorder->mediaRecorder);
    owner->eatExceptions();
}

void AndroidMediaRecorderSupport::resumeMediaRecorder(StackSlot recorder)
{
    FlowNativeMediaRecorder* flowRecorder = (FlowNativeMediaRecorder*)getFlowRunner()->GetNative<FlowNativeMediaRecorder*>(recorder);
    owner->env->CallVoidMethod(owner->owner, cbResumeMediaRecorder, flowRecorder->mediaRecorder);
    owner->eatExceptions();
}

void AndroidMediaRecorderSupport::pauseMediaRecorder(StackSlot recorder)
{
    FlowNativeMediaRecorder* flowRecorder = (FlowNativeMediaRecorder*)getFlowRunner()->GetNative<FlowNativeMediaRecorder*>(recorder);
    owner->env->CallVoidMethod(owner->owner, cbPauseMediaRecorder, flowRecorder->mediaRecorder);
    owner->eatExceptions();
}

void AndroidMediaRecorderSupport::stopMediaRecorder(StackSlot recorder)
{
    FlowNativeMediaRecorder* flowRecorder = (FlowNativeMediaRecorder*)getFlowRunner()->GetNative<FlowNativeMediaRecorder*>(recorder);
    owner->env->CallVoidMethod(owner->owner, cbStopMediaRecorder, flowRecorder->mediaRecorder);
    owner->eatExceptions();
}

void AndroidMediaRecorderSupport::deliverMediaRecorder(jint cb_root, jobject recorder)
{
    JNIEnv *env = owner->env;
    RUNNER_VAR = getFlowRunner();

    FlowNativeMediaRecorder* flowRecorder = new FlowNativeMediaRecorder(this);

    flowRecorder->mediaRecorder = (jobject)env->NewGlobalRef(recorder);

    RUNNER->EvalFunction(RUNNER->LookupRoot(cb_root), 1, flowRecorder->getFlowValue());
}

void AndroidMediaRecorderSupport::deliverError(jint cb_root, jstring error)
{
    JNIEnv *env = owner->env;
    RUNNER_VAR = getFlowRunner();
    RUNNER->EvalFunction(RUNNER->LookupRoot(cb_root), 1, RUNNER->AllocateString(jni2unicode(env, error)));
}

AndroidWebSocketSupport::AndroidWebSocketSupport(AndroidRunnerWrapper *owner) : AbstractWebSocketSupport(&owner->runner), owner(owner)
{
}

IMPLEMENT_FLOW_NATIVE_OBJECT(AndroidWebSocketSupport::FlowNativeWebSocket, FlowNativeObject)

AndroidWebSocketSupport::FlowNativeWebSocket::FlowNativeWebSocket(AndroidWebSocketSupport *owner) : owner(owner), FlowNativeObject(owner->getFlowRunner()) {}

AndroidWebSocketSupport::FlowNativeWebSocket::~FlowNativeWebSocket()
{
    owner->owner->env->DeleteGlobalRef(websocket);
}

void AndroidWebSocketSupport::deliverOnClose(jint callbacksKey, jint closeCode, jstring reason, jboolean wasClean)
{
    unicode_string reason_str = jni2unicode(owner->env, reason);
    onClose(callbacksKey, closeCode, reason_str, wasClean);
}

void AndroidWebSocketSupport::deliverOnError(jint callbacksKey, jstring error)
{
    unicode_string e_str = jni2unicode(owner->env, error);
    onError(callbacksKey, e_str);
}

void AndroidWebSocketSupport::deliverOnMessage(jint callbacksKey, jstring message)
{
    unicode_string message_str = jni2unicode(owner->env, message);
    onMessage(callbacksKey, message_str);
}

void AndroidWebSocketSupport::deliverOnOpen(jint callbacksKey)
{
    onOpen(callbacksKey);
}

StackSlot AndroidWebSocketSupport::doOpen(unicode_string url, int callbacksKey)
{
    JNIEnv *env = owner->env;
    jstring url_str = string2jni(env, url);
    jobject websocket = env->CallObjectMethod(owner->owner, cbOpenWSClient, url_str, callbacksKey);
    owner->eatExceptions();

    FlowNativeWebSocket* websocketNative = new FlowNativeWebSocket(this);
    websocketNative->websocket = (jobject)env->NewGlobalRef(websocket);
    return websocketNative->getFlowValue();
}

StackSlot AndroidWebSocketSupport::doSend(StackSlot websocket, unicode_string message)
{
    JNIEnv *env = owner->env;
    FlowNativeWebSocket* websocketNative = getFlowRunner()->GetNative<FlowNativeWebSocket*>(websocket);
    jstring message_str = string2jni(env, message);
    jboolean isSent = env->CallBooleanMethod(owner->owner, cbSendMessageWSClient, websocketNative->websocket, message_str);
    owner->eatExceptions();

    return StackSlot::MakeBool(isSent);
}

StackSlot AndroidWebSocketSupport::doHasBufferedData(StackSlot websocket)
{
    JNIEnv *env = owner->env;
    FlowNativeWebSocket* websocketNative = getFlowRunner()->GetNative<FlowNativeWebSocket*>(websocket);
    jboolean hasBufferedData = env->CallBooleanMethod(owner->owner, cbHasBufferedDataWSClient, websocketNative->websocket);
    owner->eatExceptions();

    return StackSlot::MakeBool(hasBufferedData);
}

void AndroidWebSocketSupport::doClose(StackSlot websocket, int code, unicode_string reason)
{
    JNIEnv *env = owner->env;
    FlowNativeWebSocket* websocketNative = getFlowRunner()->GetNative<FlowNativeWebSocket*>(websocket);
    jstring reason_str = string2jni(env, reason);
    env->CallVoidMethod(owner->owner, cbCloseWSClient, websocketNative->websocket, code, reason_str);
    owner->eatExceptions();
}

AndroidFileSystemInterface::AndroidFileSystemInterface(AndroidRunnerWrapper *owner) : FileSystemInterface(&owner->runner), owner(owner)
{

}

void AndroidFileSystemInterface::deliverOpenFileDialogCallback(jint callbackRoot, jobjectArray filePaths)
{
    RUNNER_VAR = owner->getRunner();
    JNIEnv *env = owner->env;
    RUNNER_DefSlots1(flowFilesArray);

    int length = env->GetArrayLength(filePaths);
    flowFilesArray = RUNNER->AllocateArray(length);

    for (int i = 0; i < length; ++i) {
        jstring path = (jstring)env->GetObjectArrayElement(filePaths, i);

        FlowFile *file = new FlowFile(RUNNER, jni2string(env, path));
        RUNNER->SetArraySlot(flowFilesArray, i, RUNNER->AllocNative(file));

        env->DeleteLocalRef(path);
    }

    RUNNER->EvalFunction(RUNNER->LookupRoot(callbackRoot), 1, flowFilesArray);

    RUNNER->ReleaseRoot(callbackRoot);
}

void AndroidFileSystemInterface::doOpenFileDialog(int maxFilesCount, std::vector<std::string> fileTypes, StackSlot callback)
{
    JNIEnv *env = owner->env;
    jobjectArray types = string_array2jni(owner->env, fileTypes);
    int callbackRoot = owner->getRunner()->RegisterRoot(callback);
    env->CallVoidMethod(owner->owner, cbOpenFileDialog, maxFilesCount, types, callbackRoot);
    owner->eatExceptions();
}

std::string AndroidFileSystemInterface::doFileType(const StackSlot &file)
{
    RUNNER_VAR = owner->getRunner();
    JNIEnv *env = owner->env;
    FlowFile *flowFile = RUNNER->GetNative<FlowFile*>(file);

    jstring filepath = string2jni(env, flowFile->getFilepath());
    jstring jmimetype = (jstring) env->CallObjectMethod(owner->owner, cbGetFileType, filepath);
    owner->eatExceptions();
    std::string mimetype = jni2string(env, jmimetype);
    env->DeleteLocalRef(jmimetype);
    env->DeleteLocalRef(filepath);
    return mimetype;
}

AndroidPrintingSupport::AndroidPrintingSupport(AndroidRunnerWrapper *owner) : PrintingSupport(&owner->runner), owner(owner)
{

}

void AndroidPrintingSupport::doPrintHTMLDocument(unicode_string html)
{
    JNIEnv *env = owner->env;
    jstring html_s = string2jni(env, html);

    env->CallVoidMethod(owner->owner, cbPrintHTML, html_s);

    env->DeleteLocalRef(html_s);
    owner->eatExceptions();
}

void AndroidPrintingSupport::doPrintDocumentFromURL(unicode_string url)
{
    JNIEnv *env = owner->env;
    jstring url_s = string2jni(env, url);

    env->CallVoidMethod(owner->owner, cbPrintURL, url_s);

    env->DeleteLocalRef(url_s);
    owner->eatExceptions();
}

