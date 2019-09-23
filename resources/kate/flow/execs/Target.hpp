#pragma once

#include <QFileInfo>
#include "ui_FlowConfig.h"
#include "common.hpp"

namespace flow {

struct Target {
	Target(const Ui::FlowConfig& ui, QString prog, QString targ, QString flowdir, QString outdir);
	enum Type { BYTECODE, OCAML, JAVA, JAR, CPP, CPP2, NODEJS, DEFAULT = BYTECODE };
	Type type() const { return type_; }
	QString file() const;
	QString tmpFile() const; // In case target file already exists
	QString path() const;
	QString tmpPath() const; // In case target file already exists

	QString debug() const;
	QString flowdir() const { return flowdir_; }
	QString outdir() const { return outdir_; }
	const QFileInfo& info() const { return info_; }
	QString extension() const;
	const Ui::FlowConfig& configUi() const { return configUi_; }
	bool exists() const;
	bool useTmpFile() const { return uniq_ind > 0; }
private:
	const Ui::FlowConfig& configUi_;
	Type    type_;
	QFileInfo info_;
	QString flowdir_;
	QString outdir_;
	int uniq_ind;
};

}
