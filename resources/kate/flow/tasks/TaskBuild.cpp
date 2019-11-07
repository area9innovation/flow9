#include <QWidget>
#include <QTextStream>
#include <KTextEditor/View>
#include "execs/Builder.hpp"
#include "FlowView.hpp"
#include "TaskBuild.hpp"

namespace flow {

TaskBuild::TaskBuild(FlowEnv e, int row, bool force, Task::Callback cb) : TaskFactory(e, cb), compilerTab_(new QWidget()) {
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

	QString prog = env.view.flowConfig_.ui.launchTableWidget->item(row, 1)->text();
	QString odir = env.view.flowConfig_.ui.launchTableWidget->item(row, 2)->text();
	QString targ = env.view.flowConfig_.ui.launchTableWidget->item(row, 3)->text();
	QString opts = env.view.flowConfig_.ui.launchTableWidget->item(row, 4)->text();
	QString flowdir = env.view.flowConfig_.ui.flowdirLineEdit->text();
	Target target(env.view.flowConfig_.ui, prog, targ, flowdir, odir);
	if (force || env.view.flowConfig_.progTimestampsChanged(row) || !target.exists()) {
		Builder builder(env.view.flowConfig_.ui, prog, targ, flowdir, odir);

		// Remember original target name and temporary - to rename back after building.
		QString path = builder.target().path();
		QString tmpPath = builder.target().tmpPath();

		QStringList args = builder.args(opts);
#ifdef DEBUG
		QTextStream(stdout) << "BUILD: " << builder.invocation() << " " << args.join(QLatin1Char(' ')) << "\n";
#endif

		QString workingDir = builder.compiler().confdir();
		QString executor = builder.invocation();

		Task::Callback end = [this, row, path, tmpPath]() {
			env.view.flowConfig_.slotSaveProgTimestamps(row);
			if (path != tmpPath && QFileInfo(tmpPath).isFile()) {
				if (!QFile(path).remove()) {
					throw std::runtime_error("error at removing: '" + path.toStdString() + "'");
				}
				if (!QFile(tmpPath).rename(path)) {
					throw std::runtime_error("error at renaming: '" + tmpPath.toStdString() + "' to '" + path.toStdString() + "'");
				}
			}
			callback();
		};
		Task::Output out = [this, output, tab](const QString& str) {
			appendText(output, str);
			env.view.switchToOutputTab(tab);
		};
		Task::Output err = [this, output, tab](const QString& str) {
			appendText(output, str);
			env.view.switchToOutputTab(tab);
		};
		task_ = new Task(env, executor, args, workingDir, out, err, end);
		connect(terminateButton, SIGNAL(clicked()), task_, SLOT(slotStop()));
		connect(this, SIGNAL(signalEnableTerminateButton(bool)), terminateButton, SLOT(setEnabled(bool)));
		connect(task_, SIGNAL(signalStarted()), this, SLOT(slotStarted()));
		connect(task_, SIGNAL(signalStopped()), this, SLOT(slotStopped()));
		connect(output, SIGNAL(signalCompilerLocation(QString, int, int)), &env.view, SLOT(slotGotoLocation(QString, int, int)));
	} else {
		output->insertPlainText(QLatin1String("\nProgram is already built.\n"));
		env.view.switchToOutputTab(tab);
		callback();
	}
}

TaskBuild::~TaskBuild() {
	if (task_) {
		task_->slotStop();
	}
	if (compilerTab_) {
		env.view.removeOutputTab(compilerTab_);
	}
}

void TaskBuild::slotClose() {
	delete this;
}

void TaskBuild::slotStarted() {
	emit signalEnableTerminateButton(true);
}

void TaskBuild::slotStopped() {
	emit signalEnableTerminateButton(false);
	task_ = nullptr;
}


}
