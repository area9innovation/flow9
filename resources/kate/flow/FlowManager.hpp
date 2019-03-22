#pragma once

#include <QProcess>
#include <QFileInfo>
#include <QDir>

#include <KTextEditor/View>

#include <chrono>

#include "ui_RenameDialog.h"

#include "common.hpp"

namespace flow {

class FlowView;

class FlowManager : public QObject {
	Q_OBJECT
public:
	enum State {
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
    void slotRename();
    void slotCompleteRename();
    void slotOutline();

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
    void build(int, State nextState, bool force = false);
    bool makeGlobalConfig(const QString& root) const;

    KTextEditor::MainWindow* mainWindow_;
    FlowView& flowView_;
	QProcess  compileProcess_;
	QProcess  launchProcess_;
	Ui::RenameDialog renameDialog_;

	typedef std::chrono::high_resolution_clock::time_point Time;

	struct InternalState {
		InternalState() : state(State::IDLE) { }
		template<class T>
		InternalState(State s, const T& d) : state(s), data(d) {
			start = std::chrono::high_resolution_clock::now();
		}
		double milliseconds() const {
			auto dur = end - start;
			auto time = std::chrono::duration_cast<std::chrono::milliseconds>(dur).count();
			return static_cast<double>(time) / 1000.0;
		}
		State state;
		QVariant data;
		QString output;
		Time start;
		Time end;
	};

	struct StateKeeper {
		InternalState get() {
			internal_state_.end = std::chrono::high_resolution_clock::now();
			return internal_state_;
		}
		QString& output() { return internal_state_.output; }
		template<class T>
		bool start(State s, const T& d) {
			if (internal_state_.state != State::IDLE) return false;
			internal_state_ = InternalState(s, d);
			return true;
		}
		void stop() { internal_state_ = InternalState(); }
	private:
		InternalState internal_state_;
	};
	StateKeeper state_;
};

}
