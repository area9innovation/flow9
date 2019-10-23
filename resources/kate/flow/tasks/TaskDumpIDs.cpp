#include <QTextStream>
#include <KTextEditor/View>
#include "execs/Compiler.hpp"
#include "FlowView.hpp"
#include "TaskDumpIDs.hpp"

namespace flow {

TaskDumpIDs::TaskDumpIDs(FlowEnv e, int row, Task::Callback cb) : TaskFactory(e, cb) {
	QString prog = env.view.flowConfig_.ui.launchTableWidget->item(row, 1)->text();
	QString dir  = env.view.flowConfig_.ui.launchTableWidget->item(row, 2)->text();
	QString flowdir = env.view.flowConfig_.ui.flowdirLineEdit->text();
	Compiler compiler(env.view.flowConfig_.ui, prog, flowdir);
	QStringList args;
	args << compiler.includeArgs();
	args << QLatin1String("dump-ids=") + prog + QLatin1String(".ids");
	args << QLatin1String("dump-ids-all=1");
	args << prog;
#ifdef DEBUG
	QTextStream(stdout) << "DUMP_IDS: " << compiler.invocation() << " " << args.join(QLatin1Char(' ')) << "\n";
#endif
	QString workingDir = compiler.confdir();
	QString executor = compiler.invocation();

	Task::Output out = [this](const QString& str) { out_ += str; };
	Task::Output err = [this](const QString& str) {
		QTextStream(stdout) << "LOOKUP DEF ERROR: " << str << "\n";
	};
	task_ = new Task(env, executor, args, workingDir, out, err, callback, this);
}

}
