#ifndef DRAW_FANCY
#error DRAW_FANCY required
#endif

uniform lowp sampler2D s_tex;
#define TEX(pos) texture2D(s_tex, pos)

in lowp vec4 v_drawColor;
in frag_highp vec2 v_texCoord;

uniform lowp float u_font_dist_min;
uniform mediump float u_font_dist_coeff;

#ifndef GL_ES
out frag_highp vec4 fragColor;
#endif

void main() {
  mediump float dist = TEX(v_texCoord).a - u_font_dist_min;
  mediump float t = clamp(dist * u_font_dist_coeff, 0.0, 1.0);
#ifndef GL_ES
  //lowp float alpha = smoothstep(u_font_dist_min, u_font_dist_max, dist);
  lowp float alpha = t * t * (3.0 - 2.0*t);
  gl_FragColor = v_drawColor * alpha;
#else
  gl_FragColor = v_drawColor * t;
#endif
}