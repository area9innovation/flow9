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

#if defined(GL_ES) || (__VERSION__ <= 120)
    #define in  varying
    #define out varying
#else
    #define attribute    in
    #define texture2D    texture
    #define gl_FragColor fragColor
#endif
