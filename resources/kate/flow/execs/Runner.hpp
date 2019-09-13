#pragma once

#include <QFileInfo>
#include "ui_FlowConfig.h"
#include "common.hpp"

namespace flow {

struct Runner {
	Runner(const Ui::FlowConfig& ui, QString prog, QString targ, QString flowdir);
	enum Type { BYTECODE, OCAML, JAVA, CPP, CPP2, NODEJS, DEFAULT = BYTECODE };
	Type type() const { return type_; }
	QString invocation() const;
	QString target() const;
	QString debug() const;
	QString flowdir() const { return flowdir_; }
	//QStringList targetArgs() const;
	QString extension() const;
	QStringList args(QString execArgs, QString progArgs) const;
	const Ui::FlowConfig& configUi() const { return configUi_; }
private:
	const Ui::FlowConfig& configUi_;
	Type    type_;
	QString target_;
	QFileInfo info_;
	QString flowdir_;
};

}
