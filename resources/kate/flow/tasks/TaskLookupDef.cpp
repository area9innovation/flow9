#include <QTextStream>
#include <KTextEditor/View>
#include "execs/Compiler.hpp"
#include "FlowView.hpp"
#include "TaskLookupDef.hpp"

namespace flow {

TaskLookupDef::TaskLookupDef(FlowEnv e, Task::Callback cb) : TaskFactory(e, cb) {
	QString file = curFile(env.main);
	QString id = curIdentifier(env.main);
	env.main->activeView()->document()->documentSave();
	QString flowdir = env.view.flowConfig_.ui.flowdirLineEdit->text();
	Compiler compiler(env.view.flowConfig_.ui, file, flowdir);
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
		return;
	}
	args << file;
#ifdef DEBUG
	QTextStream(stdout) << "LOOKUP: " << compiler.invocation() << " " << args.join(QLatin1Char(' ')) << "\n";
#endif
	QString workingDir = compiler.confdir();
	QString executor = compiler.invocation();

	Task::Callback end = [this]() {
		static QRegExp fileLineRegex(QLatin1String("([^:]+):([0-9]*)[: ].*"));
		QStringList outLines = out_.split(QLatin1Char('\n'));
		for (auto outLine : outLines) {
			if (fileLineRegex.exactMatch(outLine)) {
				QString file = fileLineRegex.cap(1);
				int line = fileLineRegex.cap(2).toInt() - 1;
				if (line > -1) {
					env.view.slotGotoLocation(file, line);
				}
				break;
			}
		}
		callback();
	};
	Task::Output out = [this](const QString& str) { out_ += str; };
	Task::Output err = [this](const QString& str) {
		QTextStream(stdout) << "LOOKUP DEF ERROR: " << str << "\n";
	};
	task_ = new Task(env, executor, args, workingDir, out, err, end, this);
}

}
