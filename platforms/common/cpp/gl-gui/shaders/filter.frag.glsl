uniform lowp sampler2D s_tex;
#define TEX(pos) texture2D(s_tex, pos)

#ifdef ONE_TEXTURE
#define MASK(pos) TEX(pos)
#else
uniform lowp sampler2D s_mask;
#define MASK(pos) texture2D(s_mask, pos)
#endif

in frag_highp vec2 v_texCoord;

uniform bool u_filter_inner;

#ifdef FILTER_SHADOW
uniform lowp vec4 u_shadow_color; // non-premultiplied
#endif

#ifdef FILTER_BEVEL
uniform lowp vec4 u_bevel_color1; // non-premultiplied
uniform lowp vec4 u_bevel_color2;
#define USE_MASK_B
#endif

#ifdef TEX_SHIFTS

#if defined(USE_MASK_B) && defined(USE_SWIZZLE_SHIFT)
#define SWIZZLE_MASK_B
#endif

#if defined(LOCAL_BLUR) || defined(FILTER_BLUR)
  #define VSHIFT_COUNT TEX_SHIFTS*4
  #define GET_MASK(id) (0.25*(MASK(SHIFT_COORD(id*4)) + MASK(SHIFT_COORD(id*4+1)) + MASK(SHIFT_COORD(id*4+2)) + MASK(SHIFT_COORD(id*4+3))))
#else
  #define VSHIFT_COUNT TEX_SHIFTS
  #define GET_MASK(id) MASK(SHIFT_COORD(id))
#endif

#ifdef SWIZZLE_MASK_B
  in frag_highp vec4 v_shift_coord[VSHIFT_COUNT];
  #define SHIFT_COORD_A(i) v_shift_coord[i].xy
  #define SHIFT_COORD_B(i) v_shift_coord[i].zw
#else
  in frag_highp vec2 v_shift_coord_a[VSHIFT_COUNT];
  #define SHIFT_COORD_A(i) v_shift_coord_a[i]
  #ifdef USE_MASK_B
    in frag_highp vec2 v_shift_coord_b[VSHIFT_COUNT];
    #define SHIFT_COORD_B(i) v_shift_coord_b[i]
  #endif
#endif

#endif

#ifndef GL_ES
out frag_highp vec4 fragColor;
#endif

void main() {
  lowp vec4 color = TEX(v_texCoord);

#ifndef TEX_SHIFTS
  lowp vec4 mask = MASK(v_texCoord);
#else
  #define SHIFT_COORD(i) SHIFT_COORD_A(i)
  lowp vec4 mask = GET_MASK(0);
  #undef SHIFT_COORD
#ifdef USE_MASK_B
  #define SHIFT_COORD(i) SHIFT_COORD_B(i)
  lowp vec4 mask2 = GET_MASK(0);
  #undef SHIFT_COORD
#endif
#endif

#if defined(FILTER_MASK)
  // Mask filter
  color *= mask.a;
#elif defined(FILTER_BLUR)
  // Local blur filter
  color = mask;
#elif defined(FILTER_SHADOW) || defined(FILTER_BEVEL)
  // Complex filters
 #if defined(FILTER_SHADOW)
    if (u_filter_inner) {
      color += (u_shadow_color * color.a - color * u_shadow_color.a) * (1.0 - mask.a);
    } else {
      color += u_shadow_color * (mask.a * (1.0 - color.a));
    }
 #elif defined(FILTER_BEVEL)
    lowp float adiff = mask.a - mask2.a;
    if (u_filter_inner) {
      lowp vec4 bcolor = (adiff > 0.0 ? u_bevel_color1 : u_bevel_color2);
      color += (bcolor * color.a - color * bcolor.a) * adiff;
    } else {
      lowp vec4 bcolor = (adiff > 0.0 ? u_bevel_color1 : u_bevel_color2);
      color += bcolor * (adiff * (1.0 - color.a));
    }
 #endif
#else
#error No filter selected
#endif

  gl_FragColor = color;
}
