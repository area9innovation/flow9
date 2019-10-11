#pragma once

#include "TaskFactory.hpp"

namespace flow {

class TaskDumpIDs : public TaskFactory {
	Q_OBJECT
public:
	TaskDumpIDs(FlowEnv e, int row, Task::Callback callback = []() { });

private:
	QString out_;
};

}
