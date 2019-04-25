//
// BezierUtils.as - A small collection of static utilities for use with single-segment Bezier curves, or more generally
// any curve implementing the IParametric interface
//
// copyright (c) 2006-2008, Jim Armstrong.  All Rights Reserved.
//
// This software program is supplied 'as is' without any warranty, express, implied, 
// or otherwise, including without limitation all warranties of merchantability or fitness
// for a particular purpose.  Jim Armstrong shall not be liable for any special incidental, or 
// consequential damages, including, without limitation, lost revenues, lost profits, or 
// loss of prospective economic advantage, resulting from the use or misuse of this software 
// program.
//
// Programmed by Jim Armstrong, Singularity (www.algorithmist.net)
//
// Version 1.0

/*
  Translated to C++ and tweaked by Alexander Gavrilov.
 */

#include "BezierUtils.h"

static const unsigned MAX_DEPTH = 64; // maximum recursion depth
static const float EPSILON = 1e-4;

static vec2 bezierPoint(const std::vector<vec2> &curve, float t, int s, int e)
{
    float t1 = 1.0f - t;

    switch (e - s) {
    case 0:
        return vec2(0.0f);
    case 1:
        return curve[s];
    case 2:
        return t1*curve[s] + t*curve[s+1];
    case 3:
        return t1*t1*curve[s] + 2*t1*t*curve[s+1] + t*t*curve[s+2];
    case 4:
        return t1*t1*t1*curve[s] + 3*t1*t1*t*curve[s+1] + 3*t1*t*t*curve[s+2] + t*t*t*curve[s+3];
    default:
        return t1*bezierPoint(curve, t, s, e-1) + t*bezierPoint(curve, t, s+1, e);
    }
}

vec2 bezierPoint(const std::vector<vec2> &curve, float t)
{
    return bezierPoint(curve, t, 0, curve.size());
}

inline unsigned getLinearIndex(unsigned n, unsigned r, unsigned c) {
    return n*r + c;
}

static std::vector<vec2> toBezierForm(vec2 p, const std::vector<vec2> &v)
{
    /* compute control vec2s of the polynomial resulting from the inner
       product of B(t)-P and B'(t), constructing the result as a Bezier
       curve of order 2n-1, where n is the degree of B(t). */

    unsigned n = v.size()-1;

    std::vector<vec2> c(n+1);
    for (unsigned i = 0; i <= n; ++i)
        c[i] = v[i] - p;

    std::vector<vec2> d(n);
    for (unsigned i = 0; i < n; ++i)
        d[i] = float(n)*(v[i+1] - v[i]);

    std::vector<float> cd(n*(n+1));
    for (unsigned row = 0; row < n; row++) {
        vec2 dv = d[row];

        for (unsigned col = 0; col <= n; col++)
            cd[getLinearIndex(n+1, row, col)] = glm::dot(dv, c[col]);
    }

    unsigned degree = 2*n - 1;

    // Bezier is uniform parameterized
    std::vector<vec2> w(degree+1);
    for (unsigned i = 0; i <= degree; i++)
        w[i] = vec2(float(i)/degree, 0.0f);

    // reference to appropriate pre-computed coefficients
    static const float Z_CUBIC[] = {1.0, 0.6, 0.3, 0.1, 0.4, 0.6, 0.6, 0.4, 0.1, 0.3, 0.6, 1.0};
    static const float Z_QUAD[]  = {1.0, 2.0/3.0, 1.0/3.0, 1.0/3.0, 2.0/3.0, 1.0};
    const float *z = (n == 3) ? Z_CUBIC : Z_QUAD;

    unsigned m = n-1;
    for(unsigned k=0; k <= n+m; ++k)
    {
        unsigned lb = std::max(0, int(k-m));
        unsigned ub = std::min(k, n);

        for(unsigned i=lb; i<=ub; ++i)
        {
            unsigned j     = k - i;
            unsigned index = getLinearIndex(n+1, j, i);
            w[i+j].y      += cd[index]*z[index];
        }
    }

    return w;
}

static unsigned crossingCount(const std::vector<vec2> &_v, unsigned _degree)
{
    /* how many times does the Bezier curve cross the horizontal
       axis - the float of roots is less than or equal to this count */

    unsigned nCrossings = 0;
    int sign = _v[0].y < 0 ? -1 : 1;
    int oldSign = sign;

    for(unsigned i=1; i <= _degree; ++i)
    {
        sign = _v[i].y < 0 ? -1 : 1;
        if( sign != oldSign )
            nCrossings++;

        oldSign = sign;
    }

    return nCrossings;
}

static bool isControlPolygonLinear(const std::vector<vec2> &_v, unsigned _degree)
{
    /* is the control polygon for a Bezier curve suitably linear
       for subdivision to terminate?

       Given array of control vec2s, _v, find the distance from each
       interior control vec2 to line connecting v[0] and v[degree] */

    // implicit equation for line connecting first and last control vec2s
    float a = _v[0].y - _v[_degree].y;
    float b = _v[_degree].x - _v[0].x;
    float c = _v[0].x * _v[_degree].y - _v[_degree].x * _v[0].y;

    //float abSquared = a*a + b*b;

    std::vector<float> distance(_degree);       // Distances from control vec2s to line

    for(unsigned i=1; i<_degree; ++i)
    {
        // Compute distance from each of the vec2s to that line
        distance[i] = a * _v[i].x + b * _v[i].y + c;
        /*if( distance[i] > 0.0 )
        {
            distance[i] = (distance[i] * distance[i]) / abSquared;
        }
        else if( distance[i] < 0.0 )
        {
            distance[i] = -((distance[i] * distance[i]) / abSquared);
        }*/
    }

    // Find the largest distance
    float maxDistanceAbove = 0.0;
    float maxDistanceBelow = 0.0;

    for(unsigned i=1; i<_degree; ++i)
    {
        maxDistanceBelow = std::min(maxDistanceBelow, distance[i]);
        maxDistanceAbove = std::max(maxDistanceAbove, distance[i]);
    }

    // Implicit equation for zero line
    float a1 = 0.0;
    float b1 = 1.0;
    float c1 = 0.0;

    // Implicit equation for "above" line
    float a2 = a;
    float b2 = b;
    float c2 = c - maxDistanceAbove;

    float det = a1*b2 - a2*b1;
    float dInv = 1.0/det;

    float intercept1 = (b1*c2 - b2*c1)*dInv;

    //  Implicit equation for "below" line
    a2 = a;
    b2 = b;
    c2 = c - maxDistanceBelow;

    float intercept2 = (b1*c2 - b2*c1)*dInv;

    // Compute intercepts of bounding box
    float leftIntercept  = std::min(intercept1, intercept2);
    float rightIntercept = std::max(intercept1, intercept2);

    float error = 0.5*(rightIntercept-leftIntercept);

    return error < EPSILON;
}

static float computeXIntercept(const std::vector<vec2> &_v, unsigned _degree)
{
    /* compute intersection of line segnet from first
       to last control vec2 with horizontal axis */

    float XNM = _v[_degree].x - _v[0].x;
    float YNM = _v[_degree].y - _v[0].y;
    float XMK = _v[0].x;
    float YMK = _v[0].y;

    float detInv = - 1.0/YNM;

    return (XNM*YMK - YNM*XMK) * detInv;
}

static void subdivide(const std::vector<vec2> &_c, float _t, std::vector<vec2> *_left, std::vector<vec2> *_right)
{
    /* subdivide( _c:Array, _t:float, _left:Array, _right:Array )
       deCasteljau subdivision of an arbitrary-order Bezier curve */

    unsigned degree = _c.size()-1;
    unsigned n      = degree+1;
    float    t1     = 1.0 - _t;

    std::vector<vec2> p(_c.begin(), _c.end());

    p.resize(n*n);

    for(unsigned i=1; i<=degree; ++i)
    {
        for(unsigned j=0; j<=degree-i; ++j)
        {
            unsigned ij     = getLinearIndex(n, i, j);
            unsigned im1j   = getLinearIndex(n, i-1, j);
            unsigned im1jp1 = getLinearIndex(n, i-1, j+1);

            p[ij] = t1*p[im1j] + _t*p[im1jp1];
        }
    }

    _left->resize(degree+1);

    for(unsigned j=0; j<=degree; ++j)
    {
        (*_left)[j] = p[getLinearIndex(n, j, 0)];
    }

    _right->resize(degree+1);

    for(unsigned j=0; j<=degree; ++j)
    {
        (*_right)[j] = p[getLinearIndex(n, degree-j, j)];
    }
}

static void findRoots(std::vector<float> *t, const std::vector<vec2> &_w, unsigned _degree, unsigned _depth)
{
    // return roots in [0,1] of a polynomial in Bernstein-Bezier form
    switch (crossingCount(_w, _degree))
    {
    case 0:
        return;

    case 1:
        // Unique solution - stop recursion when the tree is deep enough (return 1 solution at midvec2)
        if( _depth >= MAX_DEPTH )
        {
            t->push_back(0.5*(_w[0].x + _w[_degree].x));
            return;
        }

        if( isControlPolygonLinear(_w, _degree) )
        {
            t->push_back(computeXIntercept(_w, _degree));
            return;
        }
        break;
    }

    // Otherwise, solve recursively after subdividing control polygon
    std::vector<vec2> left, right;
    subdivide(_w, 0.5, &left, &right);

    findRoots(t, left, _degree, _depth+1);
    findRoots(t, right, _degree, _depth+1);
}

static std::pair<float,float> closestPointToSegment(vec2 pointA, vec2 pointB, vec2 pointC)
{
    float dot1 = glm::dot(pointB - pointA, pointC - pointB);
    if (dot1 >= 0)
        return std::pair<float,float>(1.0f, glm::distance(pointB, pointC));

    float dot2 = glm::dot(pointA - pointB, pointC - pointA);
    if (dot2 >= 0)
        return std::pair<float,float>(0.0f, glm::distance(pointA, pointC));

    float len = glm::distance(pointA, pointB);
    float cross = glm::cross(glm::vec3(pointB - pointA, 0.0f), glm::vec3(pointC - pointA, 0.0f)).z;
    float dist = std::abs(cross / len);

    return std::pair<float,float>(0.5f, dist);
}

std::pair<float,float> closestPointToBezier(const std::vector<vec2> &curve, vec2 p)
{
    if (curve.size() == 2)
        return closestPointToSegment(curve[0], curve[1], p);

    if (curve.size() != 3 && curve.size() != 4)
        return std::pair<float,float>(0, 0);;

    int n = curve.size()-1;
    vec2 pt0 = curve[0];
    vec2 pt1 = curve[n];

    float d0 = glm::distance(pt0, p);
    float d1 = glm::distance(pt1, p);

    std::vector<vec2> w = toBezierForm(p, curve);

    std::vector<float> roots;
    findRoots(&roots, w, 2*n-1, 0);

    float dmin = std::min(d0, d1);
    float tmin = (d0 < d1) ? 0 : 1;

    for (unsigned i = 0; i < roots.size(); ++i) {
        float t = roots[i];
        if (t < 0 || t > 1) continue;

        vec2 tp = bezierPoint(curve, t);
        float d = glm::distance(p, tp);
        if (d < dmin) {
            tmin = t; dmin = d;
        }
    }

    return std::pair<float,float>(tmin, dmin);
}
