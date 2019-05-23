#ifndef GLUTILS_H
#define GLUTILS_H

#include "core/CommonTypes.h"

#ifdef IOS
  #include <OpenGLES/ES2/gl.h>
  #include <OpenGLES/ES2/glext.h>
#else
  #ifdef FLOW_EMBEDDED
    #include <GLES2/gl2.h>
    #include <GLES2/gl2ext.h>
  #else
    #define GL_GLEXT_PROTOTYPES
    #ifdef WIN32
      #include <GL/glew.h>
    #else
      #ifdef __APPLE__
        #include <OpenGL/gl.h>
      #else
        #include <GL/gl.h>
      #endif
    #endif
    #ifdef __APPLE__
      #include <OpenGL/glext.h>
    #else
      #include <GL/glext.h>
    #endif
  #endif
#endif

#include <glm/glm.hpp>

using glm::mat2;
using glm::mat3;

using glm::vec2;
using glm::vec3;
using glm::vec4;

using glm::ivec2;

using glm::min;
using glm::max;

BEGIN_STL_HASH_NAMESPACE
    template <> struct hash<glm::ivec2> {
        size_t operator() (const glm::ivec2& v) const {
            return hash<int>()(v.x) ^ hash<int>()(v.y);
        }
    };
END_STL_HASH_NAMESPACE

struct ShaderUniform {
    std::string name;
    std::string type;
    std::string value;

    ShaderUniform(std::string name, std::string type, std::string value) {
        this->name = name;
        this->type = type;
        this->value = value;
    }
};

inline bool is_pow2(unsigned value) { return (value & (value-1)) == 0; }

vec4 flowToColor(const StackSlot &color, const StackSlot &alpha, bool premultiplied = true);
vec2 flowAngledVector(const StackSlot &angle, const StackSlot & distance);

unsigned colorToInt(vec4 color, bool premultiplied = true);

inline vec2 roundf(vec2 val) { return vec2(roundf(val.x), roundf(val.y)); }

vec2 roundFromZero(vec2 val);

inline void push_comps(std::vector<float> &vec, vec2 v) {
    int size = vec.size();
    vec.resize(size+2);
    float *p = &vec[size];
    p[0] = v[0]; p[1] = v[1];
}

inline void push_comps(std::vector<float> &vec, vec4 v) {
    int size = vec.size();
    vec.resize(size+4);
    float *p = &vec[size];
    p[0] = v[0]; p[1] = v[1];
    p[2] = v[2]; p[3] = v[3];
}

inline vec2 toVec2(const vec2 &v) { return v; }
inline vec2 toVec2(const vec3 &v) { return vec2(v) / v[2]; }

inline vec3 toVec3(const vec2 &v) { return vec3(v, 1.0f); }
inline vec3 toVec3(const vec3 &v) { return v; }

struct GLTransform {
    mat3 forward;
    mat3 reverse;

    GLTransform() {}
    GLTransform(const mat3 &f, const mat3 &r) : forward(f), reverse(r) {}

    // This matrix value contains 1/scale:
    float getScale() const { return reverse[2][2]; }
    float getScaleRev() const { return forward[2][2]; }

    GLTransform inverse() const { return GLTransform(reverse, forward); }
};

inline GLTransform operator* (const GLTransform &t1, const GLTransform &t2) {
    return GLTransform(t1.forward * t2.forward, t2.reverse * t1.reverse);
}

inline vec3 operator* (const GLTransform &t, const vec2 &v) { return t.forward * vec3(v, 1.0f); }
inline vec3 operator* (const GLTransform &t, const vec3 &v) { return t.forward * v; }

inline vec3 operator/ (const vec2 &v, const GLTransform &t) { return t.reverse * vec3(v, 1.0f); }
inline vec3 operator/ (const vec3 &v, const GLTransform &t) { return t.reverse * v; }

inline vec2 roundToGrid(const GLTransform &transform, vec2 pt) {
    return toVec2(roundf(toVec2(transform * pt)) / transform);
}

inline vec2 transformShift(const GLTransform &transform, vec2 dpt) {
    return transform.getScale() * (mat2(transform.forward) * dpt);
}

struct GLUnpackedTransform {
    float x, y, sx, sy, angle; // rotation is clockwise

    GLUnpackedTransform() : x(0), y(0), sx(1), sy(1), angle(0) {}
    GLUnpackedTransform(float x, float y, float sx, float sy, float angle)
        : x(x), y(y), sx(sx), sy(sy), angle(angle) {}

    GLTransform toMatrixForm();

    bool isZeroScale() {
        return fabsf(sx) < 1e-6 || fabsf(sy) < 1e-6;
    }
};

struct GLBoundingBox {
    bool isEmpty;
    vec2 min_pt, max_pt;

    GLBoundingBox() : isEmpty(true) {}
    GLBoundingBox(const vec2 &vmin, const vec2 &vmax)
        : isEmpty(false), min_pt(vmin), max_pt(vmax) {}

    void clear() { isEmpty = true; }

    void roundOut() {
        if (!isEmpty) {
            min_pt = glm::floor(min_pt);
            max_pt = glm::ceil(max_pt);
        }
    }

    void expand(float delta) {
        if (!isEmpty) {
            min_pt -= vec2(delta);
            max_pt += vec2(delta);
        }
    }

    void expand(vec2 delta) {
        if (!isEmpty) {
            min_pt += glm::min(vec2(0), delta);
            max_pt += glm::max(vec2(0), delta);
        }
    }

    vec2 size() const {
        return isEmpty ? vec2(0.0) : max_pt - min_pt;
    }

    bool contains(vec3 v) const { return contains(toVec2(v)); }
    bool contains(vec2 v) const {
        return !isEmpty && (v.x >= min_pt.x && v.y >= min_pt.y && v.x <= max_pt.x && v.y <= max_pt.y);
    }

    // Check with a confidence radius
    bool contains(vec3 v, float r) const { return contains(toVec2(v), r / v.z); }
    bool contains(vec2 v, float r) const {
        return !isEmpty && (v.x + r >= min_pt.x && v.y + r >= min_pt.y && v.x - r <= max_pt.x && v.y - r <= max_pt.y);
    }

    GLBoundingBox &operator |= (const vec3 &pt) {
        return (*this |= toVec2(pt));
    }

    GLBoundingBox &operator |= (const vec2 &pt);
    GLBoundingBox &operator |= (const GLBoundingBox &bbox);
    GLBoundingBox &operator &= (const GLBoundingBox &bbox);
};

GLBoundingBox operator* (const GLTransform &t, const GLBoundingBox &v);

class GLRectStrip {
    unsigned count, num_pts;
    std::vector<float> points;

    float *push(int cnt);
public:
    GLRectStrip() : count(0), num_pts(0) {}

    void reserve(unsigned sz) { if (sz > num_pts) points.resize(sz); }
    int size() const { return count; }

    int getNumPoints() const { return num_pts; }

    void addRect(vec2 p1, vec2 p2);
    void bindToAttrib(int id) const;
    void drawStrip() const;
};

#endif // GLUTILS_H
