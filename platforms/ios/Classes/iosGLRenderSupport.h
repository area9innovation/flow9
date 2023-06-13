#ifndef IOSGLRENDERSUPPORT_H
#define IOSGLRENDERSUPPORT_H

#import <UIKit/UIKit.h>

#import "EAGLView.h"
#import "EAGLViewController.h"
#include "GLRenderSupport.h"
#include "utils.h"
#import "URLLoader.h"
#import <MediaPlayer/MediaPlayer.h>
#import <WebKit/WebKit.h>
#import "FlowVideoPlayerController.h"

#import "FlowAVPlayerView.h"
#import "FlowRTCVideoPreview.h"

#import "GLRenderer.h"

class iosGLRenderSupport;
@class EAGLViewController;

enum FlowUIOrientation {
    FlowUIPortrait,
    FlowUILandscape,
    FlowUIAuto
};

enum FlowCameraFitMode {
    FlowCameraFitContain = 0,
    FlowCameraFitFill = 1,
    FlowCameraFitCover = 2
};

enum FlowCameraMode {
    FlowCameraPhotoMode = 0,
    FlowCameraVideoMode = 1
};

@interface FlowUITextView : UITextView {
    @private
    GLTextClip * textClip;
}

@property(nonatomic, assign) NSString* realText;
@property(nonatomic, assign) NSString* pendingText;
@property(nonatomic, assign) UIFont* pendingFont;
@property(nonatomic, assign) UIScrollView* scrollHorizontalView;

- (id)initWithClip:(GLTextClip*)textClip;
@end

//
//
// ObjC helpers
@interface TextFieldDelegate : NSObject <UITextViewDelegate> {
    @private
    iosGLRenderSupport * owner;
}

- (id) initWithOwner: (iosGLRenderSupport *) ownr;
- (void)textViewDidChange:(FlowUITextView *)textView;
- (void)textViewDidChangeSelection:(FlowUITextView *)textView;
@end

@interface WebViewDelegate : NSObject <WKNavigationDelegate> {
@private
    iosGLRenderSupport * owner;
    NSMutableDictionary * WebViewInnerDomains;
    NSMutableDictionary * WebViewWhiteListInnerDomains;
    NSMutableDictionary * WebViewExternalDocuments;
}

- (id) initWithOwner: (iosGLRenderSupport *) ownr;
- (BOOL)webView:(WKWebView *)web_view shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(WKNavigationType)nt;
@end

@interface WebScrollViewDelegate : NSObject <UIScrollViewDelegate> {
@private
    iosGLRenderSupport * owner;
}
- (id) initWithOwner: (iosGLRenderSupport *) ownr;
-(UIView*)viewForZoomingInScrollView:(UIScrollView *)scrollView;
-(void)scrollViewWillBeginZooming:(UIScrollView*)scrollView withView: (UIView*) view;
-(void) dealloc;
@end

@interface ImagePickerControllerDelegate : NSObject <UIImagePickerControllerDelegate> {
@private
    iosGLRenderSupport * owner;
    NSString * desiredFileName;
    int desiredWidth;
    int desiredHeight;
    int compressQuality;
    int fitMode;
    int duration;
    int size;
    int flowCameraMode;
}

@property (nonatomic, assign) int desiredWidth;
@property (nonatomic, assign) int desiredHeight;
@property (nonatomic, assign) int compressQuality;
@property (nonatomic, copy) NSString * desiredFileName;
@property (nonatomic, assign) int fitMode;
@property (nonatomic, assign) int duration;
@property (nonatomic, assign) int size;
@property (nonatomic, assign) int flowCameraMode;

- (id) initWithOwner: (iosGLRenderSupport *) ownr;
+ (UIImage *) resizeImage: (UIImage *) img toDesiredWidth: (int) reqWidth andDesiredHeight: (int) reqHeight withFitMode : (int) imgFitMode;
@end

@interface FlowWKMessageHandler : NSObject<WKScriptMessageHandler> {
@private
    iosGLRenderSupport* owner;
}

- (id) initWithOwner: (iosGLRenderSupport*) ownr;
- (void)userContentController:(WKUserContentController *)userContentController
didReceiveScriptMessage:(WKScriptMessage *)message;

@end

@interface AudioRecordControlDelegate : NSObject <AVAudioRecorderDelegate> {
@private
    iosGLRenderSupport * owner;
}

@property (nonatomic, copy) NSString * desiredFileName;
@property (nonatomic, copy) NSURL * audioRecordURL;
@property (nonatomic, assign) int duration;
@property (nonatomic, assign) int size;
@property (nonatomic, assign) bool manuallyStopped;
@property (nonatomic, strong) AVAudioRecorder * audioRecorder;

- (id) initWithOwner: (iosGLRenderSupport *) ownr;
@end

//
//
// iosGLRenderSupport
class iosGLRenderSupport : public GLRenderSupport
{
    std::string ResourceBase;
    
public:
    std::map<GLClip*, UIView*> NativeWidgets;
    std::map<UIView*, GLClip*> NativeWidgetClips;
    
    std::map<UIView*, FlowVideoPlayerController *> FlowVideoPlayerControllers;
    
    FlowUITextView * activeTextWidget;
    
    iosGLRenderSupport(ByteCodeRunner *owner, EAGLView *glview, EAGLViewController *glviewcontroller, UIView * widgets_view, std::string res_base, BOOL handle_accessible);
    ~iosGLRenderSupport();
    
    void paintGL();
    
    void LoadFont(std::string code, std::string name);
    
    bool loadAssetData(StaticBuffer *buffer, std::string name, size_t size);
    
    CGPoint fixIphoneXMousePoint(int x, int y);
    void mouseMoveEvent(int x, int y);
    void mousePressEvent(int x, int y);
    void mouseReleaseEvent(int x, int y);
    bool returnKeyEventFromTextClip(GLTextClip* clip);

    void textViewChanged(FlowUITextView * textview, bool text_changed);
    void setInterfaceOrientation(UIDeviceOrientation orientation);
    void adjustGlobalScale(CGPoint old, CGPoint cur, CGFloat scale);

    void setFullScreenTargetRect(float x, float y, float width, float height);
    
    void callFlowFromJS(UIView * web_view, NSString * absolute_url);
    
    bool sendPinchGestureEvent(UIGestureRecognizerState state, CGPoint center, float scale);
    bool sendPanGestureEvent(UIGestureRecognizerState state, CGPoint position, CGPoint translation);
    bool sendSwipeGestureEvent(CGPoint position, CGPoint velocity);
    
    bool loadSystemFont(FontHeader *header, TextFont textFont);
    bool loadSystemGlyph(const FontHeader *header, GlyphHeader *info, StaticBuffer *pixels, TextFont textFont, ucs4_char code);
    
    void resizeGLSurface();
    
    void notifyCameraEvent(int code, std::string message, int width, int height);
    void notifyCameraEventVideo(int code, std::string message, int width, int height, int duration, int size);
    void notifyCameraEventAudio(int code, std::string message, int duration, int size);
    
    FlowUIOrientation getFlowUIOrientation() { return flowUIOrientation; }
    
    void dispatchKeyboardHeight(double height);
    bool isKeyboardListenersAttached();
protected:
    void initializeGL();
    
    void resolvePictureDataAsBitmap(unicode_string url, NSData * data);
    bool loadPicture(unicode_string url, bool cache);
    bool loadPicture(unicode_string url, HttpRequest::T_SMap& headers, bool cache);
    
    void abortPictureLoading(unicode_string url);
    
    void OnRunnerReset(bool inDestructor);
    void OnHostEvent(HostEvent);
    NativeFunction *MakeNativeFunction(const char *name, int num_args);
    
    bool doCreateNativeWidget(GLClip *clip, bool neww);
    void doDestroyNativeWidget(GLClip *clip);
    void doReshapeNativeWidget(GLClip *clip, const GLBoundingBox &bbox, float scale, float alpha);
    
    bool doCreateTextWidget(UIView *&widget, GLTextClip *text_clip);
    bool doCreateVideoWidget(UIView *&widget, GLVideoClip *video_clip);
    void doUpdateVideoPlay(GLVideoClip *video_clip);
    void doUpdateVideoPosition(GLVideoClip *video_clip);
    void doUpdateVideoVolume(GLVideoClip *video_clip);
    void doUpdateVideoPlaybackRate(GLVideoClip *video_clip);
    bool doCreateWebWidget(UIView *&widget, GLWebClip *web_clip);
    virtual StackSlot webClipHostCall(GLWebClip */*clip*/, const unicode_string &/*name*/, const StackSlot &/*args*/);
    virtual StackSlot setWebClipZoomable(GLWebClip */*clip*/, const StackSlot &/*args*/);
    virtual StackSlot setWebClipDomains(GLWebClip */*clip*/, const StackSlot &/*args*/);
    virtual StackSlot webClipEvalJS(GLWebClip* /*clip*/, const unicode_string& /*js*/, StackSlot& /*cb*/);
    StackSlot jsstring2stackslot(NSString * str);
    
    void doRequestRedraw();
    bool hasCursorSupport() { return false; }

    void doOpenUrl(unicode_string, unicode_string);
    
    void doSetInterfaceOrientation(std::string orientation);
    
    void GetTargetTokens(std::set<std::string>&);
    
    void updateAccessibleElements();
    void onTextClipStateChanged(GLTextClip*);
    
    int doGetNumberOfCameras();
    void doCameraTakePhoto(int cameraId, std::string additionalInfo, int desiredWidth , int desiredHeight, int compressQuality, std::string fileName, int fitMode);
    void doCameraTakeVideo(int cameraId, std::string additionalInfo, int duration , int size, int quality, std::string fileName);
    void doStartRecordAudio(std::string additionalInfo, std::string fileName, int duration);
    void doStopRecordAudio();
    void doTakeAudioRecord();
    
    void destroyAllNativeWidgets();
    
private:
    EAGLView * GLView;
    EAGLViewController * GLViewController;
    UIView * WidgetsView;
    EAGLContext * context;
    GLuint targetRenderbuffer;
    GLuint targetFrameBuffer;
    GLuint targetStencilBuffer;
    GLint targetRenderbufferHeight;
    GLint targetRenderbufferWidth;
    
    TextFieldDelegate * commonTextFieldDelegate;
    WebViewDelegate * commonWebViewDelegate;
    WebScrollViewDelegate * commonWebScrollViewDelegate;
    ImagePickerControllerDelegate * commonImagePickerControllerDelegate;
    AudioRecordControlDelegate * commonAudioRecordControllerDelegate;
  
    FlowUIOrientation flowUIOrientation;
    
    BOOL handleAccessibleElements;
    
    BOOL needsDrawingGL;
    
    float ScreenScale;
    
    BOOL hasFullScreenTarget;
    float FullScreenTargetCenterX, FullScreenTargetCenterY, FullScreenTargetScaleFactor;
    
    std::string lastCameraAdditionalArgs;
    
    FlowGestureState GestureRecognizerState2FlowGestureState(UIGestureRecognizerState state) {
        if (state == UIGestureRecognizerStateBegan) return FlowGestureStateBegin;
        if (state == UIGestureRecognizerStateChanged) return FlowGestureStateProgress;
        return FlowGestureStateEnd;
    }
    
    DECLARE_NATIVE_METHOD(setClipboard);
    DECLARE_NATIVE_METHOD(setFullScreenRectangle);
    DECLARE_NATIVE_METHOD(isFullScreen);
    DECLARE_NATIVE_METHOD(onFullScreen);
    DECLARE_NATIVE_METHOD(hostCall); // Override
    
    DECLARE_NATIVE_METHOD(setBackgroundColor);
    DECLARE_NATIVE_METHOD(setStatusBarColor);
    DECLARE_NATIVE_METHOD(setStatusBarVisible);
    DECLARE_NATIVE_METHOD(setStatusBarIconsTheme);
};

#endif // IOSGLRENDERSUPPORT_H
