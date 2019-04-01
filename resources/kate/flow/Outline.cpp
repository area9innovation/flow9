#include <QMessageBox>

#include <KTextEditor/View>

#include "Icons.hpp"
#include "Outline.moc"

#include "FlowView.hpp"
#include "FlowManager.hpp"
#include "Outline.hpp"

namespace flow {

Outline::Outline(KTextEditor::MainWindow* window, FlowView* view) :
	QWidget(window->activeView()),
	window_ (window),
	view_ (view),

	toolView_ (nullptr),
	tree_ (nullptr),
	popup_ (nullptr),

	refresh_(nullptr),
	showAll_ (nullptr),
	showImports_ (nullptr),
	showForbids_ (nullptr),
	showExports_ (nullptr),
	showTypes_ (nullptr),
	showFuncs_ (nullptr),
	showVars_ (nullptr),
	showNatives_ (nullptr),
	treeMode_ (nullptr),
	sortingMode_ (nullptr)
{
	toolView_ = window_->createToolView
	(
		view_->plugin(),
		QLatin1String("kate_private_plugin_flow_outline"),
		KTextEditor::MainWindow :: Left,
		QIcon(QLatin1String("application-x-ms-dos-executable")),
		i18n("Outline")
	);
	tree_ = new TreeWidget(toolView_, this);
	popup_ = new QMenu(tree_);

	setup();

	showImports_->setChecked(true);
	showForbids_->setChecked(true);
	showExports_->setChecked(true);
	showTypes_->setChecked(true);
	showFuncs_->setChecked(true);
	showVars_->setChecked(true);
	showNatives_->setChecked(true);
}
Outline::~Outline() { }

void Outline::refresh() {
	if (!window_->activeView() || !toolView_->isVisible()) return;
	view_->flowManager_->slotOutline();
}

static QIcon selectIcon(const QString& kind) {

	static QPixmap unionPixmap(class_xpm);
	static QPixmap structPixmap(struct_xpm);
	static QPixmap functionPixmap(method_xpm);
	static QPixmap functionDeclPixmap(macro_xpm);
	static QPixmap globalPixmap(class_int_xpm);

	if (kind == QLatin1String("import")) {
		return QIcon::fromTheme(QLatin1String("media-playback-start"));
	} else if (kind == QLatin1String("export")) {
		return QIcon::fromTheme(QLatin1String("media-playback-stop"));
	} else if (kind == QLatin1String("forbid")) {
		return QIcon::fromTheme(QLatin1String("media-playback-pause"));
	} else if (kind == QLatin1String("struct")) {
		return QIcon(structPixmap);
	} else if (kind == QLatin1String("union")) {
		return QIcon(unionPixmap);
	} else if (kind == QLatin1String("fundef")) {
		return QIcon(functionPixmap);
	} else if (kind == QLatin1String("fundecl")) {
		return QIcon(functionDeclPixmap);
	} else if (kind == QLatin1String("vardef")) {
		return QIcon(globalPixmap);
	} else if (kind == QLatin1String("vardecl")) {
		return QIcon(globalPixmap);
	} else if (kind == QLatin1String("natdef")) {
		return QIcon(functionPixmap);
	} else if (kind == QLatin1String("natdecl")) {
		return QIcon(functionDeclPixmap);
	} else {
		return QIcon::fromTheme(QLatin1String("media-playback-start"));
	}
}

bool Outline::decideToShow(const QString& kind) {
	if (kind == QLatin1String("import")) {
		return showImports_->isChecked();
	} else if (kind == QLatin1String("export")) {
		return showExports_->isChecked();
	} else if (kind == QLatin1String("forbid")) {
		return showForbids_->isChecked();
	} else if (kind == QLatin1String("struct") || kind == QLatin1String("union")) {
		return showTypes_->isChecked();
	} else if (kind == QLatin1String("fundef") || kind == QLatin1String("fundecl")) {
		return showFuncs_->isChecked();
	} else if (kind == QLatin1String("vardef") || kind == QLatin1String("vardecl")) {
		return showVars_->isChecked();
	} else if (kind == QLatin1String("natdef") || kind == QLatin1String("natdecl")) {
		return showNatives_->isChecked();
	} else {
		return false;
	}
}

void Outline::update(const QString& output)
{
	tree_->clear();

/* Example of output:
/home/dmitry/area9/flow9/tools/flowc/flowc_helpers.flow:1:1: import tools/common/pathutil
/home/dmitry/area9/flow9/tools/flowc/flowc_helpers.flow:2:1: import math/md5
/home/dmitry/area9/flow9/tools/flowc/flowc_helpers.flow:13:5: export addDesugaredModuleToGlobal
/home/dmitry/area9/flow9/tools/flowc/flowc_helpers.flow:15:5: export addErrorsToTypeEnv
/home/dmitry/area9/flow9/tools/flowc/flowc_helpers.flow:68:1: fundef addDesugaredModuleToGlobal
/home/dmitry/area9/flow9/tools/flowc/flowc_helpers.flow:13:5: fundecl addDesugaredModuleToGlobal
/home/dmitry/area9/flow9/tools/flowc/flowc_helpers.flow:315:1: fundef addErrorsToTypeEnv
/home/dmitry/area9/flow9/tools/flowc/flowc_helpers.flow:15:5: fundecl addErrorsToTypeEnv
*/
	static QRegExp itemLineRegex(QLatin1String("^(.*):(\\d+):(\\d+):\\s*([^\\s]*)\\s([^\\s]*)$"));
	QStringList outLines = output.split(QLatin1Char('\n'));
	for (auto outLine : outLines) {
		if (itemLineRegex.exactMatch(outLine)) {
			QString kind = itemLineRegex.cap(4);
			if (!decideToShow(kind)) {
				continue;
			}
			QTreeWidgetItem* item = new QTreeWidgetItem (tree_);
			item->setIcon (0, selectIcon(kind));
			item->setText (0, itemLineRegex.cap(5)); // Name
			item->setText (1, itemLineRegex.cap(1)); // file
			item->setText (2, itemLineRegex.cap(2)); // line
			item->setText (3, itemLineRegex.cap(3)); // column
		}
	}
}

void Outline::pushShowAll()
{
	showImports_->setChecked(true);
	showForbids_->setChecked(true);
	showExports_->setChecked(true);
	showTypes_->setChecked(true);
	showFuncs_->setChecked(true);
	showVars_->setChecked(true);
	showNatives_->setChecked(true);
	refresh();
}

void Outline::toggleTreeMode() {
	refresh();
}
void Outline::toggleSortingMode() {
	//sortingMode_->setChecked(treeMode_->isChecked());
	refresh();
}

void Outline::slotShowContextMenu (const QPoint& point) {
	popup_->popup(tree_->mapToGlobal(point));
}
void Outline::gotoDefinition(QTreeWidgetItem* item) {
	const QString& locate = item->text(4);
	if (locate == QLatin1String("no")) {
		return;
	}
	QString path = item->text(1);
	const int line = item->text(2).toInt() - 1;
	const int column = item->text(3).toInt() - 1;
	view_->slotGotoLocation(path, line, column);
}

void Outline::setup() {
	refresh_ = popup_->addAction(i18n("Refresh"));
	connect(refresh_, SIGNAL(triggered()), this, SLOT (refresh()));

	popup_->addSeparator();
	showAll_ = popup_->addAction(i18n("Show All"));
	connect(showAll_, SIGNAL(triggered()), this, SLOT (pushShowAll()));

	showImports_ = popup_->addAction(i18n("Show Imports"));
	showImports_->setCheckable(true);
	connect(showImports_, SIGNAL(triggered()), this, SLOT (refresh()));
	showExports_ = popup_->addAction(i18n("Show Exports"));
	showExports_->setCheckable(true);
	connect(showExports_, SIGNAL(triggered()), this, SLOT (refresh()));
	showForbids_ = popup_->addAction(i18n("Show Forbids"));
	showForbids_->setCheckable(true);
	connect(showForbids_, SIGNAL(triggered()), this, SLOT (refresh()));
	showTypes_ = popup_->addAction(i18n("Show Types"));
	showTypes_->setCheckable(true);
	connect(showTypes_, SIGNAL(triggered()), this, SLOT (refresh()));
	showFuncs_ = popup_->addAction(i18n("Show Functions"));
	showFuncs_->setCheckable(true);
	connect(showFuncs_, SIGNAL(triggered()), this, SLOT (refresh()));
	showVars_ = popup_->addAction(i18n("Show Variables"));
	showVars_->setCheckable(true);
	connect(showVars_, SIGNAL(triggered()), this, SLOT (refresh()));
	showNatives_ = popup_->addAction(i18n("Show Natives"));
	showNatives_->setCheckable(true);
	connect(showNatives_, SIGNAL(triggered()), this, SLOT (refresh()));

	/*popup_->addSeparator();
	treeMode_ = popup_->addAction(i18n ("List/Tree Mode"));
	treeMode_->setCheckable(true);
	connect(treeMode_, SIGNAL(triggered()), this, SLOT (toggleTreeMode()));
	sortingMode_ = popup_->addAction(i18n("Enable Sorting"));
	sortingMode_->setCheckable(true);
	connect(sortingMode_, SIGNAL(triggered()), this, SLOT (toggleSortingMode()));*/

	QStringList titles;
	titles << i18nc ("@title:column", "Outline") << i18nc ("@title:column", "Position");
	tree_->setColumnCount (2);
	tree_->setHeaderLabels (titles);
	tree_->setColumnHidden (1, true);
	tree_->setSortingEnabled (false);
	tree_->setRootIsDecorated (0);
	tree_->setContextMenuPolicy (Qt::CustomContextMenu);
	tree_->setIndentation (10);
	tree_->setLayoutDirection (Qt::LeftToRight);

	connect (tree_, SIGNAL (customContextMenuRequested(const QPoint&)), this, SLOT (slotShowContextMenu(const QPoint&)));
	connect (tree_, SIGNAL (itemActivated(QTreeWidgetItem*, int)), this, SLOT (gotoDefinition(QTreeWidgetItem*)));
}

Outline::TreeWidget::TreeWidget(QWidget* parent, Outline* n) :
	QTreeWidget(parent), outline(n) { }

void Outline::TreeWidget::showEvent(QShowEvent *event) {
	outline->refresh();
	QTreeView::showEvent(event);
}

}
