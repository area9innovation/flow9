#pragma once

#include <QPointer>
#include <KXMLGUIClient>
#include <KSelectAction>
#include <KActionMenu>
#include <KTextEditor/MainWindow>

#include "Plugin.hpp"

#include "FlowOutput.hpp"
#include "FlowConfig.hpp"
#include "Outline.hpp"

namespace flow {

class FlowManager;
class DebugView;
class FlowServer;

class FlowView : public QObject, public KXMLGUIClient {
	Q_OBJECT
public:
	FlowView(KatePluginFlow* plugin, KTextEditor::MainWindow* mainWin);
	virtual ~FlowView();

	KatePluginFlow* plugin() { return plugin_; }

public Q_SLOTS:
	void slotReloadLaunchConfigs();
	void showMenu();
	void slotGotoLocation(const QString& file, int line, int col = 0);

private:
	friend class DebugView;
	friend class DebugManager;
	friend class Outline;
	void initActions();

	void readConfig(const KConfigGroup& config);
    void writeConfig(KConfigGroup& config);
    void eraseConfig(KConfigGroup& config);

	KTextEditor::MainWindow* mainWindow_;
	KatePluginFlow*          plugin_;
	QPointer<KSelectAction>  runSelectAction_;
	QPointer<KSelectAction>  buildSelectAction_;
	QPointer<KSelectAction>  debugSelectAction_;
	QPointer<KSelectAction>  forceBuildSelectAction_;

	QAction* lookupDef_;
	QAction* lookupType_;
	QAction* lookupUses_;
	QAction* rename_;
	QPointer<KActionMenu> menu_;

public:
	FlowOutput   flowOutput_;
	FlowConfig   flowConfig_;
	FlowManager* flowManager_;
	DebugView*   debugView_;
	FlowServer*  flowServer_;
	Outline*     outline_;
};

}
