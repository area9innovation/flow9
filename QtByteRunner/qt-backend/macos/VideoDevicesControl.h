#ifndef VIDEODEVICESCONTROL_H
#define VIDEODEVICESCONTROL_H

#include <QList>
#include "qt-backend/QMediaStreamSupport.h"

class VideoDevicesControl
{
public:
    static QList<CameraInfo> getVideoDevices();
};
#endif // VIDEODEVICESCONTROL_H
