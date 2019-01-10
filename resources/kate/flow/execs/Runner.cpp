#include <QDir>

#include "Runner.hpp"

namespace flow {

Runner::Runner(QString prog, QString targ, QString flowdir) :
	type_(DEFAULT), target_(targ), info_(prog), flowdir_(flowdir) {
	if (targ == QLatin1String("js")) {
		type_ = NODEJS;
	} else if (targ == QLatin1String("bytecode") || targ == QLatin1String("bc")) {
		type_ = BYTECODE;
	} else if (targ == QLatin1String("ml")) {
		type_ = OCAML;
	} else if (targ == QLatin1String("java")) {
		type_ = JAVA;
	} else if (targ == QLatin1String("cpp")) {
		type_ = CPP;
	}
}

QString Runner::invocation() const {
	switch (type_) {
	case BYTECODE: return QFileInfo(flowdir_ + QLatin1String("/bin/flowcpp")).absoluteFilePath();
	case JAVA:     return QLatin1String("java");
	case NODEJS:   return QLatin1String("node");
	case CPP:      return target();
	default:       return QString(); // TODO: add other runners
	}
}

QString Runner::extension() const {
	switch (type_) {
	case BYTECODE: return QLatin1String(".bytecode");
	case NODEJS:   return QLatin1String(".js");
	case OCAML:    return QLatin1String(".ml");
	case JAVA:     return QLatin1String(".jar");
	case CPP:      return QLatin1String(".exe");
	default:       return QLatin1String();
	}
}

QString Runner::target() const {
	return info_.dir().path() + QDir::separator() + info_.baseName() + extension();
}

QString Runner::debug() const {
	return info_.baseName() + QLatin1String(".debug");
}

QStringList Runner::args(QString execArgs, QString progArgs) const {
	switch (type_) {
	case Runner::BYTECODE: {
		QStringList args;
		args << execArgs.split(QRegExp(QLatin1String("\\s+"))).filter(QRegExp(QLatin1String("^(?!\\s*$).+")));
		args << info_.dir().path() + QDir::separator() + info_.baseName() + QLatin1String(".bytecode");
		args << info_.dir().path() + QDir::separator() + info_.baseName() + QLatin1String(".debug");
		QStringList launchArgs = progArgs.split(QRegExp(QLatin1String("\\s+"))).filter(QRegExp(QLatin1String("^(?!\\s*$).+")));
		if (!launchArgs.isEmpty()) {
			args << QLatin1String("--");
			args << launchArgs;
		}
		return args;
	}
	case Runner::JAVA: {
		QStringList args;
		args << execArgs.split(QRegExp(QLatin1String("\\s+"))).filter(QRegExp(QLatin1String("^(?!\\s*$).+")));
		args << QLatin1String("-jar");
		args << target();
		args << progArgs.split(QRegExp(QLatin1String("\\s+"))).filter(QRegExp(QLatin1String("^(?!\\s*$).+")));
		return args;
	}
	case Runner::NODEJS: {
		QStringList args;
		args << execArgs.split(QRegExp(QLatin1String("\\s+"))).filter(QRegExp(QLatin1String("^(?!\\s*$).+")));
		args << target();
		args << progArgs.split(QRegExp(QLatin1String("\\s+"))).filter(QRegExp(QLatin1String("^(?!\\s*$).+")));
		return args;
	}
	case Runner::CPP: {
		QStringList args;
		args << execArgs.split(QRegExp(QLatin1String("\\s+"))).filter(QRegExp(QLatin1String("^(?!\\s*$).+")));
		args << progArgs.split(QRegExp(QLatin1String("\\s+"))).filter(QRegExp(QLatin1String("^(?!\\s*$).+")));
		return args;
	}
	default: return QStringList();
	}
}

}
