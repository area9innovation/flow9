#include <QMenu>
#include <QTextStream>
#include <KXMLGUIFactory>
#include <KActionCollection>
#include <KMessageBox>
#include <KLocalizedString>
#include <KConfigGroup>
#include <KSharedConfig>

#include "common.hpp"
#include "FlowView.hpp"
#include "FlowManager.hpp"
#include "FlowServer.hpp"
#include "DebugManager.hpp"
#include "DebugView.hpp"

namespace flow {

FlowView::FlowView(KatePluginFlow* plugin, KTextEditor::MainWindow* mainWin) :
	QObject(mainWin),
	mainWindow_(mainWin),
	plugin_(plugin),
	flowOutput_(mainWindow_->createToolView(
		plugin_,
		QLatin1String("FlowOutputToolView"),
		KTextEditor::MainWindow::ToolViewPosition::Bottom,
		QIcon::fromTheme(QLatin1String("media-playback-start")),
		QLatin1String("Flow output")
	)),
	flowConfig_(mainWindow_->createToolView(
		plugin_,
		QLatin1String("FlowConfigToolView"),
		KTextEditor::MainWindow::ToolViewPosition::Bottom,
		QIcon::fromTheme(QLatin1String("media-playback-start")),
		QLatin1String("Flow config")
	)),
	flowManager_(new FlowManager(mainWindow_, *this)),
	debugView_(new DebugView(plugin_, mainWindow_, *this)),
	flowServer_(new FlowServer(mainWindow_, *this)),
	outline_ (new Outline(mainWindow_, this))
{
	KConfigGroup config(KSharedConfig::openConfig(), QLatin1String("Flow"));
    readConfig(config);

    KXMLGUIClient::setComponentName(QLatin1String("kateflowmenu"), i18n("Flow language support"));
    KXMLGUIClient::setXMLFile(QLatin1String("menu_ui.rc"));

    initActions();
    debugView_->slotReloadLaunchConfigs();
    slotReloadLaunchConfigs();
    connect(flowOutput_.ui.compilerOutTextEdit, SIGNAL(signalCompilerError(QString, int, int)), this, SLOT(slotGotoLocation(QString, int, int)));
    connect (mainWindow_, SIGNAL(viewChanged(KTextEditor::View*)), outline_, SLOT(refresh(KTextEditor::View*)));

    mainWindow_->guiFactory()->addClient(this);
    if (flowConfig_.ui.serverAutostartCheckBox->isChecked()) {
    	flowServer_->slotStart();
    }
}

FlowView::~FlowView() {
	flowServer_->slotTerminate();
	KConfigGroup config(KSharedConfig::openConfig(), QLatin1String("Flow"));
	eraseConfig(config);
    writeConfig(config);
    delete outline_;
    delete debugView_;
    delete flowManager_;
	mainWindow_->guiFactory()->removeClient(this);
}

void FlowView::slotReloadLaunchConfigs() {
	QStringList launchNames;
    for (int row = 0; row < flowConfig_.ui.launchTableWidget->rowCount(); ++row) {
        launchNames << flowConfig_.ui.launchTableWidget->item(row, 0)->text();
    }
    runSelectAction_->setItems(launchNames);
    buildSelectAction_->setItems(launchNames);
    debugSelectAction_->setItems(launchNames);
    forceBuildSelectAction_->setItems(launchNames);
}

void FlowView::slotGotoLocation(const QString& path, const int line, const int column) {
	if (!QFile::exists(path)) {
		KMessageBox::sorry(0, i18n("File '") + path + i18n("' doesn't exist"));
        return;
    }
	if (KTextEditor::View* view = mainWindow_->openUrl(QUrl::fromLocalFile(path))) {
		QString lineString = view->document()->line(line);
		int tabsNum = lineString.count(QLatin1Char('\t'));
		mainWindow_->activateView(view->document());
		mainWindow_->activeView()->setCursorPosition(KTextEditor::Cursor(line, column - tabsNum * 3));
		mainWindow_->activeView()->setFocus();
	} else {
		KMessageBox::sorry(0, i18n("Cannot open ") + path);
	}
}

void FlowView::initActions() {

    QAction* a = actionCollection()->addAction(QLatin1String("compile"), flowManager_, SLOT(slotCompile()));
    a->setText(i18n("Compile"));
    a->setIcon(QIcon::fromTheme(QLatin1String("media-playback-stop")));
    actionCollection()->setDefaultShortcut(a, QKeySequence(QLatin1String("F7")));

    runSelectAction_ = actionCollection()->add<KSelectAction>(QLatin1String("run"));
    runSelectAction_->setText(i18n("Run"));
    runSelectAction_->setIcon(QIcon::fromTheme(QLatin1String("media-playback-start")));

    buildSelectAction_ = actionCollection()->add<KSelectAction>(QLatin1String("build"));
    buildSelectAction_->setText(i18n("Build"));
    buildSelectAction_->setIcon(QIcon::fromTheme(QLatin1String("media-playback-start")));

    debugSelectAction_ = actionCollection()->add<KSelectAction>(QLatin1String("debug"));
    debugSelectAction_->setText(i18n("Debug"));
    debugSelectAction_->setIcon(QIcon::fromTheme(QLatin1String("media-playback-start")));

    forceBuildSelectAction_ = actionCollection()->add<KSelectAction>(QLatin1String("force_build"));
    forceBuildSelectAction_->setText(i18n("Force Build"));
    forceBuildSelectAction_->setIcon(QIcon::fromTheme(QLatin1String("media-playback-start")));

    connect(runSelectAction_,   SIGNAL(triggered(int)), flowManager_, SLOT(slotRun(int)));
    connect(debugSelectAction_, SIGNAL(triggered(int)), flowManager_, SLOT(slotDebug(int)));
    connect(buildSelectAction_, SIGNAL(triggered(int)), flowManager_, SLOT(slotBuild(int)));
    connect(forceBuildSelectAction_, SIGNAL(triggered(int)), flowManager_, SLOT(slotForceBuild(int)));
    connect(&flowConfig_, SIGNAL(launchConfigsChanged()), this, SLOT(slotReloadLaunchConfigs()));

    menu_ = new KActionMenu(i18n("Flow"), this);
    actionCollection()->addAction(QLatin1String("popup_flow_menu"), menu_);
    connect(menu_->menu(), SIGNAL(aboutToShow()), this, SLOT(showMenu()));

    lookupDef_ = menu_->menu()->addAction(QLatin1String("lookup_flow_definition"), flowManager_, SLOT(slotLookupDefinition()));
    lookupDef_->setShortcut(QKeySequence(QLatin1String("F12")));

    lookupType_ = menu_->menu()->addAction(QLatin1String("lookup_flow_type"), flowManager_, SLOT(slotLookupType()));
    //a->setShortcut(QKeySequence(QLatin1String("Shift+T")));

    lookupUses_ = menu_->menu()->addAction(QLatin1String("lookup_flow_uses"), flowManager_, SLOT(slotLookupUses()));

    rename_ = menu_->menu()->addAction(QLatin1String("rename_flow_id"), flowManager_, SLOT(slotRename()));
    //a->setShortcut(QKeySequence(QLatin1String("Ctrl+Shift+R")));
}

void FlowView::showMenu() {
	const QString identifier = curIdentifier(mainWindow_);
	if (identifier.isEmpty()) {
		lookupDef_->setText (i18n ("Nothing to lookup"));
		lookupType_->setText (i18n ("Nothing to lookup"));
		lookupUses_->setText (i18n ("Nothing to lookup"));
		rename_->setText (i18n ("Nothing to rename"));
	} else {
		lookupDef_->setText (i18n ("Lookup definition: %1", identifier));
		lookupType_->setText (i18n ("Lookup type: %1", identifier));
		lookupUses_->setText (i18n ("Find all uses of: %1", identifier));
		rename_->setText (i18n ("Rename: %1", identifier));
	}
}

void FlowView::readConfig(const KConfigGroup& config) {
	int i = config.readEntry(QLatin1String("Opened flow files number"), 0);
	while (i--) {
		QString file = config.readEntry(QStringLiteral("Opened flow %1 file").arg(i), QString());
		KTextEditor::View* view = mainWindow_->openUrl(QUrl::fromLocalFile(file));
		int line = config.readEntry(QStringLiteral("Opened flow %1 file line").arg(i), 0);
		int column = config.readEntry(QStringLiteral("Opened flow %1 file column").arg(i), 0);
		view->setCursorPosition(KTextEditor::Cursor(line, column));
		view->activateWindow();
		view->show();
		view->raise();
	}
	debugView_->readConfig(config);
	flowConfig_.readConfig(config);
}

void FlowView::writeConfig(KConfigGroup& config) {
	debugView_->writeConfig(config);
	flowConfig_.writeConfig(config);
	config.writeEntry(QLatin1String("Opened flow files number"), mainWindow_->views().count());
    int i = 0;
    for (auto view : mainWindow_->views()) {
    	auto file = view->document()->url().toLocalFile();
    	if (!file.endsWith(QLatin1String(".flow"))) continue;
    	config.writeEntry(QStringLiteral("Opened flow %1 file").arg(i), file);
    	config.writeEntry(QStringLiteral("Opened flow %1 file line").arg(i), view->cursorPosition().line());
    	config.writeEntry(QStringLiteral("Opened flow %1 file column").arg(i), view->cursorPosition().column());
    	++i;
    }
}

void FlowView::eraseConfig(KConfigGroup& config) {
	debugView_->eraseConfig(config);
	flowConfig_.eraseConfig(config);
	int i = config.readEntry(QLatin1String("Opened flow files number"), 0);
	while (i--) {
		config.deleteEntry(QStringLiteral("Opened flow %1 file").arg(i));
		config.deleteEntry(QStringLiteral("Opened flow %1 file line").arg(i));
		config.deleteEntry(QStringLiteral("Opened flow %1 file column").arg(i));
	}
	config.deleteEntry(QLatin1String("Opened flow files number"));
}

}
