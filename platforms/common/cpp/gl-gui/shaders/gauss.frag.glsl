#define GAUSS_SHIFTS TEX_SHIFTS

uniform lowp sampler2D s_tex;
#define TEX(pos) texture2D(s_tex, pos)

in frag_highp vec2 v_texCoord;

#ifdef USE_SWIZZLE_SHIFT
in frag_highp vec4 v_shift_coord[GAUSS_SHIFTS];
#define SHIFT_COORD_A(i) v_shift_coord[i].xy
#define SHIFT_COORD_B(i) v_shift_coord[i].zw
#else
uniform mediump vec2 u_gauss_shifts[16];
#define SHIFT_COORD_A(i) v_texCoord + u_gauss_shifts[i]
#define SHIFT_COORD_B(i) v_texCoord - u_gauss_shifts[i]
#endif


uniform mediump int u_gauss_steps;
uniform mediump float u_gauss_base_coeff;
uniform mediump float u_gauss_shift_coeff[32];

#ifndef GL_ES
out frag_highp vec4 fragColor;
#endif

void main() {
  mediump vec4 color = vec4(0.0);
  for (int i = 0; i < u_gauss_steps; i++) {
      color += (TEX(SHIFT_COORD_A(i)) + TEX(SHIFT_COORD_B(i))) * u_gauss_shift_coeff[i];
  }

  gl_FragColor = TEX(v_texCoord) * u_gauss_base_coeff + color;
}
