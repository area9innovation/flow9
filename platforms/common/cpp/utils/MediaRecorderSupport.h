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
    virtual void makeMediaRecorder(unicode_string websocketUri, unicode_string filePath, StackSlot mediaStream, int timeslice,
                            int onReadyRoot, int onErrorRoot) {}

    virtual void startMediaRecorder(StackSlot recorder, int timeslice) {}
    virtual void resumeMediaRecorder(StackSlot recorder) {}
    virtual void pauseMediaRecorder(StackSlot recorder) {}
    virtual void stopMediaRecorder(StackSlot recorder) {}

    DECLARE_NATIVE_METHOD(makeMediaRecorderFromStream)
    DECLARE_NATIVE_METHOD(startRecording)
    DECLARE_NATIVE_METHOD(resumeRecording)
    DECLARE_NATIVE_METHOD(pauseRecording)
    DECLARE_NATIVE_METHOD(stopRecording)
};

#endif // MEDIARECORDERSUPPORT_H
