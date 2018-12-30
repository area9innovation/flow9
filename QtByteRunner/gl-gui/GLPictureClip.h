#ifndef GLPICTURECLIP_H
#define GLPICTURECLIP_H

#include "GLClip.h"
#include "GLRenderer.h"

class GLPictureClip : public GLClip
{
protected:
    unicode_string name;
    bool only_download, pending;

    GLTextureImage::Ptr image;

    // ROOTS:
    StackSlot size_callback;
    StackSlot error_callback;

    void flowGCObject(GarbageCollectorFn);
    bool flowDestroyObject();

    void computeBBoxSelf(GLBoundingBox &bbox, const GLTransform &transform);

    void renderInner(GLRenderer *renderer, GLDrawSurface *surface, const GLBoundingBox &clip_box);

public:
    GLPictureClip(GLRenderSupport *owner, unicode_string name);

    bool isOnlyDownload() { return only_download; }
    const unicode_string &getName() { return name; }

    void setCallbacks(const StackSlot &size_cb, const StackSlot &error_cb, bool only_download = false);

    void reportError(unicode_string msg);
    void setImage(GLTextureImage::Ptr image);
    void setDownloaded();

    DEFINE_FLOW_NATIVE_OBJECT(GLPictureClip, GLClip);
};

#endif // GLPICTURECLIP_H
