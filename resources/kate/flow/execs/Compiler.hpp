#pragma once

#include <QDir>
#include "ui_FlowConfig.h"
#include "Runner.hpp"

namespace flow {

struct Compiler {
	Compiler(const Ui::FlowConfig& ui, QString file, QString flowdir);
	enum Type { FLOW, FLOWC1, FLOWC2, DEFAULT = FLOW };
	Type type() const { return type_; }
	QStringList includeArgs() const;
	QStringList debugArgs(Runner) const;
	QStringList targetArgs(Runner) const;
	QStringList compileArgs(QString) const;
	QString invocation() const;
	QString flowfile() const { return file_; }
	QString flowdir() const { return flowdir_; }
	QString confdir() const { return confFile_.dir().path(); }
	QFileInfo confFile() const { return confFile_; }
	QString include() const { return include_; }
	QString compiler() const;
	const ConfigFile& config() const { return config_; }
	const Ui::FlowConfig configUi() const { return configUi_; }
private:
	const Ui::FlowConfig& configUi_;
	Type    type_;
	QString file_;
	QString include_;
	QString flowdir_;
	QFileInfo confFile_;
	ConfigFile config_;
};

}
