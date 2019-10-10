#pragma once

#include <memory>
#include "TaskFactory.hpp"
#include "ui_DebugOutput.h"

namespace flow {

class TaskDumpIDs;
class TaskBuild;

class TaskDebug : public TaskFactory {
	Q_OBJECT
public:
	TaskDebug(FlowEnv e, int row, Task::Callback callback = []() { });

	Task* task() override;

private:
	std::unique_ptr<TaskBuild> builder_;
	std::unique_ptr<TaskDumpIDs> dumper_;
};

}
