#ifndef GLGRAPHICS_H
#define GLGRAPHICS_H

#include "GLClip.h"
#include "GLUtils.h"
#include "GLRenderer.h"

class GLGradientMesh {
public:
    typedef shared_ptr<GLGradientMesh> Ptr;

    class Primitive {
        GLenum mode;
        bool contiguous;
        std::vector<GLushort> indices;

    public:
        typedef shared_ptr<Primitive> Ptr;

        Primitive(GLenum mode) : mode(mode), contiguous(false) {}

        void setContiguous(GLushort start, GLushort count) {
            contiguous = true;
            indices.resize(2);
            indices[0] = start; indices[1] = count;
        }

        void reserve(int count) {
            indices.reserve(count);
        }

        void addVertex(GLushort idx) {
            indices.push_back(idx);
        }

        void render();
    };

private:
    std::vector<float> vertices;
    std::vector<float> vertex_colors;

    std::vector<Primitive::Ptr> primitives;

public:
    static Ptr Make() { return Ptr(new GLGradientMesh()); }

    void clear() {
        vertices.clear();
        vertex_colors.clear();
        primitives.clear();
    }

    void reserve(int count) {
        vertices.reserve(2*count);
        vertex_colors.reserve(4*count);
    }

    unsigned size() {
        return vertices.size()/2;
    }

    GLushort addVertex(vec2 pos, vec4 color) {
        GLushort id = vertices.size()/2;
        push_comps(vertices, pos);
        push_comps(vertex_colors, color);
        return id;
    }

    Primitive::Ptr addPrimitive(GLenum mode) {
        Primitive::Ptr ptr(new Primitive(mode));
        primitives.push_back(ptr);
        return ptr;
    }

    void render(GLRenderer *renderer, float alpha);
};

class GLGraphics : public FlowNativeObject
{
protected:
    // ROOTS:
    GLClip *parent;

    void flowGCObject(GarbageCollectorFn);
    bool flowDestroyObject();

    typedef std::vector<float> T_Vertices;

    struct Element {
        enum Type {
            MoveTo,
            LineTo,
            CurveTo
        } type;

        vec2 pt, cpt;
        float length;

        Element(Type t, vec2 p, vec2 c = vec2(), float l = 0.0f)
            : type(t), pt(p), cpt(c), length(l) {}
    };

    struct Gradient {
        bool enabled, is_radial;
        std::map<float, vec4> color_steps;
        GLTransform matrix;

        std::map<float, vec4> color_steps_adj;

        GLGradientMesh mesh;

        void computeVertices(GLGraphics *graphics);
        void render(GLRenderer *renderer, float alpha);

        void buildLinearMesh(GLGradientMesh::Ptr pmesh, T_Vertices &vertices, bool line);

        DECLARE_NATIVE_METHOD(init);

    private:
        void adjustColorSteps(float minv, float maxv);
        void computeVerticesLinear(GLBoundingBox &bbox);
        void computeVerticesRadial(GLBoundingBox &bbox);
    };

    bool draw_line;
    vec4 line_color;
    float line_thickness;
    Gradient line_gradient;

    bool draw_fill;
    vec4 fill_color;
    Gradient fill_gradient;

    GLBoundingBox bbox;

    struct DetailMesh {
        T_Vertices vertices;
        T_Vertices border_vertices;
        std::vector<std::pair<int,int> > strips;
    };

    typedef std::map<int, DetailMesh> T_detail_map;
    typedef std::map<int, GLGradientMesh::Ptr> T_detail_gradient_map;

    struct Contour {
        typedef shared_ptr<Contour> Ptr;

        bool is_convex, is_filled;
        float max_curve, sum_curve;
        GLuint vbo_id;
        std::vector<Element> elements;

        T_detail_map detail_map;
        T_detail_gradient_map line_gradient_map, fill_gradient_map;

        Contour();

        void computeBBox(GLBoundingBox &bbox, const GLTransform &transform);
        void render(GLGraphics *obj, GLRenderer *renderer, const GLTransform &transform, float alpha);

        void tesselate(DetailMesh &mesh, float size, float line_width);
        void pushBorderPoints(T_Vertices &border, vec2 prev_point, vec2 curr_point, float line_width, bool new_strip);
        void pushLinesBorderPoints(T_Vertices &border, vec2 prev_point, vec2 curr_point, vec2 next_point, float line_width, bool new_strip);
        void checkConvex();

        bool usesStencil(GLGraphics *obj);
    };

    std::vector<Contour::Ptr> contours;
    Contour::Ptr cur_contour;
    bool fill_active;
    vec2 cur_pt;

    void reset();
    void endContour();

public:
    GLGraphics(GLClip *parent);

    DEFINE_FLOW_NATIVE_OBJECT(GLGraphics, FlowNativeObject);

    bool isEmpty();
    bool usesStencil();

    void computeBBox(GLBoundingBox &bbox, const GLTransform &transform);

    void render(GLRenderer *renderer, const GLTransform &transform, float alpha);

public:
    static DECLARE_NATIVE_METHOD(makeMatrix);

    DECLARE_NATIVE_METHOD(setLineStyle);
    DECLARE_NATIVE_METHOD(moveTo);
    DECLARE_NATIVE_METHOD(lineTo);
    DECLARE_NATIVE_METHOD(curveTo);

    DECLARE_NATIVE_METHOD(beginFill);
    DECLARE_NATIVE_METHOD(beginGradientFill);
    DECLARE_NATIVE_METHOD(beginLineGradientFill);
    DECLARE_NATIVE_METHOD(endFill);

    DECLARE_NATIVE_METHOD(setLineGradientStroke);

    DECLARE_NATIVE_METHOD(clearGraphics);
};

#endif // GLGRAPHICS_H
