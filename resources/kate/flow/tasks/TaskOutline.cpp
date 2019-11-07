#include <QTextStream>
#include <KTextEditor/View>
#include "execs/Compiler.hpp"
#include "FlowView.hpp"
#include "TaskOutline.hpp"

namespace flow {

TaskOutline::TaskOutline(FlowEnv e, const QString& file, Task::Callback cb) : TaskFactory(e, cb) {
	QString flowdir = env.view.flowConfig_.ui.flowdirLineEdit->text();
	Compiler compiler(env.view.flowConfig_.ui, file, flowdir);
	QStringList args;
	args << compiler.includeArgs();
	if (compiler.type() == Compiler::FLOWC1) {
		args << QLatin1String("incremental-priority=1");
		args << QLatin1String("print-outline=1");
	} else {
		return;
	}
	args << file;
#ifdef DEBUG
	QTextStream(stdout) << "OUTLINE: " << compiler.invocation() << " " << args.join(QLatin1Char(' ')) << "\n";
#endif
	QString workingDir = compiler.confdir();
	QString executor = compiler.invocation();

	Task::Callback end = [this]() {
		env.view.outline_->update(out_);
		callback();
	};
	Task::Output out = [this](const QString& str) { out_ += str; };
	Task::Output err = [this](const QString& str) {
		QTextStream(stdout) << "OUTLINE ERROR: " << str << "\n";
	};
	task_ = new Task(env, executor, args, workingDir, out, err, end, this);
}

}
