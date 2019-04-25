#import <UIKit/UIKit.h>
#ifdef FLOW_PUSH_NOTIFICATIONS
#import "Classes/iosFirebaseAppDelegate.h"
#else
#import "Classes/iosAppDelegate.h"
#endif


int main(int argc, char *argv[]) {
    int retVal = 0;
    
    @autoreleasepool {
        retVal = UIApplicationMain(argc, argv, nil, NSStringFromClass(
#ifdef FLOW_PUSH_NOTIFICATIONS
                                                                      [iosFirebaseAppDelegate class]
#else
                                                                      [iosAppDelegate class]
#endif
                                   ));

    }
    
    return retVal;
}
