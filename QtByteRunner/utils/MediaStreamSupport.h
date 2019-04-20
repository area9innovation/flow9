#ifndef MEDIASTREAMSUPPORT_H
#define MEDIASTREAMSUPPORT_H

#include "core/ByteCodeRunner.h"

class MediaStreamSupport : public NativeMethodHost
{
public:
    MediaStreamSupport(ByteCodeRunner *Runner, QString dirPath);
protected:
    NativeFunction *MakeNativeFunction(const char *name, int num_args);
private:

    virtual void initializeDeviceInfo(int onDeviceInfoReadyRoot) {}
    virtual void getAudioInputDevices(int onDeviceInfoReadyRoot) {}
    virtual void getVideoInputDevices(int onDeviceInfoReadyRoot) {}
    virtual void makeStream(bool recordAudio, bool recordVideo, unicode_string audioDeviceId, unicode_string videoDeviceId,
                                int onReadyRoot, int onErrorRoot) {}
    virtual void stopStream(StackSlot mediaStream) {}

    DECLARE_NATIVE_METHOD(initDeviceInfo)
    DECLARE_NATIVE_METHOD(requestAudioInputDevices)
    DECLARE_NATIVE_METHOD(requestVideoInputDevices)

    DECLARE_NATIVE_METHOD(makeMediaStream)
    DECLARE_NATIVE_METHOD(stopMediaStream)
};

#endif // MEDIASTREAMSUPPORT_H
