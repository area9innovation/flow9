#ifndef GL_ES
#define highp
#define frag_highp
#define mediump
#define lowp
#else
#ifndef GL_FRAGMENT_PRECISION_HIGH
#define frag_highp mediump
#else
#define frag_highp highp
#endif
#endif

#if defined(GL_ES) && (__VERSION__ < 300)
    // GLSL ES 1.00 (OpenGL ES 2.0): uses varying/attribute/texture2D
    #define in  varying
    #define out varying
#elif !defined(GL_ES) && (__VERSION__ <= 120)
    // GLSL 1.10/1.20 (desktop GL <= 2.1): uses varying/attribute/texture2D
    #define in  varying
    #define out varying
#else
    // GLSL ES 3.00+ or desktop GLSL 1.30+: uses in/out/texture
    #define attribute    in
    #define texture2D    texture
    #define gl_FragColor fragColor
#endif
