#pragma once

#ifdef NDEBUG
	#define FLOW_INLINE inline
	#define FLOW_ASSERT(cond)	((void)0) 
	#ifdef __GNUC__
		#define FLOW_UNREACHABLE()	__builtin_unreachable()
		#define FLOW_ALWAYS_INLINE __attribute__((always_inline)) inline
	#else
		#define FLOW_UNREACHABLE()	 { __assume(false); }
		#define FLOW_ALWAYS_INLINE inline
	#endif
	#define FLOW_ABORT	std::abort();
	#define FLOW_ASSUME(x)	__builtin_assume(x)
#else
	#define FLOW_INLINE
	#define FLOW_ALWAYS_INLINE
	#include <cassert>
	#define FLOW_ASSERT	assert
	#define FLOW_UNREACHABLE()	{ assert(false); std::abort(); }
	#define DEBUG
	#define FLOW_ABORT	{ assert(!"FLOW_ABORT"); std::abort(); }
	#define FLOW_ASSUME		FLOW_ASSERT
#endif

#define FLOW_PRN(x) std::wcout << x << std::endl;

#define FLOW_ENABLE_CONCURRENCY
// #define FLOW_DEBUG_MEMPOOLS


