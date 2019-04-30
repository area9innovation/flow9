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
            GLTextureBitmap::Ptr bmp(new GLTextureBitmap(image_size, GL_RGBA));
            CGContext* textureContext = CGBitmapContextCreate(bmp->getDataPtr(), cg_size.width, cg_size.height, 8, cg_size.width * 4,
                                                      CGImageGetColorSpace( [image CGImage] ), kCGImageAlphaPremultipliedLast);
            CGContextDrawImage(textureContext, CGRectMake(0.0, 0.0, cg_size.width, cg_size.height), [image CGImage] );
            CGContextRelease(textureContext);
    
            [pool release];
            return bmp;
        }

    [pool release];
    return GLTextureBitmap::Ptr();
}