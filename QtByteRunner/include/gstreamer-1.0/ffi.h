#ifdef __i386__
#include "i386/ffi.h"
#elif defined(__ppc__)
#include "ppc/ffi.h"
#elif defined(__x86_64__)
#include "x86_64/ffi.h"
#elif defined(__arm__)
#include "arm/ffi.h"
#elif defined(__arm64__)
#include "arm64/ffi.h"
#else
#error "Unsupported Architecture"
#endif
