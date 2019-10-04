#include <QWidget>
#include <QTextStream>
#include <KTextEditor/View>
#include "execs/Compiler.hpp"
#include "FlowView.hpp"
#include "TaskLookupUses.hpp"

namespace flow {

TaskLookupUses::TaskLookupUses(FlowEnv e, Task::Callback cb) : TaskFactory(e, cb), compilerTab_(new QWidget()) {
	compilerOutput_.setupUi(compilerTab_);
	env.view.addOutputTab(compilerTab_, QLatin1String("Compiler"));
	connect(compilerOutput_.closeButton, SIGNAL(clicked()), this, SLOT(slotClose()));
	QString file = curFile(env.main);
	env.main->activeView()->document()->documentSave();
	QString id = curIdentifier(env.main);
	QString line = QString::number(env.main->activeView()->cursorPosition().line() + 1);
	QString col = QString::number(env.main->activeView()->cursorPosition().column() + 1);
	QString flowdir = env.view.flowConfig_.ui.flowdirLineEdit->text();
	Compiler compiler(env.view.flowConfig_.ui, file, flowdir);
	QStringList args;
	args << compiler.includeArgs();
	args << QLatin1String("find-uses=") + id;
	args << QLatin1String("exp-line=") + line;
	args << QLatin1String("exp-column=") + col;
	args << file;
#ifdef DEBUG
	QTextStream(stdout) << "FIND ALL USES: " << compiler.invocation() << " " << args.join(QLatin1Char(' ')) << "\n";
#endif
	QString workingDir = compiler.confdir();
	QString executor = compiler.invocation();

	Task::Output out = [this](const QString& str) {
		appendText(compilerOutput_.compilerOutTextEdit, str);
		env.view.switchToOutputTab(compilerTab_);
	};
	Task::Output err = [this](const QString& str) {
		appendText(compilerOutput_.compilerOutTextEdit, str);
		env.view.switchToOutputTab(compilerTab_);
	};
	task_ = new Task(env, executor, args, workingDir, out, err, callback);
	connect(compilerOutput_.terminateCompilerButton, SIGNAL(clicked()), task_, SLOT(slotStop()));
	connect(compilerOutput_.compilerOutTextEdit, SIGNAL(signalCompilerLocation(QString, int, int)), &env.view, SLOT(slotGotoLocation(QString, int, int)));
	connect(this, SIGNAL(signalEnableTerminateButton(bool)), compilerOutput_.terminateCompilerButton, SLOT(setEnabled(bool)));
	connect(task_, SIGNAL(signalStarted()), this, SLOT(slotStarted()));
	connect(task_, SIGNAL(signalStopped()), this, SLOT(slotStopped()));
}

TaskLookupUses::~TaskLookupUses() {
	if (task_) {
		task_->slotStop();
	}
	env.view.removeOutputTab(compilerTab_);
}

void TaskLookupUses::slotClose() {
	delete this;
}

void TaskLookupUses::slotStarted() {
	emit signalEnableTerminateButton(true);
}

void TaskLookupUses::slotStopped() {
	emit signalEnableTerminateButton(false);
	task_ = nullptr;
}

}
