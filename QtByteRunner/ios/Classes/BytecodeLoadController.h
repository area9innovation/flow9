#import <UIKit/UIKit.h>
#import "URLLoader.h"
#import "iosAppDelegate.h"

@interface BytecodeLoadController : UIViewController {
    IBOutlet UIProgressView *ProgressView;
}
- (IBAction) loadAndRunBytecodeFile;

@end
