#include "iosMediaRecorderSupport.h"

#include "RunnerMacros.h"
#import "utils.h"

iosMediaRecorderSupport::iosMediaRecorderSupport(ByteCodeRunner *runner) : MediaRecorderSupport(runner), owner(runner)
{
}

void iosMediaRecorderSupport::makeMediaRecorder(unicode_string websocketUri, unicode_string filePath, StackSlot mediaStream, int timeslice, int onReadyRoot, int onErrorRoot)
{
}

void iosMediaRecorderSupport::startMediaRecorder(StackSlot recorder, int timeslice)
{
}

void iosMediaRecorderSupport::resumeMediaRecorder(StackSlot recorder)
{
}

void iosMediaRecorderSupport::pauseMediaRecorder(StackSlot recorder)
{
}

void iosMediaRecorderSupport::stopMediaRecorder(StackSlot recorder)
{
}
