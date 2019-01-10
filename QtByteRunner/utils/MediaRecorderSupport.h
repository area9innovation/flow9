#ifndef MEDIARECORDERSUPPORT_H
#define MEDIARECORDERSUPPORT_H

#include "core/ByteCodeRunner.h"

class MediaRecorderSupport : public NativeMethodHost
{
public:
    MediaRecorderSupport(ByteCodeRunner *Runner);
protected:
    NativeFunction *MakeNativeFunction(const char *name, int num_args);
private:
    virtual void recordMedia(unicode_string websocketUri, unicode_string filePath, int timeslice, unicode_string videoMimeType,
                            bool recordAudio, bool recordVideo, unicode_string videoDeviceId, unicode_string audioDeviceId,
                            int cbOnWebsocketErrorRoot, int cbOnRecorderReadyRoot,
                            int cbOnMediaStreamReadyRoot, int cbOnRecorderErrorRoot) {}

    virtual void initializeDeviceInfo(int OnDeviceInfoReadyRoot) {}
    virtual void getAudioInputDevices(int OnDeviceInfoReadyRoot) {}
    virtual void getVideoInputDevices(int OnDeviceInfoReadyRoot) {}

    virtual void startMediaRecorder(StackSlot recorder, int timeslice) {}
    virtual void resumeMediaRecorder(StackSlot recorder) {}
    virtual void pauseMediaRecorder(StackSlot recorder) {}
    virtual void stopMediaRecorder(StackSlot recorder) {}

    DECLARE_NATIVE_METHOD(makeMediaRecorder)
    DECLARE_NATIVE_METHOD(initDeviceInfo)
    DECLARE_NATIVE_METHOD(requestAudioInputDevices)
    DECLARE_NATIVE_METHOD(requestVideoInputDevices)
    DECLARE_NATIVE_METHOD(startRecording)
    DECLARE_NATIVE_METHOD(resumeRecording)
    DECLARE_NATIVE_METHOD(pauseRecording)
    DECLARE_NATIVE_METHOD(stopRecording)
};

#endif // MEDIARECORDERSUPPORT_H
