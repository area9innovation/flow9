#include "MediaRecorderSupport.h"

#include "core/RunnerMacros.h"


MediaRecorderSupport::MediaRecorderSupport(ByteCodeRunner *Runner) : NativeMethodHost(Runner)
{

}

NativeFunction *MediaRecorderSupport::MakeNativeFunction(const char *name, int num_args)
{
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "MediaRecorderSupport."

    TRY_USE_NATIVE_METHOD(MediaRecorderSupport, makeMediaRecorderFromStream, 7);

    TRY_USE_NATIVE_METHOD(MediaRecorderSupport, startRecording, 2);

    TRY_USE_NATIVE_METHOD(MediaRecorderSupport, resumeRecording, 1);

    TRY_USE_NATIVE_METHOD(MediaRecorderSupport, pauseRecording, 1);

    TRY_USE_NATIVE_METHOD(MediaRecorderSupport, stopRecording, 1);

    return NULL;
}

StackSlot MediaRecorderSupport::makeMediaRecorderFromStream(RUNNER_ARGS)
{

    RUNNER_PopArgs5(websocketUri, filePath, dataCb, mediaStream, timeslice);
    RUNNER_CheckTag2(TString, websocketUri, filePath);
    RUNNER_CheckTag1(TNative, mediaStream);
    RUNNER_CheckTag1(TInt, timeslice);
    int onReadyRoot = RUNNER->RegisterRoot(RUNNER_ARG(5));
    int onErrorRoot = RUNNER->RegisterRoot(RUNNER_ARG(6));

    makeMediaRecorder(RUNNER->GetString(websocketUri), RUNNER->GetString(filePath), mediaStream, timeslice.GetInt(),
                     onReadyRoot, onErrorRoot);
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
