#pragma once

#include <QProcess>
#include <QFileInfo>
#include <QDir>

#include <KTextEditor/View>

#include <chrono>

#include "ui_RenameDialog.h"

#include "common.hpp"

namespace flow {

class FlowManager : public QObject {
	Q_OBJECT
public:
	enum Task {
		IDLE,
		COMPILING,
		RUNNING,
		BUILDING,
		DEBUGGING,
		LOOKUP_DEF,
		LOOKUP_TYPE,
		LOOKUP_USES,
		RENAMING,
		DUMPING_IDS,
		OUTLINE
	};

	FlowManager(KTextEditor::MainWindow* mainWin, FlowView& view);
	~FlowManager();

public Q_SLOTS:
	void slotCompile();
    void slotRun(int);
    void slotBuild(int);
    void slotDebug(int);
    void slotForceBuild(int);
    void slotLookupDefinition();
    void slotLookupType();
    void slotLookupUses();
    void slotStartRename();
    void slotCompleteRename();
    void slotOutline(KTextEditor::View* view);

private Q_SLOTS:
    void slotCompileError(QProcess::ProcessError err);
    void slotReadCompileStdOut();
    void slotReadCompileStdErr();
    void slotCompileFinished(int exitCode, QProcess::ExitStatus status);

    void slotLaunchError(QProcess::ProcessError err);
    void slotReadLaunchStdOut();
    void slotReadLaunchStdErr();
    void slotLaunchFinished(int exitCode, QProcess::ExitStatus status);

private:
    void build(int, Task nextTask, bool force = false);
    bool makeGlobalConfig(const QString& root) const;

    KTextEditor::MainWindow* mainWindow_;
    FlowView& flowView_;
	QProcess  compileProcess_;
	QProcess  launchProcess_;
	Ui::RenameDialog renameDialog_;

	typedef std::chrono::high_resolution_clock::time_point Time;

	struct InternalTask {
		InternalTask() : task(Task::IDLE) { }
		template<class T>
		InternalTask(Task s, const T& d) : task(s), data(d) {
			start = std::chrono::high_resolution_clock::now();
		}
		double milliseconds() const {
			auto dur = end - start;
			auto time = std::chrono::duration_cast<std::chrono::milliseconds>(dur).count();
			return static_cast<double>(time) / 1000.0;
		}
		bool showCompilerOutput() const {
			switch (task) {
			case IDLE:        return false;
			case COMPILING:   return true;
			case RUNNING:     return true;
			case BUILDING:    return true;
			case DEBUGGING:   return true;
			case LOOKUP_DEF:  return false;
			case LOOKUP_TYPE: return false;
			case LOOKUP_USES: return true;
			case RENAMING:    return false;
			case DUMPING_IDS: return false;
			case OUTLINE:     return false;
			default:          return true;
			};
		}
		QString show(bool full = false) const {
			QString ret;
			switch (task) {
			case IDLE:        ret += QLatin1String("IDLE");        break;
			case COMPILING:   ret += QLatin1String("COMPILING");   break;
			case RUNNING:     ret += QLatin1String("RUNNING");     break;
			case BUILDING:    ret += QLatin1String("BUILDING");    break;
			case DEBUGGING:   ret += QLatin1String("DEBUGGING");   break;
			case LOOKUP_DEF:  ret += QLatin1String("LOOKUP_DEF");  break;
			case LOOKUP_TYPE: ret += QLatin1String("LOOKUP_TYPE"); break;
			case LOOKUP_USES: ret += QLatin1String("LOOKUP_USES"); break;
			case RENAMING:    ret += QLatin1String("RENAMING");    break;
			case DUMPING_IDS: ret += QLatin1String("DUMPING_IDS"); break;
			case OUTLINE:     ret += QLatin1String("OUTLINE"); break;
			};
			if (full) {
				ret += QLatin1Char('\n');
				ret += QLatin1String("output:\n") + output + QLatin1String("\n");
			}
			return ret;
		}
		Task task;
		QVariant data;
		QString output;
		Time start;
		Time end;
	};

	struct TaskKeeper {
		InternalTask get() {
			internal_task_.end = std::chrono::high_resolution_clock::now();
			return internal_task_;
		}
		InternalTask peek() {
			return internal_task_;
		}
		QString& output() { return internal_task_.output; }
		template<class T>
		bool start(Task s, const T& d) {
			if (internal_task_.task != Task::IDLE) return false;
			internal_task_ = InternalTask(s, d);
			return true;
		}
		void stop() { internal_task_ = InternalTask(); }
	private:
		InternalTask internal_task_;
	};
	TaskKeeper task_;
};

}
