#include <QTextStream>
#include <QFileDialog>
#include <QRegExp>

#include <KConfigGroup>
#include <KLocalizedString>
#include <KMessageBox>

#include "common.hpp"
#include "FlowConfig.hpp"

namespace flow {

FlowConfig::FlowConfig(QWidget* parent) : QObject(parent), widget(new QWidget(parent)) {
    ui.setupUi(widget);
    connect(ui.addLaunchButton, SIGNAL(clicked()), this, SLOT(slotAddLaunch()));
    connect(ui.removeLaunchButton, SIGNAL(clicked()), this, SLOT(slotRemoveLaunch()));
    connect(ui.setFlowdirButton, SIGNAL(clicked()), this, SLOT(slotSetFlowDir()));
    connect(ui.setServerDirButton, SIGNAL(clicked()), this, SLOT(slotSetServerDir()));
    connect(ui.serverPortLineEdit, SIGNAL(textEdited(QString)), this, SLOT(slotSetServerPort(QString)));
    connect(ui.launchTableWidget, SIGNAL(itemClicked(QTableWidgetItem*)), this, SLOT(slotSetupItem(QTableWidgetItem*)));
}

FlowConfig::~FlowConfig() {
}

ProgTimestamps FlowConfig::progTimestampsCurrent(int row) const {
	QString prog = ui.launchTableWidget->item(row, 1)->text();
	QString confFile = findConfig(prog);
	ConfigFile conf = parseConfig(confFile);
	QString confDir = QFileInfo(confFile).dir().path();
	QStringList includes =
		conf.contains(QLatin1String("include")) ?
		conf[QLatin1String("include")].split(QLatin1Char(',')) :
		QStringList();
	includes << ui.flowdirLineEdit->text() + QLatin1String("/lib");
	return progTimestamps(prog, confDir, includes);
}

ProgTimestamps FlowConfig::progTimestampsSaved(int row) const {
	return progTimestamps_[row];
}

void FlowConfig::slotSetFlowDir() {
	QString flowdir = QFileDialog::getExistingDirectory(widget, i18n("Flow directory"), ui.flowdirLineEdit->text());
	if (!flowdir.isEmpty()) {
		ui.flowdirLineEdit->setText(flowdir);
	}
}

void FlowConfig::slotSetServerDir() {
	QString serverDir = QFileDialog::getExistingDirectory(widget, i18n("Server directory"), ui.serverDirLineEdit->text());
	if (!serverDir.isEmpty()) {
		ui.serverDirLineEdit->setText(serverDir);
	}
}

void FlowConfig::slotSetServerPort(const QString& port) {
	QRegExp portRegExp(QLatin1String("\\d*"));  // a digit (\d), zero or more times (*)
	if (!portRegExp.exactMatch(port)) {
		KMessageBox::sorry(0, i18n("Port is a decimal numeric value"));
		ui.serverPortLineEdit->setText(QLatin1String("10001"));
	}
}

void FlowConfig::slotSaveProgTimestamps(int row) {
	progTimestamps_[row] = progTimestampsCurrent(row);
}

void FlowConfig::slotAddLaunch() {
	int currRow = ui.launchTableWidget->currentRow();
	int rowInd = currRow == -1 ? ui.launchTableWidget->rowCount() : currRow + 1;
	ui.launchTableWidget->insertRow(rowInd);
	QString program = QFileDialog::getOpenFileName(widget, i18n("Flow file"), QString());

	// Flow file and directory should be setup via file/dir dialog,
	// so they are not directly editable
	ui.launchTableWidget->setItem(rowInd, 0, new QTableWidgetItem(QFileInfo(program).baseName()));
	ui.launchTableWidget->setItem(rowInd, 1, setNotEditable(new QTableWidgetItem(program)));
	ui.launchTableWidget->setItem(rowInd, 2, setNotEditable(new QTableWidgetItem(QFileInfo(program).dir().path())));
	ui.launchTableWidget->setItem(rowInd, 3, new QTableWidgetItem(QLatin1String("bc")));
	ui.launchTableWidget->setItem(rowInd, 4, new QTableWidgetItem(QLatin1String("timephases=1")));
	ui.launchTableWidget->setItem(rowInd, 5, new QTableWidgetItem());
	ui.launchTableWidget->setItem(rowInd, 6, new QTableWidgetItem());
	ui.removeLaunchButton->setEnabled(true);

	slotSaveProgTimestamps(rowInd);

	emit launchConfigsChanged();
}

void FlowConfig::slotRemoveLaunch() {
	int currRow = ui.launchTableWidget->currentRow();
	progTimestamps_.remove(currRow);

	ui.launchTableWidget->removeRow(currRow == -1 ? ui.launchTableWidget->rowCount() : currRow);
	if (ui.launchTableWidget->rowCount() == 0) {
		ui.removeLaunchButton->setEnabled(false);
	}

	emit launchConfigsChanged();
}

void FlowConfig::slotSetupItem(QTableWidgetItem* item) {
	if (item->column() == 1) {
		int row = item->row();
		QString dir = ui.launchTableWidget->item(row, 2)->text();
		QString program = QFileDialog::getOpenFileName(widget, i18n("Flow file"), dir, i18n("Flow sources (*.flow)"));
		if (!program.isEmpty()) {
			QFileInfo progInfo(program);
			item->setText(program);
			QTableWidgetItem* nameItem = ui.launchTableWidget->item(row, 0);
			if (nameItem && nameItem->text().isEmpty()) {
				QFileInfo progInfo(program);
				nameItem->setText(progInfo.baseName());
			}
		}
	} else if (item->column() == 2) {
		QString dir = QFileDialog::getExistingDirectory(widget, i18n("Working directory"));
		if (!dir.isEmpty()) {
			item->setText(dir);
		}
	}
}

void FlowConfig::readConfig(const KConfigGroup& config) {
	ui.flowdirLineEdit->setText(config.readEntry(QLatin1String("Flow directory"), QString()));
	ui.serverDirLineEdit->setText(config.readEntry(QLatin1String("Server directory"), QString()));
	ui.serverAutostartCheckBox->setCheckState(
		config.readEntry(QLatin1String("Server autostart"), QString()) == QLatin1String("true") ? Qt::Checked : Qt::Unchecked
	);
	for (int row = 0; row < config.readEntry(QLatin1String("Launch configs number"), 0); ++ row) {
		QString name = config.readEntry(QStringLiteral("Launch config %1 name").arg(row), QString());
		QString prog = config.readEntry(QStringLiteral("Launch config %1 program").arg(row), QString());
		QString dir  = config.readEntry(QStringLiteral("Launch config %1 directory").arg(row), QString());
		QString targ = config.readEntry(QStringLiteral("Launch config %1 target").arg(row), QString());
		QString opts = config.readEntry(QStringLiteral("Launch config %1 options").arg(row), QString());
		QString progArgs = config.readEntry(QStringLiteral("Launch config %1 program arguments").arg(row), QString());
		QString execArgs = config.readEntry(QStringLiteral("Launch config %1 executor arguments").arg(row), QString());
		progTimestamps_[row] = progTimestampsFromBinary(config.readEntry(QStringLiteral("Launch config %1 timestamps").arg(row), QByteArray()));

		ui.launchTableWidget->insertRow(row);

		QTableWidgetItem* nameItem = new QTableWidgetItem(name);
		QTableWidgetItem* progItem = new QTableWidgetItem(prog);
		QTableWidgetItem* dirItem  = new QTableWidgetItem(dir);
		QTableWidgetItem* targItem = new QTableWidgetItem(targ);
		QTableWidgetItem* optsItem = new QTableWidgetItem(opts);
		QTableWidgetItem* progArgsItem = new QTableWidgetItem(progArgs);
		QTableWidgetItem* execArgsItem = new QTableWidgetItem(execArgs);

		Qt::ItemFlags flags = progItem->flags();
		progItem->setFlags(flags & ~Qt::ItemIsEditable);
		dirItem->setFlags(flags & ~Qt::ItemIsEditable);

		ui.launchTableWidget->setItem(row, 0, nameItem);
		ui.launchTableWidget->setItem(row, 1, progItem);
		ui.launchTableWidget->setItem(row, 2, dirItem);
		ui.launchTableWidget->setItem(row, 3, targItem);
		ui.launchTableWidget->setItem(row, 4, optsItem);
		ui.launchTableWidget->setItem(row, 5, progArgsItem);
		ui.launchTableWidget->setItem(row, 6, execArgsItem);
	}
}

void FlowConfig::writeConfig(KConfigGroup& config) {
    config.writeEntry(QLatin1String("Flow directory"), ui.flowdirLineEdit->text());
    config.writeEntry(QLatin1String("Server directory"), ui.serverDirLineEdit->text());
    config.writeEntry(QLatin1String("Server autostart"),
    	ui.serverAutostartCheckBox->checkState() == Qt::Checked ? "true" : "false"
    );
    config.writeEntry(QLatin1String("Launch configs number"), ui.launchTableWidget->rowCount());
    for (int row = 0; row < ui.launchTableWidget->rowCount(); ++row) {
    	config.writeEntry(QStringLiteral("Launch config %1 name").arg(row),      ui.launchTableWidget->item(row, 0)->text());
    	config.writeEntry(QStringLiteral("Launch config %1 program").arg(row),   ui.launchTableWidget->item(row, 1)->text());
    	config.writeEntry(QStringLiteral("Launch config %1 directory").arg(row), ui.launchTableWidget->item(row, 2)->text());
    	config.writeEntry(QStringLiteral("Launch config %1 target").arg(row),    ui.launchTableWidget->item(row, 3)->text());
    	config.writeEntry(QStringLiteral("Launch config %1 options").arg(row),   ui.launchTableWidget->item(row, 4)->text());
    	config.writeEntry(QStringLiteral("Launch config %1 program arguments").arg(row), ui.launchTableWidget->item(row, 5)->text());
    	config.writeEntry(QStringLiteral("Launch config %1 executor arguments").arg(row), ui.launchTableWidget->item(row, 6)->text());
    	config.writeEntry(QStringLiteral("Launch config %1 timestamps").arg(row), progTimestampsToBinary(progTimestamps_[row]));
    }
}

void FlowConfig::eraseConfig(KConfigGroup& config) {
	for (int i = 0; i < config.readEntry(QLatin1String("Launch configs number"), 0); ++ i) {
		config.deleteEntry(QStringLiteral("Launch config %1 name").arg(i));
		config.deleteEntry(QStringLiteral("Launch config %1 program").arg(i));
		config.deleteEntry(QStringLiteral("Launch config %1 directory").arg(i));
		config.deleteEntry(QStringLiteral("Launch config %1 target").arg(i));
		config.deleteEntry(QStringLiteral("Launch config %1 options").arg(i));
		config.deleteEntry(QStringLiteral("Launch config %1 program arguments").arg(i));
		config.deleteEntry(QStringLiteral("Launch config %1 executor arguments").arg(i));
		config.deleteEntry(QStringLiteral("Launch config %1 timestamps").arg(i));
	}
	config.deleteEntry(QLatin1String("Launch configs number"));
	config.deleteEntry(QLatin1String("Flow directory"));
	config.deleteEntry(QLatin1String("Server directory"));
	config.deleteEntry(QLatin1String("Server autostart"));
}


}
