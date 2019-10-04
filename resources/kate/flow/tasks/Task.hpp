#pragma once

#include <QProcess>
#include <chrono>

#include "common.hpp"

namespace flow {

class Task : public QObject {
	Q_OBJECT
public:
	typedef std::function<void()> Callback;
	typedef std::function<void(const QString&)> Output;

	Task(
		FlowEnv env,
		const QString& e,
		const QStringList& as,
		const QString& wd,
		Output out,
		Output err,
		Callback cb,
		QObject* h = nullptr
	);
	~Task();
	QString show() const;
	double runTime() const;
	QProcess::ProcessState state() const { return proc_.state(); }
	const QString& pid() const { return pid_; }
	void write(const QString&);

public Q_SLOTS:
	void slotStart();
	void slotStop();

Q_SIGNALS:
	void signalStarted();
	void signalStopped();

private Q_SLOTS:
    void slotProcError(QProcess::ProcessError err);
    void slotProcStarted();
    void slotProcFinished(int exitCode, QProcess::ExitStatus status);
    void slotReadStdOut();
    void slotReadStdErr();

private:
	typedef std::chrono::high_resolution_clock::time_point Time;
	Time start_;
	Time end_;
	QProcess proc_;
	FlowEnv env_;
	QString pid_;

	QString executor_;
	QStringList args_;
	QString workingDir_;
	Output stdout_;
	Output stderr_;
	Callback callback_;

	QObject* handler_;
};

}
