#pragma once

#include <QWidget>
#include <KConfigGroup>

#include "common.hpp"
#include "DebugView.hpp"
#include "Plugin.hpp"

#include "ui_FlowConfig.h"

namespace flow {

class FlowConfig : public QObject {
	Q_OBJECT
public:
	FlowConfig(QWidget*);
	virtual ~FlowConfig();

	void readConfig(const KConfigGroup& config);
    void writeConfig(KConfigGroup& config);
    void eraseConfig(KConfigGroup& config);
    bool progTimestampsChanged(int row) const {
    	return flow::progTimestampsChanged(progTimestampsCurrent(row), progTimestampsSaved(row));
    }
    ProgTimestamps progTimestampsCurrent(int row) const;
    ProgTimestamps progTimestampsSaved(int row) const;

	Ui::FlowConfig ui;

public Q_SLOTS:
	void slotSaveProgTimestamps(int row);

Q_SIGNALS:
	void launchConfigsChanged();

private Q_SLOTS:
	void slotSetFlowDir();
	void slotSetServerDir();
	void slotSetServerPort(const QString&);
	void slotAddLaunch();
	void slotRemoveLaunch();
	void slotSetupItem(QTableWidgetItem*);

private:
	QWidget* widget;
	QMap<int, ProgTimestamps> progTimestamps_;
};

}
