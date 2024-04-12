#ifdef __linux__
# include <sys/sysinfo.h>
#endif

#ifdef __APPLE__
# include <mach/task.h>
# include <mach/mach_init.h>
#endif

#ifdef _WINDOWS
# include <windows.h>
#else
# include <sys/resource.h>
#endif
#include "__flow_runtime_memory.hpp"

namespace flow {

std::unique_ptr<MemoryPool> MemoryPool::instance_;

/// The amount of memory currently being used by this process, in bytes.
/// By default, returns the full virtual arena, but if resident=true,
/// it will report just the resident set in RAM (if supported on that OS).
std::size_t memory_used(bool resident) {
#if defined(__linux__)
	// Ugh, getrusage doesn't work well on Linux.  Try grabbing info
	// directly from the /proc pseudo-filesystem.  Reading from
	// /proc/self/statm gives info on your own process, as one line of
	// numbers that are: virtual mem program size, resident set size,
	// shared pages, text/code, data/stack, library, dirty pages.  The
	// mem sizes should all be multiplied by the page size.
	std::size_t size = 0;
	FILE *file = fopen("/proc/self/statm", "r");
	if (file) {
		unsigned long vm = 0;
		unsigned long rss = 0;
		// The first num: vm size
		if (fscanf(file, "%lu", &vm) != 1) {
			vm = 0;
		}
		// The second num: rss size
		if (fscanf(file, "%lu", &rss) != 1) {
			rss = 0;
		}
		fclose(file);
		if (resident) {
			size = static_cast<std::size_t>(rss) * getpagesize();
		} else {
			size = static_cast<std::size_t>(vm) * getpagesize();
		}
	}
	return size;

#elif defined(__APPLE__)
	// Inspired by:
	// http://miknight.blogspot.com/2005/11/resident-set-size-in-mac-os-x.html
	struct task_basic_info t_info;
	mach_msg_type_number_t t_info_count = TASK_BASIC_INFO_COUNT;
	task_info(current_task(), TASK_BASIC_INFO, (task_info_t)&t_info, &t_info_count);
	size_t size = (resident ? t_info.resident_size : t_info.virtual_size);
	return size;

#elif defined(_WINDOWS)
	// According to MSDN...
	PROCESS_MEMORY_COUNTERS counters;
	if (GetProcessMemoryInfo (GetCurrentProcess(), &counters, sizeof (counters)))
		return counters.PagefileUsage;
	else return 0;
#else
	// No idea what platform this is
	return 0;   // Punt
#endif
}

}
