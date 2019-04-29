#ifdef EXTERNAL_TEXTURE
#extension GL_OES_EGL_image_external : require
#endif

uniform lowp vec4 u_mainColor;

#ifdef DRAW_FANCY

#ifdef EXTERNAL_TEXTURE
uniform samplerExternalOES s_tex;
#else
uniform lowp sampler2D s_tex;
#endif

#define TEX(pos) texture2D(s_tex, pos)

uniform bool u_useTexture;

// Will swizzle the red and blue channels when accessing the texture if true
// Necessary for some video formats in order to avoid swizzling on the CPU
uniform bool u_swizzleRB;

in lowp vec4 v_drawColor;
in frag_highp vec2 v_texCoord;
#endif

#ifndef GL_ES
out frag_highp vec4 fragColor;
#endif

void main() {
#ifndef DRAW_FANCY  
  gl_FragColor = u_mainColor;
#else
  lowp vec4 color;
  if (u_useTexture) {
    color = TEX(v_texCoord);
    if (u_swizzleRB)
      color.rb = color.br;
    color.rgb = mix(color.rgb, u_mainColor.rgb * color.a, u_mainColor.a);
  } else {
    color = u_mainColor;
  }
  gl_FragColor = color * v_drawColor;
#endif
}
