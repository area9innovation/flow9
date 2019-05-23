#ifndef iosMediaRecorderSupport_h
#define iosMediaRecorderSupport_h

#include "ByteCodeRunner.h"
#include "MediaRecorderSupport.h"
#include "iosMediaStreamSupport.h"


class iosMediaRecorderSupport : public MediaRecorderSupport
{
    ByteCodeRunner *owner;
public:
    iosMediaRecorderSupport(ByteCodeRunner *runner);
    
protected:
    void makeMediaRecorder(unicode_string websocketUri, unicode_string filePath, StackSlot mediaStream, int timeslice, int onReadyRoot, int onErrorRoot);
    
    void startMediaRecorder(StackSlot recorder, int timeslice);
    void resumeMediaRecorder(StackSlot recorder);
    void pauseMediaRecorder(StackSlot recorder);
    void stopMediaRecorder(StackSlot recorder);
};

#endif /* iosMediaRecorderSupport_h */
