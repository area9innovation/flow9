#include "GLFilter.h"
#include "GLRenderer.h"

#ifdef _MSC_VER
#define _USE_MATH_DEFINES
#include <math.h>
#endif

IMPLEMENT_FLOW_NATIVE_OBJECT(GLFilter, FlowNativeObject);

GLFilter::GLFilter(GLRenderSupport *owner) :
    FlowNativeObject(owner->getFlowRunner()), owner(owner)
{
    blur_radius = blur_quality = -1;
}

bool GLFilter::flowDestroyObject()
{
    for (size_t i = 0; i < clips.size(); i++)
    {
        eraseItem(clips[i]->filters, this);
        clips[i]->wipeFlags(GLClip::WipeChildChanged);
    }

    return true;
}

float GLFilter::getBlurSigma(const GLTransform &transform)
{
    if (blur_radius <= 0)
        return -1;

    float radius = 0.5 * blur_radius * transform.getScale();
    float quality = std::min(3.0f, blur_quality);
    return sqrtf(quality*radius*(radius+1)/3);
}

vec2 GLFilter::transformFilterShift(GLClip * /*clip*/, vec2 shift)
{
    GLClip *stage = owner->Stage;

    return transformShift(stage->getLocalTransform(), roundFromZero(shift));
}

void GLFilter::updateBBox(GLClip *clip, const GLBoundingBox &, GLBoundingBox *full_bbox)
{
    float radius = 1.0f;
    if (blur_radius > 0)
        radius += blur_radius * clip->getGlobalTransform().getScale() * sqrtf(blur_quality);
    full_bbox->expand(ceilf(radius));
}

void GLFilter::computeBlurCoeffs(std::vector<float> *coeffs, std::vector<float> *deltas, float sigma, float margin)
{
    std::vector<float> raw_coeffs;

    float c1 = 1.0f/sqrtf(2*M_PI)/sigma;
    float c2 = -0.5f/sigma/sigma;

    float base_coeff = c1;
    float csum = base_coeff;

    int i = 1;
    do {
        float c = c1 * exp(i*i*c2);

        raw_coeffs.push_back(c);
        csum += c*2;

        i++;
    } while (((i%2) != 1 || (1.0f - csum) > margin) && i <= 32);

    float correction = 1.0f/csum;
    coeffs->push_back(base_coeff * correction);

    for (unsigned i = 0; i < raw_coeffs.size(); i += 2) {
        float total = raw_coeffs[i] + raw_coeffs[i+1];
        float alpha = raw_coeffs[i+1]/total;
        deltas->push_back(1.0f+i+alpha);
        coeffs->push_back(total*correction);
    }
}

void GLFilter::renderBigBlur(GLRenderer *renderer, GLDrawSurface *input, GLDrawSurface *output, float sigma, bool drop_input)
{
    GLDrawSurface tmp(renderer, input->getBBox(), output->getFlowStack());

    std::vector<float> coeffs, deltas;
    computeBlurCoeffs(&coeffs, &deltas, sigma, 0.25f / std::min(3.0f,blur_quality));

    tmp.makeCurrent();
    renderer->renderBigBlur(input, false, coeffs[0], deltas.size(), &deltas[0], &coeffs[1]);

    if (drop_input)
        input->discard();

    output->makeCurrent();
    renderer->renderBigBlur(&tmp, true, coeffs[0], deltas.size(), &deltas[0], &coeffs[1]);
}

void GLFilter::renderBlurNode(GLClip *clip, GLRenderer *renderer, GLDrawSurface *output, GLDrawSurface *input)
{
    float sigma = getBlurSigma(clip->getGlobalTransform());

    if (needsSeparateBlur(sigma))
        renderBigBlur(renderer, input, output, sigma);
}

IMPLEMENT_FLOW_NATIVE_OBJECT(GLBlurFilter, GLFilter);

GLBlurFilter::GLBlurFilter(GLRenderSupport *owner, float radius, float quality) :
    GLFilter(owner)
{
    blur_radius = radius;
    blur_quality = quality;
}

void GLBlurFilter::render(GLClip *clip, GLRenderer *renderer, GLDrawSurface *output, GLDrawSurface *input, GLDrawSurface *)
{
    float sigma = getBlurSigma(clip->getGlobalTransform());

    if (needsSeparateBlur(sigma))
        renderBigBlur(renderer, input, output, sigma, true);
    else {
        output->makeCurrent();
        renderer->renderLocalBlur(input, sigma);
    }
}

IMPLEMENT_FLOW_NATIVE_OBJECT(GLDropShadowFilter, GLFilter);

GLDropShadowFilter::GLDropShadowFilter(GLRenderSupport *owner, vec2 shift, vec4 color, bool inner, float radius, float quality) :
    GLFilter(owner)
{
    blur_radius = radius;
    blur_quality = quality;
    shadow_inner = inner;
    shadow_shift = shift;
    shadow_color = color;
}

void GLDropShadowFilter::updateBBox(GLClip *clip, const GLBoundingBox &own_bbox, GLBoundingBox *full_bbox)
{
    GLFilter::updateBBox(clip, own_bbox, full_bbox);

    if (!shadow_inner)
        full_bbox->expand(shadow_shift);
}

void GLDropShadowFilter::render(GLClip *clip, GLRenderer *renderer, GLDrawSurface *output, GLDrawSurface *input, GLDrawSurface *blur)
{
    const GLTransform &transform = clip->getGlobalTransform();
    vec2 shift = transformFilterShift(clip, shadow_shift);

    output->makeCurrent();

    if (blur)
        renderer->renderShadow(input, blur, -shift, shadow_color, shadow_inner, -1.0f);
    else {
        float sigma = getBlurSigma(transform);
        renderer->renderShadow(input, input, -shift, shadow_color, shadow_inner, sigma);
    }
}

IMPLEMENT_FLOW_NATIVE_OBJECT(GLBevelFilter, GLFilter);

GLBevelFilter::GLBevelFilter(GLRenderSupport *owner, vec2 shift, vec4 color1, vec4 color2, bool inner, float radius, float quality) :
    GLFilter(owner)
{
    blur_radius = radius;
    blur_quality = quality;
    bevel_inner = inner;
    bevel_shift = shift;
    bevel_color1 = color1;
    bevel_color2 = color2;
}

void GLBevelFilter::updateBBox(GLClip *clip, const GLBoundingBox &own_bbox, GLBoundingBox *full_bbox)
{
    GLFilter::updateBBox(clip, own_bbox, full_bbox);

    if (!bevel_inner) {
        full_bbox->expand(bevel_shift);
        full_bbox->expand(-bevel_shift);
    }
}

void GLBevelFilter::render(GLClip *clip, GLRenderer *renderer, GLDrawSurface *output, GLDrawSurface *input, GLDrawSurface *blur)
{
    vec2 shift = transformFilterShift(clip, bevel_shift);

    output->makeCurrent();

    if (blur)
        renderer->renderBevel(input, blur, shift, bevel_color1, bevel_color2, bevel_inner, -1.0f);
    else {
#ifdef IOS
        float sigma = -1.0f;
#else
        const GLTransform &transform = clip->getGlobalTransform();
        float sigma = getBlurSigma(transform);
#endif
        renderer->renderBevel(input, input, shift, bevel_color1, bevel_color2, bevel_inner, sigma);
    }
}
