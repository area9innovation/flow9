#include "MediaRecorderSupport.h"

#include "core/RunnerMacros.h"


MediaRecorderSupport::MediaRecorderSupport(ByteCodeRunner *Runner) : NativeMethodHost(Runner)
{

}

NativeFunction *MediaRecorderSupport::MakeNativeFunction(const char *name, int num_args)
{
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "MediaRecorderSupport."

    TRY_USE_NATIVE_METHOD(MediaRecorderSupport, makeMediaRecorder, 12);

    TRY_USE_NATIVE_METHOD(MediaRecorderSupport, initDeviceInfo, 1);

    TRY_USE_NATIVE_METHOD(MediaRecorderSupport, requestAudioInputDevices, 1);

    TRY_USE_NATIVE_METHOD(MediaRecorderSupport, requestVideoInputDevices, 1);

    TRY_USE_NATIVE_METHOD(MediaRecorderSupport, startRecording, 2);

    TRY_USE_NATIVE_METHOD(MediaRecorderSupport, resumeRecording, 1);

    TRY_USE_NATIVE_METHOD(MediaRecorderSupport, pauseRecording, 1);

    TRY_USE_NATIVE_METHOD(MediaRecorderSupport, stopRecording, 1);

    return NULL;
}

StackSlot MediaRecorderSupport::makeMediaRecorder(RUNNER_ARGS)
{

    RUNNER_PopArgs8(websocketUri, filePath, timeslice, videoMimeType, recordAudio, recordVideo, videoDeviceId, audioDeviceId);
    RUNNER_CheckTag5(TString, websocketUri, filePath, videoMimeType, videoDeviceId, audioDeviceId);
    RUNNER_CheckTag1(TInt, timeslice);
    RUNNER_CheckTag2(TBool, recordAudio, recordVideo);
    int cbOnWebsocketErrorRoot = RUNNER->RegisterRoot(RUNNER_ARG(8));
    int cbOnRecorderReadyRoot = RUNNER->RegisterRoot(RUNNER_ARG(9));
    int cbOnMediaStreamReadyRoot = RUNNER->RegisterRoot(RUNNER_ARG(10));
    int cbOnRecorderErrorRoot = RUNNER->RegisterRoot(RUNNER_ARG(11));

    recordMedia(RUNNER->GetString(websocketUri), RUNNER->GetString(filePath), timeslice.GetInt(), RUNNER->GetString(videoMimeType),
                recordAudio.GetBool(), recordVideo.GetBool(), RUNNER->GetString(videoDeviceId), RUNNER->GetString(audioDeviceId),
                     cbOnWebsocketErrorRoot, cbOnRecorderReadyRoot,
                     cbOnMediaStreamReadyRoot, cbOnRecorderErrorRoot);
    RETVOID;
}

StackSlot MediaRecorderSupport::initDeviceInfo(RUNNER_ARGS)
{
    StackSlot &cbOnDeviceInfoReady = RUNNER_ARG(0);    
    int cbOnDeviceInfoReadyRoot = RUNNER->RegisterRoot(cbOnDeviceInfoReady);
    initializeDeviceInfo(cbOnDeviceInfoReadyRoot);

    RETVOID;
}

StackSlot MediaRecorderSupport::requestAudioInputDevices(RUNNER_ARGS)
{
    StackSlot &cbOnDeviceInfoReady = RUNNER_ARG(0);
    int cbOnDeviceInfoReadyRoot = RUNNER->RegisterRoot(cbOnDeviceInfoReady);
    getAudioInputDevices(cbOnDeviceInfoReadyRoot);

    RETVOID;
}

StackSlot MediaRecorderSupport::requestVideoInputDevices(RUNNER_ARGS)
{
    StackSlot &cbOnDeviceInfoReady = RUNNER_ARG(0);
    int cbOnDeviceInfoReadyRoot = RUNNER->RegisterRoot(cbOnDeviceInfoReady);
    getVideoInputDevices(cbOnDeviceInfoReadyRoot);

    RETVOID;
}

StackSlot MediaRecorderSupport::startRecording(RUNNER_ARGS)
{
    RUNNER_PopArgs2(recorder, timeslice);
    RUNNER_CheckTag1(TNative, recorder);
    RUNNER_CheckTag1(TInt, timeslice);

    startMediaRecorder(recorder, timeslice.GetInt());

    RETVOID;
}

StackSlot MediaRecorderSupport::resumeRecording(RUNNER_ARGS)
{
    RUNNER_PopArgs1(recorder);
    RUNNER_CheckTag1(TNative, recorder);

    resumeMediaRecorder(recorder);

    RETVOID;
}

StackSlot MediaRecorderSupport::pauseRecording(RUNNER_ARGS)
{
    RUNNER_PopArgs1(recorder);
    RUNNER_CheckTag1(TNative, recorder);

    pauseMediaRecorder(recorder);

    RETVOID;
}

StackSlot MediaRecorderSupport::stopRecording(RUNNER_ARGS)
{
    RUNNER_PopArgs1(recorder);
    RUNNER_CheckTag1(TNative, recorder);

    stopMediaRecorder(recorder);

    RETVOID;
}
