#define GAUSS_SHIFTS TEX_SHIFTS

uniform lowp sampler2D s_tex;
#define TEX(pos) texture2D(s_tex, pos)

in frag_highp vec2 v_texCoord;

#ifdef USE_SWIZZLE_SHIFT
in frag_highp vec4 v_shift_coord[GAUSS_SHIFTS];
#define SHIFT_COORD_A(i) v_shift_coord[i].xy
#define SHIFT_COORD_B(i) v_shift_coord[i].zw
#else
in frag_highp vec2 v_shift_coord_a[GAUSS_SHIFTS];
in frag_highp vec2 v_shift_coord_b[GAUSS_SHIFTS];
#define SHIFT_COORD_A(i) v_shift_coord_a[i]
#define SHIFT_COORD_B(i) v_shift_coord_b[i]
#endif

uniform mediump float u_gauss_base_coeff;
uniform mediump vec4 u_gauss_shift_coeff;

#ifndef GL_ES
out frag_highp vec4 fragColor;
#endif

void main() {
  mediump vec4 cb = TEX(v_texCoord);
  mediump mat4 c;

  c[0] = TEX(SHIFT_COORD_A(0)) + TEX(SHIFT_COORD_B(0));

#if GAUSS_SHIFTS == 1
  // 5x5: <= 1.54
  cb = c[0]*u_gauss_shift_coeff[0] + cb*u_gauss_shift_coeff[1];
#elif GAUSS_SHIFTS == 2
  // 9x9: <= 2.12
  c[1] = TEX(SHIFT_COORD_A(1));
  c[2] = TEX(SHIFT_COORD_B(1));
  c[3] = cb;
  cb = c * u_gauss_shift_coeff;
#elif GAUSS_SHIFTS == 3
  // 13x13: <= 2.95
  c[1] = TEX(SHIFT_COORD_A(1)) + TEX(SHIFT_COORD_B(1));
  c[2] = TEX(SHIFT_COORD_A(2)) + TEX(SHIFT_COORD_B(2));
  c[3] = cb;
  cb = c * u_gauss_shift_coeff;
#elif GAUSS_SHIFTS == 4
  // 17x17: <= 4.95
  c[1] = TEX(SHIFT_COORD_A(1)) + TEX(SHIFT_COORD_B(1));
  c[2] = TEX(SHIFT_COORD_A(2)) + TEX(SHIFT_COORD_B(2));
  c[3] = TEX(SHIFT_COORD_A(3)) + TEX(SHIFT_COORD_B(3));
  cb = cb * u_gauss_base_coeff + c * u_gauss_shift_coeff;
#else
#error Invalid gauss shift count
#endif
  
  gl_FragColor = cb;
}
