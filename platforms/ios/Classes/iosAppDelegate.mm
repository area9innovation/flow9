#import "iosAppDelegate.h"
#import "BytecodeViewController.h"
#import "WebCacheProtocol.h"
#import "DeviceInfo.h"
#import <iostream>

#ifdef HOCKEY_APP_ID
//#import <HockeySDK/HockeySDK.h>
#endif

#ifdef LOCALYTICS_APP_KEY
/*
 To use in-app notifications successfully, please switch on push notifications:
 
 In Xcode, select your project and click on your target.
 Select the Capabilities tab.
 Turn on Background Modes and enable Remote Notifications.
 */
#import <Localytics/Localytics.h>
#endif

using namespace std;

@interface iosAppDelegate (Private)
- (void) initApplication: (NSURL *) bytecodeUrl;
- (void) initFlowRunner;
- (void) runFlowProgram;
- (void) startBytecodeFile: (NSString*) path;
@end

@implementation iosAppDelegate

@synthesize window;
@synthesize DefaultURLParameters;
@synthesize DbgConsoleOn;

- (void) redirectCoutToLog {
    cout.rdbuf(new IOSLogStreambuf());
    cout.unsetf(std::ios_base::unitbuf);
    cout << "cout redirected to log" << endl;
    
    // Dont show StaticBuffer, GC etc in the console for now
    //cerr.rdbuf(new IOSLogStreambuf()); cerr.unsetf(std::ios_base::unitbuf);
    //cerr << "cerr redirected to log" << endl;
}

- (void) readAppPreferences {
    self.DbgConsoleOn = [[NSUserDefaults standardUserDefaults] boolForKey:@"flow_console"];
    
    NSString * overridden_base_url = [[NSUserDefaults standardUserDefaults] stringForKey:@"base_url"];
    if (overridden_base_url && ![overridden_base_url isEqualToString:@""]) {
        LogI(@"Override base URL from the app settings with: %@", overridden_base_url);
        [URLLoader setBaseURL: overridden_base_url];
    }
    
#ifdef ACCESSIBLE
    accessible = YES;
#else
    accessible = [[NSUserDefaults standardUserDefaults] boolForKey:@"accessibility"];
#endif
}

#pragma mark Application messages

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions: (NSDictionary *)launchOptions {
    LogI(@"didFinishLaunchingWithOptions");
    
    window.accessibilityLabel = @"Flow Main Window";
    [self redirectCoutToLog];
    [self readAppPreferences];
    self.DefaultURLParameters = @"";
    localNotificationWakingUpId = -1;
    
        
    LogI(@"application: updating the standardUserDefaults");
    
    NSString  *mainBundlePath = [[NSBundle mainBundle] bundlePath];
    NSString  *settingsPropertyListPath = [mainBundlePath
                                           stringByAppendingPathComponent:@"Settings.bundle/Root.plist"];
    
    NSDictionary *settingsPropertyList = [NSDictionary
                                          dictionaryWithContentsOfFile:settingsPropertyListPath];
    
    NSMutableArray      *preferenceArray = [settingsPropertyList objectForKey:@"PreferenceSpecifiers"];
    NSMutableDictionary *registerableDictionary = [NSMutableDictionary dictionary];
    
    for (int i = 0; i < [preferenceArray count]; i++)  {
        NSString  *key = [[preferenceArray objectAtIndex:i] objectForKey:@"Key"];
        
        if (key)  {
            id  value = [[preferenceArray objectAtIndex:i] objectForKey:@"DefaultValue"];
            [registerableDictionary setObject:value forKey:key];
        }
    }
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:registerableDictionary];
    [[NSUserDefaults standardUserDefaults] synchronize];


#ifdef LOCALYTICS_APP_KEY
    // Localytics API key is defined in project properties.
    // There can be different apps with different keys, please change project settins.
    NSString * localyticsKey = LOCALYTICS_APP_KEY;

    [Localytics autoIntegrate: localyticsKey
        withLocalyticsOptions:@{
                                LOCALYTICS_WIFI_UPLOAD_INTERVAL_SECONDS: @5,
                                LOCALYTICS_GREAT_NETWORK_UPLOAD_INTERVAL_SECONDS: @10,
                                LOCALYTICS_DECENT_NETWORK_UPLOAD_INTERVAL_SECONDS: @30,
                                LOCALYTICS_BAD_NETWORK_UPLOAD_INTERVAL_SECONDS: @90
                                }
        launchOptions:launchOptions];
    
    if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        UIUserNotificationType types = (UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound);
        UIUserNotificationSettings * settings = [UIUserNotificationSettings settingsForTypes: types categories: nil];
        [application registerUserNotificationSettings: settings];
        [application registerForRemoteNotifications];
    } else {
        [application registerForRemoteNotificationTypes: (UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound)];
    }
#endif

#ifdef HOCKEY_APP_ID
//    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier: HOCKEY_APP_ID];
//    [[BITHockeyManager sharedHockeyManager] startManager];
//    [[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation];
#endif
    // Crashes handling is enabled by default
    
    // check if local notification was clicked
    if ([launchOptions objectForKey: UIApplicationLaunchOptionsLocalNotificationKey]) {
        UILocalNotification * notification = [launchOptions objectForKey: UIApplicationLaunchOptionsLocalNotificationKey];
        if ([notification.userInfo objectForKey: @"flowLocalNotificationId"]) {
            localNotificationWakingUpId = [[notification.userInfo objectForKey: @"flowLocalNotificationId"] intValue];
            //[[UIApplication sharedApplication] setApplicationIconBadgeNumber: 0];
        }
    }
    

    // Should launch view directly only if was not launched by external app
    if ([launchOptions objectForKey: UIApplicationLaunchOptionsURLKey])
        [self tryToLoadBytecodeByInitUrlAndRun: (NSURL*)[launchOptions objectForKey: UIApplicationLaunchOptionsURLKey]];
    else
        [self LaunchStartingViewController];

    return YES;
}

-(void)tryToLoadBytecodeByInitUrlAndRun: (NSURL*)url {
    // Should work only for generic target
#if defined(BYTECODE_FILE) || defined(COMPILED_FLOW)
    [self LaunchStartingViewController];
#else
    NSString* bc_url = nil;
    NSString* query = [url query];
    
    // Setting up URL parameters given by loader URL
    if (query) {
        LogI(@"URL parameters by loader URL: %@", query);
        self.DefaultURLParameters = query;
    }
    
    for (NSString *param in [query componentsSeparatedByString:@"&"]) {
        NSArray *elts = [param componentsSeparatedByString:@"="];
        if([elts count] < 2) continue;
        if ([[elts firstObject] isEqualToString:@"bytecode"])
            bc_url = [[elts lastObject] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
    
    if (bc_url) {
        self.bcUrlForBytecodeViewer = bc_url;
    }
    
    [self LaunchStartingViewController];
#endif
}

- (void)LaunchStartingViewController
{
    NSString *storyboardID = @"EAGL View Controller";
#if defined(BYTECODE_FILE)
    LogI(@"Bundled target (bytecode)");
    self.BytecodeFilePath = [[NSBundle mainBundle] pathForResource: BYTECODE_FILE ofType:@"b"];
#elif defined(COMPILED_FLOW)
    LogI(@"Bundled target (native)");
#else
    LogI(@"Generic target");
    NSString *BytecodeFilePath = [[[NSProcessInfo processInfo] environment] valueForKey:@"BYTECODE_PATH"];
    if (BytecodeFilePath) {
        self.BytecodeFilePath = BytecodeFilePath;
    } else if (self.bcUrlForBytecodeViewer) {
        storyboardID = @"Bytecode Load Controller";
    } else if (urlToOpen == nil) {
        storyboardID = @"Bytecode View Controller";
    } else {
        self.BytecodeFilePath = [urlToOpen path];
    }
#endif

    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Generic" bundle:nil];
    UIViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:storyboardID];
    self.window.rootViewController = viewController;
    [self.window makeKeyAndVisible];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    LogI(@"application: openURL: %@", url);
    urlToOpen = [url retain];
    
    if ([self isCustomFileTypeUrl: urlToOpen]) {
        // Awaked from background? notify immediately
        if (Runner != NULL) Runner->NotifyCustomFileTypeOpened(NS2UNICODE([urlToOpen path]));
        // else notify after running flow main
        return YES;
    }

#if defined(BYTECODE_FILE) || defined(COMPILED_FLOW)
    
    NSString * url_parameters = [url query];
    url_parameters = url_parameters == nil ? @"" : url_parameters;

    if ( self.BytecodeFilePath != nil) { // The app is already running in background
         if (![url_parameters isEqualToString: self.DefaultURLParameters]) { // Do not restart for the same data
             self.DefaultURLParameters = url_parameters;
             [self restartRunner];
         }
    } else {
        self.DefaultURLParameters = url_parameters;
    }
#endif
    
    return YES;
}

- (BOOL) isCustomFileTypeUrl: (NSURL*) url {
    return [url isFileURL] && ![[url pathExtension] isEqualToString:@"bytecode"];
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity
 restorationHandler:(void (^)(NSArray *restorableObjects))restorationHandler {
    if ([userActivity.activityType isEqualToString: NSUserActivityTypeBrowsingWeb]) {
        NSURL *url = [userActivity webpageURL];
        LogI(@"application: continueUserActivity: %@", url);
        urlToOpen = [url retain];
        
#if defined(BYTECODE_FILE) || defined(COMPILED_FLOW)
        NSString * url_parameters = [url query];
        url_parameters = url_parameters == nil ? @"" : url_parameters;
        
        if ( self.BytecodeFilePath != nil) { // The app is already running in background
            self.DefaultURLParameters = url_parameters;
            [self restartRunner];
        }
#endif
        return YES;
    }
    
    return NO;
}

- (void)sendFirebaseMessage:(NSString *)messageId body:(NSString *)body title:(NSString *)title from:(NSString *)from stamp:(NSUInteger)stamp data:(NSDictionary *) data {
    STL_HASH_MAP<unicode_string, unicode_string> dataMap;
    for (NSString* key in data) {
        dataMap[NS2UNICODE(key)] = NS2UNICODE([data objectForKey:key]);
    }
    
    NotificationsSupport->deliverFBMessage(NS2UNICODE(messageId), NS2UNICODE(body), NS2UNICODE(title), NS2UNICODE(from), (long)stamp, dataMap);
}

- (void)sendFirebaseToken:(NSString *)token {
    NotificationsSupport->deliverFBToken(NS2UNICODE(token));
}

static enum { RemoteNotificationsNotCalled, RemoteNotificationsSuccess, RemoteNotificationsFail } RemoteNotificationState = RemoteNotificationsNotCalled;

- (void)scheduleExecuteAllRequestPermissionCallbacks: (BOOL) success {
    RemoteNotificationState = success ? RemoteNotificationsSuccess : RemoteNotificationsFail;
}

-(void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
    // Looks like in iOS 8 we should call registerForRemoteNotifications from here
    if (notificationSettings.types != UIUserNotificationTypeNone) {
        [application registerForRemoteNotifications];
        [self scheduleExecuteAllRequestPermissionCallbacks: true];
    } else {
        [self scheduleExecuteAllRequestPermissionCallbacks: false];
    }
}

// Next 2 methods, for older iOS versions, to be sure that callbacks will be called
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    [self scheduleExecuteAllRequestPermissionCallbacks: true];
}

static BOOL sheduledFailToRegisterForRemoteNotifications = NO;

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    LogI(@"didFailToRegisterForRemoteNotificationsWithError : %@", err.description);
    [self scheduleExecuteAllRequestPermissionCallbacks: false];
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    NotificationsSupport->onNotificationClickHandle(notification);
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    LogI(@"applicationDidEnterBackground");
    [GLViewController suspendDrawing];
    if (Runner) Runner->NotifyPlatformEvent(PlatformApplicationSuspended);
    
    //[window endEditing: YES]; // Close screen kbd to avoid bugs for WKWebView when top portion of kbd was shown after resuming
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    LogI(@"applicationWillEnterForeground");
    if (Runner) Runner->NotifyPlatformEvent(PlatformApplicationResumed);
    [GLViewController resumeDrawing];
}

- (void) applicationWillTerminate: (UIApplication *)application {
    LogI(@"applicationWillTerminate");
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    LogW(@"Application did receive memory warning");
    LogW(@"Cache stats: mem %lu/%lu disk %lu/%lu",
        (unsigned long)[NSURLCache sharedURLCache].currentMemoryUsage,
        (unsigned long)[NSURLCache sharedURLCache].memoryCapacity,
        (unsigned long)[NSURLCache sharedURLCache].currentDiskUsage ,
        (unsigned long)[NSURLCache sharedURLCache].diskCapacity
    );
    if (Runner) {
        Runner->NotifyPlatformEvent(PlatformLowMemory);
        LogW(@"Force GC");
        Runner->ForceGC(0, true);
    }
}

- (void) EAGLViewLoaded: (EAGLViewController *) controller glView: (EAGLView*) glview {
    GLViewController = controller;
    GLView = glview;
    
    [self initFlowRunner];
    
    // TO DO : may be there is better way to get it
    WKWebView *web_view = [[WKWebView alloc] initWithFrame:CGRectZero];
    
    [web_view evaluateJavaScript:@"navigator.userAgent" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        if ([result isKindOfClass:[NSString class]]) {
            NSString* current_ua = (NSString*)result;
            #if defined(APP_VISIBLE_NAME) && defined(APP_VERSION)
                 NSString* ua = [NSString stringWithFormat: @"%@ [%@/v%@]", current_ua, APP_VISIBLE_NAME, APP_VERSION];
            #else
                 NSString* ua = [NSString stringWithFormat: @"%@ %@", current_ua, @"FlowRunner"];
            #endif
            
            NSDictionary * defs = [NSDictionary dictionaryWithObjectsAndKeys: ua, @"FlowUserAgent", nil];
            [[NSUserDefaults standardUserDefaults] registerDefaults: defs];
            LogI(@"User-Agent for WebViews : %@", ua);
        }

        [web_view release];
    }];
}

- (void) initFlowRunner
{
    [GLViewController showActivityIndicator];
    
    LogI(@"Initializing bytecode runner");
    
    NSUserDefaults * standardUserDefaults = [NSUserDefaults standardUserDefaults];
    NSInteger max_heap_size = [standardUserDefaults integerForKey: @"max_heap_size"];
    if (max_heap_size > 0) {
        LogI(@"MAX_HEAP_SIZE from user settings: %u Mb", max_heap_size);
        MAX_HEAP_SIZE = 1024 * 1024 * max_heap_size;
    }
   
    Runner = new ByteCodeRunner();
    
    // Set network state
    Runner->NotifyPlatformEvent( [URLLoader hasConnection] ? PlatformNetworkOnline : PlatformNetworkOffline );
    
    LocalStore = new FileLocalStore(Runner);
    
    // Init local storage
    NSString * flow_local_storage_path = [applicationLibraryDirectory() stringByAppendingString: @"/flow-local-store/" ];
    if (![[NSFileManager defaultManager] fileExistsAtPath: flow_local_storage_path]) {
        [[NSFileManager defaultManager]
            createDirectoryAtPath: flow_local_storage_path withIntermediateDirectories: YES attributes: nil error: nil];
        // Do not sync the storage with iCloud
        [URLLoader addSkipBackupAttributeToItemAtURL: [NSURL fileURLWithPath: flow_local_storage_path isDirectory: YES]];
        LogI(@"Flow local storage created");
    }
    LogI(@"Flow local storage path: %@", flow_local_storage_path);
    LocalStore->SetBasePath( [flow_local_storage_path UTF8String] );
    
    // Copy www bundle to Library to access preloaded content
    NSString* wwwTargetDirectory = [applicationLibraryDirectory() stringByAppendingString: @"/www/"];
    NSURL* wwwSourceDirectoryUrl = [[[NSBundle mainBundle] resourceURL] URLByAppendingPathComponent:@"www"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:wwwTargetDirectory]) {
        NSError *copyError = nil;
        [[NSFileManager defaultManager] copyItemAtPath:[wwwSourceDirectoryUrl path] toPath:wwwTargetDirectory error:&copyError];
    }
    

    CFURLRef cwd = (CFURLRef)[NSURL fileURLWithPath: flow_local_storage_path isDirectory: YES];
    char path[PATH_MAX];
    if (CFURLGetFileSystemRepresentation(cwd, TRUE, (UInt8 *)path, PATH_MAX)) {
        LogI(@"cwd: %s", path);
        chdir(path);
    } else {
        LogI(@"Error setting cwd");
    }
    
    TimerSupport  = new iosTimerSupport(Runner);
    SoundSupport = new iosSoundSupport(Runner);
    LocalyticsSupport = new iosLocalyticsSupport(Runner);
    NotificationsSupport = new iosNotificationsSupport(Runner);
#ifdef NSLOCATION_WHEN_IN_USE_USAGE_DESCRIPTION
    GeolocationSupport = new iosGeolocationSupport(Runner);
#endif
#ifdef FLOW_INAPP_PURCHASE
    InAppPurchases = new AppleStorePurchase(Runner);
#endif
    WebSocketSupport = new iosWebSocketSupport(Runner);
    ClassKitSupport = new iosClassKitSupport(Runner);
#ifdef FLOW_MEDIASTREAM
    MediaStream = new iosMediaStreamSupport(Runner);
    WebRTC = new iosWebRTCSupport(Runner);
    MediaRecorder = new iosMediaRecorderSupport(Runner, WebSocketSupport);
#endif
    Printing = new iosPrintingSupport(Runner);
    FSInterface = new iosFileSystemInterface(Runner, GLViewController);
   
    NSString * resources_path = [[[NSProcessInfo processInfo] environment] valueForKey:@"MEDIA_PATH"];
    if (!resources_path)
        resources_path = [[NSBundle mainBundle] resourcePath];
    resources_path = [resources_path stringByAppendingString: @"/"];

    RenderSupport = new iosGLRenderSupport(Runner, GLView , GLViewController, GLViewController.view, [resources_path UTF8String], accessible);

    // Load fonts
    LogI(@"Loading fonts...");
    NSString * fontsPath = [resources_path stringByAppendingPathComponent:@"dfont"];
    NSError * error;
    NSArray * fontDirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:fontsPath error:&error];
    for (NSString *font in fontDirs) {
        RenderSupport->LoadFont([font UTF8String], [[@"dfont" stringByAppendingPathComponent:font] UTF8String]);
        LogI(@"Font \"%@\" loaded", font);
    }
    
    [GLViewController setRenderSupport: RenderSupport];
    
	UIDevice* thisDevice = [UIDevice currentDevice];
	NSString* encodedDeviceName = [[[[DeviceInfo getDeviceName]
		stringByReplacingOccurrencesOfString:@" " withString:@"_"]
		stringByReplacingOccurrencesOfString:@"(" withString:@"["]
		stringByReplacingOccurrencesOfString:@")" withString:@"]"];

    NSString * user_agent = [NSString stringWithFormat:@"%@/%@ iOS(%@) dpi=%d %.0fx%.0f",
							 encodedDeviceName,
							 thisDevice.systemVersion,
                             thisDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? @"iPad" : @"iPhone",
                             RenderSupport->getDPI(), [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height];
    HttpSupport = new iosHttpSupport(Runner, RenderSupport, user_agent);
    LogI(@"Set User agent for http request : %@", user_agent);
    
    LogI(@"Cache stats: mem %lu/%lu disk %lu/%lu",
         (unsigned long)[NSURLCache sharedURLCache].currentMemoryUsage,
         (unsigned long)[NSURLCache sharedURLCache].memoryCapacity,
         (unsigned long)[NSURLCache sharedURLCache].currentDiskUsage ,
         (unsigned long)[NSURLCache sharedURLCache].diskCapacity
    );
    
    [self setURLParameters]; // URL parameters from launcher view, compiler macro and app preferences
    [self setLoaderUrl];
    
    [self runFlowProgram];
}

- (void) setURLParameters
{
#ifdef DEFAULT_URL_PARAMETERS
    LogI(@"URL parameters from compiler macro: %@", DEFAULT_URL_PARAMETERS);
    [self appendUrlParametersFromString: DEFAULT_URL_PARAMETERS]; // URL parameters from compiler macro
#endif
    
    // URL parameters from App preferences
    NSUserDefaults * standardUserDefaults = [NSUserDefaults standardUserDefaults];
    NSString *url_parameters = [standardUserDefaults stringForKey:@"url_parameters"];
    LogI(@"URL parameters from user settings: %@", url_parameters);
    [self appendUrlParametersFromString: url_parameters];
    
    LogI(@"URL parameters from URL or launcher view: %@", self.DefaultURLParameters);
    [self appendUrlParametersFromString: self.DefaultURLParameters];
}

// URL Parameters from string in format "p1=v1&p2=v2" or "p1=v1 v2=v2"
- (void) appendUrlParametersFromString: (NSString *) str
{
    if (str == nil || [str length] == 0) return;
    
    STL_HASH_MAP<unicode_string, unicode_string> & params = Runner->getUrlParameterMap();

    NSString * sep = [str rangeOfString: @"&"].location != NSNotFound ? @"&" : @" ";
    NSArray * pairs = [str componentsSeparatedByString: sep];
    
    for (int i = 0; i < [pairs count]; ++i) {
        NSArray * pair = [[pairs objectAtIndex: i] componentsSeparatedByString: @"="];
        if ([pair count] == 2) {
            params[NS2UNICODE([pair objectAtIndex: 0])] =
                NS2UNICODE([[pair objectAtIndex: 1] stringByReplacingPercentEscapesUsingEncoding: NSUTF8StringEncoding]);
        }
    }
}

- (void) setLoaderUrl {
    NSString * loader_url = [[NSURL URLWithString:@"flowrunner.html" relativeToURL:[URLLoader getBaseURL]] absoluteString];
    if (![self.DefaultURLParameters isEqualToString: @""]) {
        loader_url = [loader_url stringByAppendingFormat: @"?%@", self.DefaultURLParameters];
    }
    LogI(@"Set loaderURL = %@", loader_url);
    Runner->setUrlString(NS2UNICODE(loader_url));
}

- (void) restartRunner
{
    LogI(@"restartRunner");
    [self.window endEditing: YES]; // It crashes if there is first responder. bug in iOS?
    DELAY(1000, ^{
        [self destroyRunner];
        [self initFlowRunner];
    } );
}

- (void) destroyRunner {
    delete Runner; Runner = NULL;
    delete TimerSupport; TimerSupport = NULL;
    delete HttpSupport; HttpSupport  = NULL;
    
    [GLViewController setRenderSupport: NULL];
    delete RenderSupport; RenderSupport = NULL;
    
    delete SoundSupport; SoundSupport = NULL;
    delete LocalyticsSupport; LocalyticsSupport = NULL;
#ifdef FLOW_INAPP_PURCHASE
    delete InAppPurchases; InAppPurchases = NULL;
#endif
    delete NotificationsSupport; NotificationsSupport = NULL;
#ifdef NSLOCATION_WHEN_IN_USE_USAGE_DESCRIPTION
    delete GeolocationSupport; GeolocationSupport = NULL;
#endif
#ifdef FLOW_MEDIASTREAM
    delete MediaStream; MediaStream = NULL;
    delete WebRTC; WebRTC = NULL;
    delete MediaRecorder; MediaRecorder = NULL;
#endif
}

#ifdef COMPILED_FLOW
NativeProgram *load_native_program();
#endif

- (void) runFlowProgram
{
    LogI(@"Build date : @%s", __TIMESTAMP__);
    LogI(@"Running Flow Program");

#ifdef COMPILED_FLOW
    Runner->Init(load_native_program());
    Runner->RunMain();
#else
    NSData * bytecode = [[NSData alloc] initWithContentsOfFile: self.BytecodeFilePath];
    
    if (bytecode) {
        Runner->Init((const char *)[bytecode bytes], [bytecode length]);
        Runner->RunMain();
    } else {
        LogE(@"Cannot load bytecode at %@", self.BytecodeFilePath);
    }
    
    [bytecode dealloc];
#endif
    
    [GLViewController hideActivityIndicator];
    
    [self startNetworkStateListening];
    
    if (RemoteNotificationState != RemoteNotificationsNotCalled) {
        // Now flow code is ready to be notified
        NotificationsSupport->executeAllRequestPermissionCallbacks(RemoteNotificationState == RemoteNotificationsSuccess);
    }
    
    if (localNotificationWakingUpId != -1) {
        NSString * key = [NSString stringWithFormat: @"flowLocalNotificationId_%i", localNotificationWakingUpId];
        if ([[NSUserDefaults standardUserDefaults] objectForKey: key]) {
            NSData * data = [[NSUserDefaults standardUserDefaults] objectForKey: key];
            UILocalNotification * localNotification = [NSKeyedUnarchiver unarchiveObjectWithData: data];
            NotificationsSupport->onNotificationClickHandle(localNotification);
        }
        localNotificationWakingUpId = -1;
    }
    
    // Notify openning a file
    if ([self isCustomFileTypeUrl: urlToOpen]) {
        Runner->NotifyCustomFileTypeOpened(NS2UNICODE([urlToOpen path]));
    }
}

static bool NetworkConnected = YES;
- (void) updateNetworkState: (NSTimer *)timer {
    bool cur_conn = [URLLoader hasConnection];
    if (cur_conn != NetworkConnected) {
        NetworkConnected = cur_conn;
        if (Runner) Runner->NotifyPlatformEvent(NetworkConnected ? PlatformNetworkOnline : PlatformNetworkOffline);
        LogI(@"Network state changed : %@", NetworkConnected ? @"OnLine" : @"OffLine");
    }
}

- (void) startNetworkStateListening {
    NetworkConnected = [URLLoader hasConnection];
    if (Runner) Runner->NotifyPlatformEvent(NetworkConnected ? PlatformNetworkOnline : PlatformNetworkOffline);
    
    if (CheckNetworkTimer != nil) [CheckNetworkTimer invalidate];
    CheckNetworkTimer = [NSTimer scheduledTimerWithTimeInterval: 1.0f target: self selector: @selector(updateNetworkState:) userInfo: nil repeats:YES];
}
@end
