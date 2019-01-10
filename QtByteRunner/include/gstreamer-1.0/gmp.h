#ifdef __i386__
#include "i386/gmp.h"
#elif defined(__ppc__)
#include "ppc/gmp.h"
#elif defined(__x86_64__)
#include "x86_64/gmp.h"
#elif defined(__arm__)
#include "arm/gmp.h"
#elif defined(__arm64__)
#include "arm64/gmp.h"
#else
#error "Unsupported Architecture"
#endif
