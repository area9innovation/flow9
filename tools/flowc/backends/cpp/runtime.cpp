#include "flow_natives.hpp"
#include "flow_object.hpp"
#include "flow_array.hpp"
#include "flow_string.hpp"

namespace flow {

	template <typename T>
	using array_t = array<ptr_type_t<T>>;

} // namespace flow


using flow::flow_t;

template <typename T1, typename T2, typename = std::enable_if_t<!std::is_same_v<T1, T2> && std::is_convertible_v<T1, T2>>>
FLOW_INLINE bool operator== (const T1& left, const T2& right) {
	return right == static_cast<T2>(left);	// buggy cast!
}

template <typename T1, typename T2, typename = flow::is_union_type_t<T1>, typename = flow::is_struct_type_t<T2>>
FLOW_INLINE bool operator== (const T1& left, const flow::ptr<T2>& right) {
	if (left.id_() == right.obj_id()) {
		return left == static_cast<T1>(right);
	} else {
		return false;
	}
}

template <typename T1, typename T2>
FLOW_INLINE bool operator!= (const T1& left, const T2& right) {
	return !(left == right);
}

static_assert(sizeof(int) == 4, "Requires 32-bit mode!");

void flow_main();

template <typename T>
FLOW_INLINE bool operator == (const std::function<T>& f1, const std::function<T>& f2) {
	// we cannot compare functions
	FLOW_ABORT
}

namespace flow {
	void register_struct_creators();
}

void print_rdtsc(const char* msg, uint64_t t) {
	if (t != 0) {
		std::wcout << msg << rdtsc2ms(t) << " ms" << std::endl;
	}
}

uint64_t g_tsc_start = 0, g_tsc_finish = 0;

uint64_t g_tree_lookup_tsc = 0;
uint64_t g_tree_lookup_cmp_tsc = 0;
uint64_t g_set_tree_tsc = 0;


void dump_tsc_counters() {
	if (g_tsc_finish == 0) g_tsc_finish = rdtsc();
	print_rdtsc("total      = ", g_tsc_finish - g_tsc_start);
	print_rdtsc("alloc      = ", flow::mem_pools.alloc_tsc_);
	print_rdtsc("release    = ", flow::mem_pools.release_tsc_);
	print_rdtsc("replace    = ", g_replace_tsc);
	print_rdtsc("array ctr  = ", flow::g_array_tsc);
	print_rdtsc("string ctr = ", flow::g_string_tsc);
	print_rdtsc("string ops = ", flow::g_string2_tsc);
	print_rdtsc("string cmp = ", flow::g_string_cmp_tsc);
	print_rdtsc("lookup     = ", g_tree_lookup_tsc);
	print_rdtsc("lookup_cmp = ", g_tree_lookup_cmp_tsc);
	print_rdtsc("deep_copy  = ", g_deep_copy_tsc);
	// print_rdtsc("setTree    = ", g_set_tree_tsc);
	print_rdtsc("page_alloc = ", flow::g_page_alloc);
}

#ifdef FLOWC_RUNTIME_INCLUDE_URLPARAMETER
namespace flow {
	void refreshAllUrlParameters();
}
#endif // FLOWC_RUNTIME_INCLUDE_URLPARAMETER

void printLookupTreeStats();

int main(int argc, char** argv) {
	stored_argv = argv;
	stored_argc = argc;
	
	
	flow::register_struct_creators();
	
#ifdef FLOWC_RUNTIME_INCLUDE_URLPARAMETER
	flow::refreshAllUrlParameters();
#endif // FLOWC_RUNTIME_INCLUDE_URLPARAMETER

	
#ifdef DEBUG
	int allocated = flow::gAllocated;
	auto strings_count0 = flow::string_base::live_counter_;
#endif
#ifdef FLOW_DEBUG_STRINGS
	// print_live_strings();
	auto str0 = flow::g_live_strings;
#endif
	g_tsc_start = rdtsc();
	flow_main();
	g_tsc_finish = rdtsc();
#ifdef DEBUG
	auto strings_count1 = flow::string_base::live_counter_;
#endif
#ifdef FLOW_DEBUG_STRINGS
	auto str1 = flow::g_live_strings;
	if (str0 != str1) {
		FLOW_PRN("---- str0 ----");
		for (auto& s : str0) {
			if (str1.count(s) == 0) {
				FLOW_PRN(s->to_wstring() << "; ref = " << s->dbg_ref_count());
			}
		}
		FLOW_PRN("---- str1 ----");
		for (auto& s : str1) {
			if (str0.count(s) == 0) {
				FLOW_PRN(s->to_wstring() << "; ref = " << s->dbg_ref_count());
			}
		}
		FLOW_PRN("---------");
	}
#endif
	dump_tsc_counters();
	// printLookupTreeStats();
#ifdef DEBUG
	flow::print_mem_stat();
	FLOW_ASSERT(allocated == flow::gAllocated);
	if (strings_count0 != strings_count1) {
		FLOW_PRN(strings_count0);
		FLOW_PRN(strings_count1);
		FLOW_PRN(flow::string_base::live_counter_);
		FLOW_ASSERT(strings_count0 == flow::string_base::live_counter_);
	}
#endif

	auto allocated_mem_size = flow::mem_pools.mem_size() + flow::string::pool_.mem_size();
	FLOW_PRN("allocated " << (allocated_mem_size / 1048576) << " mb");

	return 0;
}
