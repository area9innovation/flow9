#include <QTextStream>
#include <QToolTip>
#include <KTextEditor/View>
#include "execs/Compiler.hpp"
#include "FlowView.hpp"
#include "TaskLookupType.hpp"

namespace flow {

TaskLookupType::TaskLookupType(FlowEnv e, Task::Callback cb) : TaskFactory(e, cb) {
	QString file = curFile(env.main);
	QString line = QString::number(env.main->activeView()->cursorPosition().line() + 1);
	QString col = QString::number(env.main->activeView()->cursorPosition().column() + 1);
	env.main->activeView()->document()->documentSave();
	QString flowdir = env.view.flowConfig_.ui.flowdirLineEdit->text();
	Compiler compiler(env.view.flowConfig_.ui, file, flowdir);
	if (compiler.type() != Compiler::FLOWC1) {
		return;
	}
	QStringList args;
	args << compiler.includeArgs();
	args << QLatin1String("find-type=1");
	args << QLatin1String("exp-line=") + line;
	args << QLatin1String("exp-column=") + col;
	args << file;
#ifdef DEBUG
	QTextStream(stdout) << "LOOKUP TYPE: " << compiler.invocation() << " " << args.join(QLatin1Char(' ')) << "\n";
#endif
	QString workingDir = compiler.confdir();
	QString executor = compiler.invocation();

	Task::Callback end = [this]() {
		static QRegExp typeRegex(QLatin1String("Type=(.*)"));
		QStringList outLines = out_.split(QLatin1Char('\n'));
		for (auto outLine : outLines) {
			if (typeRegex.exactMatch(outLine)) {
				QString type = typeRegex.cap(1);
				if (!type.isEmpty()) {
					KTextEditor::View* activeView = env.main->activeView();
					if (!activeView || !activeView->cursorPosition().isValid()) {
						break;
					}
					QPoint viewCoordinates = activeView->cursorPositionCoordinates();
					QPoint globalCoorinates = activeView->mapToGlobal(viewCoordinates);
					QToolTip::showText(globalCoorinates, type);
				}
				break;
			}
		}
		callback();
	};
	Task::Output out = [this](const QString& str) { out_ += str; };
	Task::Output err = [this](const QString& str) {
		QTextStream(stdout) << "LOOKUP TYPE ERROR: " << str << "\n";
	};
	task_ = new Task(env, executor, args, workingDir, out, err, end, this);
}

}
