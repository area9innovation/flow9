#ifndef GLSCHEDULE_H
#define GLSCHEDULE_H

#include "GLClip.h"
#include "GLFilter.h"
#include "GLRenderer.h"

/*
 * Schedule nodes are used to control the order in which off-screen
 * input buffers used by filters and masks are rendered.
 */

class GLScheduleNode
{
public:
    typedef shared_ptr<GLScheduleNode> Ptr;

    GLScheduleNode(GLClip *owner);
    virtual ~GLScheduleNode();

    void renderRec(GLRenderer *renderer, const GLBoundingBox &clip_box);
    void renderTo(GLRenderer *renderer, GLDrawSurface *out);

    void discard();

    void invalidateBufferCache();

    bool isReady() { return !output_box.isEmpty && output && output->isReady(); }
    GLDrawSurface *getSurface() { return isReady() ? output : NULL; }

    bool isInClip() { return in_clip; }
    void setInClip() { in_clip = true; }

protected:
    GLClip *owner;
    GLBoundingBox output_box;
    GLDrawSurface *output;
    std::vector<Ptr> inputs;

    bool in_clip;

    void retainOutput();

    virtual void freeInputs();
    virtual void doRender(GLRenderer *renderer, GLDrawSurface *out) = 0;
};

class GLClipScheduleNode : public GLScheduleNode
{
public:
    GLClipScheduleNode(GLClip *owner);

    void addInput(Ptr node);

protected:
    virtual void doRender(GLRenderer *renderer, GLDrawSurface *out);
};

class GLMaskScheduleNode : public GLScheduleNode
{
public:
    GLMaskScheduleNode(GLClip *owner, Ptr main, Ptr mask);

protected:
    virtual void doRender(GLRenderer *renderer, GLDrawSurface *out);
};

class GLBlurScheduleNode : public GLScheduleNode
{
public:
    GLBlurScheduleNode(GLClip *owner, Ptr input, GLFilter *filter);

protected:
    GLFilter *filter;

    virtual void freeInputs() { /* NOP */ }
    virtual void doRender(GLRenderer *renderer, GLDrawSurface *out);
};

class GLFilterScheduleNode : public GLScheduleNode
{
public:
    GLFilterScheduleNode(GLClip *owner, Ptr input, GLFilter *filter);

protected:
    GLFilter *filter;

    virtual void doRender(GLRenderer *renderer, GLDrawSurface *out);
};

#endif // GLSCHEDULE_H
