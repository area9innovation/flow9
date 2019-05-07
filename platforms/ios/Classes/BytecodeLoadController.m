#import "BytecodeLoadController.h"

@implementation BytecodeLoadController
- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self loadAndRunBytecodeFile];
    
}

- (void) dealloc {
    [ProgressView release];
    [super dealloc];
}

- (IBAction) loadAndRunBytecodeFile {
    iosAppDelegate * app =[UIApplication sharedApplication].delegate;
    
    ProgressView.progress = 0.0;
    void (^on_progress)(float p) = ^void(float p) { ProgressView.progress = p; };
    void (^on_error)(void) = ^void(void) {
        
        [[[UIAlertView alloc] initWithTitle:@"Error" message: [NSString stringWithFormat:@"Cannot download URL: %@", app.bcUrlForBytecodeViewer] delegate: self cancelButtonTitle: @"OK" otherButtonTitles: nil] show];
        
        [self performSegueWithIdentifier: @"RunBytecodeLoader" sender: self];
    };
    void (^on_success)(NSData * data) = ^void(NSData * data) {
        ProgressView.hidden = YES;
        
        app.BytecodeFilePath = [URLLoader cachePathForURL: app.bcUrlForBytecodeViewer];
        
        [self performSegueWithIdentifier: @"RunFlowViewController" sender: self];
    };
    
    URLLoader * loader = [[URLLoader alloc] initWithURL: app.bcUrlForBytecodeViewer onSuccess: on_success onError: on_error onProgress: on_progress onlyCache:YES];
    [loader start];
}

@end
