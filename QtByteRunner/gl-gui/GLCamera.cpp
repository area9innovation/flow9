#include "GLCamera.h"

#include "core/GarbageCollector.h"
#include "core/RunnerMacros.h"

IMPLEMENT_FLOW_NATIVE_OBJECT(GLCamera, GLClip);

GLCamera::GLCamera(GLRenderSupport *owner, ivec2 size, int camID, int camWidth, int camHeight, float camFps, int recordMode, const StackSlot &onReadyForRecording_cb, const StackSlot &onFailed_cb) :
    GLClip(owner), size(size), camID(camID), camWidth(camWidth), camHeight(camHeight), camFps(camFps), recordMode(recordMode)
{
	addEventCallback(FlowRecordReady, onReadyForRecording_cb);
	addEventCallback(FlowRecordFailed, onFailed_cb);

	failed = false;
	record = false;
	owner->createNativeWidget(this);
}

void GLCamera::computeBBoxSelf(GLBoundingBox &bbox, const GLTransform &transform)
{
    GLClip::computeBBoxSelf(bbox, transform);

    bbox |= transform * GLBoundingBox(vec2(0,0), vec2(size));
}

void GLCamera::notifyError()
{
	cerr << "GLCamera::notifyError" << endl;
    failed = true;
    owner->destroyNativeWidget(this);

    RUNNER_VAR = getFlowRunner();
    RUNNER_DefSlotArray(args, 1);

    args[0] = RUNNER->AllocateString("NetConnection.Connect.Failed");
    invokeEventCallbacks(FlowRecordFailed, 1, args);
}

void GLCamera::notifyReadyForRecording()
{
	cerr << "GLCamera::notifyReadyForRecording" << endl;
    RUNNER_VAR = getFlowRunner();
    RUNNER_DefSlotArray(args, 1);

    args[0] = getFlowValue();
    invokeEventCallbacks(FlowRecordReady, 1, args);
}

void GLCamera::notifyEvent(GLCamera::Event ev)
{
	cerr << "GLCamera::notifyEvent" << endl;
    RUNNER_VAR = getFlowRunner();
    RUNNER_DefSlotArray(args, 1);

    const char *tag = "";

    switch (ev) {
    case RecordStart: tag = "NetStream.Record.Start"; break;
    case RecordStop:  tag = "NetStream.Record.Stop";  break;
    }

    args[0] = RUNNER->AllocateString(tag);
    invokeEventCallbacks(FlowRecordStreamEvent, 1, args);
}

void GLCamera::update()
{
	cerr << "GLCamera::update" << endl;
    if (!checkFlag(HasNativeWidget))
        return;
    cerr << "GLCamera::update end" << endl;
    owner->doUpdateCameraState(this);
}

StackSlot GLCamera::startRecord(RUNNER_ARGS)
{
	cerr << "GLCamera::startRecord:" << record << endl;
	if (record) {
		cerr << "GLCamera::startRecord: true" <<  endl;
	}else{
		cerr << "GLCamera::startRecord: false" <<  endl;
	}
    RUNNER_PopArgs2(name_str, mode_str);
    RUNNER_CheckTag2(TString, name_str, mode_str);
    filename = RUNNER->GetString(name_str);
    //mode = RUNNER->GetString(mode_str);//Ignore this parameter

    if (!record) {
    	record = true;
        update();
    }

    RETVOID;
}

StackSlot GLCamera::stopRecord(RUNNER_ARGS)
{
	cerr << "GLCamera::stopRecord" << endl;
	IGNORE_RUNNER_ARGS;

    if (record) {
    	record = false;
        update();
    }

    RETVOID;
}

StackSlot GLCamera::addCameraStatusListener(RUNNER_ARGS)
{
    RUNNER_PopArgs1(callback);

    return addEventCallback(RUNNER, FlowRecordStreamEvent, callback, "addCameraStatusListener$dispose");
}
