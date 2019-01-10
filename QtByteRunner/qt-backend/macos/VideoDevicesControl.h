#ifndef VIDEODEVICESCONTROL_H
#define VIDEODEVICESCONTROL_H

#include <QList>
#include "qt-backend/QMediaRecorderSupport.h"

class VideoDevicesControl
{
public:
    static QList<CameraInfo> getVideoDevices();
};
#endif // VIDEODEVICESCONTROL_H
