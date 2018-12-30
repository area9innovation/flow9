#include "GLWebClip.h"

#include "core/GarbageCollector.h"
#include "core/RunnerMacros.h"

IMPLEMENT_FLOW_NATIVE_OBJECT(GLWebClip, GLClip);

GLWebClip::GLWebClip(GLRenderSupport *owner, ivec2 size, const unicode_string url, bool use_cache, const StackSlot & callback, const StackSlot & _ondone) :
    GLClip(owner), size(size), url(url), callback(callback), useCache(use_cache), ondone(_ondone)
{
    owner->createNativeWidget(this);
}

void GLWebClip::computeBBoxSelf(GLBoundingBox &bbox, const GLTransform &transform)
{
    GLClip::computeBBoxSelf(bbox, transform);
    bbox |= transform * GLBoundingBox(vec2(0,0), vec2(size));
}

StackSlot GLWebClip::webClipHostCall(RUNNER_ARGS)
{
    RUNNER_PopArgs2(name, args);
    RUNNER_CheckTag1(TString, name);
    RUNNER_CheckTag1(TArray, args);
    return owner->webClipHostCall(this, RUNNER->GetString(name), args);
}

StackSlot GLWebClip::webClipEvalJS(RUNNER_ARGS)
{
    RUNNER_PopArgs1(code);
    RUNNER_CheckTag1(TString, code);
    return owner->webClipEvalJS(this, RUNNER->GetString(code));
}

StackSlot GLWebClip::setWebClipZoomable(RUNNER_ARGS)
{
    RUNNER_PopArgs1(zoom);
    RUNNER_CheckTag(TBool, zoom);
    
    owner->setWebClipZoomable(this, zoom);
    RETVOID;
}

StackSlot GLWebClip::setWebClipDomains(RUNNER_ARGS)
{
    RUNNER_PopArgs1(domains);
    RUNNER_CheckTag(TArray, domains);

    owner->setWebClipDomains(this, domains);
    RETVOID;
}

void GLWebClip::flowGCObject(GarbageCollectorFn ref)
{
    GLClip::flowGCObject(ref);
    ref << callback << ondone;
}

void GLWebClip::notifyPageLoaded() {
	RUNNER_VAR = getFlowRunner();
	RUNNER_DefSlots1(msg);
	msg = RUNNER->AllocateString(parseUtf8("OK"));
    RUNNER->EvalFunction(ondone, 1, msg);
}

void GLWebClip::notifyError(std::string e) {
	RUNNER_VAR = getFlowRunner();
	RUNNER_DefSlots1(msg);
	msg = RUNNER->AllocateString(parseUtf8(e));
    RUNNER->EvalFunction(ondone, 1, msg);
}
