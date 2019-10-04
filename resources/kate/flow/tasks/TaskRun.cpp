#include <QWidget>
#include <QTextStream>
#include <KTextEditor/View>
#include "execs/Runner.hpp"
#include "FlowView.hpp"
#include "TaskRun.hpp"
#include "TaskBuild.hpp"

namespace flow {

TaskRun::TaskRun(FlowEnv e, int row, Task::Callback cb) : TaskFactory(e, cb), launchTab_(new QWidget()) {
	QPlainTextEdit* output;
	QWidget* tab;
	QPushButton* terminateButton;

	if (!env.view.flowOutput_.ui.terminateCompilerButton->isEnabled() &&
		env.view.flowOutput_.ui.reuseCompilerOutCheckBox->checkState() == Qt::Checked) {
		// Reuse default launch output
		output = env.view.flowOutput_.ui.launchOutTextEdit;
		tab = env.view.flowOutput_.ui.defaultLaunchTab;
		terminateButton = env.view.flowOutput_.ui.terminateLaunchButton;
		output->clear();
	} else {
		// Make a new launch tab
		launchOutput_.setupUi(launchTab_);
		env.view.addOutputTab(launchTab_, QLatin1String("Launch"));
		connect(launchOutput_.closeButton, SIGNAL(clicked()), this, SLOT(slotClose()));

		output = launchOutput_.launchOutTextEdit;
		tab = launchTab_;
		terminateButton = launchOutput_.terminateLaunchButton;
	}

	QString prog     = env.view.flowConfig_.ui.launchTableWidget->item(row, 1)->text();
	QString odir     = env.view.flowConfig_.ui.launchTableWidget->item(row, 2)->text();
	QString targ     = env.view.flowConfig_.ui.launchTableWidget->item(row, 3)->text();
	QString progArgs = env.view.flowConfig_.ui.launchTableWidget->item(row, 5)->text();
	QString execArgs = env.view.flowConfig_.ui.launchTableWidget->item(row, 6)->text();
	QString flowdir  = env.view.flowConfig_.ui.flowdirLineEdit->text();
	Runner runner(env.view.flowConfig_.ui, prog, targ, flowdir, odir);

	QStringList args = runner.args(execArgs, progArgs);
#ifdef DEBUG
	QTextStream(stdout) << "RUN: " << runner.invocation() << " " << args.join(QLatin1Char(' ')) << "\n";
#endif
	//QString workingDir = runner.confdir();
	QString executor = runner.invocation();
	if (executor.isEmpty()) {
		return;
	}

	Task::Output out = [this, output, tab](const QString& str) {
		appendText(output, str);
		env.view.switchToOutputTab(tab);
	};
	Task::Output err = [this, output, tab](const QString& str) {
		appendText(output, str);
		env.view.switchToOutputTab(tab);
	};
	task_ = new Task(env, executor, args, odir, out, err, callback);
	connect(terminateButton, SIGNAL(clicked()), task_, SLOT(slotStop()));
	connect(this, SIGNAL(signalEnableTerminateButton(bool)), terminateButton, SLOT(setEnabled(bool)));
	connect(task_, SIGNAL(signalStarted()), this, SLOT(slotStarted()));
	connect(task_, SIGNAL(signalStopped()), this, SLOT(slotStopped()));

	if (env.view.flowConfig_.progTimestampsChanged(row) || !runner.target().exists()) {
		builder_.reset(new TaskBuild(env, row, false, [this]() { task_->slotStart(); }));
	}
}

TaskRun::~TaskRun() {
	if (task_) {
		task_->slotStop();
	}
	if (launchTab_) {
		env.view.removeOutputTab(launchTab_);
	}
}

Task* TaskRun::task() {
	return builder_ ? builder_->task() : task_;
}

void TaskRun::slotClose() {
	delete this;
}

void TaskRun::slotStarted() {
	emit signalEnableTerminateButton(true);
}

void TaskRun::slotStopped() {
	emit signalEnableTerminateButton(false);
	task_ = nullptr;
}

}
