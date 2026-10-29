#include "ImageLoader.h"
#import <UIKit/UIKit.h>


// TO DO : SWF files
GLTextureBitmap::Ptr loadImageAuto(const uint8_t *data, unsigned size)
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    UIImage * image = [UIImage imageWithData:[NSData dataWithBytesNoCopy: (void *) data length: size] ];
    if (image)
    {
            CGSize cg_size = [image size];
            ivec2 image_size(cg_size.width , cg_size.height);
            // The bitmap is sized from the image, so refuse a size no bitmap may hold before drawing into it
            if (GLTextureBitmap::bitmapBytes(image_size, GL_RGBA) == 0) {
                NSLog(@"Image size out of range: %dx%d", image_size.x, image_size.y);
                [pool release];
                return GLTextureBitmap::Ptr();
            }
            GLTextureBitmap::Ptr bmp(new GLTextureBitmap(image_size, GL_RGBA));
            CGContext* textureContext = CGBitmapContextCreate(bmp->getDataPtr(), image_size.x, image_size.y, 8, size_t(image_size.x) * 4,
                                                      CGImageGetColorSpace( [image CGImage] ), kCGImageAlphaPremultipliedLast);
            CGContextDrawImage(textureContext, CGRectMake(0.0, 0.0, image_size.x, image_size.y), [image CGImage] );
            CGContextRelease(textureContext);
    
            [pool release];
            return bmp;
        }

    [pool release];
    return GLTextureBitmap::Ptr();
}