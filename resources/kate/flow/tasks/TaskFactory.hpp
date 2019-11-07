#pragma once

#include "Task.hpp"

namespace flow {

class TaskFactory : public QObject {
	Q_OBJECT
public:
	TaskFactory(FlowEnv e, Task::Callback callback = []() { });
	virtual ~TaskFactory() { }

	virtual Task* task() { return task_; }

protected:
	FlowEnv env;
	Task::Callback callback;
	Task* task_ = nullptr;
};

}
