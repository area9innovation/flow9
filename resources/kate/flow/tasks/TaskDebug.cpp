#include <QTextStream>
#include <QFile>
#include <KTextEditor/View>
#include "execs/Runner.hpp"
#include "FlowView.hpp"
#include "debug/DebugView.hpp"
#include "debug/DebugManager.hpp"
#include "TaskBuild.hpp"
#include "TaskDumpIDs.hpp"
#include "TaskDebug.hpp"

namespace flow {

TaskDebug::TaskDebug(FlowEnv e, int row, Task::Callback cb) : TaskFactory(e, cb) {
	QString prog = env.view.flowConfig_.ui.launchTableWidget->item(row, 1)->text();
	dumper_.reset(new TaskDumpIDs(env, row, [this, prog, row]() {
		QString idsFile = prog + QLatin1String(".ids");
		env.view.debugView_->symbols().loadIdFile(idsFile);
		QFile(idsFile).remove();
		env.view.debugView_->manager()->slotDebug(row);
	}));
	builder_.reset(new TaskBuild(env, row, false, [this]() {
		dumper_->task()->slotStart();
	}));
}

Task* TaskDebug::task() {
	return builder_->task();
}

}
