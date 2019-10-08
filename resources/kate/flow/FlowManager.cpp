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
	env_.view.taskManager_.compile();
}

void FlowManager::slotRun(int row) {
	env_.view.taskManager_.run(row);
}

void FlowManager::slotDebug(int row) {
	env_.view.taskManager_.debug(row);
}

void FlowManager::slotBuild(int row) {
	env_.view.taskManager_.build(row, false);
}

void FlowManager::slotForceBuild(int row) {
	env_.view.taskManager_.build(row, true);
}

void FlowManager::slotLookupDefinition() {
	env_.view.taskManager_.lookupDef();
}

void FlowManager::slotLookupType() {
	env_.view.taskManager_.lookupType();
}

void FlowManager::slotLookupUses() {
	env_.view.taskManager_.lookupUses();
}

void FlowManager::slotOutline(KTextEditor::View* view) {
	QString file = view->document()->url().toLocalFile();
	env_.view.taskManager_.outline(file);
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
	env_.view.taskManager_.rename(renamed);
}

}
