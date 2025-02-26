#include "GLGraphics.h"

#include "core/GarbageCollector.h"
#include "core/RunnerMacros.h"

// For windows: cmath has no M_PI definition
#define M_PI 3.14159265358979323846

#define _USE_MATH_DEFINES
#include <cmath>
using namespace std;

IMPLEMENT_FLOW_NATIVE_OBJECT(GLGraphics, FlowNativeObject);

static const int BEZIER_STEP = 3.0f;
void GLGradientMesh::Primitive::render()
{
    if (indices.empty()) return;

    if (contiguous)
        glDrawArrays(mode, indices[0], indices[1]);
    else
        glDrawElements(mode, indices.size(), GL_UNSIGNED_SHORT, indices.data());
}

void GLGradientMesh::render(GLRenderer *renderer, float alpha)
{
    if (vertices.empty() || primitives.empty()) return;

    renderer->beginDrawFancy(vec4(alpha), false);

    glVertexAttribPointer(GLRenderer::AttrVertexPos, 2, GL_FLOAT, GL_FALSE, 0, &vertices[0]);
    glVertexAttribPointer(GLRenderer::AttrVertexColor, 4, GL_FLOAT, GL_FALSE, 0, &vertex_colors[0]);

    glEnableVertexAttribArray(GLRenderer::AttrVertexColor);

    for (unsigned i = 0; i < primitives.size(); i++)
        primitives[i]->render();

    glDisableVertexAttribArray(GLRenderer::AttrVertexColor);
}

GLGraphics::GLGraphics(GLClip *parent_) :
    FlowNativeObject(parent_->getFlowRunner()), parent(parent_)
{
    reset();
}

void GLGraphics::reset()
{
    draw_line = draw_fill = line_gradient.enabled = fill_gradient.enabled = false;
    cur_contour.reset();
    cur_pt = vec2(0,0);
    fill_active = true;
    contours.clear();
    bbox.clear();
}

GLGraphics::Contour::Contour()
{
    max_curve = sum_curve = 0.0f;
    is_convex = true;
    is_filled = false;
    vbo_id = (GLuint)-1;
}

void GLGraphics::flowGCObject(GarbageCollectorFn ref)
{
    ref << parent;
}

bool GLGraphics::flowDestroyObject()
{
    parent->graphics = NULL;
    parent->wipeFlags(GLClip::WipeGraphicsChanged);

    for (unsigned j = 0; j < contours.size(); j++) {
        if (contours[j]->vbo_id > 0) {
            glDeleteBuffers(1, &contours[j]->vbo_id);
        }
    }

    return true;
}

bool GLGraphics::isEmpty()
{
    return contours.empty();
}

void GLGraphics::computeBBox(GLBoundingBox &bbox, const GLTransform &transform)
{
    if (isEmpty())
        return;

    GLBoundingBox my_bbox;

    for (unsigned j = 0; j < contours.size(); j++)
        contours[j]->computeBBox(my_bbox, transform);

    my_bbox |= transform * cur_pt;

    if (draw_line)
        my_bbox.expand(0.5f * std::max(1.0f, transform.getScale() * line_thickness));

    bbox |= my_bbox;

    bbox.isEmpty = glm::distance(bbox.min_pt, bbox.max_pt) == 0.0f;
}

void GLGraphics::Contour::computeBBox(GLBoundingBox &my_bbox, const GLTransform &transform)
{
    for (unsigned i = 0; i < elements.size(); i++) {
        my_bbox |= transform * elements[i].pt;
        if (elements[i].type == Element::CurveTo)
            my_bbox |= transform * elements[i].cpt;
    }
}


void GLGraphics::render(GLRenderer *renderer, const GLTransform &transform, float alpha)
{
    if (isEmpty()) return;

    for (unsigned j = 0; j < contours.size(); j++)
        contours[j]->render(this, renderer, transform, alpha);

    renderer->reportGLErrors("GLGraphics::render");
}

bool GLGraphics::usesStencil()
{
    for (unsigned j = 0; j < contours.size(); j++)
        if (contours[j]->usesStencil(this))
            return true;

    return false;
}

bool GLGraphics::Contour::usesStencil(GLGraphics *obj)
{
    bool draw_fill = obj->draw_fill && is_filled;
    bool draw_line = obj->draw_line;

    return (
        (draw_fill && !is_convex) ||
        (draw_fill && obj->fill_gradient.enabled && obj->fill_gradient.is_radial) ||
        (draw_line && obj->line_gradient.enabled && obj->line_gradient.is_radial)
    );
}

void GLGraphics::Contour::render(GLGraphics *obj, GLRenderer *renderer, const GLTransform &transform, float alpha)
{
    int scale_idx = int(max_curve * transform.getScale() / BEZIER_STEP);
    DetailMesh &dmesh = detail_map[scale_idx];
    T_Vertices &vertices = dmesh.vertices;
    T_Vertices &border = dmesh.border_vertices;
    
    float line_width = usesStencil(obj) && !renderer->useWorkaround(GLRenderer::WorkaroundNoStencil) ?
        renderer->getDevicePixelRatio() * transform.getScale() * obj->line_thickness
    :
        renderer->getDevicePixelRatio() * obj->line_thickness;
    
    if (vertices.empty()) {
        float s = (max_curve > 0)? max_curve : 1.0f;
        tesselate(dmesh, (scale_idx + 0.5)*BEZIER_STEP/s, line_width);
    }

    int count = vertices.size()/2;

    bool draw_fill = obj->draw_fill && is_filled;
    bool draw_line = obj->draw_line;

    if (usesStencil(obj) && !renderer->useWorkaround(GLRenderer::WorkaroundNoStencil))
    {
        int cropmask, cropval;
        renderer->getCropStencilMask(&cropval, &cropmask);

        glStencilMask(GLRenderer::StencilDrawBits);
        glClear(GL_STENCIL_BUFFER_BIT);

        glVertexAttribPointer(GLRenderer::AttrVertexPos, 2, GL_FLOAT, GL_FALSE, 0, &vertices[0]);
        renderer->beginDrawSimple(obj->line_color * alpha);

        glEnable(GL_STENCIL_TEST);
        glStencilFunc(GL_NEVER,0,0);
        glStencilOp(GL_INVERT,GL_INVERT,GL_INVERT);

        if (draw_fill) {
            glStencilMask(GLRenderer::StencilDrawFill);
            glDrawArrays(GL_TRIANGLE_FAN, 0, count);
        }

        if (draw_line && border.size() > 0) {
            if (!obj->line_gradient.enabled)
                renderer->resetStencilTest(true);
            
            glVertexAttribPointer(GLRenderer::AttrVertexPos, 2, GL_FLOAT, GL_FALSE, 0, &border[0]);
            glStencilMask(GLRenderer::StencilDrawLine);

            if (obj->line_thickness != 0.0) {
                glLineWidth(renderer->getDevicePixelRatio() * transform.getScale() * obj->line_thickness);
                glDrawArrays(GL_TRIANGLE_STRIP, 0, int(border.size()/2));
            }
        }

        glStencilOp(GL_KEEP,GL_KEEP,GL_KEEP);

        if (draw_fill) {
            glStencilFunc(GL_EQUAL, GLRenderer::StencilDrawFill | cropval, GLRenderer::StencilDrawBits | cropmask);

            if (obj->fill_gradient.enabled)
                obj->fill_gradient.render(renderer, alpha);
            else {
                renderer->beginDrawSimple(obj->fill_color * alpha);
                renderer->drawRect(obj->bbox.min_pt, obj->bbox.max_pt);
            }
        }

        if (draw_line && obj->line_gradient.enabled) {
            glStencilFunc(GL_EQUAL, GLRenderer::StencilDrawLine | cropval, GLRenderer::StencilDrawLine | cropmask);
            obj->line_gradient.render(renderer, alpha);
        }

        renderer->resetStencilTest();
    }
    else
    {
        if (draw_fill) {
            if (obj->fill_gradient.enabled)
            {
                GLGradientMesh::Ptr &pmesh = fill_gradient_map[scale_idx];

                if (!pmesh) {
                    pmesh = GLGradientMesh::Make();
                    obj->fill_gradient.buildLinearMesh(pmesh, vertices, false);
                }

                pmesh->render(renderer, alpha);
            }
            else
            {
                renderer->beginDrawSimple(obj->fill_color * alpha);
                if (!glIsBuffer(vbo_id)) {
                    glGenBuffers(1, &vbo_id);
                    glBindBuffer(GL_ARRAY_BUFFER, vbo_id);
                    glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(float), &vertices[0], GL_STATIC_DRAW);
                    glBindBuffer(GL_ARRAY_BUFFER, 0);
                }

                glBindBuffer(GL_ARRAY_BUFFER, vbo_id);
                glVertexAttribPointer(GLRenderer::AttrVertexPos, 2, GL_FLOAT, GL_FALSE, 0, NULL);
                glDrawArrays(GL_TRIANGLE_FAN, 0, count);
                glBindBuffer(GL_ARRAY_BUFFER, 0);
            }
        }

        if (draw_line) {
            if (obj->line_gradient.enabled)
            {
                glLineWidth(renderer->getDevicePixelRatio() * std::max(1.0f, transform.getScale() * obj->line_thickness));
                GLGradientMesh::Ptr &pmesh = line_gradient_map[scale_idx];

                if (!pmesh) {
                    pmesh = GLGradientMesh::Make();
                    obj->line_gradient.buildLinearMesh(pmesh, vertices, true);
                }

                pmesh->render(renderer, alpha);
            }
            else if (border.size() > 0)
            {
                glVertexAttribPointer(GLRenderer::AttrVertexPos, 2, GL_FLOAT, GL_FALSE, 0, &border[0]);
                renderer->beginDrawSimple(obj->line_color * alpha);
                for (size_t i = 0; i< dmesh.strips.size(); i++) {
                    glDrawArrays(GL_TRIANGLE_STRIP, dmesh.strips[i].first, dmesh.strips[i].second);
                }
            }
        }
    }
}

void GLGraphics::Contour::tesselate(DetailMesh &dmesh, float size, float line_width)
{
    T_Vertices &varr = dmesh.vertices;
    T_Vertices &border = dmesh.border_vertices;
    varr.reserve(2*int(sum_curve * size / BEZIER_STEP + elements.size() + 2));
    border.reserve(4*int(sum_curve * size / BEZIER_STEP + elements.size() + 2));

    bool add_strip = true;
    int last_idx = -1;
    int cur_idx = 0;
    vec2 last_pt;

    for (unsigned i = 0; i < elements.size(); i++) {
        Element &elt = elements[i];

        if (elt.type == Element::CurveTo) {
            int steps = int(elt.length * size / BEZIER_STEP) + 1;
            float tstep = 1.0f/steps;

            for (int j = 1; j < steps; j++) {
                float t = j * tstep;
                float t1 = 1.0f - t;
                vec2 point = t1*t1*last_pt + 2.0f*t1*t*elt.cpt + t*t*elt.pt;
                pushBorderPoints(border, glm::core::type::vec2(varr[varr.size() - 2], varr[varr.size() - 1]), point, line_width, add_strip && border.size() == 0);
                push_comps(varr, point);
            }
            
            // need to finish curve border line
            pushBorderPoints(border, elt.cpt, elt.pt, line_width, false);
        }
        
        if (!add_strip && elt.type == Element::LineTo) {
            if (i != elements.size() - 1) {
                Element &next_elt = elements[i + 1];
                pushLinesBorderPoints(border, last_pt, elt.pt, next_elt.type == Element::CurveTo ? next_elt.cpt : next_elt.pt, line_width, false);
            } else {
                pushBorderPoints(border, last_pt, elt.pt, line_width, false);
            }
        }
        
        push_comps(varr, elt.pt);
        
        if (elt.type == Element::MoveTo || last_idx < 0)
            add_strip = true;
        else
        {
            if (add_strip) {
                if (elt.type == Element::LineTo) {
                    if (i != elements.size() - 1) {
                        Element &next_elt = elements[i + 1];
                        pushLinesBorderPoints(border, last_pt, elt.pt, next_elt.type == Element::CurveTo ? next_elt.cpt : next_elt.pt, line_width, true);
                    } else if (elt.type != Element::CurveTo) {
                        pushBorderPoints(border, last_pt, elt.pt, line_width, true);
                    }
                    
                }
                
                dmesh.strips.push_back(std::pair<int,int>(last_idx, 0));
            }
            
            cur_idx = border.size()/2;
            
            add_strip = false;
            dmesh.strips.back().second += cur_idx - last_idx;
        }

        last_idx = cur_idx;
        last_pt = elt.pt;
    }
    
    push_comps(varr, elements[0].pt);

    if (vbo_id > 0) {
        glDeleteBuffers(1, &vbo_id);
    }
    glGenBuffers(1, &vbo_id);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_id);
    glBufferData(GL_ARRAY_BUFFER, varr.size() * sizeof(float), &varr[0], GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}

void GLGraphics::Contour::pushBorderPoints(T_Vertices &border, vec2 prev_point, vec2 curr_point, float line_width, bool new_strip)
{
    if (prev_point != curr_point) {
        vec2 vec = (curr_point - prev_point);
        double len = sqrt(vec.x * vec.x + vec.y * vec.y);
        vec2 perpendicular_unit_vec = glm::core::type::vec2(vec.y / len, - vec.x / len);
        vec2 left_border_point = curr_point + perpendicular_unit_vec * line_width / 2.f;
        vec2 right_border_point = curr_point - perpendicular_unit_vec * line_width / 2.f;
        
        if (new_strip) {
            vec2 prev_left_border_point = prev_point - perpendicular_unit_vec * line_width / 2.f;
            vec2 prev_right_border_point = prev_point + perpendicular_unit_vec * line_width / 2.f;
            
            push_comps(border, prev_left_border_point);
            push_comps(border, prev_right_border_point);
            
        }
        
        push_comps(border, right_border_point);
        push_comps(border, left_border_point);
    }
}

void GLGraphics::Contour::pushLinesBorderPoints(T_Vertices &border, vec2 prev_point, vec2 curr_point, vec2 next_point, float line_width, bool new_strip)
{
    if (prev_point != curr_point && curr_point != next_point) {
        vec2 prev_vec = prev_point - curr_point;
        vec2 next_vec = next_point - curr_point;
        
        float prev_len = sqrt(prev_vec.x * prev_vec.x + prev_vec.y * prev_vec.y);
        float next_len = sqrt(next_vec.x * next_vec.x + next_vec.y * next_vec.y);
        
        vec2 middle_vec = glm::core::type::vec2(prev_vec.x / prev_len + next_vec.x / next_len, prev_vec.y / prev_len + next_vec.y / next_len);
        middle_vec = middle_vec.x == 0 && middle_vec.y == 0 ? glm::core::type::vec2(prev_vec.y / prev_len, - prev_vec.x / prev_len) : middle_vec;
        float middle_len = sqrt(middle_vec.x * middle_vec.x + middle_vec.y * middle_vec.y);

        float lines_angle_sin = sin(acos((prev_vec.x * next_vec.x + prev_vec.y * next_vec.y) / (prev_len * next_len))/2);
        float stack_point_len = line_width / (2.f * lines_angle_sin);
        vec2 final_middle_lengthed_vec = (middle_vec * stack_point_len) / middle_len;
        
        vec2 right_stack_point = curr_point + final_middle_lengthed_vec;
        vec2 left_stack_point = curr_point - final_middle_lengthed_vec;
        
        if (new_strip) {
            vec2 perpendicular_vec = glm::core::type::vec2(prev_vec.y, - prev_vec.x);
            vec2 left_border_point = prev_point + (perpendicular_vec * line_width) / (2.f * prev_len);
            vec2 right_border_point = prev_point - (perpendicular_vec * line_width) / (2.f * prev_len);
            
            push_comps(border, left_border_point);
            push_comps(border, right_border_point);
        }

        if (lines_angle_sin < 0.1f) {
            // Skip right stack point to avoid extra lines
            bool skip_right_point = stack_point_len > std::min(prev_len, next_len);

            vec2 middle_perpendecular_lenghted = glm::core::type::vec2(middle_vec.y, - middle_vec.x) * line_width / (2.f * middle_len);

            if (prev_vec.x * middle_vec.y - middle_vec.x * prev_vec.y > 0) {
                push_comps(border, curr_point + middle_perpendecular_lenghted);
                push_comps(border, curr_point - middle_perpendecular_lenghted);

                if (!skip_right_point) {
                    push_comps(border, right_stack_point);
                }
            } else {
                if (!skip_right_point) {
                    push_comps(border, right_stack_point);
                }

                push_comps(border, curr_point - middle_perpendecular_lenghted);
                push_comps(border, curr_point + middle_perpendecular_lenghted);
            }

            return;
        }
        
        if (prev_vec.x * middle_vec.y - middle_vec.x * prev_vec.y > 0) {
            push_comps(border, left_stack_point);
            push_comps(border, right_stack_point);
        } else {
            push_comps(border, right_stack_point);
            push_comps(border, left_stack_point);
        }
    }
}

namespace {
    struct ConvexTracker {
        vec2 last_delta, last_pt;
        bool seen_negative, seen_positive;

        ConvexTracker(vec2 pt1)
            : last_delta(0.0f), last_pt(pt1),
              seen_negative(false), seen_positive(false)
        {
        }

        void addPoint(vec2 pt) {
            if (pt == last_pt)
                return;

            vec2 delta = pt - last_pt;
            float cross = last_delta.x*delta.y - delta.x*last_delta.y;
            if (cross < -1e-6)
                seen_negative = true;
            else if (cross > 1e-6)
                seen_positive = true;
            last_delta = delta;
            last_pt = pt;
        }

        bool isNotConvex() {
            return seen_negative && seen_positive;
        }
    };
}

void GLGraphics::Contour::checkConvex()
{
    if (elements.empty()) return;

    ConvexTracker track(elements[0].pt);

    for (unsigned i = 0; i < elements.size(); i++) {
        Element &elt = elements[i];

        if (elt.type == Element::CurveTo)
            track.addPoint(0.25f*track.last_pt + 0.5f*elt.cpt + 0.25f*elt.pt);

        track.addPoint(elt.pt);
    }

    track.addPoint(elements[0].pt);

    is_convex = !track.isNotConvex();
}

void GLGraphics::Gradient::render(GLRenderer *renderer, float alpha)
{
    mesh.render(renderer, alpha);
}

void GLGraphics::Gradient::adjustColorSteps(float minv, float maxv)
{
    color_steps_adj.clear();

    std::map<float,vec4>::iterator it, it_limit;
    it = color_steps.upper_bound(minv); // <
    it_limit = color_steps.lower_bound(maxv); // <=

    // Find min edge; duplicate the leftmost specified point if necessary
    if (it != color_steps.begin()) {
        --it;
    } else {
        color_steps_adj[minv] = it->second;
    }

    // Likewise copy until the right edge and duplicate if necessary
    if (it_limit == color_steps.end()) {
        color_steps_adj.insert(it, it_limit);
        color_steps_adj[maxv] = (--it_limit)->second;
    } else {
        color_steps_adj.insert(it, ++it_limit);
    }
}

void GLGraphics::Gradient::computeVertices(GLGraphics *graphics)
{
    mesh.clear();

    if (color_steps.empty()) return;

    GLBoundingBox bbox;
    graphics->computeBBox(bbox, matrix.inverse());

    if (bbox.isEmpty) return;

    if (is_radial) {
        computeVerticesRadial(bbox);
    } else {
        computeVerticesLinear(bbox);
    }
}

void GLGraphics::Gradient::computeVerticesLinear(GLBoundingBox &bbox)
{
    // Compute the gradient range and active steps
    adjustColorSteps(bbox.min_pt[0], bbox.max_pt[0]);

    // Build the vertex coordinates and colors
    mesh.reserve(color_steps_adj.size()*2);

    std::map<float,vec4>::iterator it = color_steps_adj.begin();
    for (; it != color_steps_adj.end(); ++it) {
        mesh.addVertex(toVec2(matrix * vec2(it->first, bbox.min_pt[1])), it->second);
        mesh.addVertex(toVec2(matrix * vec2(it->first, bbox.max_pt[1])), it->second);
    }

    mesh.addPrimitive(GL_TRIANGLE_STRIP)->setContiguous(0, mesh.size());
}

namespace {
    struct LinearBinSet {
        bool line;
        GLGradientMesh::Ptr pmesh;
        std::vector<float> bin_start;
        std::vector<vec4> bin_color;
        std::vector<GLGradientMesh::Primitive::Ptr> bin_points;
        std::map<float, int> bin_index;
        int last_bin;

        LinearBinSet(GLGradientMesh::Ptr pmesh, const std::map<float,vec4> &color_steps, bool line)
            : line(line), pmesh(pmesh)
        {
            bin_start.push_back(-100.0f);
            bin_color.push_back(color_steps.begin()->second);
            if (!line)
                bin_points.push_back(pmesh->addPrimitive(GL_TRIANGLE_FAN));

            last_bin = 0;

            std::map<float,vec4>::const_iterator it = color_steps.begin();
            for (; it != color_steps.end(); ++it)
            {
                bin_index[it->first] = last_bin++;
                bin_start.push_back(it->first);
                bin_color.push_back(it->second);
                if (!line)
                    bin_points.push_back(pmesh->addPrimitive(GL_TRIANGLE_FAN));
            }
        }

        std::pair<int, vec4> findBin(vec2 pos)
        {
            std::map<float,int>::iterator it = bin_index.upper_bound(pos.x);

            if (it == bin_index.end())
            {
                return std::pair<int, vec4>(last_bin, bin_color[last_bin]);
            }
            else
            {
                int cur_bin = it->second;
                float delta = (pos.x - bin_start[cur_bin])/(bin_start[cur_bin+1]-bin_start[cur_bin]);
                vec4 color = bin_color[cur_bin]*(1.0f - delta) + bin_color[cur_bin+1]*delta;
                return std::pair<int, vec4>(cur_bin, color);
            }
        }

        void binPoint(int bin, GLushort id)
        {
            if (!line)
                bin_points[bin]->addVertex(id);
        }
    };
}


void GLGraphics::Gradient::buildLinearMesh(GLGradientMesh::Ptr pmesh, T_Vertices &vertices, bool line)
{
    if (is_radial) return;

    if (color_steps.empty()) return;

    // Make bins for each gradient segment
    LinearBinSet bins(pmesh, color_steps, line);

    // Track vertices
    int last_bin = -1;
    GLushort last_id = 0;
    vec2 last_pos;

    for (unsigned i = 0; i < vertices.size(); i+=2)
    {
        vec2 real_pos(vertices[i], vertices[i+1]);
        vec2 pos = toVec2(real_pos / matrix);

        std::pair<int,vec4> bin_info = bins.findBin(pos);
        int cur_bin = bin_info.first;

        bool cur_done = false;

        if (last_bin != -1 && last_bin != cur_bin)
        {
            // Split at bin boundaries
            while (last_bin != cur_bin)
            {
                int edge_id = (cur_bin > last_bin ? last_bin+1 : last_bin);
                int new_bin = last_bin + (cur_bin > last_bin ? 1 : -1);

                float edge = bins.bin_start[edge_id];

                // Need a point to exit the previous bin?
                if (last_pos.x != edge) {
                    // Will enter the cur bin exactly at edge, or split needed?
                    if (pos.x == edge) {
                        assert(new_bin == cur_bin);

                        cur_done = true;
                        last_id = pmesh->addVertex(real_pos, bin_info.second);
                    } else {
                        float delta = (edge - last_pos.x)/(pos.x - last_pos.x);
                        float y = last_pos.y*(1.0f - delta) + pos.y*delta;

                        vec2 split_pos(edge, y);
                        vec4 edge_color = bins.bin_color[edge_id];

                        last_id = pmesh->addVertex(toVec2(matrix * split_pos), edge_color);
                    }

                    // Exit the prev bin
                    bins.binPoint(last_bin, last_id);
                }

                // Enter the new bin
                bins.binPoint(new_bin, last_id);
                last_bin = new_bin;
            }
        }

        // Add the point alone, unless already binned
        if (!cur_done) {
            last_id = pmesh->addVertex(real_pos, bin_info.second);
            bins.binPoint(cur_bin, last_id);
        }

        last_bin = cur_bin;
        last_pos = pos;
    }

    if (line)
        pmesh->addPrimitive(GL_LINE_STRIP)->setContiguous(0, pmesh->size());
}

void GLGraphics::Gradient::computeVerticesRadial(GLBoundingBox &bbox)
{
    // Compute the gradient range and active steps
    vec2 z(0.0f);
    float dist = std::max(std::max(glm::distance(z, bbox.min_pt),
                                   glm::distance(z, bbox.max_pt)),
                          std::max(glm::distance(z, vec2(bbox.min_pt[0],bbox.max_pt[1])),
                                   glm::distance(z, vec2(bbox.max_pt[0],bbox.min_pt[1]))));

    adjustColorSteps(0.0f, dist);

    // Build the vertex coordinates and colors
    int radial_segments = 64;

    int ncircles = color_steps_adj.size()-1;
    int nvert = ncircles*radial_segments + 1;

    mesh.reserve(nvert);

    std::map<float,vec4>::iterator it = color_steps_adj.begin();

    // Add the center point
    assert(it->first == 0.0f);
    mesh.addVertex(toVec2(matrix * z), it->second);

    // Build the circles
    float segment_angle = 2*M_PI / radial_segments;

    for (++it; it != color_steps_adj.end(); ++it) {
        float radius = it->first;

        for (int i = 0; i < radial_segments; i++) {
            vec2 pt = radius * vec2(cos(segment_angle*i), sin(segment_angle*i));
            mesh.addVertex(toVec2(matrix * pt), it->second);
        }
    }

    // Build the fan
    GLGradientMesh::Primitive::Ptr fan = mesh.addPrimitive(GL_TRIANGLE_FAN);
    fan->reserve(radial_segments + 2);

    fan->addVertex(0);
    for (int j = 0; j < radial_segments; j++)
        fan->addVertex(j+1);
    fan->addVertex(1);

    // Build the strips
    GLGradientMesh::Primitive::Ptr strip = mesh.addPrimitive(GL_TRIANGLE_STRIP);
    strip->reserve((ncircles-1)*(radial_segments*2+6));

    for (int i = 1; i < ncircles; i++) {
        int base0 = (i-1)*radial_segments + 1;
        int base1 = i*radial_segments + 1;

        // degenerate triangle link end
        strip->addVertex(base0);
        strip->addVertex(base0);

        // circular strip
        for (int j = 0; j < radial_segments; j++) {
            strip->addVertex(base0+j);
            strip->addVertex(base1+j);
        }

        strip->addVertex(base0);
        strip->addVertex(base1);

        // degenerate triangle link start
        strip->addVertex(base1);
        strip->addVertex(base1);
    }
}

StackSlot GLGraphics::Gradient::init(RUNNER_ARGS)
{
    RUNNER_PopArgs5(colors, alphas, offs, matrix_obj, type_str);
    RUNNER_CheckTag1(TNative, matrix_obj);
    RUNNER_CheckTag3(TArray, colors, alphas, offs);
    RUNNER_CheckTag1(TString, type_str);
    RUNNER_DefSlots3(color, alpha, offset);

    matrix = RUNNER->GetNative<GLTransform>(matrix_obj);

    // Determine the gradient type
    unicode_string type_us = RUNNER->GetString(type_str);

    static const unicode_string linear_us = parseUtf8("linear");
    static const unicode_string radial_us = parseUtf8("radial");

    is_radial = (type_us == radial_us);

    if (!is_radial && type_us != linear_us) {
        RUNNER->ReportError(InvalidArgument, "invalid gradient type: '%s'", encodeUtf8(type_us).c_str());
        RETVOID;
    }

    // Decode the steps
    int offs_len = RUNNER->GetArraySize(offs);
    int alphas_len = RUNNER->GetArraySize(alphas);
    int colors_len = RUNNER->GetArraySize(colors);

    if (offs_len != alphas_len || alphas_len != colors_len) {
        RUNNER->ReportError(InvalidArgument, "colors, alphas and offs must have the same size");
        RETVOID;
    }

    for (int i = 0; i < offs_len; i++)
    {
        color = RUNNER->GetArraySlot(colors, i);
        alpha = RUNNER->GetArraySlot(alphas, i);
        offset = RUNNER->GetArraySlot(offs, i);
        RUNNER_CheckTag1(TInt, color);
        RUNNER_CheckTag2(TDouble, alpha, offset);

        float pos = offset.GetDouble();

        if (is_radial) {
            // radius can't ever be negative
            if (pos < 0.0f) pos = 0.0f;
        } else {
            pos = pos * 2.0f - 1.0f;
        }

        color_steps[pos] = flowToColor(color, alpha);
    }

    enabled = true;
    mesh.clear();

    RETVOID;
}

StackSlot GLGraphics::makeMatrix(RUNNER_ARGS)
{
    RUNNER_PopArgs5(width, height, rot, x_offs, y_offs);
    RUNNER_CheckTag5(TDouble, width, height, rot, x_offs, y_offs);

    /*vec2 sincos = glm::abs(flowAngledVector(rot, StackSlot::MakeDouble(0.5f)));
    float scale = sincos.x*width.GetDouble() + sincos.y*height.GetDouble();*/

    GLUnpackedTransform trf(
                x_offs.GetDouble() + 0.5f*width.GetDouble(),
                y_offs.GetDouble() + 0.5f*height.GetDouble(),
                width.GetDouble()*0.5f,
                height.GetDouble()*0.5f,
                0.0f
                );

    GLUnpackedTransform rtrf(0.0f, 0.0f, 1.0f, 1.0f, rot.GetDouble());

    return RUNNER->AllocNative<GLTransform>(trf.toMatrixForm() * rtrf.toMatrixForm());
}

StackSlot GLGraphics::setLineStyle(RUNNER_ARGS)
{
    RUNNER_PopArgs3(width, color_val, opacity);
    RUNNER_CheckTag2(TDouble, width, opacity);
    RUNNER_CheckTag(TInt, color_val);

    draw_line = true;
    line_color = flowToColor(color_val, opacity);
    line_thickness = width.GetDouble();

    RETVOID;
}

StackSlot GLGraphics::moveTo(RUNNER_ARGS)
{
    RUNNER_PopArgs2(x, y);
    RUNNER_CheckTag2(TDouble, x, y);

    vec2 pt(x.GetDouble(), y.GetDouble());

    if (isnan(pt.x) || isnan(pt.y)) {
        RUNNER->flow_err << "NaN in Graphics::moveTo" << std::endl;
        RETVOID;
    }

    endContour();

    cur_pt = pt;

    RETVOID;
}

bool isPointOnLine(vec2 start, vec2 end, vec2 point) {
    double dx = (point.y - start.y) * (end.x - start.x);
    double dy = (point.x - start.x) * (end.y - start.y);
    return abs(dy - dx) <= 0.002;
}

StackSlot GLGraphics::lineTo(RUNNER_ARGS)
{
    RUNNER_PopArgs2(x, y);
    RUNNER_CheckTag2(TDouble, x, y);

    vec2 pt(x.GetDouble(), y.GetDouble());

    if (isnan(pt.x) || isnan(pt.y)) {
        RUNNER->flow_err << "NaN in Graphics::lineTo" << std::endl;
        RETVOID;
    }

    if (!cur_contour) {
        contours.push_back(cur_contour = Contour::Ptr(new Contour()));
        cur_contour->elements.push_back(Element(Element::MoveTo, cur_pt));
    }

    std::vector<Element> &elements = cur_contour->elements;

    vec2 prev_pt = elements.empty() ? pt : elements.back().pt;

    float len = glm::distance(prev_pt, pt);

    cur_contour->max_curve = std::max(cur_contour->max_curve, len);
    cur_contour->sum_curve += len;
    
    if (len != 0.f) {
        Element newElement = Element(Element::LineTo, pt);
        
        if (elements.size() > 1 && elements.back().type == Element::LineTo && isPointOnLine(elements.at(elements.size() - 2).pt, pt, prev_pt)) {
            elements[elements.size() - 1] = newElement;
        } else {
            elements.push_back(newElement);
        }

        parent->wipeFlags(GLClip::WipeGraphicsChanged);
    }

    RETVOID;
}

StackSlot GLGraphics::curveTo(RUNNER_ARGS)
{
    RUNNER_PopArgs4(cx, cy, x, y);
    RUNNER_CheckTag4(TDouble, cx, cy, x, y);

    vec2 pt(x.GetDouble(), y.GetDouble());
    vec2 cpt(cx.GetDouble(), cy.GetDouble());

    if (isnan(pt.x) || isnan(pt.y) || isnan(cpt.x) || isnan(cpt.y)) {
        RUNNER->flow_err << "NaN in Graphics::curveTo" << std::endl;
        RETVOID;
    }

    if (!cur_contour) {
        contours.push_back(cur_contour = Contour::Ptr(new Contour()));
        cur_contour->elements.push_back(Element(Element::MoveTo, cur_pt));
    }

    std::vector<Element> &elements = cur_contour->elements;

    vec2 prev_pt = elements.empty() ? pt : elements.back().pt;

    float len = glm::distance(prev_pt, cpt) + glm::distance(cpt, pt);

    cur_contour->max_curve = std::max(cur_contour->max_curve, len);
    cur_contour->sum_curve += len;
    if (len != 0.f) {
        elements.push_back(Element(Element::CurveTo, pt, cpt, len));

        parent->wipeFlags(GLClip::WipeGraphicsChanged);
    }

    RETVOID;
}

StackSlot GLGraphics::beginFill(RUNNER_ARGS)
{
    RUNNER_PopArgs2(color_val, opacity_val);
    RUNNER_CheckTag(TInt, color_val);
    RUNNER_CheckTag(TDouble, opacity_val);

    draw_fill = true;
    fill_color = flowToColor(color_val, opacity_val);

    RETVOID;
}

StackSlot GLGraphics::beginLineGradientFill(RUNNER_ARGS)
{
    RUNNER_CopyArgArray(newargs, 4, 1);
    newargs[4] = RUNNER->AllocateString("linear");
    return beginGradientFill(RUNNER, newargs);
}

StackSlot GLGraphics::beginGradientFill(RUNNER_ARGS)
{
    draw_fill = true;
    fill_gradient.init(RUNNER, &RUNNER_ARG(0));
    if (!fill_gradient.color_steps.empty())
        fill_color = fill_gradient.color_steps.begin()->second;
    RETVOID;
}

void GLGraphics::endContour()
{
    if (!cur_contour)
        return;

    std::vector<Element> &elements = cur_contour->elements;

    // Close the loop with a line if doing a fill
    if (draw_fill && fill_active && !elements.empty() && elements.back().pt != elements.front().pt)
        elements.push_back(Element(Element::LineTo, elements.front().pt));

    cur_contour->is_filled = fill_active;
    cur_contour->checkConvex();
    cur_contour.reset();
}

StackSlot GLGraphics::endFill(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    endContour();

    fill_active = false;

    bbox.clear();
    computeBBox(bbox, GLTransform());

    if (line_gradient.enabled)
        line_gradient.computeVertices(this);
    if (fill_gradient.enabled)
        fill_gradient.computeVertices(this);

    parent->wipeFlags(GLClip::WipeGraphicsChanged);

    RETVOID;
}

StackSlot GLGraphics::setLineGradientStroke(RUNNER_ARGS)
{
    RUNNER_CopyArgArray(newargs, 4, 1);
    newargs[4] = RUNNER->AllocateString("linear");
    draw_line = true;
    line_gradient.init(RUNNER, newargs);
    if (!line_gradient.color_steps.empty())
        line_color = line_gradient.color_steps.begin()->second;
    RETVOID;
}

StackSlot GLGraphics::clearGraphics(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    reset();

    parent->wipeFlags(GLClip::WipeGraphicsChanged);

    RETVOID;
}
