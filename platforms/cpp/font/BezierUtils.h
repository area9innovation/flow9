#ifndef BEZIERUTILS_H
#define BEZIERUTILS_H

#include <vector>
#include <glm/glm.hpp>

using glm::vec2;

vec2 bezierPoint(const std::vector<vec2> &curve, float t);

std::pair<float,float> closestPointToBezier(const std::vector<vec2> &curve, vec2 p);

#endif // BEZIERUTILS_H
