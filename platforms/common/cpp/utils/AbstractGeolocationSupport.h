#ifndef ABSTRACTGEOLOCATIONSUPPORT_H
#define ABSTRACTGEOLOCATIONSUPPORT_H

#include "core/ByteCodeRunner.h"

class AbstractGeolocationSupport : public NativeMethodHost {

public:
    AbstractGeolocationSupport(ByteCodeRunner *owner);

    enum GeolocationErrorCode {
        GeolocationErrorPermissionDenied = 1,
        GeolocationErrorPositionUnavailable = 2,
        GeolocationErrorTimeout = 3
    };

    void executeOnOkCallback(int callbacksRoot, bool removeAfterCall,
                             double latitude, double longitude, double altitude,
                             double accuracy, double altitudeAccuracy,
                             double heading , double speed, double time);
    void executeOnErrorCallback(int callbacksRoot, bool removeAfterCall, int code, std::string message);

protected:
    NativeFunction *MakeNativeFunction(const char *, int);
    void OnRunnerReset(bool inDestructor);
    void flowGCObject(GarbageCollectorFn);
    virtual void doGeolocationGetCurrentPosition(int callbacksRoot, bool enableHighAccuracy, double timeout, double maximumAge, std::string turnOnGeolocationMessage, std::string okButtonText, std::string cancelButtonText) = 0;
    virtual void doGeolocationWatchPosition(int callbacksRoot, bool enableHighAccuracy, double timeout, double maximumAge, std::string turnOnGeolocationMessage, std::string okButtonText, std::string cancelButtonText) = 0;
    virtual void afterWatchDispose(int callbacksRoot) = 0;

private:

    struct GeolocationCallbacksRoot {
        int onOkCbRoot, onErrorCbRoot;

        GeolocationCallbacksRoot() : onOkCbRoot(-1), onErrorCbRoot(-1) {
        }

        GeolocationCallbacksRoot(int onOkCbRoot, int onErrorCbRoot) : onOkCbRoot(onOkCbRoot), onErrorCbRoot(onErrorCbRoot) {
        }
    };

    typedef STL_HASH_MAP<int, GeolocationCallbacksRoot> T_GeolocationCallbackRoots;
    T_GeolocationCallbackRoots CallbackRoots;
    int nCallbackRoots;

    int RegisterRoot(GeolocationCallbacksRoot geolocationCallbackRoots);
    void ReleaseRoot(int i);
    void removeCallbackRoots(int callbacksRoot);
    static StackSlot removeGeolocationWatchPosition(ByteCodeRunner*, StackSlot*, void*);

    DECLARE_NATIVE_METHOD(geolocationGetCurrentPosition);
    DECLARE_NATIVE_METHOD(geolocationWatchPosition);
};

#endif // ABSTRACTGEOLOCATIONSUPPORT_H

