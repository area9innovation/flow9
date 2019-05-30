#include "VideoDevicesControl.h"

#import <AVFoundation.h>
#import <CMFormatDescription.h>

QList<CameraInfo> VideoDevicesControl::getVideoDevices()
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    QList<CameraInfo> answer;
    for (NSUInteger i=0; i < [devices count]; i++) {
        AVCaptureDevice *device = devices[i];
        CameraInfo info(QString::number(i), device.localizedName.UTF8String);
        for (AVCaptureDeviceFormat *format in [device formats]) {
            CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
            if (dimensions.width >= info.max_width && dimensions.height >= info.max_height) {
                info.max_width = dimensions.width;
                info.max_height = dimensions.height;
            }
        }
        answer.append(info);
    }
    return answer;
}
