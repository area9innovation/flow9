#include "GLPictureClip.h"

#include "core/GarbageCollector.h"
#include "core/RunnerMacros.h"

IMPLEMENT_FLOW_NATIVE_OBJECT(GLPictureClip, GLClip);

GLPictureClip::GLPictureClip(GLRenderSupport *owner, unicode_string name) :
    GLClip(owner), name(name)
{
    size_callback = error_callback = StackSlot::MakeVoid();
    pending = true;
}

void GLPictureClip::flowGCObject(GarbageCollectorFn ref)
{
    GLClip::flowGCObject(ref);
    ref << size_callback << error_callback;
}

bool GLPictureClip::flowDestroyObject()
{
    if (pending)
        owner->removePictureFromPending(this);

    return GLClip::flowDestroyObject();
}

void GLPictureClip::setCallbacks(const StackSlot &size_cb, const StackSlot &error_cb, bool only_dl)
{
    size_callback = size_cb;
    error_callback = error_cb;
    only_download = only_dl;
}

void GLPictureClip::reportError(unicode_string msg)
{
    if (!error_callback.IsVoid()) {
        RUNNER_VAR = getFlowRunner();

        RUNNER_DefSlots1(str);
        str = RUNNER->AllocateString(msg);
        RUNNER->EvalFunction(error_callback, 1, str);
    }

    pending = false;

    size_callback = error_callback = StackSlot::MakeVoid();
}

void GLPictureClip::setDownloaded()
{
    assert(only_download);

    if (!size_callback.IsVoid()) {
        RUNNER_VAR = getFlowRunner();
        RUNNER->EvalFunction(size_callback, 2, StackSlot::MakeDouble(1), StackSlot::MakeDouble(1));
    }

    pending = false;

    size_callback = error_callback = StackSlot::MakeVoid();
}

void GLPictureClip::setImage(GLTextureImage::Ptr image)
{
    this->image = image;
    wipeFlags(WipeGraphicsChanged);

    if (!size_callback.IsVoid()) {
        ivec2 size = image->getSize();

        RUNNER_VAR = getFlowRunner();
        RUNNER->EvalFunction(size_callback, 2, StackSlot::MakeDouble(size.x), StackSlot::MakeDouble(size.y));
    }

    pending = false;

    size_callback = error_callback = StackSlot::MakeVoid();
}

void GLPictureClip::computeBBoxSelf(GLBoundingBox &bbox, const GLTransform &transform)
{
    GLClip::computeBBoxSelf(bbox, transform);

    if (image)
        bbox |= transform * GLBoundingBox(vec2(0,0), vec2(image->getSize()));
}

void GLPictureClip::renderInner(GLRenderer *renderer, GLDrawSurface *surface, const GLBoundingBox &clip_box)
{
    // Actually painting - force lazy-loaded pictures
    if (image && image->isStub() && !owner->loadStubPicture(name, image)) {
        cerr << "Could not force lazy-loaded picture." << endl;
        image.reset();
    }

    if (image) {
        surface->makeCurrent();

        renderer->beginDrawFancy(vec4(0,0,0,0), true);

        glVertexAttrib4f(GLRenderer::AttrVertexColor, global_alpha, global_alpha, global_alpha, global_alpha);

        image->drawRect(renderer, vec2(0,0), vec2(image->getSize()));

        renderer->reportGLErrors("GLPictureClip::renderInner post image");
    }

    GLClip::renderInner(renderer, surface, clip_box);
}
