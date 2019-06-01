#import <Foundation/Foundation.h>
#import "FlowVideoPlayerView.h"

@implementation FlowVideoPlayerView

- (void) playVideo {
    
}

- (void) pauseVideo {
    
}

- (void) seekTo: (int64_t) offset {
    
}

- (void) setVolume: (float) volume {
    
}

- (void) setRate: (float) rate {
    
}

- (void) removeFromSuperview {
    [self pauseVideo];
    
    [super removeFromSuperview];
}

- (void) dealloc {
    if (RenderingContext != nil) {
        CGContextRelease(RenderingContext);
    }
    [CoreImageContext release];
    [super dealloc];
}

- (void) renderFrameImage: (CGImageRef) cgi {
    CGRect text_rect = CGRectMake(0, 0, CGBitmapContextGetWidth(RenderingContext), CGBitmapContextGetHeight(RenderingContext));
    CGContextDrawImage(RenderingContext, text_rect, cgi);
    VideoTextureBitmap->invalidate();
}

- (void) setTargetVideoTexture: (GLTextureBitmap::Ptr) video_texture {
    VideoTextureBitmap = video_texture;
    ivec2 size = VideoTextureBitmap->getSize();
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    RenderingContext = CGBitmapContextCreate(VideoTextureBitmap->getDataPtr(), size.x, size.y, 8, 4 * size.x, cs, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(cs);
    CGContextSetInterpolationQuality(RenderingContext, kCGInterpolationNone);
    
    CGContextSetRGBFillColor(RenderingContext, 0, 0, 0, 1);
    CGContextFillRect(RenderingContext, CGRectMake(0, 0, size.x, size.y));
    
    VideoTextureBitmap->invalidate();
}
@end

