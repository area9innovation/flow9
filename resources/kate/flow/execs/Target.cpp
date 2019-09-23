#include <QDir>
#include "Target.hpp"

namespace flow {

Target::Target(const Ui::FlowConfig& ui, QString prog, QString targ, QString flowdir, QString outdir) :
	configUi_(ui), type_(DEFAULT), info_(prog), flowdir_(flowdir), outdir_(outdir), uniq_ind(0) {

	if (!QDir(flowdir).exists()) {
		throw std::runtime_error("directory '" + flowdir.toStdString() + "' doesn't exist");
	}
	if (targ == QLatin1String("js")) {
		type_ = NODEJS;
	} else if (targ == QLatin1String("bytecode") || targ == QLatin1String("bc")) {
		type_ = BYTECODE;
	} else if (targ == QLatin1String("ml")) {
		type_ = OCAML;
	} else if (targ == QLatin1String("java")) {
		type_ = JAVA;
	} else if (targ == QLatin1String("jar")) {
		type_ = JAR;
	} else if (targ == QLatin1String("cpp")) {
		type_ = CPP;
	} else if (targ == QLatin1String("cpp2")) {
		type_ = CPP2;
	}
	while (QFileInfo(tmpPath()).isFile()) ++uniq_ind;
	if (QFileInfo(tmpPath()).isFile()) {
		throw std::runtime_error("tmp file '" + tmpPath().toStdString() + "' already exists");
	}
}

QString Target::extension() const {
	switch (type_) {
	case BYTECODE: return QLatin1String(".bytecode");
	case NODEJS:   return QLatin1String(".js");
	case OCAML:    return QLatin1String(".ml");
	case JAVA:     return QLatin1String(".jar");
	case JAR:      return QLatin1String(".jar");
	case CPP:      return QLatin1String(".exe");
	case CPP2:     return QLatin1String(".exe");
	default:       return QLatin1String();
	}
}

QString Target::file() const {
	return info_.baseName() + extension();
}

QString Target::tmpFile() const {
	QString postfix = (uniq_ind == 0) ? QString() : QLatin1String("_") + QString::number(uniq_ind);
	return info_.baseName() + postfix + extension();
}

QString Target::path() const {
	return info_.dir().path() + QDir::separator() + info_.baseName() + extension();
}

QString Target::tmpPath() const {
	QString postfix = (uniq_ind == 0) ? QString() : QLatin1String("_") + QString::number(uniq_ind);
	return info_.dir().path() + QDir::separator() + info_.baseName() + postfix + extension();
}

QString Target::debug() const {
	return info_.baseName() + QLatin1String(".debug");
}

bool Target::exists() const {
	return QFileInfo(path()).isFile();
}

}
