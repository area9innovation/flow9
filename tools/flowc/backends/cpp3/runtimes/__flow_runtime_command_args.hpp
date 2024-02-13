#pragma once

#include <map>
#include "__flow_runtime_types.hpp"

namespace flow {

struct CommandArgs {
	static void init(int argc, const char* argv[]);
	static void dispose() { args.clear(); }
	static std::map<string, string> args;
};

}
