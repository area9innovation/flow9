#ifndef GLWEBCLIP_H
#define GLWEBCLIP_H

#include "GLClip.h"
#include "GLRenderer.h"

class GLWebClip : public GLClip
{
protected:
    ivec2 size;
    unicode_string url;
    bool useCache;
    StackSlot callback, ondone;

    void computeBBoxSelf(GLBoundingBox &bbox, const GLTransform &transform);
    void flowGCObject(GarbageCollectorFn);
public:
    GLWebClip(GLRenderSupport *owner, ivec2 size, const unicode_string url, bool use_cache, const StackSlot & callback, const StackSlot & _ondone);
    unicode_string getUrl() { return url; }
    const StackSlot & getFlowCallback() { return callback; }
    bool getUseCache() { return useCache; }
    void notifyPageLoaded();
    void notifyError(std::string e);

    DEFINE_FLOW_NATIVE_OBJECT(GLWebClip, GLClip);

    DECLARE_NATIVE_METHOD(webClipHostCall);
    DECLARE_NATIVE_METHOD(webClipEvalJS);
    DECLARE_NATIVE_METHOD(setWebClipZoomable);
    DECLARE_NATIVE_METHOD(setWebClipDomains);
};

#endif // GLWEBCLIP_H
