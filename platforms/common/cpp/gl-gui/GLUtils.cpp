#include "GLUtils.h"
#include "GLRenderer.h"
#include "GLRenderSupport.h"

#define _USE_MATH_DEFINES
#include <math.h>

IMPLEMENT_NATIVE_VALUE_TYPE(GLTransform);

vec4 flowToColor(const StackSlot &color_slot, const StackSlot &alpha, bool premultiplied)
{
    int color = color_slot.GetInt();
    float av = alpha.GetDouble();

    vec3 tmp(
        ((color>>16)&0xFF)/255.0f,
        ((color>>8)&0xFF)/255.0f,
        (color&0xFF)/255.0f
    );

    return vec4(premultiplied ? tmp * av : tmp, av);
}

unsigned colorToInt(vec4 color, bool premultiplied) {
    float alpha = color.a;
    vec4 rgb = color;

    if (premultiplied && alpha != 0.0f)
        rgb /= alpha;

    return (unsigned(alpha * 255.0f)<<24) |
           (unsigned(rgb.r * 255.0f)<<16) |
           (unsigned(rgb.g * 255.0f)<<8) |
            unsigned(rgb.b * 255.0f);
}

vec2 flowAngledVector(const StackSlot &angle, const StackSlot &distance)
{
    float rad_angle = float(M_PI) * angle.GetDouble() / 180.0f;

    return float(distance.GetDouble()) * vec2(cosf(rad_angle), sinf(rad_angle));
}

vec2 roundFromZero(vec2 val) {
    float ax = fabsf(val.x);
    if (ax < 1.0f && ax > 1e-2f)
        val.x = val.x/ax;

    float ay = fabsf(val.y);
    if (ay < 1.0f && ay > 1e-2f)
        val.y = val.y/ay;

    return val;
}

GLTransform GLUnpackedTransform::toMatrixForm()
{
    float rad_angle = float(M_PI) * angle / 180.0f;
    float cosv = cosf(rad_angle);
    float sinv = sinf(rad_angle);

    float sx = this->sx, sy = this->sy;
    float rsx = 1.0f/sx, rsy = 1.0f/sy;

    float rscale = sqrt(fabsf(sx*sy));
    float scale = 1.0f / rscale;

    // Avoid NaNs from division by zero: make both
    // forward and reverse matrices scale into zero
    if (isZeroScale()) {
        rsx = rsy = 0.0f;
        rscale = scale = 1.0f;
    }

    mat3 forward =
            mat3(1.0f, 0.0f, 0.0f,
                 0.0f, 1.0f, 0.0f,
                 x, y, 1.0f)
            *
            mat3(cosv, sinv, 0.0f,
                 -sinv, cosv, 0.0f,
                 0.0f, 0.0f, 1.0f)
            *
            mat3(sx*scale, 0.0f, 0.0f,
                 0.0f, sy*scale, 0.0f,
                 0.0f, 0.0f, scale);

    mat3 reverse =
            mat3(rscale*rsx, 0.0f, 0.0f,
                 0.0f, rscale*rsy, 0.0f,
                 0.0f, 0.0f, rscale)
            *
            mat3(cosv, -sinv, 0.0f,
                 sinv, cosv, 0.0f,
                 0.0f, 0.0f, 1.0f)
            *
            mat3(1.0f, 0.0f, 0.0f,
                 0.0f, 1.0f, 0.0f,
                 -x, -y, 1.0f);

    return GLTransform(forward, reverse);
}

GLTransform GLUnpackedTransform::toMatrixForm(float width, float height)
{
    float rad_angle = float(M_PI) * angle / 180.0f;
    float cosv = cosf(rad_angle);
    float sinv = sinf(rad_angle);

    float sx = this->sx, sy = this->sy;
    float rsx = 1.0f/sx, rsy = 1.0f/sy;

    float rscale = sqrt(fabsf(sx*sy));
    float scale = 1.0f / rscale;

    // Avoid NaNs from division by zero: make both
    // forward and reverse matrices scale into zero
    if (isZeroScale()) {
        rsx = rsy = 0.0f;
        rscale = scale = 1.0f;
    }

    mat3 forward =
            mat3(1.0f, 0.0f, 0.0f,
                 0.0f, 1.0f, 0.0f,
                 x, y, 1.0f)
            *
            mat3(cosv, sinv, 0.0f,
                 -sinv, cosv, 0.0f,
                 0.0f, 0.0f, 1.0f)
            *
            mat3(sx*scale, 0.0f, 0.0f,
                 0.0f, sy*scale, 0.0f,
                 0.0f, 0.0f, scale)
            *
            mat3(1.0f, 0.0f, 0.0f,
                 0.0f, 1.0f, 0.0f,
                 -width * ox, -height * oy, 1.0f);

    mat3 reverse =
            mat3(1.0f, 0.0f, 0.0f,
                 0.0f, 1.0f, 0.0f,
                 width * ox, height * oy, 1.0f)
            *
            mat3(rscale*rsx, 0.0f, 0.0f,
                 0.0f, rscale*rsy, 0.0f,
                 0.0f, 0.0f, rscale)
            *
            mat3(cosv, -sinv, 0.0f,
                 sinv, cosv, 0.0f,
                 0.0f, 0.0f, 1.0f)
            *
            mat3(1.0f, 0.0f, 0.0f,
                 0.0f, 1.0f, 0.0f,
                 -x, -y, 1.0f);

    return GLTransform(forward, reverse);
}

GLBoundingBox &GLBoundingBox::operator |= (const vec2 &pt) {
    if (isEmpty) {
        min_pt = max_pt = pt;
        isEmpty = false;
    } else {
        min_pt = min(min_pt, pt);
        max_pt = max(max_pt, pt);
    }
    return *this;
}

GLBoundingBox &GLBoundingBox::operator |= (const GLBoundingBox &bbox) {
    if (!bbox.isEmpty) {
        if (isEmpty) {
            *this = bbox;
        } else {
            min_pt = min(min_pt, bbox.min_pt);
            max_pt = max(max_pt, bbox.max_pt);
        }
    }
    return *this;
}

GLBoundingBox &GLBoundingBox::operator &= (const GLBoundingBox &bbox) {
    if (isEmpty || bbox.isEmpty) {
        isEmpty = true;
    } else {
        min_pt = max(min_pt, bbox.min_pt);
        max_pt = min(max_pt, bbox.max_pt);
        if (min_pt[0] >= max_pt[0] || min_pt[1] >= max_pt[1])
            isEmpty = true;
    }
    return *this;
}

GLBoundingBox operator* (const GLTransform &t, const GLBoundingBox &v) {
    GLBoundingBox out;
    if (!v.isEmpty) {
        out |= t * v.min_pt;
        out |= t * v.max_pt;
        out |= t * vec2(v.min_pt.x, v.max_pt.y);
        out |= t * vec2(v.max_pt.x, v.min_pt.y);
    }
    return out;
}

float *GLRectStrip::push(int cnt)
{
    int cp = num_pts;
    num_pts += cnt;
    if (num_pts > points.size())
        points.resize(num_pts*2);
    return &points[cp];
}

#if 0
void GLRectStrip::addRect(vec2 p1, vec2 p2) {
    if (count++ > 0) {
        vec2 lpt(points[num_pts-2],points[num_pts-1]);

        // Insert a linkage using degenerate triangles
        float *p = push(4*2);
        p[0] = p[2] = lpt.x;
        p[1] = p[3] = lpt.y;
        p[4] = p[6] = p1.x;
        p[5] = p[7] = p1.y;
    }

    float *p = push(4*2);
    p[0] = p1.x; p[1] = p1.y;
    p[2] = p1.x; p[3] = p2.y;
    p[4] = p2.x; p[5] = p1.y;
    p[6] = p2.x; p[7] = p2.y;
}

void GLRectStrip::drawStrip() const {
    glDrawArrays(GL_TRIANGLE_STRIP, 0, num_pts/2);
}
#else
void GLRectStrip::addRect(vec2 p1, vec2 p2) {
    float *p = push(6*2);
    p[0] = p1.x; p[1] = p1.y;
    p[2] = p1.x; p[3] = p2.y;
    p[4] = p2.x; p[5] = p1.y;
    p[6] = p2.x; p[7] = p1.y;
    p[8] = p1.x; p[9] = p2.y;
    p[10] = p2.x; p[11] = p2.y;
}

void GLRectStrip::drawStrip() const {
    glDrawArrays(GL_TRIANGLES, 0, num_pts/2);
}
#endif

void GLRectStrip::bindToAttrib(int id) const {
    glVertexAttribPointer(id, 2, GL_FLOAT, GL_FALSE, 0, &points[0]);
}
