#import "EAGLView.h"
#import "EAGLViewController.h"

#define FRAME_INTERVAL 1 // FPS is supposed to be 60 for any device
#define AUTOLOCK_DELAY 2 // mins

@interface EAGLViewController ()
@property (nonatomic, retain) EAGLContext *context;
@end

@implementation EAGLViewController

@synthesize context;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    RenderSupport = NULL;
    DisplayLink = nil;
    
    iosAppDelegate * app = [UIApplication sharedApplication].delegate;
    
    if (app.DbgConsoleOn) {
        [DebugLog sharedLog].delegate = self;
        CGSize view_size = self.view.frame.size;
        DebugConsoleOriginalHeigth = MIN(view_size.height, view_size.width) / 2.0;
        DebugViewHeight.constant = DebugConsoleOriginalHeigth;
    } else {
        DebugViewHeight.constant = 0.0; // Hide console
        DebugView.hidden = YES;
    }
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        [[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(keyboardDidShow:) name: UIKeyboardDidShowNotification object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(keyboardWillHide:) name: UIKeyboardWillHideNotification object: nil];
    }
    
    statusBarVisible = YES;
    statusBar = nil;
    statusBarIconsTheme = NO;
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void) viewDidAppear:(BOOL)animated {
    [self resumeDrawing];
}

- (void) viewWillDisappear:(BOOL)animated {
    [self suspendDrawing];
}

- (void)viewDidLayoutSubviews {
    static BOOL first_layout = YES;
    if (first_layout) {
        first_layout = NO;
        iosAppDelegate * app = [UIApplication sharedApplication].delegate;
        [app EAGLViewLoaded: self glView: GLView];
    }
    
    if (RenderSupport) RenderSupport->resizeGLSurface();
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    if (RenderSupport) {
        switch(RenderSupport->getFlowUIOrientation()) {
            case FlowUILandscape: return UIInterfaceOrientationMaskLandscape;
            case FlowUIPortrait: return UIInterfaceOrientationMaskPortrait;
            default: ;
        }
    }

    return UIInterfaceOrientationMaskAll;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    if (statusBar == nil) {
        return;
    }
    
    if (@available(iOS 13.0, *)) {
        CGRect frame = [UIApplication sharedApplication].keyWindow.windowScene.statusBarManager.statusBarFrame;
        [statusBar setFrame: frame];
    }
}

- (void) keyboardDidShow: (NSNotification*) aNotification {
    if (!RenderSupport)
        return;
    
    FlowUITextView * focused = RenderSupport->activeTextWidget;
    if (focused != nil) {
        NSDictionary* info = [aNotification userInfo];
        CGFloat kb_rect_height = [self.view convertRect: [[info objectForKey: UIKeyboardFrameEndUserInfoKey] CGRectValue] fromView: self.view.window].size.height;
        
        if (RenderSupport->isKeyboardListenersAttached()) {
            RenderSupport->dispatchKeyboardHeight(kb_rect_height);
            return;
        }
        
        CGFloat kb_origin = self.view.frame.size.height - kb_rect_height;
        CGFloat space_above_kb_center = kb_origin / 2.0;
        
        CGRect focused_rect = focused.scrollHorizontalView.frame;
        CGFloat focused_center = focused_rect.origin.y + focused_rect.size.height / 2.0;

        CGFloat shift = MAX(space_above_kb_center - focused_center, -kb_rect_height);
        
        if (shift < 0.0)
            self.view.transform = CGAffineTransformMakeTranslation(0.0, shift);
    }
}

- (void) keyboardWillHide: (NSNotification*) aNotification {
    if (!RenderSupport)
        return;
    
    RenderSupport->dispatchKeyboardHeight(0.0);
    self.view.transform = CGAffineTransformIdentity;
}

static bool gestureBeingHandledByFlow = false;
- (IBAction) handlePinchGesture: (UIPinchGestureRecognizer *) recognizer {
    static CGPoint old_center;
    static CGFloat old_scale = 1.0f;
    
    CGPoint current_center = [recognizer locationInView: self.view];
    
    float screen_scale = GLView.contentScaleFactor;
    current_center.x *= screen_scale; current_center.y *= screen_scale;
    
    if ([recognizer state] == UIGestureRecognizerStateBegan) {
        old_center = current_center;
    }
    
    if (RenderSupport) {
        bool handled_by_flow = RenderSupport->sendPinchGestureEvent([recognizer state], current_center, recognizer.scale);
        
        if (!handled_by_flow && [recognizer state] != UIGestureRecognizerStateBegan) {
            CGFloat df = recognizer.scale / old_scale;
            RenderSupport->adjustGlobalScale(old_center, current_center, df);
        }
        
        if ([recognizer state] == UIGestureRecognizerStateBegan && handled_by_flow)
            gestureBeingHandledByFlow = true;
    }
    
    old_center = current_center;
    old_scale = recognizer.scale;
}

- (IBAction) handlePanGesture:(UIPanGestureRecognizer *)recognizer {
    CGPoint location = [recognizer locationInView: self.view];
    
    bool handled_by_flow = false;
    if (RenderSupport != NULL) {
        CGPoint translation = [recognizer translationInView: self.view];
        handled_by_flow = RenderSupport->sendPanGestureEvent([recognizer state], location, translation);
        
        if ([recognizer state] == UIGestureRecognizerStateBegan && handled_by_flow)
            gestureBeingHandledByFlow = true;
        
        [recognizer setTranslation: CGPointMake(0, 0) inView: self.view];
    }
}

- (void) drawFrame {
    if (RenderSupport) RenderSupport->paintGL();
}

- (void) setRenderSupport: (iosGLRenderSupport *) renderer {
    RenderSupport = renderer;
}

// Emulate mouse events
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch * touch = [touches anyObject];
    if (RenderSupport) {
        currentTouchPos = [touch locationInView: self.view];
        RenderSupport->mousePressEvent(currentTouchPos.x, currentTouchPos.y);
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch * touch = [touches anyObject];
    if (RenderSupport && !gestureBeingHandledByFlow) {
        currentTouchPos = [touch locationInView: self.view];
        RenderSupport->mouseMoveEvent(currentTouchPos.x, currentTouchPos.y);
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch * touch = [touches anyObject];
    if (RenderSupport) {
        if (!gestureBeingHandledByFlow) {
            CGPoint pos = [touch locationInView: self.view];
            RenderSupport->mouseReleaseEvent(pos.x, pos.y);
        } else {
            gestureBeingHandledByFlow = false;
        }
    }
    
    [self extendIdleTimerTimeout];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded: touches withEvent: event]; // send mouseup too
}

// Disable idle timer for a fixed amount of time.
- (void) extendIdleTimerTimeout {
    // Cancel previous scheduled messages to turn idle timer back on
    [NSObject cancelPreviousPerformRequestsWithTarget: self
                                             selector: @selector(reenableIdleTimer)
                                               object: nil];
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    [self performSelector:@selector(reenableIdleTimer) withObject:nil afterDelay: AUTOLOCK_DELAY * 60];
}

- (void) reenableIdleTimer {
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
}

- (void) suspendDrawing {
    glFinish();
    [DisplayLink removeFromRunLoop:[NSRunLoop currentRunLoop] forMode: NSDefaultRunLoopMode];
    [DisplayLink release];
    DisplayLink = nil;
}

- (void) resumeDrawing {
    if (DisplayLink == nil) {
        DisplayLink = [[self.view.window.screen displayLinkWithTarget: self selector: @selector(drawFrame)] retain];
        DisplayLink.frameInterval = FRAME_INTERVAL;
        [DisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode: NSDefaultRunLoopMode];
    }
}

- (void) showActivityIndicator {
    [ActivityIndicator startAnimating];
}

- (void) hideActivityIndicator {
    
    [ActivityIndicator stopAnimating];
}

- (UIViewController *)childViewControllerForStatusBarHidden {
    return nil; // or viewControllers.first
}

- (BOOL)prefersStatusBarHidden {
    return !statusBarVisible;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return statusBarIconsTheme ? UIStatusBarStyleLightContent : UIStatusBarStyleDefault;
}

- (void) setStatusBarVisible: (BOOL)visible {
    statusBarVisible = visible;
    if (statusBar != nil) {
        if (visible) {
            [[UIApplication sharedApplication].keyWindow addSubview: statusBar];
        } else {
            [statusBar removeFromSuperview];
        }
    }
    
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void) setStatusBarIconsTheme: (BOOL)light {
    statusBarIconsTheme = light;
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void) setStatusBarColor: (UIColor*)color {
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"13.0")) {
        CGRect frame = [UIApplication sharedApplication].keyWindow.windowScene.statusBarManager.statusBarFrame;
        statusBar = [[UIView alloc]initWithFrame:frame];
        statusBar.backgroundColor =  color;
        
        if (statusBarVisible) {
            [[UIApplication sharedApplication].keyWindow addSubview: statusBar];
        }
    } else {
        UIView *bar = [[UIApplication sharedApplication] valueForKeyPath:@"statusBarWindow.statusBar"];
        bar.backgroundColor = color;
    }
}

#pragma mark Debug console methods
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [DebugLog sharedLog].LogMessages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *simpleTableIdentifier = @"SimpleTableItem";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: simpleTableIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
    }
    
    cell.textLabel.text = [[DebugLog sharedLog].LogMessages objectAtIndex: indexPath.row];
    
    return cell;
}

- (void) logUpdated {
    // 0.5 s timeout
    [NSObject cancelPreviousPerformRequestsWithTarget: self];
    [self performSelector: @selector(refreshConsoleTable) withObject: nil afterDelay: 0.5];
}

- (IBAction) copyLog: (id) sender {
    NSString * log = [[DebugLog sharedLog].LogMessages componentsJoinedByString: @"\n"];
    UIPasteboard * pb = [UIPasteboard generalPasteboard];
    [pb setString: log];
}

- (void) refreshConsoleTable {
    [ConsoleLogTable reloadData];
    if (AutoscrollSwitch.on) {
        [ConsoleLogTable scrollRectToVisible:CGRectMake(0, ConsoleLogTable.contentSize.height - ConsoleLogTable.bounds.size.height, ConsoleLogTable.bounds.size.width, ConsoleLogTable.bounds.size.height) animated:YES];
    }
}

- (IBAction) debugViewHeightStepperValueChanged: (UIStepper *)sender {
    double height = [sender value] / 100.0 * DebugConsoleOriginalHeigth;
    DebugViewHeight.constant = height;
}
@end
