#include <QDir>
#include "Runner.hpp"

namespace flow {

Runner::Runner(const Ui::FlowConfig& ui, QString prog, QString targ, QString flowdir, QString outdir) :
	target_(ui, prog, targ, flowdir, outdir) {
	if (!target().exists()) {
		throw std::runtime_error("program '" + prog.toStdString() + "' doesn't exist");
	}
}

QString Runner::invocation() const {
	switch (target().type()) {
	case Target::BYTECODE: return QFileInfo(target().flowdir() + QLatin1String("/bin/flowcpp")).absoluteFilePath();
	case Target::JAVA:     return QLatin1String("java");
	case Target::JAR:      return QLatin1String("java");
	case Target::NODEJS:   return QLatin1String("node");
	case Target::CPP:      return target().file();
	case Target::CPP2:     return target().file();
	default:       return QString(); // TODO: add other runners
	}
}

QStringList Runner::args(QString execArgs, QString progArgs) const {
	switch (target().type()) {
	case Target::BYTECODE: {
		QStringList args;
		args << execArgs.split(QRegExp(QLatin1String("\\s+"))).filter(QRegExp(QLatin1String("^(?!\\s*$).+")));
		args << target().info().dir().path() + QDir::separator() + target().info().baseName() + QLatin1String(".bytecode");
		args << target().info().dir().path() + QDir::separator() + target().info().baseName() + QLatin1String(".debug");
		QStringList launchArgs = progArgs.split(QRegExp(QLatin1String("\\s+"))).filter(QRegExp(QLatin1String("^(?!\\s*$).+")));
		if (!launchArgs.isEmpty()) {
			args << QLatin1String("--");
			args << launchArgs;
		}
		return args;
	}
	case Target::JAVA: {
		QStringList args;
		args << execArgs.split(QRegExp(QLatin1String("\\s+"))).filter(QRegExp(QLatin1String("^(?!\\s*$).+")));
		args << QLatin1String("-jar");
		args << target().file();
		args << progArgs.split(QRegExp(QLatin1String("\\s+"))).filter(QRegExp(QLatin1String("^(?!\\s*$).+")));
		return args;
	}
	case Target::JAR: {
		QStringList args;
		args << execArgs.split(QRegExp(QLatin1String("\\s+"))).filter(QRegExp(QLatin1String("^(?!\\s*$).+")));
		args << QLatin1String("-jar");
		args << target().file();
		args << progArgs.split(QRegExp(QLatin1String("\\s+"))).filter(QRegExp(QLatin1String("^(?!\\s*$).+")));
		return args;
	}
	case Target::NODEJS: {
		QStringList args;
		args << execArgs.split(QRegExp(QLatin1String("\\s+"))).filter(QRegExp(QLatin1String("^(?!\\s*$).+")));
		args << target().file();
		args << progArgs.split(QRegExp(QLatin1String("\\s+"))).filter(QRegExp(QLatin1String("^(?!\\s*$).+")));
		return args;
	}
	case Target::CPP: {
		QStringList args;
		args << execArgs.split(QRegExp(QLatin1String("\\s+"))).filter(QRegExp(QLatin1String("^(?!\\s*$).+")));
		args << progArgs.split(QRegExp(QLatin1String("\\s+"))).filter(QRegExp(QLatin1String("^(?!\\s*$).+")));
		return args;
	}
	case Target::CPP2: {
		QStringList args;
		args << execArgs.split(QRegExp(QLatin1String("\\s+"))).filter(QRegExp(QLatin1String("^(?!\\s*$).+")));
		args << progArgs.split(QRegExp(QLatin1String("\\s+"))).filter(QRegExp(QLatin1String("^(?!\\s*$).+")));
		return args;
	}
	default: return QStringList();
	}
}

}
