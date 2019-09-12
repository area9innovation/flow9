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
#include "DebugManager.hpp"

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
	try {
		QString file = curFile(mainWindow_);
		if (state_.start(COMPILING, file)) {
			mainWindow_->activeView()->document()->documentSave();
			QString flowdir = flowView_.flowConfig_.ui.flowdirLineEdit->text();
			Compiler compiler(file, flowdir);
			QStringList args;
			args << compiler.includeArgs();
			args << compiler.compileArgs(file);
#ifdef DEBUG
			QTextStream(stdout) << "COMPILE: " << compiler.invocation() << " " << args.join(QLatin1Char(' ')) << "\n";
#endif
			if (state_.peek().showCompilerOutput()) {
				flowView_.flowOutput_.ui.compilerOutTextEdit->clear();
			}
			compileProcess_.setWorkingDirectory(compiler.confdir());
			compileProcess_.start(compiler.invocation(), args);
			flowView_.flowOutput_.ui.terminateCompilerButton->setEnabled(true);
		}
	} catch (std::exception& ex) {
		compileProcess_.kill();
		state_.stop();
		//KMessageBox::sorry(0, QLatin1String(ex.what()));
	}
}

void FlowManager::slotRun(int row) {
	try {
		QString prog = flowView_.flowConfig_.ui.launchTableWidget->item(row, 1)->text();
		QString dir  = flowView_.flowConfig_.ui.launchTableWidget->item(row, 2)->text();
		QString targ = flowView_.flowConfig_.ui.launchTableWidget->item(row, 3)->text();
		QString progArgs = flowView_.flowConfig_.ui.launchTableWidget->item(row, 5)->text();
		QString execArgs = flowView_.flowConfig_.ui.launchTableWidget->item(row, 6)->text();
		QString flowdir = flowView_.flowConfig_.ui.flowdirLineEdit->text();
		Runner runner(prog, targ, flowdir);
		if (flowView_.flowConfig_.progTimestampsChanged(row) || !QFileInfo(runner.target()).isFile()) {
			build(row, RUNNING);
		} else if (state_.start(RUNNING, row)) {
			QString invocation = runner.invocation();
			if (invocation.isEmpty()) {
				state_.stop();
				return;
			}
			QStringList args = runner.args(execArgs, progArgs);
	#ifdef DEBUG
			QTextStream(stdout) << "RUN: " << invocation << " " << args.join(QLatin1Char(' ')) << "\n";
	#endif
			if (state_.peek().showCompilerOutput()) {
				flowView_.flowOutput_.ui.launchOutTextEdit->clear();
			}
			launchProcess_.setWorkingDirectory(dir);
			launchProcess_.start(runner.invocation(), args);
			flowView_.flowOutput_.ui.terminateLaunchButton->setEnabled(true);
		}
	} catch (std::exception& ex) {
		launchProcess_.kill();
		state_.stop();
		KMessageBox::sorry(0, QLatin1String(ex.what()));
	}
}

void FlowManager::slotDebug(int row) {
	try {
		if (flowView_.flowConfig_.progTimestampsChanged(row)) {
			build(row, DEBUGGING);
		} else {
			// At first we neew to dump executable ids
			QString prog = flowView_.flowConfig_.ui.launchTableWidget->item(row, 1)->text();
			QString dir  = flowView_.flowConfig_.ui.launchTableWidget->item(row, 2)->text();
			QString flowdir = flowView_.flowConfig_.ui.flowdirLineEdit->text();
			Compiler compiler(prog, flowdir);
			if (compiler.type() == Compiler::FLOWC1) {
				if (state_.start(DUMPING_IDS, QString::number(row) + QLatin1String(":") + prog)) {
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
		state_.stop();
		KMessageBox::sorry(0, QLatin1String(ex.what()));
	}
}

void FlowManager::build(int row, State nextState, bool force) {
	try {
		QString prog = flowView_.flowConfig_.ui.launchTableWidget->item(row, 1)->text();
		QString targ = flowView_.flowConfig_.ui.launchTableWidget->item(row, 3)->text();
		QString opts = flowView_.flowConfig_.ui.launchTableWidget->item(row, 4)->text();
		//QString astr = flowView_.flowConfig_.ui.launchTableWidget->item(row, 5)->text();
		QString flowdir = flowView_.flowConfig_.ui.flowdirLineEdit->text();
		Builder builder(prog, targ, flowdir);
		if (force || flowView_.flowConfig_.progTimestampsChanged(row) || !QFileInfo(builder.runner().target()).isFile()) {
			if (state_.start(BUILDING, QString::number(row) + QLatin1String(":") + QString::number(static_cast<int>(nextState)))) {
				QStringList args = builder.args(opts);
	#ifdef DEBUG
				QTextStream(stdout) << "BUILD: " << builder.invocation() << " " << args.join(QLatin1Char(' ')) << "\n";
	#endif
				//QTextStream(stdout) << "NEXT_STATE: " << nextState << "\n";
				if (state_.peek().showCompilerOutput()) {
					flowView_.flowOutput_.ui.compilerOutTextEdit->clear();
				}
				compileProcess_.setWorkingDirectory(builder.compiler().confdir());
				compileProcess_.start(builder.invocation(), args);
				flowView_.flowOutput_.ui.terminateCompilerButton->setEnabled(true);
			}
		} else {
			if (state_.peek().showCompilerOutput()) {
				flowView_.flowOutput_.ui.compilerOutTextEdit->clear();
			}
			flowView_.flowOutput_.ui.compilerOutTextEdit->insertPlainText(QLatin1String("Program is already built."));
			flowView_.flowOutput_.ui.tabWidget->setCurrentIndex(0);
		}
	} catch (std::exception& ex) {
		compileProcess_.kill();
		state_.stop();
		KMessageBox::sorry(0, QLatin1String(ex.what()));
	}
}

void FlowManager::slotBuild(int row) {
	build(row, IDLE);
}

void FlowManager::slotForceBuild(int row) {
	build(row, IDLE, true);
}

void FlowManager::slotLookupDefinition() {
	try {
		QString file = curFile(mainWindow_);
		QString id = curIdentifier(mainWindow_);
		if (!id.isEmpty() && state_.start(LOOKUP_DEF, file + QLatin1String(":") + id)) {
			mainWindow_->activeView()->document()->documentSave();
			QString flowdir = flowView_.flowConfig_.ui.flowdirLineEdit->text();
			Compiler compiler(file, flowdir);
			QStringList args;
			args << compiler.includeArgs();
			if (compiler.type() == Compiler::FLOWC1) {
				args << QLatin1String("legacy-format=1");
				args << QLatin1String("incremental-priority=1");
				args << QLatin1String("find-definition=") + id;
			} else if (compiler.type() == Compiler::FLOW) {
				args << QLatin1String("--find-definition");
				args << id;
			} else {
				state_.stop();
				return;
			}
			args << file;
	#ifdef DEBUG
			QTextStream(stdout) << "LOOKUP: " << compiler.invocation() << " " << args.join(QLatin1Char(' ')) << "\n";
	#endif
			if (state_.peek().showCompilerOutput()) {
				flowView_.flowOutput_.ui.compilerOutTextEdit->clear();
			}
			compileProcess_.setWorkingDirectory(compiler.confdir());
			compileProcess_.start(compiler.invocation(), args);
			flowView_.flowOutput_.ui.terminateCompilerButton->setEnabled(true);
		}
	} catch (std::exception& ex) {
		compileProcess_.kill();
		state_.stop();
		KMessageBox::sorry(0, QLatin1String(ex.what()));
	}
}

void FlowManager::slotLookupType() {
	try {
		KTextEditor::View* activeView = mainWindow_->activeView();
		if (!activeView || !activeView->cursorPosition().isValid()) {
			return;
		}
		QString file = curFile(mainWindow_);
		QString line = QString::number(activeView->cursorPosition().line() + 1);
		QString col = QString::number(activeView->cursorPosition().column() + 1);
		if (state_.start(LOOKUP_TYPE, file + QLatin1String(":") + line + QLatin1String(":") + col)) {
			mainWindow_->activeView()->document()->documentSave();
			QString flowdir = flowView_.flowConfig_.ui.flowdirLineEdit->text();
			Compiler compiler(file, flowdir);
			if (compiler.type() != Compiler::FLOWC1) {
				KMessageBox::sorry(0, i18n("Only flowc compiler allows type lookup"));
				state_.stop();
				return;
			}
			QStringList args;
			args << compiler.includeArgs();
			args << QLatin1String("find-type=1");
			args << QLatin1String("exp-line=") + line;
			args << QLatin1String("exp-column=") + col;
			args << file;
	#ifdef DEBUG
			QTextStream(stdout) << "LOOKUP TYPE: " << compiler.invocation() << " " << args.join(QLatin1Char(' ')) << "\n";
	#endif
			if (state_.peek().showCompilerOutput()) {
				flowView_.flowOutput_.ui.compilerOutTextEdit->clear();
			}
			compileProcess_.setWorkingDirectory(compiler.confdir());
			compileProcess_.start(compiler.invocation(), args);
			flowView_.flowOutput_.ui.terminateCompilerButton->setEnabled(true);
		}
	} catch (std::exception& ex) {
		compileProcess_.kill();
		state_.stop();
		KMessageBox::sorry(0, QLatin1String(ex.what()));
	}
}

void FlowManager::slotLookupUses() {
	try {
		KTextEditor::View* activeView = mainWindow_->activeView();
		if (!activeView || !activeView->cursorPosition().isValid()) {
			return;
		}
		QString id = curIdentifier(mainWindow_);
		QString file = curFile(mainWindow_);
		QString line = QString::number(activeView->cursorPosition().line() + 1);
		QString col = QString::number(activeView->cursorPosition().column() + 1);
		if (state_.start(LOOKUP_USES, file + QLatin1String(":") + line + QLatin1String(":") + col)) {
			mainWindow_->activeView()->document()->documentSave();
			QString flowdir = flowView_.flowConfig_.ui.flowdirLineEdit->text();
			Compiler compiler(file, flowdir);
			if (compiler.type() != Compiler::FLOWC1) {
				KMessageBox::sorry(0, i18n("Only flowc compiler allows uses lookup"));
				state_.stop();
				return;
			}
			QStringList args;
			args << compiler.includeArgs();
			args << QLatin1String("find-uses=") + id;
			args << QLatin1String("exp-line=") + line;
			args << QLatin1String("exp-column=") + col;
			args << file;
	#ifdef DEBUG
			QTextStream(stdout) << "FIND ALL USES: " << compiler.invocation() << " " << args.join(QLatin1Char(' ')) << "\n";
	#endif
			if (state_.peek().showCompilerOutput()) {
				flowView_.flowOutput_.ui.compilerOutTextEdit->clear();
			}
			compileProcess_.setWorkingDirectory(compiler.confdir());
			compileProcess_.start(compiler.invocation(), args);
			flowView_.flowOutput_.ui.terminateCompilerButton->setEnabled(true);
		}
	} catch (std::exception& ex) {
		compileProcess_.kill();
		state_.stop();
		KMessageBox::sorry(0, QLatin1String(ex.what()));
	}
}

void FlowManager::slotOutline(KTextEditor::View* view) {
	try {
		QString file = view->document()->url().toLocalFile();
		if (state_.start(OUTLINE, file)) {
			QString flowdir = flowView_.flowConfig_.ui.flowdirLineEdit->text();
			Compiler compiler(file, flowdir);
			QStringList args;
			args << compiler.includeArgs();
			if (compiler.type() == Compiler::FLOWC1) {
				args << QLatin1String("incremental-priority=1");
				args << QLatin1String("print-outline=1");
			} else {
				state_.stop();
				return;
			}
			args << file;
	#ifdef DEBUG
			QTextStream(stdout) << "OUTLINE: " << compiler.invocation() << " " << args.join(QLatin1Char(' ')) << "\n";
	#endif
			if (state_.peek().showCompilerOutput()) {
				flowView_.flowOutput_.ui.compilerOutTextEdit->clear();
			}
			compileProcess_.setWorkingDirectory(compiler.confdir());
			compileProcess_.start(compiler.invocation(), args);
			flowView_.flowOutput_.ui.terminateCompilerButton->setEnabled(true);
		}
	} catch (std::exception& ex) {
		compileProcess_.kill();
		state_.stop();
		KMessageBox::sorry(0, QLatin1String(ex.what()));
	}
}

void FlowManager::slotRename() {
	QString file = curFile(mainWindow_);
	Compiler compiler(file, flowView_.flowConfig_.ui.flowdirLineEdit->text());
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
	try {
		KTextEditor::View* activeView = mainWindow_->activeView();
		if (!activeView || !activeView->cursorPosition().isValid()) {
			return;
		}
		QString file = curFile(mainWindow_);
		QString id = curIdentifier(mainWindow_);
		QString root = findFlowRoot(file);
		bool configCreated = makeGlobalConfig(root);

		QString renamed = renameDialog_.renameLineEdit->text();
		mainWindow_->deleteViewBar(activeView);

		QString line = QString::number(activeView->cursorPosition().line());
		QString col = QString::number(activeView->cursorPosition().column());

		QString stateString;
		stateString += file + QLatin1String(":");
		stateString += id + QLatin1String(":");
		stateString += renamed + QLatin1String(":");
		stateString += root + QLatin1String(":");
		stateString += configCreated ? QLatin1String("YES") : QLatin1String("NO");

		if (!id.isEmpty() && !renamed.isEmpty() && id != renamed && state_.start(RENAMING, stateString)) {
			mainWindow_->activeView()->document()->documentSave();
			QString flowdir = flowView_.flowConfig_.ui.flowdirLineEdit->text();
			Compiler compiler(file, flowdir);
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
			if (state_.peek().showCompilerOutput()) {
				flowView_.flowOutput_.ui.compilerOutTextEdit->clear();
			}
			compileProcess_.setWorkingDirectory(compiler.confdir());
			compileProcess_.start(compiler.invocation(), args);
			flowView_.flowOutput_.ui.terminateCompilerButton->setEnabled(true);
		}
	} catch (std::exception& ex) {
		compileProcess_.kill();
		state_.stop();
		KMessageBox::sorry(0, QLatin1String(ex.what()));
	}
}

void FlowManager::slotCompileError(QProcess::ProcessError err) {
	KMessageBox::sorry(nullptr, i18n("Error at compilation: ") + compileProcess_.errorString());
	compileProcess_.kill();
	state_.stop();
}

void FlowManager::slotLaunchError(QProcess::ProcessError err) {
	KMessageBox::sorry(nullptr, i18n("Error at running: ") + launchProcess_.errorString());
	launchProcess_.kill();
	state_.stop();
}

void FlowManager::slotReadCompileStdOut() {
	QString out = QString::fromLocal8Bit(compileProcess_.readAllStandardOutput().data());
    state_.output() += out;
    if (state_.peek().showCompilerOutput()) {
    	appendText(flowView_.flowOutput_.ui.compilerOutTextEdit, out);
    	flowView_.flowOutput_.ui.tabWidget->setCurrentIndex(0);
    }
}

void FlowManager::slotReadCompileStdErr() {
	QString out = QString::fromLocal8Bit(compileProcess_.readAllStandardError().data());
    state_.output() += out;
    appendText(flowView_.flowOutput_.ui.compilerOutTextEdit, out);
    flowView_.flowOutput_.ui.tabWidget->setCurrentIndex(0);
}

void FlowManager::slotReadLaunchStdOut() {
	QString out = QString::fromLocal8Bit(launchProcess_.readAllStandardOutput().data());
    state_.output() += out;
	appendText(flowView_.flowOutput_.ui.launchOutTextEdit, out);
	flowView_.flowOutput_.ui.tabWidget->setCurrentIndex(1);
}

void FlowManager::slotReadLaunchStdErr() {
	QString out = QString::fromLocal8Bit(launchProcess_.readAllStandardError().data());
    state_.output() += out;
	appendText(flowView_.flowOutput_.ui.launchOutTextEdit, out);
	flowView_.flowOutput_.ui.tabWidget->setCurrentIndex(1);
}

static void outputExecutionTime(QPlainTextEdit* edit, double time) {
	std::stringstream ss;
	ss << "[Finished in: " << time << "s]\n";
	appendText(edit, QString::fromStdString(ss.str()));
}

void FlowManager::slotCompileFinished(int exitCode, QProcess::ExitStatus status) {
	InternalState internal_state = state_.get();
	state_.stop();
	flowView_.flowOutput_.ui.terminateCompilerButton->setEnabled(false);
	if (internal_state.showCompilerOutput()) {
		outputExecutionTime(flowView_.flowOutput_.ui.compilerOutTextEdit, internal_state.milliseconds());
	}
	if (!exitCode && status == QProcess::NormalExit) {
		switch (internal_state.state) {
		case IDLE: QTextStream(stdout) << "This shold not ever happen\n"; break;
		case COMPILING: break;
		case RUNNING:   break;
		case BUILDING: {
			static QRegExp rowStateRegex(QLatin1String("([^:]+):([0-9]+)"));
			if (rowStateRegex.exactMatch(internal_state.data.value<QString>())) {
				int row = rowStateRegex.cap(1).toInt();
				flowView_.flowConfig_.slotSaveProgTimestamps(row);
            	State nextState = static_cast<State>(rowStateRegex.cap(2).toInt());
            	switch (nextState) {
            	case RUNNING: slotRun(row); break;
            	case DEBUGGING: slotDebug(row); break;
            	default: break;
            	}
			} else {
				QTextStream(stdout) << "building state is corrupted: " << internal_state.data.value<QString>() << "\n";
			}
			break;
		}
		case LOOKUP_DEF: {
			static QRegExp fileLineRegex(QLatin1String("([^:]+):([0-9]*)[: ].*"));
			QStringList outLines = internal_state.output.split(QLatin1Char('\n'));
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
			QStringList outLines = internal_state.output.split(QLatin1Char('\n'));
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
			flowView_.outline_->update(internal_state.output);
			break;
		}
		case LOOKUP_USES:
			break;
		case RENAMING: {
			QStringList state = internal_state.data.value<QString>().split(QLatin1Char(':'));
			Q_ASSERT(state.count() == 5);
			if (state.last() == QLatin1String("YES")) {
				QString root = state[state.count() - 2];
				QFile confFile (root + QDir::separator() + QLatin1String("flow.config"));
				confFile.remove();
			}
			KMessageBox::information(mainWindow_->activeView(), i18n("Renaming finished"));
			break;
		}
		case DUMPING_IDS: {
			QStringList state = internal_state.data.value<QString>().split(QLatin1Char(':'));
			Q_ASSERT(state.count() == 2);
			int row = state[0].toInt();
			QString idsFile = state[1] + QLatin1String(".ids");
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
		if (internal_state.state != COMPILING  && internal_state.state != LOOKUP_DEF &&
			internal_state.state != LOOKUP_TYPE && internal_state.state != LOOKUP_USES) {
			QString message = i18n("*** flowc crashed *** ") + compileProcess_.errorString();
			message += QLatin1String(", exit code: ") + QString::number(exitCode);
			appendText(flowView_.flowOutput_.ui.compilerOutTextEdit, message);
			flowView_.flowOutput_.ui.tabWidget->setCurrentIndex(0);
			KMessageBox::sorry(mainWindow_->activeView(), message);
		}
	}
}

void FlowManager::slotLaunchFinished(int exitCode, QProcess::ExitStatus status) {
	InternalState internal_state = state_.get();
	state_.stop();
	flowView_.flowOutput_.ui.terminateLaunchButton->setEnabled(false);
	outputExecutionTime(flowView_.flowOutput_.ui.launchOutTextEdit, internal_state.milliseconds());
	if (exitCode || status != QProcess::NormalExit) {
		QString message = i18n("*** application crashed *** ") + launchProcess_.errorString();
		message += QLatin1String(", exit code: ") + QString::number(exitCode);
		appendText(flowView_.flowOutput_.ui.launchOutTextEdit, message);
		flowView_.flowOutput_.ui.tabWidget->setCurrentIndex(1);
		KMessageBox::sorry(mainWindow_->activeView(), message);
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
