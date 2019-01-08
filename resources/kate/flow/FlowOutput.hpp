#pragma once

#include <QWidget>

#include "ui_FlowOutput.h"

namespace flow {

class FlowOutput : public QObject {
	Q_OBJECT
public:
	FlowOutput(QWidget*);
	~FlowOutput();
	Ui::FlowOutput ui;
};

}
