#ifndef GLPICTURECLIP_H
#define GLPICTURECLIP_H

#include "GLClip.h"
#include "GLRenderer.h"

#include <vector>

using namespace std;

class GLPictureClip : public GLClip
{
protected:
    static int MaxTextureSize;

    unicode_string name;
    bool only_download, pending;

    vector<vector<GLTextureBitmap::Ptr>> imageGrid;

    // ROOTS:
    StackSlot size_callback;
    StackSlot error_callback;

    void flowGCObject(GarbageCollectorFn);
    bool flowDestroyObject();

    void computeBBoxSelf(GLBoundingBox &bbox, const GLTransform &transform);

    void renderInner(GLRenderer *renderer, GLDrawSurface *surface, const GLBoundingBox &clip_box);

public:
    static void setMaxTextureSize(int size);
    GLPictureClip(GLRenderSupport *owner, unicode_string name);

    bool isOnlyDownload() { return only_download; }
    const unicode_string &getName() { return name; }

    void setCallbacks(const StackSlot &size_cb, const StackSlot &error_cb, bool only_download = false);

    void reportError(unicode_string msg);
    void setImage(GLTextureBitmap::Ptr image);
    void setDownloaded();

    DEFINE_FLOW_NATIVE_OBJECT(GLPictureClip, GLClip);
    
private:
    void setTextureGrid(GLTextureBitmap::Ptr image);
    vec2 computeImageGridSize();
    void checkNeedsSplitTexture();
    GLTextureBitmap::Ptr cropTextureBitmap(GLTextureBitmap::Ptr image, vec2 offset, vec2 size);
};

#endif // GLPICTURECLIP_H
