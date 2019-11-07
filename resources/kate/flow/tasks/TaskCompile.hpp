#pragma once

#include "TaskFactory.hpp"
#include "ui_CompileOutput.h"

namespace flow {

class TaskCompile : public TaskFactory {
	Q_OBJECT
public:
	TaskCompile(FlowEnv e, Task::Callback callback = []() { });
	~TaskCompile();

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
