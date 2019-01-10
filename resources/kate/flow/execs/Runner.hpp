#pragma once

#include <QFileInfo>
#include "common.hpp"

namespace flow {

struct Runner {
	Runner(QString prog, QString targ, QString flowdir);
	enum Type { BYTECODE, OCAML, JAVA, CPP, NODEJS, DEFAULT = BYTECODE };
	Type type() const { return type_; }
	QString invocation() const;
	QString target() const;
	QString debug() const;
	QString flowdir() const { return flowdir_; }
	//QStringList targetArgs() const;
	QString extension() const;
	QStringList args(QString execArgs, QString progArgs) const;
private:
	Type    type_;
	QString target_;
	QFileInfo info_;
	QString flowdir_;
};

}
