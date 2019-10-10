#pragma once

#include "TaskFactory.hpp"

namespace flow {

class TaskLookupType : public TaskFactory {
	Q_OBJECT
public:
	TaskLookupType(FlowEnv e, Task::Callback callback = []() { });

private:
	QString out_;
};

}
