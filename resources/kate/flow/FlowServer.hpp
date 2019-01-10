#pragma once

#include <QProcess>
#include <QFileInfo>
#include <QDir>

#include <KTextEditor/View>

#include "common.hpp"

namespace flow {

class FlowView;

class FlowServer : public QObject {
	Q_OBJECT
public:
	FlowServer(KTextEditor::MainWindow* mainWin, FlowView& view);
	~FlowServer();

public Q_SLOTS:
	// Controls
	void slotStart();
	void slotTerminate();
	void slotClearIncremental();

private Q_SLOTS:
	// Process slots
	void slotStarted();
	void slotReadStdOut();
	void slotReadStdErr();
	void slotError(QProcess::ProcessError err);
	void slotFinished(int exitCode, QProcess::ExitStatus status);

private:
	KTextEditor::MainWindow* mainWindow_;
	FlowView& flowView_;
	QProcess  serverProcess_;
	QProcess  shutdownProcess_;
};

}
