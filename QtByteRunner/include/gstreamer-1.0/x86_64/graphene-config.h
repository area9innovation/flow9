/* graphene-config.h
 *
 * This is a generated file. Please modify 'configure.ac'.
 */

#ifndef __GRAPHENE_CONFIG_H__
#define __GRAPHENE_CONFIG_H__

#ifdef __cplusplus
extern "C" {
#endif

#ifndef GRAPHENE_SIMD_BENCHMARK
# if defined(__SSE__) || (_M_IX86_FP > 0) || (_M_X64 > 0)
#  define GRAPHENE_HAS_SSE 1
# endif
# define GRAPHENE_HAS_SCALAR 1
#endif /* GRAPHENE_SIMD_BENCHMARK */

#if defined(GRAPHENE_HAS_SSE)
# define GRAPHENE_USE_SSE
# define GRAPHENE_SIMD_S "sse"
#elif defined(GRAPHENE_HAS_ARM_NEON)
# define GRAPHENE_USE_ARM_NEON
# define GRAPHENE_SIMD_S "neon"
#elif defined(GRAPHENE_HAS_GCC)
# define GRAPHENE_USE_GCC
# define GRAPHENE_SIMD_S "gcc"
#elif defined(GRAPHENE_HAS_SCALAR)
# define GRAPHENE_USE_SCALAR
# define GRAPHENE_SIMD_S "scalar"
#else
# error "Unsupported platform."
#endif

#ifndef __GI_SCANNER__
# if defined(GRAPHENE_USE_SSE)
#  include <xmmintrin.h>
#  include <emmintrin.h>
#  if defined(_M_IX86_FP)
#   if _M_IX86_FP >= 2
#    define GRAPHENE_USE_SSE4_1
#   endif
#  elif defined(__SSE4_1__)
#   define GRAPHENE_USE_SSE4_1
#  endif
#  if defined(GRAPHENE_USE_SSE4_1)
#   include <smmintrin.h>
#  endif
typedef __m128 graphene_simd4f_t;
# elif defined(GRAPHENE_USE_ARM_NEON)
#  include <arm_neon.h>
typedef float32x4_t graphene_simd4f_t;
# elif defined(GRAPHENE_USE_GCC)
typedef float graphene_simd4f_t __attribute__((vector_size(16)));
# elif defined(GRAPHENE_USE_SCALAR)
typedef struct {
  /*< private >*/
  float x, y, z, w;
} graphene_simd4f_t;
# else
#  error "Unsupported platform."
# endif
#else /* __GI_SCANNER__ */
/* The gobject-introspection scanner has issues parsing the
 * system headers with SIMD built-ins, so we fall back to
 * scalars; it does not really matter, as we wrap them in
 * our public API, and introspection cannot use the SIMD API
 * directly anyway.
 */
typedef struct {
  /*< private >*/
  float x, y, z, w;
} graphene_simd4f_t;
#endif /* __GI_SCANNER__ */

typedef struct {
  /*< private >*/
  graphene_simd4f_t x, y, z, w;
} graphene_simd4x4f_t;

#ifdef __cplusplus
}
#endif

#endif /* __GRAPHENE_CONFIG_H__ */
