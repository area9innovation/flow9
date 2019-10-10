#pragma once

#include "TaskFactory.hpp"

namespace flow {

class TaskLookupDef : public TaskFactory {
	Q_OBJECT
public:
	TaskLookupDef(FlowEnv e, Task::Callback callback = []() { });

private:
	QString out_;
};

}
