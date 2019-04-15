#ifndef GLFILTER_H
#define GLFILTER_H

#include "GLClip.h"

class GLFilter : public FlowNativeObject
{
protected:
    GLRenderSupport *owner;

    friend class GLClip;
    std::vector<GLClip*> clips;

    bool flowDestroyObject();

    float blur_radius; // <=0: no blur
    float blur_quality;

    float getBlurSigma(const GLTransform &transform, float radius = -1.0);

    bool needsSeparateBlur(float sigma) {
        return sigma >= 1.25f - std::min(3.0f, blur_quality) * 0.1f;
    }

    void renderBigBlur(GLRenderer *renderer, GLDrawSurface *input, GLDrawSurface *output, float sigma, bool drop_input = false);

    vec2 transformFilterShift(GLClip *clip, vec2 shift);

private:
    void computeBlurCoeffs(std::vector<float> *coeffs, std::vector<float> *deltas, float sigma, float margin);

public:
    GLFilter(GLRenderSupport *owner);

    DEFINE_FLOW_NATIVE_OBJECT(GLFilter, FlowNativeObject)

    virtual bool needsBlurNode() { return true; }

    virtual void updateBBox(GLClip *clip, const GLBoundingBox &own_bbox, GLBoundingBox *full_bbox);
    virtual void render(GLClip *clip, GLRenderer *renderer, GLDrawSurface *output, GLDrawSurface *input, GLDrawSurface *blur) = 0;

    void renderBlurNode(GLClip *clip, GLRenderer *renderer, GLDrawSurface *output, GLDrawSurface *input);
};

class GLBlurFilter : public GLFilter
{
public:
    GLBlurFilter(GLRenderSupport *owner, float radius, float quality);

    DEFINE_FLOW_NATIVE_OBJECT(GLBlurFilter, GLFilter)

    virtual bool needsBlurNode() { return false; }

    virtual void render(GLClip *clip, GLRenderer *renderer, GLDrawSurface *output, GLDrawSurface *input, GLDrawSurface *blur);
};

class GLDropShadowFilter : public GLFilter
{
    bool shadow_inner;
    vec2 shadow_shift;
    vec4 shadow_color;

public:
    GLDropShadowFilter(GLRenderSupport *owner, vec2 shift, vec4 color, bool inner, float radius, float quality);

    DEFINE_FLOW_NATIVE_OBJECT(GLDropShadowFilter, GLFilter)

    virtual void updateBBox(GLClip *clip, const GLBoundingBox &own_bbox, GLBoundingBox *full_bbox);
    virtual void render(GLClip *clip, GLRenderer *renderer, GLDrawSurface *output, GLDrawSurface *input, GLDrawSurface *blur);
};

class GLBevelFilter : public GLFilter
{
    bool bevel_inner;
    vec2 bevel_shift;
    vec4 bevel_color1, bevel_color2;

public:
    GLBevelFilter(GLRenderSupport *owner, vec2 shift, vec4 color1, vec4 color2, bool inner, float radius, float quality);

    DEFINE_FLOW_NATIVE_OBJECT(GLBevelFilter, GLFilter)

    virtual void updateBBox(GLClip *clip, const GLBoundingBox &own_bbox, GLBoundingBox *full_bbox);
    virtual void render(GLClip *clip, GLRenderer *renderer, GLDrawSurface *output, GLDrawSurface *input, GLDrawSurface *blur);
};

class GLShaderFilter : public GLFilter
{
    unicode_string vertex, fragment, uniform;
    static int program_id_counter;
    int program_id;
    bool compiled;

public:
    GLShaderFilter(GLRenderSupport *owner, unicode_string vertex, unicode_string fragment, unicode_string uniform);

    DEFINE_FLOW_NATIVE_OBJECT(GLShaderFilter, GLFilter)

    virtual void updateBBox(GLClip *clip, const GLBoundingBox &own_bbox, GLBoundingBox *full_bbox);
    virtual void render(GLClip *clip, GLRenderer *renderer, GLDrawSurface *output, GLDrawSurface *input, GLDrawSurface *blur);
};

#endif // GLFILTER_H
