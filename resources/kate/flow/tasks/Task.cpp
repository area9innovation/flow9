#include "tasks/Task.hpp"

#include <stdexcept>
#include "FlowView.hpp"

namespace flow {

Task::Task(
	FlowEnv env,
	const QString& e,
	const QStringList& as,
	const QString& wd,
	Output out,
	Output err,
	Callback cb,
	QObject* h
): env_(env), executor_(e), args_(as), workingDir_(wd), stdout_(out), stderr_(err), callback_(cb), handler_(h) {
	connect(&proc_, SIGNAL(readyReadStandardError()), this, SLOT(slotReadStdErr()));
	connect(&proc_, SIGNAL(readyReadStandardOutput()), this, SLOT(slotReadStdOut()));
	connect(&proc_, SIGNAL(error(QProcess::ProcessError)), this, SLOT(slotProcError(QProcess::ProcessError)));
	connect(&proc_, SIGNAL(finished(int, QProcess::ExitStatus)), this, SLOT(slotProcFinished(int, QProcess::ExitStatus)));
	connect(&proc_, SIGNAL(started()), this, SLOT(slotProcStarted()));
}

Task::~Task() {
	slotStop();
	for (int i = 0; i < env_.view.flowConfig_.ui.tasksTableWidget->rowCount(); ++i) {
		if (env_.view.flowConfig_.ui.tasksTableWidget->item(i, 0)->text() == pid_) {
			env_.view.flowConfig_.ui.tasksTableWidget->removeRow(i);
			break;
		}
	}
	delete handler_;
}

void Task::write(const QString& data) {
	proc_.write(qPrintable(data));
}

double Task::runTime() const {
	auto dur = end_ - start_;
	auto time = std::chrono::duration_cast<std::chrono::milliseconds>(dur).count();
	return static_cast<double>(time) / 1000.0;
}

void Task::slotStart() {
	try {
		proc_.setWorkingDirectory(workingDir_);
		proc_.start(executor_, args_);
		pid_ = QString::number(proc_.processId());
		int row = env_.view.flowConfig_.ui.tasksTableWidget->rowCount();
		env_.view.flowConfig_.ui.tasksTableWidget->insertRow(row);
		env_.view.flowConfig_.ui.tasksTableWidget->setItem(row, 0, new QTableWidgetItem(pid_));
		env_.view.flowConfig_.ui.tasksTableWidget->setItem(row, 1, new QTableWidgetItem(executor_));
		env_.view.flowConfig_.ui.tasksTableWidget->setItem(row, 2, new QTableWidgetItem(args_.join(QLatin1String(" "))));
	} catch (std::exception& ex) {
		proc_.kill();
		stderr_(QLatin1String(ex.what()) + QLatin1String("\n"));
	}
}

void Task::slotStop() {
	try {
		proc_.kill();
		if (!proc_.waitForFinished()) {
			// TODO:
		}
	} catch (std::exception& ex) {
		stderr_(QLatin1String(ex.what()) + QLatin1String("\n"));
	}
}

void Task::slotProcStarted() {
	emit signalStarted();
}

void Task::slotProcError(QProcess::ProcessError err) {
	stdout_(QLatin1String("Error: ") + proc_.errorString());
	proc_.kill();
}

void Task::slotReadStdOut() {
	QString out = QString::fromLocal8Bit(proc_.readAllStandardOutput().data());
    stdout_(out);
}

void Task::slotReadStdErr() {
	QString err = QString::fromLocal8Bit(proc_.readAllStandardError().data());
    stderr_(err);
}

void Task::slotProcFinished(int exitCode, QProcess::ExitStatus status) {
	emit signalStopped();
	if (!exitCode && status == QProcess::NormalExit) {
		callback_();
	} else {
		QString err = QLatin1String("*** flowc terminated *** ");
		err += QLatin1String("exit code: ") + QString::number(exitCode) + QLatin1String("\n");
		err += proc_.errorString() + QLatin1String("\n");
		stderr_(err);
	}
	env_.view.taskManager_.remove(pid_);
}

QString Task::show() const {
	return workingDir_ + QLatin1String("/") + executor_ + QLatin1String(" ") + args_.join(QLatin1String(" "));
}

}
