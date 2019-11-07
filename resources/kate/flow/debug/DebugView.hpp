#pragma once

#include <QPointer>
#include <QUrl>

#include <KXMLGUIClient>
#include <KConfigGroup>
#include <KSelectAction>
#include <KTextEditor/Application>
#include <KTextEditor/MainWindow>

#include "DebugSymbols.hpp"
#include "ui_StackLocals.h"
#include "ui_BreakPoints.h"

namespace flow {

class FlowView;
class DebugManager;
class LocalsManager;
class StackManager;

class DebugView : public QObject, public KXMLGUIClient {
    Q_OBJECT

public:
  DebugView(KTextEditor::Plugin *plugin, KTextEditor::MainWindow *mainWin, FlowView& view);
    ~DebugView();

    void readConfig(const KConfigGroup& config);
    void writeConfig(KConfigGroup& config);
    void eraseConfig(KConfigGroup& config);

    DebugManager* manager() { return manager_; }
    DebugSymbols& symbols() { return symbols_; }

public Q_SLOTS:
	void slotReloadLaunchConfigs();

private Q_SLOTS:
    void slotToggleBreakpoint();
    void slotGoTo(const QUrl& url, int line);

    void slotAboutToShowMenu();
    void slotBreakpointSet(const QUrl& file, int line);
    void slotBreakpointCleared(const QUrl& file, int line);
    void slotSendCommand();
    void slotDebugEnable();
    void slotDebugDisable();
    void slotClearMarks();
    void slotBreakpointSelected(QTableWidgetItem*);
    void slotFrameSelected(QTableWidgetItem*);

private:
    friend class DebugManager;
    int breakpointIndex(const QUrl &file, int line) const;
    void initActions();
    void setDebugEnabled(bool enable);

    KTextEditor::Application* kateApp_;
    KTextEditor::MainWindow*  mainWin_;
    FlowView&                 flowView_;
    QWidget*                  localsStackToolView;
    QWidget*                  breakPointsToolView;
public:
    Ui::StackLocals           localsStack;
    Ui::BreakPoints           breakPoints_;
private:
    QPointer<KSelectAction>   debugActions_;
    int                       activeThread_;
    QString                   lastCommand_;
    DebugSymbols              symbols_;
    DebugManager*             manager_;
    LocalsManager*            locals_;
    StackManager*             stack_;
    QAction*                  breakpoint_;
    QUrl                      lastExecUrl_;
    int                       lastExecLine_;
};

}
