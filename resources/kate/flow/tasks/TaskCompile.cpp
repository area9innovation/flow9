#include <QWidget>
#include <QTextStream>
#include <KTextEditor/View>
#include "execs/Compiler.hpp"
#include "FlowView.hpp"
#include "TaskCompile.hpp"

namespace flow {

TaskCompile::TaskCompile(FlowEnv e, Task::Callback cb) : TaskFactory(e, cb), compilerTab_(new QWidget()) {
	QPlainTextEdit* output;
	QWidget* tab;
	QPushButton* terminateButton;

	if (!env.view.flowOutput_.ui.terminateCompilerButton->isEnabled() &&
		env.view.flowOutput_.ui.reuseCompilerOutCheckBox->checkState() == Qt::Checked) {
		// Reuse default compiler output
		output = env.view.flowOutput_.ui.compilerOutTextEdit;
		tab = env.view.flowOutput_.ui.defaultCompilerTab;
		terminateButton = env.view.flowOutput_.ui.terminateCompilerButton;
		output->clear();
	} else {
		// Make a new compiler tab
		compilerOutput_.setupUi(compilerTab_);
		env.view.addOutputTab(compilerTab_, QLatin1String("Compiler"));
		connect(compilerOutput_.closeButton, SIGNAL(clicked()), this, SLOT(slotClose()));

		output = compilerOutput_.compilerOutTextEdit;
		tab = compilerTab_;
		terminateButton = compilerOutput_.terminateCompilerButton;
	}

	QString file = curFile(env.main);
	env.main->activeView()->document()->documentSave();
	QString flowdir = env.view.flowConfig_.ui.flowdirLineEdit->text();
	Compiler compiler(env.view.flowConfig_.ui, file, flowdir);
	QStringList args;
	args << compiler.includeArgs();
	args << compiler.compileArgs(file);
#ifdef DEBUG
	QTextStream(stdout) << "COMPILE: " << compiler.invocation() << " " << args.join(QLatin1Char(' ')) << "\n";
#endif
	QString workingDir = compiler.confdir();
	QString executor = compiler.invocation();

	Task::Output out = [this, tab, output](const QString& str) {
		appendText(output, str);
		env.view.switchToOutputTab(tab);
	};
	Task::Output err = [this, tab, output](const QString& str) {
		appendText(output, str);
		env.view.switchToOutputTab(tab);
	};
	task_ = new Task(env, executor, args, workingDir, out, err, callback);
	connect(terminateButton, SIGNAL(clicked()), task_, SLOT(slotStop()));
	connect(this, SIGNAL(signalEnableTerminateButton(bool)), terminateButton, SLOT(setEnabled(bool)));
	connect(task_, SIGNAL(signalStarted()), this, SLOT(slotStarted()));
	connect(task_, SIGNAL(signalStopped()), this, SLOT(slotStopped()));
	connect(output, SIGNAL(signalCompilerLocation(QString, int, int)), &env.view, SLOT(slotGotoLocation(QString, int, int)));
}

TaskCompile::~TaskCompile() {
	if (task_) {
		task_->slotStop();
	}
	if (compilerTab_) {
		env.view.removeOutputTab(compilerTab_);
	}
}

void TaskCompile::slotClose() {
	delete this;
}

void TaskCompile::slotStarted() {
	emit signalEnableTerminateButton(true);
}

void TaskCompile::slotStopped() {
	emit signalEnableTerminateButton(false);
	task_ = nullptr;
}

}
