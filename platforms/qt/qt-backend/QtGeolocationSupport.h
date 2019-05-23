#ifndef QTGEOLOCATIONSUPPORT_H
#define QTGEOLOCATIONSUPPORT_H

#include <QObject>
#include <QTimerEvent>
#include <QHash>
#include "core/ByteCodeRunner.h"
#include "utils/AbstractGeolocationSupport.h"

class QtGeolocationSupport : public QObject, public AbstractGeolocationSupport
{
    Q_OBJECT

public:
    QtGeolocationSupport(ByteCodeRunner* runner);
    ~QtGeolocationSupport();

    struct GeolocationTimeoutInfo
    {
        int callbacksRoot;
        bool removeAfterCall;

        GeolocationTimeoutInfo(int callbacksRoot, bool removeAfterCall)
            : callbacksRoot(callbacksRoot), removeAfterCall(removeAfterCall) {
        }
    };

    QHash<int, int> callbackRootToTimerId; // callbacksRoot -> timerId
    QHash<int, GeolocationTimeoutInfo> scheduledTimers;

    void timerEvent(QTimerEvent*);

protected:
    virtual void doGeolocationGetCurrentPosition(int callbacksRoot, bool enableHighAccuracy, double timeout, double maximumAge, std::string turnOnGeolocationMessage, std::string okButtonText, std::string cancelButtonText);
    virtual void doGeolocationWatchPosition(int callbacksRoot, bool enableHighAccuracy, double timeout, double maximumAge, std::string turnOnGeolocationMessage, std::string okButtonText, std::string cancelButtonText);
    virtual void afterWatchDispose(int callbacksRoot);
};

#endif // QTGEOLOCATIONSUPPORT_H

