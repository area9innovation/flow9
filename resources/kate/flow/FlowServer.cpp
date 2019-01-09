//#include <sstream>

#include <QPair>
#include <QSettings>
#include <QFileInfoList>
#include <QTextStream>
#include <QToolTip>
#include <QDir>
#include <QDirIterator>
#include <QFile>

#include <KMessageBox>

#include "execs/Compiler.hpp"
#include "FlowView.hpp"
#include "FlowServer.hpp"

namespace flow {

FlowServer::FlowServer(KTextEditor::MainWindow* mainWin, FlowView& view) :
	QObject(mainWin), mainWindow_(mainWin), flowView_(view) {

	connect(&serverProcess_, SIGNAL(error(QProcess::ProcessError)), this, SLOT(slotError(QProcess::ProcessError)));
    connect(&serverProcess_, SIGNAL(readyReadStandardError()), this, SLOT(slotReadStdErr()));
    connect(&serverProcess_, SIGNAL(readyReadStandardOutput()), this, SLOT(slotReadStdOut()));
    connect(&serverProcess_, SIGNAL(finished(int, QProcess::ExitStatus)), this, SLOT(slotFinished(int, QProcess::ExitStatus)));
    connect(&serverProcess_, SIGNAL(started()), this, SLOT(slotStarted()));

    connect(flowView_.flowConfig_.ui.serverStartButton, SIGNAL(clicked()), this, SLOT(slotStart()));
    connect(flowView_.flowConfig_.ui.serverTerminateButton, SIGNAL(clicked()), this, SLOT(slotTerminate()));
    connect(flowView_.flowConfig_.ui.serverClearConsoleButton, SIGNAL(clicked()), flowView_.flowConfig_.ui.serverTextEdit, SLOT(clear()));
    connect(flowView_.flowConfig_.ui.serverClearIncrementalButton, SIGNAL(clicked()), this, SLOT(slotClearIncremental()));
}

FlowServer::~FlowServer() { }

void FlowServer::slotStart() {
	if (flowView_.flowConfig_.ui.serverStartButton->isEnabled()) {
		QString flowdir = flowView_.flowConfig_.ui.flowdirLineEdit->text();
		QString flowc1 = QFileInfo(flowdir + QLatin1String("/bin/flowc1")).absoluteFilePath();
		QStringList args;
		args << QLatin1String("server-mode=1");
		args << QLatin1String("server-port=") + flowView_.flowConfig_.ui.serverPortLineEdit->text();
		//QTextStream(stdout) << "SERVER START: " << flowc1 << " " << args.join(QLatin1Char(' ')) << "\n";
		flowView_.flowConfig_.ui.serverTextEdit->clear();
		serverProcess_.setWorkingDirectory(flowView_.flowConfig_.ui.serverDirLineEdit->text());
		serverProcess_.start(flowc1, args);
	}
}

void FlowServer::slotTerminate() {
	if (flowView_.flowConfig_.ui.serverTerminateButton->isEnabled()) {
		QString flowdir = flowView_.flowConfig_.ui.flowdirLineEdit->text();
		QString flowc1 = QFileInfo(flowdir + QLatin1String("/bin/flowc1")).absoluteFilePath();
		QStringList args;
		args << QLatin1String("server-shutdown=1");
		args << QLatin1String("server-port=") + flowView_.flowConfig_.ui.serverPortLineEdit->text();
		//QTextStream(stdout) << "SERVER TERMINATE: " << flowc1 << " " << args.join(QLatin1Char(' ')) << "\n";
		shutdownProcess_.setWorkingDirectory(flowView_.flowConfig_.ui.serverDirLineEdit->text());
		shutdownProcess_.start(flowc1, args);
		if (!shutdownProcess_.waitForFinished(1000) || !serverProcess_.waitForFinished(1000)) {
			QTextStream(stdout) << "KILLING SERVER\n";
			serverProcess_.kill();
		}
	}
}

void FlowServer::slotClearIncremental() {
	QString objcDir = flowView_.flowConfig_.ui.serverDirLineEdit->text() + QLatin1String("/objc");
	QDir dir(objcDir);
	//QTextStream(stdout) << "DELETING INCREMENTALS FROM: " << objcDir << "\n";
	dir.setNameFilters(QStringList() << QLatin1String("*.*"));
	dir.setFilter(QDir::Files);
	foreach (QString dirFile, dir.entryList()) {
		dir.remove(dirFile);
	}
}

void FlowServer::slotStarted() {
	flowView_.flowConfig_.ui.serverTerminateButton->setEnabled(true);
	flowView_.flowConfig_.ui.serverStartButton->setEnabled(false);
}

void FlowServer::slotReadStdOut() {
	QString out = QString::fromLocal8Bit(serverProcess_.readAllStandardOutput().data());
    //state_.output() += out;
	appendText(flowView_.flowConfig_.ui.serverTextEdit, out);
	flowView_.flowConfig_.ui.tabWidget->setCurrentIndex(2);
}

void FlowServer::slotReadStdErr() {
	QString out = QString::fromLocal8Bit(serverProcess_.readAllStandardError().data());
    //state_.output() += out;
    appendText(flowView_.flowConfig_.ui.serverTextEdit, out);
    flowView_.flowConfig_.ui.tabWidget->setCurrentIndex(2);
}

void FlowServer::slotError(QProcess::ProcessError err) {
	KMessageBox::sorry(nullptr, i18n("Flowc server error: ") + serverProcess_.errorString());
}

void FlowServer::slotFinished(int exitCode, QProcess::ExitStatus status) {
	flowView_.flowConfig_.ui.serverTerminateButton->setEnabled(false);
	flowView_.flowConfig_.ui.serverStartButton->setEnabled(true);
	//outputExecutionTime(flowView_.flowConfig_.ui.serverTextEdit, internal_state.milliseconds());
	if (exitCode || status != QProcess::NormalExit) {
        QString message = i18n("*** flowc server crashed *** ") + serverProcess_.errorString();
        message += QLatin1String(", exit code: ") + QString::number(exitCode);
    	appendText(flowView_.flowConfig_.ui.serverTextEdit, message);
    	//flowView_.flowConfig_.ui.tabWidget->setCurrentIndex(0);
		KMessageBox::sorry(mainWindow_->activeView(), message);
	}
}

}
