#include "Builder.hpp"

namespace flow {

QString Builder::invocation() const {
	switch (target_.type()) {
	case Target::BYTECODE: return compiler_.invocation();
	case Target::NODEJS:   return compiler_.invocation();
	case Target::JAVA:     return QFileInfo(compiler_.flowdir() + QLatin1String("/bin/build-with-flowc1")).absoluteFilePath();
	case Target::CPP:      return QFileInfo(compiler_.flowdir() + QLatin1String("/bin/build-with-flowc1")).absoluteFilePath();
	case Target::CPP2:     return compiler_.invocation();
	case Target::JAR:      return compiler_.invocation();
	default:               return QString();
	}
}

QStringList Builder::args(const QString& options) const {
	switch (target_.type()) {
	case Target::BYTECODE:
	case Target::NODEJS: {
		QStringList args;
		args << compiler_.includeArgs();
		args << compiler_.debugArgs(target_);
		args << compiler_.targetArgs(target_);
		args << compilerOpts(options);
		args << compiler_.compileArgs(compiler_.flowfile());
		return args;
	}
	case Target::JAVA: {
 		QStringList args;
		args << QLatin1String("type=java");
		args << QLatin1String("compiler=") + compiler_.compiler();
		args << QLatin1String("file=") + compiler_.flowfile();
		args << QLatin1String("flowdir=") + compiler_.flowdir();
		args << builderOpts(options);
 		return args;
 	}
	case Target::JAR: {
		QStringList args;
		args << QLatin1String("jar=") + target().tmpFile();
		args << options.split(QRegExp(QLatin1String("\\s+"))).filter(QRegExp(QLatin1String("^(?!\\s*$).+")));
		args << compiler_.flowfile();
		return args;
	}
	case Target::CPP: {
		QStringList args;
		args << QLatin1String("type=c++");
		args << QLatin1String("compiler=") + compiler_.compiler();
		args << QLatin1String("file=") + compiler_.flowfile();
		args << QLatin1String("flowdir=") + compiler_.flowdir();
		args << builderOpts(options);
		return args;
	}
	case Target::CPP2: {
		QStringList args;
		args << QLatin1String("cpp2=") + compiler_.flowfile();
		args << options.split(QRegExp(QLatin1String("\\s+"))).filter(QRegExp(QLatin1String("^(?!\\s*$).+")));
		args << compiler_.flowfile();
		return args;
	}
	default: return QStringList();
	}
}

QStringList Builder::builderOpts(const QString& options) const {
	QStringList opts;
	opts << QLatin1String("opt_I=") + compiler_.include();
	for (auto opt : compiler_.config().toStdMap()) {
		if (opt.first.startsWith(QLatin1String("opt_"))) {
			opts << opt.first + QLatin1String("=") + opt.second;
		}
	}
	for (auto option : options.split(QRegExp(QLatin1String("\\s+")))) {
		QString prefixedOption = QLatin1String("opt_") + option;
		QString optionName = prefixedOption.mid(0, prefixedOption.indexOf(QLatin1Char('=')));
		if (!option.isEmpty() && !compiler_.config().contains(optionName)) {
			opts << prefixedOption;
		}
	}
	return opts;
}

QStringList Builder::compilerOpts(const QString& options) const {
	QStringList opts;
	for (auto opt : compiler_.config().toStdMap()) {
		if (opt.first.startsWith(QLatin1String("opt_"))) {
			opts << opt.first.mid(4) + QLatin1String("=") + opt.second;
		}
	}
	for (auto option : options.split(QRegExp(QLatin1String("\\s+")))) {
		QString optionName = option.mid(0, option.indexOf(QLatin1Char('=')));
		if (!option.isEmpty() && !compiler_.config().contains(QLatin1String("opt_") + optionName)) {
			opts << option;
		}
	}
	return opts;
}

}
