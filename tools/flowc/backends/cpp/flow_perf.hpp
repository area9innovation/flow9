#pragma once

#include <cstdint>

// #define FLOW_ENABLE_PERF_COUNTERS

#ifdef FLOW_ENABLE_PERF_COUNTERS

inline uint64_t rdtsc() {
	uint64_t a, d;
	__asm__ volatile ("rdtsc" : "=a" (a), "=d" (d));
	return (d<<32) | a;
}

struct tsc_holder {
	uint64_t& value_;
	uint64_t t0_;
	tsc_holder(uint64_t& v) : value_(v) {
		t0_ = rdtsc();
	}
	~tsc_holder() {
		value_ += rdtsc() - t0_;
	}
};

#else // FLOW_ENABLE_PERF_COUNTERS

inline uint64_t rdtsc() {
	return 0;
}

struct tsc_holder {
	tsc_holder(uint64_t& ) {}
};


#endif // FLOW_ENABLE_PERF_COUNTERS

int rdtsc2ms(uint64_t t) {
	return  t/2600000;
}
