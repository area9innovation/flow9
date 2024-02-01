#include "__flow_runtime_command_args.hpp"

using namespace flow;

std::map<string, string> CommandArgs::args;

void CommandArgs::init(int argc, const char* argv[]) {
	for (int i = 1; i < argc; ++ i) {
		std::string arg(argv[i]);
		std::size_t eq_ind = arg.find("=");
		if (eq_ind == std::string::npos) {
			CommandArgs::args[std2string(arg)] = u"";
		} else {
			std::string key = arg.substr(0, eq_ind);
			std::string val = arg.substr(eq_ind + 1, arg.size() - eq_ind - 1);
			CommandArgs::args[std2string(key)] = std2string(val);
		}
	}
}
