#ifndef GLCAMERA_H
#define GLCAMERA_H

#include "GLClip.h"
#include "GLRenderer.h"

class GLCamera : public GLClip
{
protected:
    ivec2 size;
    unicode_string filename;
    bool record, failed;
    int camID, camWidth, camHeight, camFps, recordMode;

    void update();
    void computeBBoxSelf(GLBoundingBox &bbox, const GLTransform &transform);

public:
    GLCamera(GLRenderSupport *owner, ivec2 size, int camID, int camWidth, int camHeight, float camFps, int recordMode, const StackSlot &OnReadyForRecording_cb, const StackSlot &onFailed_cb);

    enum Event {
    	RecordReady = 0, // Ready for recording
        RecordStart = 1, // Start recording
        RecordStop = 2   // Stop recording
    };

    const unicode_string &getName() { return filename; }
    bool isRecord() { return record; }
    const int &getCamID() { return camID; }
    const int &getCamWidth() { return camWidth; }
    const int &getCamHeight() { return camHeight; }
    const int &getCamFps() { return camFps; }
    const int &getRecordMode() { return recordMode; }

    void notifyError();
    void notifyReadyForRecording();
    void notifyEvent(GLCamera::Event ev);

    DEFINE_FLOW_NATIVE_OBJECT(GLCamera, GLClip);

public:
    DECLARE_NATIVE_METHOD(startRecord);
    DECLARE_NATIVE_METHOD(stopRecord);
    DECLARE_NATIVE_METHOD(addCameraStatusListener);
};

#endif // GLCAMERA_H
