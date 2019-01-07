#include "DebugView.hpp"

#include <QMenu>
#include <QFileInfo>

#include <KXMLGUIFactory>
#include <KActionMenu>
#include <KActionCollection>
#include <KConfigGroup>

#include <KLocalizedString>
#include <KTextEditor/View>
#include <KTextEditor/Editor>
#include <KTextEditor/Cursor>
#include <KTextEditor/MarkInterface>

#include "common.hpp"

#include "FlowView.hpp"
#include "FlowManager.hpp"
#include "LocalsManager.hpp"
#include "StackManager.hpp"
#include "DebugManager.hpp"
#include "DebugView.moc"

namespace flow {

DebugView::DebugView(KTextEditor::Plugin *plugin, KTextEditor::MainWindow *mainWin, FlowView& view)
:   QObject(mainWin), mainWin_(mainWin), flowView_(view), lastExecLine_(-1) {
    kateApp_ = KTextEditor::Editor::instance()->application();

    KXMLGUIClient::setComponentName(QLatin1String("kateflowdebug"), i18n("Kate Flow debugger"));
    KXMLGUIClient::setXMLFile(QLatin1String("debug_ui.rc"));

    localsStackToolView = mainWin_->createToolView(plugin, i18n("Locals and Stack"),
                                                      KTextEditor::MainWindow::Right,
													  QIcon::fromTheme(QLatin1String("media-playback-start")),
                                                      i18n("Locals and Stack"));
    // stack locals
    localsStack.setupUi(new QWidget(localsStackToolView));
    breakPointsToolView = mainWin_->createToolView(plugin, i18n("Breakpoints"),
                                                      KTextEditor::MainWindow::Right,
													  QIcon::fromTheme(QLatin1String("media-playback-start")),
                                                      i18n("Breakpoints"));

    breakPoints_.setupUi(new QWidget(breakPointsToolView));
    manager_  = new DebugManager(flowView_);
    locals_ = new LocalsManager(localsStack.locals, flowView_);
    stack_ = new StackManager(localsStack.stack, flowView_);
    initActions();
    setDebugEnabled(false);
    mainWin_->guiFactory()->addClient(this);
}

DebugView::~DebugView() {
    mainWin_->guiFactory()->removeClient(this);
    delete localsStackToolView;
    delete breakPointsToolView;
}

void DebugView::slotReloadLaunchConfigs() {
	QStringList launchNames;
    for (int row = 0; row < flowView_.flowConfig_.ui.launchTableWidget->rowCount(); ++row) {
        launchNames << flowView_.flowConfig_.ui.launchTableWidget->item(row, 0)->text();
    }
    debugActions_->setItems(launchNames);
}

void DebugView::slotAboutToShowMenu() {
    KTextEditor::View* editView = mainWin_->activeView();
    QUrl               url = editView->document()->url();
    int                line = editView->cursorPosition().line();

    // GDB uses 1 based line numbers, kate uses 0 based...
    if (manager_->hasBreakpoint(url, line + 1)) {
        breakpoint_->setText(i18n("Remove breakpoint"));
    }
    else {
        breakpoint_->setText(i18n("Insert breakpoint"));
    }
}

void DebugView::slotToggleBreakpoint() {
	KTextEditor::View* editView = mainWin_->activeView();
	QUrl currURL  = editView->document()->url();
	int line = editView->cursorPosition().line();
	manager_->toggleBreakpoint(currURL, line + 1);
}

int DebugView::breakpointIndex(const QUrl &file, int line) const {
	QString fileString = file.toLocalFile();
	QString lineString = QString::number(line + 1);
	for (int row = 0; row < breakPoints_.breakPointsTable->rowCount(); ++ row) {
		QString bpLine = breakPoints_.breakPointsTable->item(row, 0)->text();
		QString bpFile = breakPoints_.breakPointsTable->item(row, 1)->text();
		if (lineString == bpLine && fileString == bpFile) {
			return row;
		}
	}
	return -1;
}

void DebugView::slotBreakpointSet(const QUrl &file, int line) {
    if (KTextEditor::MarkInterface* iface = qobject_cast<KTextEditor::MarkInterface*>(kateApp_->findUrl(file))) {
        iface->setMarkDescription(KTextEditor::MarkInterface::BreakpointActive, i18n("Breakpoint"));
        iface->setMarkPixmap(KTextEditor::MarkInterface::BreakpointActive,
                             QIcon::fromTheme(QLatin1String("media-playback-pause")).pixmap(9, 9));
        iface->addMark(line, KTextEditor::MarkInterface::BreakpointActive);
        if (breakpointIndex(file, line) == -1) {
			int rowInd = breakPoints_.breakPointsTable->rowCount();
			breakPoints_.breakPointsTable->insertRow(rowInd);

			QTableWidgetItem* lineItem = new QTableWidgetItem(QString::number(line + 1));
			QTableWidgetItem* fileItem = new QTableWidgetItem(file.toLocalFile());

			Qt::ItemFlags flags = lineItem->flags();
			lineItem->setFlags(flags & ~Qt::ItemIsEditable);
			fileItem->setFlags(flags & ~Qt::ItemIsEditable);

			breakPoints_.breakPointsTable->setItem(rowInd, 0, lineItem);
			breakPoints_.breakPointsTable->setItem(rowInd, 1, fileItem);
        }
    }
}

void DebugView::slotBreakpointCleared(const QUrl &file, int line) {
    if (KTextEditor::MarkInterface* iface = qobject_cast<KTextEditor::MarkInterface*>(kateApp_->findUrl(file))) {
        iface->removeMark(line, KTextEditor::MarkInterface::BreakpointActive);
        int row = breakpointIndex(file, line);
        if (row != -1) {
        	breakPoints_.breakPointsTable->removeRow(row);
        }
    }
}

void DebugView::slotBreakpointSelected(QTableWidgetItem* item) {
	int row = item->row();
	QString bpLine = breakPoints_.breakPointsTable->item(row, 0)->text();
	QString bpFile = breakPoints_.breakPointsTable->item(row, 1)->text();
	slotGoTo(QUrl::fromLocalFile(bpFile), bpLine.toInt() - 1);
}

void DebugView::slotFrameSelected(QTableWidgetItem* item) {
	int row = item->row();
	int level  = localsStack.stack->item(row, 0)->text().toInt();
	QString bpFile = localsStack.stack->item(row, 5)->text();
	QString bpLine = localsStack.stack->item(row, 6)->text();
	slotGoTo(QUrl::fromLocalFile(bpFile), bpLine.toInt() - 1);
	manager_->stackFrameSelected(level);
}

//static int lastGoToLineNum = -1;

void DebugView::slotGoTo(const QUrl& url, int line) {
	QString file = url.toLocalFile();
    // skip not existing files
    if (!QFile::exists(file)) {
        return;
    }

    KTextEditor::View* editView = mainWin_->openUrl(url);
    if (editView && editView->setCursorPosition(KTextEditor::Cursor(line, 0))) {
    	editView->raise();
    	editView->setFocus(Qt::OtherFocusReason);
    }

    if (KTextEditor::MarkInterface* iface = qobject_cast<KTextEditor::MarkInterface*>(kateApp_->findUrl(lastExecUrl_))) {
        iface->removeMark(lastExecLine_, KTextEditor::MarkInterface::Bookmark);
    }
    if (KTextEditor::MarkInterface* iface = qobject_cast<KTextEditor::MarkInterface*>(kateApp_->findUrl(url))) {
        iface->setMarkDescription(KTextEditor::MarkInterface::Bookmark, i18n("Current"));
        iface->setMarkPixmap(KTextEditor::MarkInterface::Bookmark,
                             QIcon::fromTheme(QLatin1String("media-playback-start")).pixmap(9, 9));
        iface->addMark(line, KTextEditor::MarkInterface::Bookmark);
    }
    lastExecUrl_ = url;
    lastExecLine_ = line;
}

void DebugView::slotDebugEnable() {
	setDebugEnabled(true);
}

void DebugView::slotDebugDisable() {
	setDebugEnabled(false);
	if (KTextEditor::MarkInterface* iface = qobject_cast<KTextEditor::MarkInterface*>(kateApp_->findUrl(lastExecUrl_))) {
        iface->removeMark(lastExecLine_, KTextEditor::MarkInterface::Bookmark);
    }
	lastExecUrl_.clear();
    lastExecLine_ = -1;
    localsStack.stack->clearContents();
    localsStack.locals->clear();
}

void DebugView::setDebugEnabled(bool enable) {
    actionCollection()->action(QLatin1String("step_in"))->setEnabled(enable);
    actionCollection()->action(QLatin1String("step_over"))->setEnabled(enable);
    actionCollection()->action(QLatin1String("step_out"))->setEnabled(enable);
    actionCollection()->action(QLatin1String("continue"))->setEnabled(enable);
    actionCollection()->action(QLatin1String("kill"))->setEnabled(enable);

    localsStack.stack->setEnabled(enable);
    localsStack.locals->setEnabled(enable);
    debugActions_->setEnabled(!enable);
    //flowView_.debugSelectAction_->setEnabled(!enable);
}

void DebugView::slotClearMarks() {
    foreach (KTextEditor::Document* doc, kateApp_->documents()) {
        if (KTextEditor::MarkInterface* iface = qobject_cast<KTextEditor::MarkInterface*>(doc)) {
            const QHash<int, KTextEditor::Mark*> marks = iface->marks();
            QHashIterator<int, KTextEditor::Mark*> i(marks);
            while (i.hasNext()) {
                i.next();
                if ((i.value()->type == KTextEditor::MarkInterface::Execution) ||
                	(i.value()->type == KTextEditor::MarkInterface::BreakpointActive)) {
                    iface->removeMark(i.value()->line, i.value()->type);
                }
            }
        }
    }
    if (KTextEditor::MarkInterface* iface = qobject_cast<KTextEditor::MarkInterface*>(kateApp_->findUrl(lastExecUrl_))) {
        iface->removeMark(lastExecLine_, KTextEditor::MarkInterface::Bookmark);
    }
}

void DebugView::slotSendCommand() {
	// TODO: use proper command
    QString cmd = flowView_.flowOutput_.ui.debugCommandLineEdit->text();
    if (cmd.isEmpty()) cmd = lastCommand_;
    lastCommand_ = cmd;
    manager_->issueCommand(cmd);
}

void DebugView::readConfig(const KConfigGroup& config) {
	manager_->readConfig(config);
}

void DebugView::writeConfig(KConfigGroup& config) {
    manager_->writeConfig(config);
}

void DebugView::eraseConfig(KConfigGroup& config) {
    manager_->eraseConfig(config);
}

void DebugView::initActions() {
    connect(manager_, SIGNAL(signalDebugLocationChanged(QUrl,int)), this, SLOT(slotGoTo(QUrl,int)));
    connect(manager_, SIGNAL(signalBreakPointSet(QUrl,int)), this, SLOT(slotBreakpointSet(QUrl,int)));
    connect(manager_, SIGNAL(signalBreakPointCleared(QUrl,int)), this, SLOT(slotBreakpointCleared(QUrl,int)));
    connect(manager_, SIGNAL(signalLocalsInfo(QString)), locals_, SLOT(slotLocalsInfo(QString)));
    connect(manager_, SIGNAL(signalStackInfo(QString)), stack_, SLOT(slotStackInfo(QString)));
    connect(manager_, SIGNAL(signalArgsInfo(QString, int)), locals_, SLOT(slotArgsInfo(QString, int)));

    connect(&manager_->debugProcess_, SIGNAL(started()), this, SLOT(slotDebugEnable()));
    connect(&manager_->debugProcess_, SIGNAL(started()), localsStack.locals, SLOT(clear()));
    connect(&manager_->debugProcess_, SIGNAL(started()), localsStack.stack, SLOT(clearContents()));
    connect(&manager_->debugProcess_, SIGNAL(finished(int, QProcess::ExitStatus)), this, SLOT(slotDebugDisable()));

    connect(flowView_.flowOutput_.ui.debugCommandPushButton, SIGNAL(clicked()), this, SLOT(slotSendCommand()));
    connect(flowView_.flowOutput_.ui.debugCommandLineEdit, SIGNAL(returnPressed()), this, SLOT(slotSendCommand()));

    connect(breakPoints_.breakPointsTable, SIGNAL(itemClicked(QTableWidgetItem*)), this, SLOT(slotBreakpointSelected(QTableWidgetItem*)));
    connect(localsStack.stack, SIGNAL(itemClicked(QTableWidgetItem*)), this, SLOT(slotFrameSelected(QTableWidgetItem*)));

    // Actions
    debugActions_ = actionCollection()->add<KSelectAction>(QLatin1String("debug"));
    debugActions_->setText(i18n("Start Debugging"));
    debugActions_->setIcon(QIcon::fromTheme(QLatin1String("media-playback-start")));

    connect(debugActions_, SIGNAL(triggered(int)), flowView_.flowManager_, SLOT(slotDebug(int)));
    connect(&flowView_.flowConfig_, SIGNAL(launchConfigsChanged()), this, SLOT(slotReloadLaunchConfigs()));

    QAction* a = actionCollection()->addAction(QLatin1String("kill"));
    a->setText(i18n("Kill / Stop Debugging"));
    a->setIcon(QIcon::fromTheme(QLatin1String("media-playback-stop")));
    connect(a, SIGNAL(triggered(bool)), manager_, SLOT(slotKill()));

    a = actionCollection()->addAction(QLatin1String("toggle_breakpoint"));
    a->setText(i18n("Toggle Breakpoint / Break"));
    a->setIcon(QIcon::fromTheme(QLatin1String("media-playback-pause")));
    connect(a, SIGNAL(triggered(bool)), this, SLOT(slotToggleBreakpoint()));

    a = actionCollection()->addAction(QLatin1String("step_in"));
    a->setText(i18n("Step In"));
    a->setIcon(QIcon::fromTheme(QLatin1String("debug-step-into")));
    connect(a, SIGNAL(triggered(bool)), manager_, SLOT(slotStepInto()));

    a = actionCollection()->addAction(QLatin1String("step_over"));
    a->setText(i18n("Step Over"));
    a->setIcon(QIcon::fromTheme(QLatin1String("debug-step-over")));
    connect(a, SIGNAL(triggered(bool)), manager_, SLOT(slotStepOver()));

    a = actionCollection()->addAction(QLatin1String("step_out"));
    a->setText(i18n("Step Out"));
    a->setIcon(QIcon::fromTheme(QLatin1String("debug-step-out")));
    connect(a, SIGNAL(triggered(bool)), manager_, SLOT(slotStepOut()));

    a = actionCollection()->addAction(QLatin1String("continue"));
    a->setText(i18n("Continue"));
    a->setIcon(QIcon::fromTheme(QLatin1String("media-playback-start")));
    connect(a, SIGNAL(triggered(bool)), manager_, SLOT(slotContinue()));

    // popup context m_menu
    QPointer<KActionMenu> menu = new KActionMenu(i18n("Debug"), this);
    actionCollection()->addAction(QLatin1String("popup_flow_debug"), menu);
    connect(menu->menu(), SIGNAL(aboutToShow()), this, SLOT(slotAboutToShowMenu()));
    breakpoint_ = menu->menu()->addAction(QLatin1String("popup_breakpoint"), this, SLOT(slotToggleBreakpoint()));
}

}
