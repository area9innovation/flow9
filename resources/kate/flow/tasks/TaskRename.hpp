#pragma once

#include "TaskFactory.hpp"
#include "ui_CompileOutput.h"

namespace flow {

class TaskRename : public TaskFactory {
	Q_OBJECT
public:
	TaskRename(FlowEnv e, const QString& renamed, Task::Callback callback = []() { });
	~TaskRename();

private Q_SLOTS:
	void slotClose();
	void slotStarted();
	void slotStopped();

Q_SIGNALS:
	void signalEnableTerminateButton(bool);

private:
	bool makeGlobalConfig(const QString& root) const;

	Ui::CompilerOutput compilerOutput_;
	QWidget* compilerTab_;
};

}
