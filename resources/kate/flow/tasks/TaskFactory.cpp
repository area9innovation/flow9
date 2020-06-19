#include "TaskFactory.hpp"

namespace flow {

TaskFactory::TaskFactory(FlowEnv e, Task::Callback cb) : env(e), callback(cb) { }

}
