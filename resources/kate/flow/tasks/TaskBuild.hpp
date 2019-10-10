#pragma once

#include "TaskFactory.hpp"
#include "ui_CompileOutput.h"

namespace flow {

class TaskBuild : public TaskFactory {
	Q_OBJECT
public:
	TaskBuild(FlowEnv e, int row, bool force, Task::Callback callback = []() { });
	~TaskBuild();

private Q_SLOTS:
	void slotClose();
	void slotStarted();
	void slotStopped();

Q_SIGNALS:
	void signalEnableTerminateButton(bool);

private:
	Ui::CompilerOutput compilerOutput_;
	QWidget* compilerTab_ = nullptr;
};

}
