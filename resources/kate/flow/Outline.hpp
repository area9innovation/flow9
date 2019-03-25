#pragma once

#include <QWidget>
#include <QPoint>
#include <QTreeWidget>
#include <QTreeWidgetItem>
#include <QDomNode>
#include <QMenu>
#include <QAction>

#include <KTextEditor/MainWindow>

namespace flow {

class FlowView;

class Outline : public QWidget {
Q_OBJECT
public:
	Outline (KTextEditor::MainWindow*, FlowView*);
	virtual ~ Outline();

	void update(const QString& data);

public Q_SLOTS:
	void refresh();

	void pushShowAll();
	void toggleTreeMode();
	void toggleSortingMode();

	void slotShowContextMenu(const QPoint&);
	void gotoDefinition(QTreeWidgetItem*);

private :
	void setup();
	bool decideToShow(const QString& kind);

	struct TreeWidget : public QTreeWidget {
		TreeWidget(QWidget*, Outline*);
		void showEvent(QShowEvent *event) Q_DECL_OVERRIDE;
		Outline* outline;
	};
		
	KTextEditor::MainWindow* window_;
	FlowView*   view_;
	QWidget*    toolView_;
	TreeWidget* tree_;

	QMenu*      popup_;
	QAction*    refresh_;
	QAction*    showAll_;
	QAction*    showImports_;
	QAction*    showExports_;
	QAction*    showForbids_;
	QAction*    showTypes_;
	QAction*    showFuncs_;
	QAction*    showVars_;
	QAction*    showNatives_;
	QAction*    treeMode_;
	QAction*    sortingMode_;
};

}
