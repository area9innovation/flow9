uniform highp vec2 u_out_pixel_size; // 2.0 / w, -2.0 / h
uniform highp vec2 u_out_offset;
uniform highp vec2 u_in_pixel_size; // 1.0 / w, -1.0 / h
uniform highp vec2 u_in_offset;

attribute highp vec2 a_VertexPos;

out frag_highp vec2 v_texCoord;

#ifdef TEX_SHIFTS
uniform highp vec2 u_tex_shifts[TEX_SHIFTS];

#ifdef FILTER_BEVEL
#define USE_MASK_B
#endif

#if defined(USE_MASK_B) && defined(USE_SWIZZLE_SHIFT)
#define SWIZZLE_MASK_B
#endif

#if defined(LOCAL_BLUR) || defined(FILTER_BLUR)
/* For trivial 3x3 gaussian (sigma <= 0.95 for 90% accuracy):

     u_blur_shift = alpha * texel_size;
     alpha = 2*exp(-1/2/sigma^2)/(1 + 2*exp(-1/2/sigma^2))
 */

  #define USE_LOCAL_BLUR
  uniform frag_highp vec2 u_local_blur_shift;

  #define VSHIFT_COUNT TEX_SHIFTS*4
#else
  #define VSHIFT_COUNT TEX_SHIFTS
#endif

#ifdef SWIZZLE_MASK_B
  out frag_highp vec4 v_shift_coord[VSHIFT_COUNT];
  #define STORE_VSHIFT(i,base) v_shift_coord[i] = vec4(base+shift, base-shift);
#else
  out frag_highp vec2 v_shift_coord_a[VSHIFT_COUNT];
  #ifdef USE_MASK_B
    out frag_highp vec2 v_shift_coord_b[VSHIFT_COUNT];
    #define STORE_VSHIFT(i,base) v_shift_coord_a[i] = base+shift; v_shift_coord_b[i] = base-shift;
  #else
    #define STORE_VSHIFT(i,base) v_shift_coord_a[i] = base+shift;
  #endif
#endif

#endif // TEX_SHIFTS

void main()
{
  // Transform pixel coordinates
  highp vec2 out_coord = a_VertexPos - u_out_offset;
  gl_Position = vec4(out_coord * u_out_pixel_size, 0.0, 1.0);

  // Compute texture coordinates
  highp vec2 scaled_xy = (a_VertexPos - u_in_offset) * u_in_pixel_size;
  v_texCoord = vec2(scaled_xy.x, 1.0 + scaled_xy.y);

#ifdef TEX_SHIFTS
  // Compute blur tap coordinates
  for (int i = 0; i < TEX_SHIFTS; i++) {
    highp vec2 shift = u_tex_shifts[i] * u_in_pixel_size;

#ifndef USE_LOCAL_BLUR
    STORE_VSHIFT(i, v_texCoord);
#else
    STORE_VSHIFT(i*4+0, v_texCoord + u_local_blur_shift);
    STORE_VSHIFT(i*4+1, v_texCoord + vec2(u_local_blur_shift.x,-u_local_blur_shift.y));
    STORE_VSHIFT(i*4+2, v_texCoord + vec2(-u_local_blur_shift.x,u_local_blur_shift.y));
    STORE_VSHIFT(i*4+3, v_texCoord - u_local_blur_shift);
#endif
  }
#endif
}
