#ifndef iosGeolocationSupport_h
#define iosGeolocationSupport_h

#ifdef NSLOCATION_WHEN_IN_USE_USAGE_DESCRIPTION

#include "ByteCodeRunner.h"
#include "AbstractGeolocationSupport.h"
#import <CoreLocation/CoreLocation.h>

class iosGeolocationSupport;

@interface iosGeolocationWatcher : NSObject {
    int callbacksRoot;
    double timeout;
    BOOL removeAfterCall;
    BOOL enableHighAccuracy;
}

@property (nonatomic, assign) int callbacksRoot;
@property (nonatomic, assign) double timeout;
@property (nonatomic, assign) BOOL enableHighAccuracy;
@property (nonatomic, assign) BOOL removeAfterCall;

- (id) initWithCallbacksRoot: (int) callbacksRootArg andTimeout: (double) timeoutArg andRemoveAfterCall: (BOOL) removeAfterCallArg andEnableHighAccuracy: (BOOL) andEnableHighAccuracyArg;
@end;

@interface GeolocationDelegate : NSObject<CLLocationManagerDelegate> {
@private
    BOOL authorizationRequested;
    BOOL locationUpdatesRequested;
    BOOL highAccuracyEnabled;
    iosGeolocationSupport * owner;
    CLLocationManager * locationManager;
    CLLocation * lastKnownLocation;
    NSMutableDictionary * singleTimeWatchers;
    NSMutableDictionary * repeatableWatches;
    NSMutableDictionary * timeoutTimers;
}

@property (nonatomic, strong) CLLocation * lastKnownLocation;
@property (nonatomic, strong) CLLocationManager * locationManager;
@property (nonatomic, strong) NSMutableDictionary * singleTimeWatchers; // Should be atomic?
@property (nonatomic, strong) NSMutableDictionary * repeatableWatches; // Should be atomic?
@property (nonatomic, strong) NSMutableDictionary * timeoutTimers; // Should be atomic?

- (id) initWithOwner: (iosGeolocationSupport *) ownr;
- (void) addWatch : (int) callbacksRoot withTimeout: (double) timeout removeAfterCall: (BOOL) singleTime enableHighAccuracy: (BOOL) enableHighAccuracy;
- (void) disposeWatcher: (int) callbacksRoots;
- (void) getCurrentLocation : (int) callbacksRoot withTimeout: (double) timeout andMaximumAge: (double) maximumAge enableHighAccuracy: (BOOL) enableHighAccuracy;
- (void) executeOnOkCallback: (int) callbacksRoot removeAfterCall: (BOOL) singleTime forLocation: (CLLocation *) location;
- (void) executeOnErrorCallback: (int) callbacksRoot removeAfterCall: (BOOL) singleTime withCode: (int) code andMessage: (NSString *) message;
- (void) updateGeolocationAccuracy: (BOOL) enableHighAccuracy;
- (unsigned long) watchersCount;
- (void) askUserForAuthorization;
- (void) addTimeoutTimer: (iosGeolocationWatcher *) watcher forKey: (NSNumber *) key;
- (void) watchTimeoutFired: (NSTimer *) timer;
- (void) cancelTimers;
- (void) startListener;
- (void) stopListener: (BOOL) resetAccuracy;

+ (BOOL) isGeolocationEnabled;
+ (BOOL) isAuthorized;
@end;

class iosGeolocationSupport : public AbstractGeolocationSupport
{
public:
    iosGeolocationSupport(ByteCodeRunner *runner);
    ~iosGeolocationSupport();
    
protected:
    virtual void doGeolocationGetCurrentPosition(int callbacksRoot, bool enableHighAccuracy, double timeout, double maximumAge, std::string turnOnGeolocationMessage, std::string okButtonText, std::string cancelButtonText);
    virtual void doGeolocationWatchPosition(int callbacksRoot, bool enableHighAccuracy, double timeout, double maximumAge, std::string turnOnGeolocationMessage, std::string okButtonText, std::string cancelButtonText);
    virtual void afterWatchDispose(int callbacksRoot);
    virtual void OnRunnerReset(bool inDestructor);
    
private:
    GeolocationDelegate * geolocationDelegate;
    
    //bool isGeolocationEnabledAndAuthorized();
};

#endif

#endif /* iosGeolocationSupport_h */
