#ifdef __i386__
#include "i386/graphene-config.h"
#elif defined(__ppc__)
#include "ppc/graphene-config.h"
#elif defined(__x86_64__)
#include "x86_64/graphene-config.h"
#elif defined(__arm__)
#include "arm/graphene-config.h"
#elif defined(__arm64__)
#include "arm64/graphene-config.h"
#else
#error "Unsupported Architecture"
#endif
