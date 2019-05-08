#include "MediaStreamSupport.h"

#include "core/RunnerMacros.h"

MediaStreamSupport::MediaStreamSupport(ByteCodeRunner *Runner) : NativeMethodHost(Runner)
{
}

NativeFunction *MediaStreamSupport::MakeNativeFunction(const char *name, int num_args)
{
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "MediaStreamSupport."

    TRY_USE_NATIVE_METHOD(MediaStreamSupport, initDeviceInfo, 1);

    TRY_USE_NATIVE_METHOD(MediaStreamSupport, requestAudioInputDevices, 1);

    TRY_USE_NATIVE_METHOD(MediaStreamSupport, requestVideoInputDevices, 1);

    TRY_USE_NATIVE_METHOD(MediaStreamSupport, makeMediaStream, 6);
    TRY_USE_NATIVE_METHOD(MediaStreamSupport, stopMediaStream, 1);

    return NULL;
}


StackSlot MediaStreamSupport::initDeviceInfo(RUNNER_ARGS)
{
    StackSlot &cbOnDeviceInfoReady = RUNNER_ARG(0);    
    int cbonDeviceInfoReadyRoot = RUNNER->RegisterRoot(cbOnDeviceInfoReady);
    initializeDeviceInfo(cbonDeviceInfoReadyRoot);

    RETVOID;
}

StackSlot MediaStreamSupport::requestAudioInputDevices(RUNNER_ARGS)
{
    StackSlot &cbOnDeviceInfoReady = RUNNER_ARG(0);
    int cbonDeviceInfoReadyRoot = RUNNER->RegisterRoot(cbOnDeviceInfoReady);
    getAudioInputDevices(cbonDeviceInfoReadyRoot);

    RETVOID;
}

StackSlot MediaStreamSupport::requestVideoInputDevices(RUNNER_ARGS)
{
    StackSlot &cbOnDeviceInfoReady = RUNNER_ARG(0);
    int cbonDeviceInfoReadyRoot = RUNNER->RegisterRoot(cbOnDeviceInfoReady);
    getVideoInputDevices(cbonDeviceInfoReadyRoot);

    RETVOID;
}

StackSlot MediaStreamSupport::makeMediaStream(RUNNER_ARGS)
{
    RUNNER_PopArgs4(recordAudio, recordVideo, audioDeviceId, videoDeviceId);
    RUNNER_CheckTag2(TString, audioDeviceId, videoDeviceId);
    RUNNER_CheckTag2(TBool, recordAudio, recordVideo);
    int onReadyRoot = RUNNER->RegisterRoot(RUNNER_ARG(4));
    int onErrorRoot = RUNNER->RegisterRoot(RUNNER_ARG(5));

    makeStream(recordAudio.GetBool(), recordVideo.GetBool(), RUNNER->GetString(audioDeviceId), RUNNER->GetString(videoDeviceId),
                     onReadyRoot, onErrorRoot);

    RETVOID;
}

StackSlot MediaStreamSupport::stopMediaStream(RUNNER_ARGS)
{
    RUNNER_PopArgs1(mediaStream);
    RUNNER_CheckTag1(TNative, mediaStream);

    stopStream(mediaStream);

    RETVOID;
}
