#include <QDirIterator>
#include <QTextStream>
#include <KMessageBox>
#include <KTextEditor/View>
#include "execs/Compiler.hpp"
#include "FlowView.hpp"
#include "TaskRename.hpp"

namespace flow {

TaskRename::TaskRename(FlowEnv e, const QString& renamed, Task::Callback cb) : TaskFactory(e, cb), compilerTab_(new QWidget()) {
	QString id = curIdentifier(env.main);
	if (id.isEmpty() || renamed.isEmpty() || id == renamed) {
		return;
	}
	compilerOutput_.setupUi(compilerTab_);
	env.view.addOutputTab(compilerTab_, QLatin1String("Rename"));
	connect(compilerOutput_.closeButton, SIGNAL(clicked()), this, SLOT(slotClose()));

	QString file = curFile(env.main);

	QString root = findFlowRoot(file);
	bool configCreated = makeGlobalConfig(root);

	QString line = QString::number(env.main->activeView()->cursorPosition().line());
	QString col = QString::number(env.main->activeView()->cursorPosition().column());

	env.main->activeView()->document()->documentSave();
	QString flowdir = env.view.flowConfig_.ui.flowdirLineEdit->text();
	Compiler compiler(env.view.flowConfig_.ui, file, flowdir);
	QStringList args;
	args << compiler.includeArgs();
	args << QLatin1String("rename=") + id;
	args << QLatin1String("to=") + renamed;
	args << QLatin1String("exp-line=") + line;
	args << QLatin1String("exp-column=") + col;
	args << file;
#ifdef DEBUG
	QTextStream(stdout) << "RENAME: " << compiler.invocation() << " " << args.join(QLatin1Char(' ')) << "\n";
#endif
	QString workingDir = compiler.confdir();
	QString executor = compiler.invocation();

	Task::Callback end = [this, configCreated, root]() {
		if (configCreated) {
			QFile confFile(root + QDir::separator() + QLatin1String("flow.config"));
			confFile.remove();
		}
		KMessageBox::information(env.main->activeView(), i18n("Renaming finished"));
		callback();
	};
	Task::Output out = [this](const QString& str) {
		appendText(compilerOutput_.compilerOutTextEdit, str);
		env.view.switchToOutputTab(compilerTab_);
	};
	Task::Output err = [this](const QString& str) {
		appendText(compilerOutput_.compilerOutTextEdit, str);
		env.view.switchToOutputTab(compilerTab_);
	};
	task_ = new Task(env, executor, args, workingDir, out, err, end);
	connect(compilerOutput_.terminateCompilerButton, SIGNAL(clicked()), task_, SLOT(slotStop()));
	connect(compilerOutput_.compilerOutTextEdit, SIGNAL(signalCompilerLocation(QString, int, int)), &env.view, SLOT(slotGotoLocation(QString, int, int)));
	connect(this, SIGNAL(signalEnableTerminateButton(bool)), compilerOutput_.terminateCompilerButton, SLOT(setEnabled(bool)));
	connect(task_, SIGNAL(signalStarted()), this, SLOT(slotStarted()));
	connect(task_, SIGNAL(signalStopped()), this, SLOT(slotStopped()));
}

TaskRename::~TaskRename() {
	env.view.removeOutputTab(compilerTab_);
}

void TaskRename::slotClose() {
	delete this;
}

void TaskRename::slotStarted() {
	emit signalEnableTerminateButton(true);
}

void TaskRename::slotStopped() {
	emit signalEnableTerminateButton(false);
	task_ = nullptr;
}

bool TaskRename::makeGlobalConfig(const QString& root) const {
	QFileInfo globalConfInfo(root + QDir::separator() + QLatin1String("flow.config"));
	if (globalConfInfo.exists()) {
		return false;
	} else {
		QSet<QString> allIncludes;
		static QString includeString = QLatin1String("include=");
		QDirIterator it(root, QStringList() << QLatin1String("flow.config"), QDir::Files, QDirIterator::Subdirectories);
		while (it.hasNext()) {
			QFile conf(it.next());
			if (!conf.open(QIODevice::ReadOnly)) {
				continue;
			}
			QTextStream in(&conf);
			while (!in.atEnd()) {
				QString line = in.readLine();
				if (line.startsWith(includeString)) {
					QStringList localIncs = line.mid(includeString.length()).split(QLatin1String(","));
					for (QString localInc : localIncs) {
						QString fullInc = it.fileInfo().dir().path() + QDir::separator() + localInc;
						allIncludes << QDir::cleanPath(fullInc);
					}
				}
			}
			conf.close();
		}
		QFile confFile(globalConfInfo.absoluteFilePath());
		if (confFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
			QTextStream out(&confFile);
			out << includeString << allIncludes.toList().join(QLatin1Char(',')) << "\n";
		}
		confFile.close();
		return true;
	}
}

}
