#ifdef NSLOCATION_WHEN_IN_USE_USAGE_DESCRIPTION

#include "iosGeolocationSupport.h"
#import "utils.h"

@implementation GeolocationDelegate

@synthesize lastKnownLocation, locationManager, singleTimeWatchers, repeatableWatches, timeoutTimers;

- (id) initWithOwner: (iosGeolocationSupport *) ownr
{
    self = [super init];
    if (self) {
        owner = ownr;
        self.lastKnownLocation = nil;
        self.singleTimeWatchers = [[NSMutableDictionary alloc] init];
        self.repeatableWatches = [[NSMutableDictionary alloc] init];
        self.timeoutTimers = [[NSMutableDictionary alloc] init];
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        authorizationRequested = NO;
        locationUpdatesRequested = NO;
        highAccuracyEnabled = YES; // next call will reset it to NO with correct settings for locationManager
        [self updateGeolocationAccuracy: NO];
    }
    return self;
}

- (void) dealloc
{
    [self cancelTimers];
    [self.timeoutTimers release];

    self.locationManager.delegate = nil;
    [self.locationManager release];
    
    [self.singleTimeWatchers removeAllObjects];
    [self.singleTimeWatchers release];
    
    [self.repeatableWatches removeAllObjects];
    [self.repeatableWatches release];
    
    [self.lastKnownLocation release];
    
    [super dealloc];
}

- (void) addWatch : (int) callbacksRoot withTimeout: (double) timeout removeAfterCall: (BOOL) singleTime enableHighAccuracy: (BOOL) enableHighAccuracy
{
    iosGeolocationWatcher * watcher = [[iosGeolocationWatcher alloc] initWithCallbacksRoot: callbacksRoot andTimeout: timeout andRemoveAfterCall: singleTime andEnableHighAccuracy: enableHighAccuracy];
    NSNumber * key = [NSNumber numberWithInt: callbacksRoot];
    [self addTimeoutTimer: watcher forKey: key];
    if (singleTime) {
        [self.singleTimeWatchers setObject: watcher forKey: key];
    } else {
        [self.repeatableWatches setObject: watcher forKey: key];
    }
    if (enableHighAccuracy) {
        [self updateGeolocationAccuracy: enableHighAccuracy];
    }
    if ([self watchersCount] == 1) {
        [self startListener];
    }
}

- (void) disposeWatcher: (int) callbacksRoots
{
    NSNumber * key = [NSNumber numberWithInt: callbacksRoots];
    if ([self.repeatableWatches objectForKey: key] != nil) {
        [self.repeatableWatches removeObjectForKey: key];
        NSTimer * timer = [self.timeoutTimers objectForKey: key];
        if (timer != nil) {
            [timer invalidate];
            [self.timeoutTimers removeObjectForKey: key];
        }
        if ([self watchersCount] == 0) {
            [self stopListener: YES];
        }
    }
}

- (void) getCurrentLocation : (int) callbacksRoot withTimeout: (double) timeout andMaximumAge: (double) maximumAge enableHighAccuracy: (BOOL) enableHighAccuracy
{
    if (self.lastKnownLocation != nil) {
        NSDate * now = [NSDate date];
        int interval = [now timeIntervalSinceDate: self.lastKnownLocation.timestamp];
        if (interval <= (int)(maximumAge / 1000.0)) {
            [self executeOnOkCallback: callbacksRoot removeAfterCall: YES forLocation: self.lastKnownLocation];
        } else {
            [self addWatch: callbacksRoot withTimeout: timeout removeAfterCall: YES enableHighAccuracy: enableHighAccuracy];
        }
    } else {
        [self addWatch: callbacksRoot withTimeout: timeout removeAfterCall: YES enableHighAccuracy: enableHighAccuracy];
    }
}

-(void)locationManager: (CLLocationManager *) manager didUpdateLocations: (NSArray *) locations
{
    [self cancelTimers];
    CLLocation * currentLocation = [locations lastObject];
    self.lastKnownLocation = currentLocation;
    for (NSNumber * key in self.singleTimeWatchers) {
        iosGeolocationWatcher * watcher = [self.singleTimeWatchers objectForKey: key];
        [self executeOnOkCallback: watcher.callbacksRoot removeAfterCall: YES forLocation: currentLocation];
    }
    [self.singleTimeWatchers removeAllObjects];
    BOOL enableHighAccuracy = NO;
    for (NSNumber * key in self.repeatableWatches) {
        iosGeolocationWatcher * watcher = [self.repeatableWatches objectForKey: key];
        [self executeOnOkCallback: watcher.callbacksRoot removeAfterCall: NO forLocation: currentLocation];
        enableHighAccuracy |= watcher.enableHighAccuracy;
        [self addTimeoutTimer: watcher forKey: key];
    }
    if (enableHighAccuracy != highAccuracyEnabled) {
        [self updateGeolocationAccuracy: enableHighAccuracy];
    }
}

- (void)locationManager: (CLLocationManager *) manager didFailWithError: (NSError *) error
{
    // ignore kCLErrorHeadingFailure for now, but this error is similar to iosGeolocationSupport::GeolocationErrorPositionUnavailable
    if (error.code == kCLErrorLocationUnknown || error.code == kCLErrorDenied) {
        [self cancelTimers];
        int errorCode = iosGeolocationSupport::GeolocationErrorPositionUnavailable;
        if (error.code == kCLErrorDenied) {
            [self stopListener: NO];
            errorCode = iosGeolocationSupport::GeolocationErrorPermissionDenied;
        }
        for (NSNumber * key in self.singleTimeWatchers) {
            iosGeolocationWatcher * watcher = [self.singleTimeWatchers objectForKey: key];
            [self executeOnErrorCallback: watcher.callbacksRoot removeAfterCall: YES withCode: errorCode andMessage: error.localizedDescription];
        }
        [self.singleTimeWatchers removeAllObjects];
        for (NSNumber * key in self.repeatableWatches) {
            iosGeolocationWatcher * watcher = [self.repeatableWatches objectForKey: key];
            [self executeOnErrorCallback: watcher.callbacksRoot removeAfterCall: NO withCode: errorCode andMessage: error.localizedDescription];
            [self addTimeoutTimer: watcher forKey: key];
        }
    }
}

- (void) locationManager: (CLLocationManager *) manager didChangeAuthorizationStatus: (CLAuthorizationStatus) status
{
    if (locationUpdatesRequested && (status == kCLAuthorizationStatusRestricted || status == kCLAuthorizationStatusDenied)) {
        [self stopListener: NO];
    } else if (!locationUpdatesRequested && ([self watchersCount] != 0) && (status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusAuthorizedAlways)) {
        [self startListener];
    }
}

+ (BOOL) isGeolocationEnabled
{
    return [CLLocationManager locationServicesEnabled];
}

+ (BOOL) isAuthorized
{
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    return (status == kCLAuthorizationStatusAuthorizedWhenInUse) || (status == kCLAuthorizationStatusAuthorizedAlways);
}

- (void) askUserForAuthorization
{
    if (!authorizationRequested && [CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
        if([[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"]) {
            [self.locationManager requestWhenInUseAuthorization];
        }
    }
}

- (unsigned long) watchersCount
{
    return [self.singleTimeWatchers count] + [self.repeatableWatches count];
}

- (void) updateGeolocationAccuracy: (BOOL) enableHighAccuracy
{
    if (enableHighAccuracy != highAccuracyEnabled) {
        highAccuracyEnabled = enableHighAccuracy;
        if (enableHighAccuracy) {
            //self.locationManager.distanceFilter = 5;
            self.locationManager.distanceFilter = kCLDistanceFilterNone;
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        } else {
            self.locationManager.distanceFilter = 10;
            self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
        }
    }
}

- (void) addTimeoutTimer: (iosGeolocationWatcher *) watcher forKey: (NSNumber *) key;
{
    NSTimer * timer = [NSTimer scheduledTimerWithTimeInterval: watcher.timeout / 1000.0 target: self selector: @selector(watchTimeoutFired:) userInfo: watcher repeats: NO];
    [self.timeoutTimers setObject: timer forKey: key];
}

- (void) watchTimeoutFired: (NSTimer *) timer
{
    iosGeolocationWatcher * watcher = timer.userInfo;
    NSNumber * key = [NSNumber numberWithInt: watcher.callbacksRoot];
    [self executeOnErrorCallback: watcher.callbacksRoot removeAfterCall: watcher.removeAfterCall withCode: iosGeolocationSupport::GeolocationErrorTimeout andMessage: @"Geolocation request timeout."];
    if (watcher.removeAfterCall) {
        [self.timeoutTimers removeObjectForKey: key];
        [self.singleTimeWatchers removeObjectForKey: key];
        if ([self watchersCount] == 0) {
            [self stopListener: YES];
        }
    } else {
        [self addTimeoutTimer: watcher forKey: key];
    }
}

- (void) cancelTimers
{
    for (NSNumber * key in self.timeoutTimers) {
        [[self.timeoutTimers objectForKey: key] invalidate]; // what if timer already invalidated by system?
    }
    [self.timeoutTimers removeAllObjects];
}

- (void) startListener
{
    if (!locationUpdatesRequested) {
        locationUpdatesRequested = YES;
        [self.locationManager startUpdatingLocation];
    }
}

- (void) stopListener: (BOOL) resetAccuracy
{
    if (locationUpdatesRequested) {
        locationUpdatesRequested = NO;
        //highAccuracyEnabled = NO;
        if (resetAccuracy) {
            [self updateGeolocationAccuracy: NO];
        }
        [self.locationManager stopUpdatingLocation];
    }
}

- (void) executeOnOkCallback: (int) callbacksRoot removeAfterCall: (BOOL) singleTime forLocation: (CLLocation *) location
{
    owner->executeOnOkCallback(callbacksRoot, singleTime, location.coordinate.latitude, location.coordinate.longitude, location.altitude, location.horizontalAccuracy, location.verticalAccuracy, location.course, location.speed, [location.timestamp timeIntervalSince1970] * 1000.0);
}

- (void) executeOnErrorCallback: (int) callbacksRoot removeAfterCall: (BOOL) singleTime withCode: (int) code andMessage: (NSString *) message
{
    owner->executeOnErrorCallback(callbacksRoot, singleTime, code, [message UTF8String]);
}
@end

@implementation iosGeolocationWatcher

@synthesize callbacksRoot, timeout, enableHighAccuracy, removeAfterCall;

- (id) initWithCallbacksRoot: (int) callbacksRootArg andTimeout: (double) timeoutArg andRemoveAfterCall: (BOOL) removeAfterCallArg andEnableHighAccuracy: (BOOL) andEnableHighAccuracyArg
{
    self = [super init];
    if (self) {
        self.callbacksRoot = callbacksRootArg;
        self.timeout = timeoutArg;
        self.removeAfterCall = removeAfterCallArg;
        self.enableHighAccuracy = andEnableHighAccuracyArg;
    }
    return self;
}
@end;

iosGeolocationSupport::iosGeolocationSupport(ByteCodeRunner *runner) : AbstractGeolocationSupport(runner)
{
    geolocationDelegate = [[GeolocationDelegate alloc] initWithOwner: this];
}

iosGeolocationSupport::~iosGeolocationSupport()
{
    [geolocationDelegate release];
}

void iosGeolocationSupport::OnRunnerReset(bool inDestructor)
{
    AbstractGeolocationSupport::OnRunnerReset(inDestructor);
}

void iosGeolocationSupport::doGeolocationGetCurrentPosition(int callbacksRoot, bool enableHighAccuracy, double timeout, double maximumAge, std::string turnOnGeolocationMessage, std::string okButtonText, std::string cancelButtonText)
{
    if ([GeolocationDelegate isGeolocationEnabled]) {
        [geolocationDelegate askUserForAuthorization];
        [geolocationDelegate getCurrentLocation: callbacksRoot withTimeout: timeout andMaximumAge: maximumAge enableHighAccuracy: enableHighAccuracy];
    }
}

void iosGeolocationSupport::doGeolocationWatchPosition(int callbacksRoot, bool enableHighAccuracy, double timeout, double maximumAge, std::string turnOnGeolocationMessage, std::string okButtonText, std::string cancelButtonText)
{
    if ([GeolocationDelegate isGeolocationEnabled]) {
        [geolocationDelegate askUserForAuthorization];
        [geolocationDelegate addWatch: callbacksRoot withTimeout: timeout removeAfterCall: NO enableHighAccuracy: enableHighAccuracy];
    }
}

void iosGeolocationSupport::afterWatchDispose(int callbacksRoot)
{
    [geolocationDelegate disposeWatcher: callbacksRoot];
}

#endif
