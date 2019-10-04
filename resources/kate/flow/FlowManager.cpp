#include <sstream>
#include <stdexcept>

#include <QPair>
#include <QSettings>
#include <QFileInfoList>
#include <QTextStream>
#include <QToolTip>
#include <QDir>
#include <QDirIterator>
#include <QFile>

#include <KMessageBox>

#include "common.hpp"
#include "execs/Builder.hpp"
#include "execs/Compiler.hpp"
#include "execs/Runner.hpp"
#include "FlowView.hpp"
#include "FlowManager.hpp"

#include "debug/DebugManager.hpp"

namespace flow {

FlowManager::FlowManager(KTextEditor::MainWindow* mainWin, FlowView& view) :
	QObject(mainWin), mainWindow_(mainWin), flowView_(view) {

	connect(&compileProcess_, SIGNAL(error(QProcess::ProcessError)), this, SLOT(slotCompileError(QProcess::ProcessError)));
    connect(&compileProcess_, SIGNAL(readyReadStandardError()), this, SLOT(slotReadCompileStdErr()));
    connect(&compileProcess_, SIGNAL(readyReadStandardOutput()), this, SLOT(slotReadCompileStdOut()));
    connect(&compileProcess_, SIGNAL(finished(int, QProcess::ExitStatus)), this, SLOT(slotCompileFinished(int, QProcess::ExitStatus)));

    connect(&launchProcess_, SIGNAL(error(QProcess::ProcessError)), this, SLOT(slotLaunchError(QProcess::ProcessError)));
    connect(&launchProcess_, SIGNAL(readyReadStandardError()), this, SLOT(slotReadLaunchStdErr()));
    connect(&launchProcess_, SIGNAL(readyReadStandardOutput()), this, SLOT(slotReadLaunchStdOut()));
    connect(&launchProcess_, SIGNAL(finished(int, QProcess::ExitStatus)), this, SLOT(slotLaunchFinished(int, QProcess::ExitStatus)));

    connect(flowView_.flowOutput_.ui.terminateCompilerButton, SIGNAL(clicked()), &compileProcess_, SLOT(kill()));
    connect(flowView_.flowOutput_.ui.terminateLaunchButton, SIGNAL(clicked()), &launchProcess_, SLOT(kill()));
}

FlowManager::~FlowManager() { }

void FlowManager::slotCompile() {
	flowView_.taskManager_.compile();
}

void FlowManager::slotRun(int row) {
	flowView_.taskManager_.run(row);
}

void FlowManager::slotDebug(int row) {
	flowView_.taskManager_.debug(row);
	return;
	try {
		if (flowView_.flowConfig_.progTimestampsChanged(row)) {
			build(row, DEBUGGING);
		} else {
			// At first we neew to dump executable ids
			QString prog = flowView_.flowConfig_.ui.launchTableWidget->item(row, 1)->text();
			QString dir  = flowView_.flowConfig_.ui.launchTableWidget->item(row, 2)->text();
			QString flowdir = flowView_.flowConfig_.ui.flowdirLineEdit->text();
			Compiler compiler(flowView_.flowConfig_.ui, prog, flowdir);
			if (compiler.type() == Compiler::FLOWC1) {
				if (task_.start(DUMPING_IDS, QString::number(row) + QLatin1String(":") + prog)) {
					mainWindow_->activeView()->document()->documentSave();
					QStringList args;
					args << compiler.includeArgs();
					args << QLatin1String("dump-ids=") + prog + QLatin1String(".ids");
					args << QLatin1String("dump-ids-all=1");
					args << prog;
	#ifdef DEBUG
					QTextStream(stdout) << "DUMP_IDS: " << compiler.invocation() << " " << args.join(QLatin1Char(' ')) << "\n";
	#endif
					flowView_.flowOutput_.ui.compilerOutTextEdit->clear();
					compileProcess_.setWorkingDirectory(dir);
					compileProcess_.start(compiler.invocation(), args);
					flowView_.flowOutput_.ui.terminateCompilerButton->setEnabled(true);
				}
			} else if (compiler.type() == Compiler::FLOW) {
				//flowView_.debugView_->symbols().loadIdFile(prog + QLatin1String(".ids"));
				flowView_.debugView_->manager()->slotDebug(row);
			}
		}
	} catch (std::exception& ex) {
		compileProcess_.kill();
		task_.stop();
		//KMessageBox::sorry(0, QLatin1String(ex.what()));
		appendText(flowView_.flowOutput_.ui.debugOutTextEdit, QLatin1String(ex.what()) + QLatin1String("\n"));
	}
}

void FlowManager::build(int row, Task nextTask, bool force) {
	flowView_.taskManager_.build(row, force);
}

void FlowManager::slotBuild(int row) {
	flowView_.taskManager_.build(row, false);
}

void FlowManager::slotForceBuild(int row) {
	flowView_.taskManager_.build(row, true);
}

void FlowManager::slotLookupDefinition() {
	flowView_.taskManager_.lookupDef();
}

void FlowManager::slotLookupType() {
	flowView_.taskManager_.lookupType();
}

void FlowManager::slotLookupUses() {
	flowView_.taskManager_.lookupUses();
}

void FlowManager::slotOutline(KTextEditor::View* view) {
	QString file = view->document()->url().toLocalFile();
	flowView_.taskManager_.outline(file);
}

void FlowManager::slotStartRename() {
	QString file = curFile(mainWindow_);
	Compiler compiler(flowView_.flowConfig_.ui, file, flowView_.flowConfig_.ui.flowdirLineEdit->text());
	if (compiler.type() == Compiler::FLOW) {
		KMessageBox::sorry(0, i18n("Only flowc compiler allows renaming"));
		return;
	}
	KTextEditor::View* activeView = mainWindow_->activeView();
	QWidget* ask = new QWidget();
	renameDialog_.setupUi(ask);
	QString id = curIdentifier(mainWindow_);
	renameDialog_.renameLineEdit->setText(id);
	connect(renameDialog_.renameButton, SIGNAL(clicked()), this, SLOT(slotCompleteRename()));
	connect(renameDialog_.renameLineEdit, SIGNAL(returnPressed()), this, SLOT(slotCompleteRename()));

	mainWindow_->addWidgetToViewBar(activeView, ask);
	mainWindow_->showViewBar(activeView);
}

void FlowManager::slotCompleteRename() {
	KTextEditor::View* activeView = mainWindow_->activeView();
	if (!activeView || !activeView->cursorPosition().isValid()) {
		return;
	}
	QString renamed = renameDialog_.renameLineEdit->text();
	mainWindow_->deleteViewBar(activeView);
	flowView_.taskManager_.rename(renamed);
}

void FlowManager::slotCompileError(QProcess::ProcessError err) {
	KMessageBox::sorry(nullptr, i18n("Error at compilation: ") + compileProcess_.errorString());
	compileProcess_.kill();
	task_.stop();
}

void FlowManager::slotLaunchError(QProcess::ProcessError err) {
	KMessageBox::sorry(nullptr, i18n("Error at running: ") + launchProcess_.errorString());
	launchProcess_.kill();
	task_.stop();
}

void FlowManager::slotReadCompileStdOut() {
	QString out = QString::fromLocal8Bit(compileProcess_.readAllStandardOutput().data());
    task_.output() += out;
    if (task_.peek().showCompilerOutput()) {
    	appendText(flowView_.flowOutput_.ui.compilerOutTextEdit, out);
    	flowView_.flowOutput_.ui.tabWidget->setCurrentIndex(0);
    }
}

void FlowManager::slotReadCompileStdErr() {
	QString out = QString::fromLocal8Bit(compileProcess_.readAllStandardError().data());
    task_.output() += out;
    appendText(flowView_.flowOutput_.ui.compilerOutTextEdit, out);
    flowView_.flowOutput_.ui.tabWidget->setCurrentIndex(0);
}

void FlowManager::slotReadLaunchStdOut() {
	QString out = QString::fromLocal8Bit(launchProcess_.readAllStandardOutput().data());
    task_.output() += out;
	appendText(flowView_.flowOutput_.ui.launchOutTextEdit, out);
	flowView_.flowOutput_.ui.tabWidget->setCurrentIndex(1);
}

void FlowManager::slotReadLaunchStdErr() {
	QString out = QString::fromLocal8Bit(launchProcess_.readAllStandardError().data());
    task_.output() += out;
	appendText(flowView_.flowOutput_.ui.launchOutTextEdit, out);
	flowView_.flowOutput_.ui.tabWidget->setCurrentIndex(1);
}

static void outputExecutionTime(QPlainTextEdit* edit, double time) {
	std::stringstream ss;
	ss << "[Finished in: " << time << "s]\n";
	appendText(edit, QString::fromStdString(ss.str()));
}

void FlowManager::slotCompileFinished(int exitCode, QProcess::ExitStatus status) {
	InternalTask internal_task = task_.get();
	task_.stop();
	flowView_.flowOutput_.ui.terminateCompilerButton->setEnabled(false);
	if (internal_task.showCompilerOutput() && flowView_.flowConfig_.ui.totalExecutionTimeCheckBox->checkState() == Qt::Checked) {
		outputExecutionTime(flowView_.flowOutput_.ui.compilerOutTextEdit, internal_task.milliseconds());
	}
	if (!exitCode && status == QProcess::NormalExit) {
		switch (internal_task.task) {
		case IDLE: QTextStream(stdout) << "This shold not ever happen\n"; break;
		case COMPILING: break;
		case RUNNING:   break;
		case BUILDING: {
			static QRegExp rowTaskRegex(QLatin1String("([0-9]+):([0-9]+):([^:]+):([^:]+)"));
			if (rowTaskRegex.exactMatch(internal_task.data.value<QString>())) {
				int row = rowTaskRegex.cap(1).toInt();
				flowView_.flowConfig_.slotSaveProgTimestamps(row);
            	Task nextTask = static_cast<Task>(rowTaskRegex.cap(2).toInt());
            	QString path = rowTaskRegex.cap(3);
            	QString tmpPath = rowTaskRegex.cap(4);
            	if (path != tmpPath && QFileInfo(tmpPath).isFile()) {
            		if (!QFile(path).remove()) {
            			throw std::runtime_error("error at removing: '" + path.toStdString() + "'");
            		}
            		if (!QFile(tmpPath).rename(path)) {
            			throw std::runtime_error("error at renaming: '" + tmpPath.toStdString() + "' to '" + path.toStdString() + "'");
            		}
            	}
            	switch (nextTask) {
            	case RUNNING: slotRun(row); break;
            	case DEBUGGING: slotDebug(row); break;
            	default: break;
            	}
			} else {
				QTextStream(stdout) << "building task is corrupted: " << internal_task.data.value<QString>() << "\n";
			}
			break;
		}
		case LOOKUP_DEF: {
			static QRegExp fileLineRegex(QLatin1String("([^:]+):([0-9]*)[: ].*"));
			QStringList outLines = internal_task.output.split(QLatin1Char('\n'));
			for (auto outLine : outLines) {
				if (fileLineRegex.exactMatch(outLine)) {
					QString file = fileLineRegex.cap(1);
            		int line = fileLineRegex.cap(2).toInt() - 1;
            		if (line > -1) {
            			flowView_.slotGotoLocation(file, line);
            		}
            		break;
				}
			}
			break;
		}
		case LOOKUP_TYPE: {
			static QRegExp typeRegex(QLatin1String("Type=(.*)"));
			QStringList outLines = internal_task.output.split(QLatin1Char('\n'));
			for (auto outLine : outLines) {
				if (typeRegex.exactMatch(outLine)) {
					QString type = typeRegex.cap(1);
            		if (!type.isEmpty()) {
            			KTextEditor::View* activeView = mainWindow_->activeView();
						if (!activeView || !activeView->cursorPosition().isValid()) {
							break;
						}
            			QPoint viewCoordinates = activeView->cursorPositionCoordinates();
            			QPoint globalCoorinates = activeView->mapToGlobal(viewCoordinates);
            			QToolTip::showText(globalCoorinates, type);
            		}
            		break;
				}
			}
			break;
		}
		case OUTLINE: {
			flowView_.outline_->update(internal_task.output);
			break;
		}
		case LOOKUP_USES:
			break;
		case RENAMING: {
			QStringList task = internal_task.data.value<QString>().split(QLatin1Char(':'));
			Q_ASSERT(task.count() == 5);
			if (task.last() == QLatin1String("YES")) {
				QString root = task[task.count() - 2];
				QFile confFile (root + QDir::separator() + QLatin1String("flow.config"));
				confFile.remove();
			}
			KMessageBox::information(mainWindow_->activeView(), i18n("Renaming finished"));
			break;
		}
		case DUMPING_IDS: {
			QStringList task = internal_task.data.value<QString>().split(QLatin1Char(':'));
			Q_ASSERT(task.count() == 2);
			int row = task[0].toInt();
			QString idsFile = task[1] + QLatin1String(".ids");
			flowView_.debugView_->symbols().loadIdFile(idsFile);
			QFile(idsFile).remove();
			flowView_.debugView_->manager()->slotDebug(row);
			break;
		}
		case DEBUGGING:
			// TODO: implement
			break;
		};
	} else {
		if (internal_task.task != COMPILING  && internal_task.task != LOOKUP_DEF &&
			internal_task.task != LOOKUP_TYPE && internal_task.task != LOOKUP_USES) {
			QString message = i18n("*** flowc terminated *** ");
			message += QLatin1String("exit code: ") + QString::number(exitCode) + QLatin1String("\n");
			message += compileProcess_.errorString() + QLatin1String("\n");
			appendText(flowView_.flowOutput_.ui.compilerOutTextEdit, message);
			flowView_.flowOutput_.ui.tabWidget->setCurrentIndex(0);
			//KMessageBox::sorry(mainWindow_->activeView(), message);
		}
	}
}

void FlowManager::slotLaunchFinished(int exitCode, QProcess::ExitStatus status) {
	InternalTask internal_task = task_.get();
	task_.stop();
	flowView_.flowOutput_.ui.terminateLaunchButton->setEnabled(false);
	outputExecutionTime(flowView_.flowOutput_.ui.launchOutTextEdit, internal_task.milliseconds());
	if (exitCode || status != QProcess::NormalExit) {
		QString message = i18n("*** application terminated *** ") + launchProcess_.errorString();
		message += QLatin1String(", exit code: ") + QString::number(exitCode);
		appendText(flowView_.flowOutput_.ui.launchOutTextEdit, message);
		flowView_.flowOutput_.ui.tabWidget->setCurrentIndex(1);
		//KMessageBox::sorry(mainWindow_->activeView(), message);
	}
}

bool FlowManager::makeGlobalConfig(const QString& root) const {
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
