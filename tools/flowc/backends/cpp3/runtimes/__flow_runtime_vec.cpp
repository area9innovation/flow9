#include "__flow_runtime_vec.hpp"

namespace flow {

Int VecStats::max_len = 0;
std::mutex VecStats::m;
std::vector<Int> VecStats::len_distrib(2048, 0);

}
