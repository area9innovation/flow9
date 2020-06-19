#pragma once

#include <memory>
#include "TaskFactory.hpp"
#include "ui_LaunchOutput.h"

namespace flow {

class TaskBuild;

class TaskRun : public TaskFactory {
	Q_OBJECT
public:
	TaskRun(FlowEnv e, int row, Task::Callback callback = []() { });
	~TaskRun();

	Task* task() override;

private Q_SLOTS:
	void slotClose();
	void slotStarted();
	void slotStopped();

Q_SIGNALS:
	void signalEnableTerminateButton(bool);

private:
	Ui::LaunchOutput launchOutput_;
	QWidget* launchTab_ = nullptr;
	std::unique_ptr<TaskBuild> builder_;
};

}
