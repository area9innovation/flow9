#import "EAGLView.h"
#import <QuartzCore/QuartzCore.h>
#import "utils.h"

@implementation EAGLView

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (id)initWithCoder:(NSCoder *) coder {
    self = [super initWithCoder: coder];

    [self checkRetina];
    self.accessibilityElements = [[NSMutableArray alloc] init];

    return self;
}

- (void) checkRetina {
    NSUserDefaults * standardUserDefaults = [NSUserDefaults standardUserDefaults];
    BOOL ignore_retina = [standardUserDefaults boolForKey:@"ignore_retina"];
    
    UIScreen * mainScreen = [UIScreen mainScreen];
    
    const CGFloat scale = [mainScreen respondsToSelector:@selector(nativeScale)] ? mainScreen.nativeScale : mainScreen.scale;
    
    if (scale > 1.0) { // Retina - we should have more pixels in renderbuffers.
        if (ignore_retina) {
            LogI(@"Retina display: Ignoring Retina high resolution");
        } else {
            LogI(@"Retina display. Content scale factor = %f", scale);
            self.contentScaleFactor = scale;
            self.layer.contentsScale = scale;
        }
    }
}

- (void)dealloc {
    [self.accessibilityElements release];
    [super dealloc];
}

- (BOOL)isAccessibilityElement {
    return NO;
}

- (NSInteger)accessibilityElementCount {
    return [self.accessibilityElements count];
}

- (id)accessibilityElementAtIndex:(NSInteger)index {
    return [self.accessibilityElements objectAtIndex: index];
}

- (NSInteger)indexOfAccessibilityElement:(id)element {
    return [self.accessibilityElements indexOfObject: element];
}

@end
