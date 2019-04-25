#include "GLSchedule.h"

#define CACHE_OUTPUT

GLScheduleNode::GLScheduleNode(GLClip *owner)
    : owner(owner), output(NULL), in_clip(false)
{
}

GLScheduleNode::~GLScheduleNode()
{
    discard();
}

void GLScheduleNode::discard()
{
    delete output;
    output = NULL;
}

void GLScheduleNode::freeInputs()
{
    for (unsigned i = 0; i < inputs.size(); i++)
        inputs[i]->discard();
}

void GLScheduleNode::retainOutput()
{
    if (output && output->isReady()) {
        owner->setFlags(GLClip::ScheduleNodeCacheValid);
        output->retain();
    }
}

void GLScheduleNode::invalidateBufferCache()
{
    if (output) {
        if (output->isRetained()) return;

        if (output->isReady() && owner->checkFlag(GLClip::ScheduleNodeCacheValid))
            output->retain();
        else
            discard();
    }

    for (unsigned i = 0; i < inputs.size(); i++)
        inputs[i]->invalidateBufferCache();
}

void GLScheduleNode::renderRec(GLRenderer *renderer, const GLBoundingBox &clip_box)
{
    if (output && output->isReady()) return;

    discard();

    // Compute the real output bounding box and surface
    if (owner->getGlobalAlpha() <= 0.0f)
        output_box.clear();
    else {
        output_box = clip_box;
        output_box &= owner->getGlobalBBox();
    }

    if (output_box.isEmpty) return;

    // Render inputs recursively
    for (unsigned i = 0; i < inputs.size(); i++)
        inputs[i]->renderRec(renderer, output_box);

    renderer->reportGLErrors("GLScheduleNode::renderRec mid");

    // Render self
    if (!in_clip) {
        output = new GLDrawSurface(renderer, output_box, owner->getFlowStack());
        doRender(renderer, output);
#ifndef CACHE_OUTPUT
        freeInputs();
#else
        retainOutput();
#endif
    }
}

void GLScheduleNode::renderTo(GLRenderer *renderer, GLDrawSurface *out)
{
    assert(in_clip && !output);

    if (output_box.isEmpty) return;

    doRender(renderer, out);
#ifndef CACHE_OUTPUT
    freeInputs();
#endif
}

GLClipScheduleNode::GLClipScheduleNode(GLClip *owner)
    : GLScheduleNode(owner)
{
}

void GLClipScheduleNode::addInput(Ptr node)
{
    assert(node && node->isInClip());
    inputs.push_back(node);
}

void GLClipScheduleNode::doRender(GLRenderer *renderer, GLDrawSurface *out)
{
    owner->render(renderer, out, output_box, true);
}

GLMaskScheduleNode::GLMaskScheduleNode(GLClip *owner, Ptr main, Ptr mask)
    : GLScheduleNode(owner)
{
    assert(main && mask);

    inputs.push_back(main);
    inputs.push_back(mask);
}

void GLMaskScheduleNode::doRender(GLRenderer *renderer, GLDrawSurface *out)
{
    GLDrawSurface *main = inputs[0]->getSurface();
    GLDrawSurface *mask = inputs[1]->getSurface();
    if (!main || !mask) return;

    out->makeCurrent();
    renderer->renderMask(main, mask);
    renderer->reportGLErrors("GLMaskScheduleNode::doRender end");
}

GLFilterScheduleNode::GLFilterScheduleNode(GLClip *owner, Ptr input, GLFilter *filter)
    : GLScheduleNode(owner), filter(filter)
{
    assert(input);
    inputs.push_back(input);

    if (filter->needsBlurNode())
        inputs.push_back(Ptr(new GLBlurScheduleNode(owner, input, filter)));
}

void GLFilterScheduleNode::doRender(GLRenderer *renderer, GLDrawSurface *out)
{
    GLDrawSurface *main = inputs[0]->getSurface();
    GLDrawSurface *blur = (inputs.size() > 1 ? inputs[1]->getSurface() : NULL);
    if (!main) return;

    filter->render(owner, renderer, out, main, blur);
}

GLBlurScheduleNode::GLBlurScheduleNode(GLClip *owner, Ptr input, GLFilter *filter)
    : GLScheduleNode(owner), filter(filter)
{
    assert(input);
    inputs.push_back(input);
}

void GLBlurScheduleNode::doRender(GLRenderer *renderer, GLDrawSurface *out)
{
    GLDrawSurface *main = inputs[0]->getSurface();
    if (!main) return;

    filter->renderBlurNode(owner, renderer, out, main);
}
