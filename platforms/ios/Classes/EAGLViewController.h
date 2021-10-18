#import <UIKit/UIKit.h>

#import <QuartzCore/QuartzCore.h>

#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#import "iosGLRenderSupport.h"

#import "EAGLView.h"
#import "iosAppDelegate.h"
#import "DebugLog.h"

class iosGLRenderSupport;

@interface EAGLViewController : UIViewController<DebugLogListener> {
    IBOutlet EAGLView * GLView;
@private
    iosGLRenderSupport * RenderSupport;
    CADisplayLink * DisplayLink;
    CGPoint currentTouchPos;
    
    UIView * statusBar;
    BOOL statusBarVisible, statusBarIconsTheme;
    
    IBOutlet UIActivityIndicatorView * ActivityIndicator;
    IBOutlet NSLayoutConstraint * DebugViewHeight;
    IBOutlet UITableView * ConsoleLogTable;
    IBOutlet UISwitch * AutoscrollSwitch;
    IBOutlet UIView * DebugView;
    
    float DebugConsoleOriginalHeigth;
}

- (void) setRenderSupport: (iosGLRenderSupport *) renderer;
- (void) suspendDrawing;
- (void) resumeDrawing;

- (IBAction) handlePinchGesture: (UIPinchGestureRecognizer *) recognizer;
- (IBAction) handlePanGesture:(UIPanGestureRecognizer *)recognizer;
- (IBAction) copyLog: (id) sender;
- (IBAction) debugViewHeightStepperValueChanged: (UIStepper *)sender;

- (void) showActivityIndicator;
- (void) hideActivityIndicator;
- (void) setStatusBarVisible: (BOOL)visible;
- (void) setStatusBarIconsTheme: (BOOL)light;
- (void) setStatusBarColor: (UIColor*)color;
@end
