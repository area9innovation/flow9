#include "QtGeolocationSupport.h"
#include "core/RunnerMacros.h"

QtGeolocationSupport::QtGeolocationSupport(ByteCodeRunner *Runner)
    : AbstractGeolocationSupport(Runner)
{
}

QtGeolocationSupport::~QtGeolocationSupport()
{
}

void QtGeolocationSupport::timerEvent(QTimerEvent *event)
{
    int timerId = event->timerId();
    QHash<int, GeolocationTimeoutInfo>::iterator it = scheduledTimers.find(timerId);
    if (it == scheduledTimers.end())
    {
        killTimer(timerId);
        return;
    }
    if (it->removeAfterCall)
    {
        killTimer(timerId);
    }

    executeOnErrorCallback(it->callbacksRoot, false, GeolocationErrorTimeout, "QtByteRunner doesn't support geolocation on desktop");

    if (it->removeAfterCall)
    {
        QHash<int, int>::iterator itMapping = callbackRootToTimerId.find(it->callbacksRoot);
        if (itMapping != callbackRootToTimerId.end()) {
            callbackRootToTimerId.erase(itMapping);
        }
        scheduledTimers.erase(it);
    }
}

void QtGeolocationSupport::doGeolocationGetCurrentPosition(int callbacksRoot, bool enableHighAccuracy, double timeout, double maximumAge, std::string turnOnGeolocationMessage, std::string okButtonText, std::string cancelButtonText)
{
    executeOnErrorCallback(callbacksRoot, true, GeolocationErrorPositionUnavailable, "QtByteRunner doesn't support geolocation on desktop");
}

void QtGeolocationSupport::doGeolocationWatchPosition(int callbacksRoot, bool enableHighAccuracy, double timeout, double maximumAge, std::string turnOnGeolocationMessage, std::string okButtonText, std::string cancelButtonText)
{
    executeOnErrorCallback(callbacksRoot, false, GeolocationErrorPositionUnavailable, "QtByteRunner doesn't support geolocation on desktop");
    int timerId = startTimer(qMax(0.0, timeout));
    scheduledTimers.insert(timerId, GeolocationTimeoutInfo(callbacksRoot, false));
    callbackRootToTimerId.insert(callbacksRoot, timerId);
}

void QtGeolocationSupport::afterWatchDispose(int callbacksRoot)
{
    QHash<int, int>::iterator itMapping = callbackRootToTimerId.find(callbacksRoot);
    if (itMapping != callbackRootToTimerId.end()) {
        QHash<int, GeolocationTimeoutInfo>::iterator it = scheduledTimers.find(*itMapping);
        if (it != scheduledTimers.end()) {
            killTimer(*itMapping);
            scheduledTimers.erase(it);
        }
        callbackRootToTimerId.erase(itMapping);
    }
}
