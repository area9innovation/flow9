#import <UIKit/UIKit.h>

#import "ByteCodeRunner.h"
#import "iosTimerSupport.h"
#import "iosGLRenderSupport.h"
#import "iosHttpSupport.h"
#import "iosSoundSupport.h"
#import "FileLocalStore.h"
#import "FileSystemInterface.h"
#import "iosLocalyticsSupport.h"
#import "iosNotificationsSupport.h"
#import "iosGeolocationSupport.h"
#import "iosWebSocketSupport.h"
#import "iosMediaStreamSupport.h"
#import "iosWebRTCSupport.h"
#import "iosMediaRecorderSupport.h"
#ifdef BYTECODE_FILE
#import "AppleStorePurchase.h"
#endif

#import "EAGLView.h"
#import "EAGLViewController.h"

class iosGLRenderSupport;

@interface iosAppDelegate : UIResponder <UIApplicationDelegate> {
@private
    ByteCodeRunner     * Runner;
    iosTimerSupport    * TimerSupport;
    iosGLRenderSupport * RenderSupport;
    iosHttpSupport     * HttpSupport;
    iosSoundSupport    * SoundSupport;
    iosLocalyticsSupport * LocalyticsSupport;
#ifdef FLOW_INAPP_PURCHASE
    AppleStorePurchase * InAppPurchases;
#endif
    iosNotificationsSupport * NotificationsSupport;
#ifdef NSLOCATION_WHEN_IN_USE_USAGE_DESCRIPTION
    iosGeolocationSupport * GeolocationSupport;
#endif
    iosWebSocketSupport * WebSocketSupport;
    iosMediaStreamSupport * MediaStream;
    iosWebRTCSupport * WebRTC;
    iosMediaRecorderSupport * MediaRecorder;
    FileLocalStore     * LocalStore;
    FileSystemInterface * FSInterface;
    
    EAGLView * GLView;
    EAGLViewController * GLViewController;
    
    NSTimer * CheckNetworkTimer;
    
    NSURL * urlToOpen;
    
    // id of last notification, that waked up application, if it was closed
    // equals to -1 if there is no such notification or it is handled already.
    int localNotificationWakingUpId;
    
    bool accessible;
}

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) NSString * DefaultURLParameters;
@property (nonatomic, retain) NSString * BytecodeFilePath;
@property (nonatomic, retain) NSString * bcUrlForBytecodeViewer;
@property (nonatomic) bool DbgConsoleOn;

- (void) EAGLViewLoaded: (EAGLViewController *) controller glView: (EAGLView*) glview;

- (void) sendFirebaseToken:(NSString *)token;
- (void) sendFirebaseMessage:(NSString *)messageId body:(NSString *)body title:(NSString *)title from:(NSString *)from stamp:(NSUInteger)stamp data:(NSDictionary *) data;

@end
