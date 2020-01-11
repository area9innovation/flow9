#include <QTextStream>
#include <KMessageBox>
#include <KTextEditor/View>
#include "execs/Compiler.hpp"
#include "FlowView.hpp"
#include "FlowManager.hpp"

#include "debug/DebugManager.hpp"

namespace flow {

FlowManager::FlowManager(FlowEnv e) :
	QObject(e.main), env_(e) {
}

void FlowManager::slotCompile() {
	try {
		env_.view.taskManager_.compile();
	} catch (std::exception& ex) {
		QTextStream(stdout) << ex.what() << endl;
	}
}

void FlowManager::slotRun(int row) {
	try {
		env_.view.taskManager_.run(row);
	} catch (std::exception& ex) {
		QTextStream(stdout) << ex.what() << endl;
	}
}

void FlowManager::slotDebug(int row) {
	try {
		env_.view.taskManager_.debug(row);
	} catch (std::exception& ex) {
		QTextStream(stdout) << ex.what() << endl;
	}
}

void FlowManager::slotBuild(int row) {
	try {
		env_.view.taskManager_.build(row, false);
	} catch (std::exception& ex) {
		QTextStream(stdout) << ex.what() << endl;
	}
}

void FlowManager::slotForceBuild(int row) {
	try {
		env_.view.taskManager_.build(row, true);
	} catch (std::exception& ex) {
		QTextStream(stdout) << ex.what() << endl;
	}
}

void FlowManager::slotLookupDefinition() {
	try {
		env_.view.taskManager_.lookupDef();
	} catch (std::exception& ex) {
		QTextStream(stdout) << ex.what() << endl;
	}
}

void FlowManager::slotLookupType() {
	try {
		env_.view.taskManager_.lookupType();
	} catch (std::exception& ex) {
		QTextStream(stdout) << ex.what() << endl;
	}
}

void FlowManager::slotLookupUses() {
	env_.view.taskManager_.lookupUses();
}

void FlowManager::slotOutline(KTextEditor::View* view) {
	QString file = view->document()->url().toLocalFile();
	try {
		env_.view.taskManager_.outline(file);
	} catch (std::exception& ex) {
		QTextStream(stdout) << ex.what() << endl;
	}
}

void FlowManager::slotStartRename() {
	QString file = curFile(env_.main);
	Compiler compiler(env_.view.flowConfig_.ui, file, env_.view.flowConfig_.ui.flowdirLineEdit->text());
	if (compiler.type() == Compiler::FLOW) {
		KMessageBox::sorry(0, i18n("Only flowc compiler allows renaming"));
		return;
	}
	KTextEditor::View* activeView = env_.main->activeView();
	QWidget* ask = new QWidget();
	renameDialog_.setupUi(ask);
	QString id = curIdentifier(env_.main);
	renameDialog_.renameLineEdit->setText(id);
	connect(renameDialog_.renameButton, SIGNAL(clicked()), this, SLOT(slotCompleteRename()));
	connect(renameDialog_.renameLineEdit, SIGNAL(returnPressed()), this, SLOT(slotCompleteRename()));

	env_.main->addWidgetToViewBar(activeView, ask);
	env_.main->showViewBar(activeView);
}

void FlowManager::slotCompleteRename() {
	KTextEditor::View* activeView = env_.main->activeView();
	if (!activeView || !activeView->cursorPosition().isValid()) {
		return;
	}
	QString renamed = renameDialog_.renameLineEdit->text();
	env_.main->deleteViewBar(activeView);
	try {
		env_.view.taskManager_.rename(renamed);
	} catch (std::exception& ex) {
		QTextStream(stdout) << ex.what() << endl;
	}
}

}
