#pragma once

#include "TaskFactory.hpp"
#include "ui_CompileOutput.h"

namespace flow {

class TaskLookupUses : public TaskFactory {
	Q_OBJECT
public:
	TaskLookupUses(FlowEnv e, Task::Callback callback = []() { });
	~TaskLookupUses();

private Q_SLOTS:
	void slotClose();
	void slotStarted();
	void slotStopped();

Q_SIGNALS:
	void signalEnableTerminateButton(bool);

private:
	Ui::CompilerOutput compilerOutput_;
	QWidget* compilerTab_;
};

}
