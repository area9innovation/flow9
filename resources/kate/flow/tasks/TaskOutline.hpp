#pragma once

#include "TaskFactory.hpp"

namespace flow {

class TaskOutline : public TaskFactory {
	Q_OBJECT
public:
	TaskOutline(FlowEnv e, const QString& file, Task::Callback callback = []() { });

private:
	QString out_;
};

}
