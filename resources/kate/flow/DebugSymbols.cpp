#include <QFile>
#include <QTextStream>
#include <tuple>
#include "peglib/peglib.h"

#include "DebugSymbols.hpp"

namespace flow {

using std::pair;

class StructDefParser {
	static const char* mi_result_grammar() {
		return R"(
			# Struct definition parser
		
			STRUCT     <- 'struct' STR_NAME '(' FIELDS ');'
			STR_NAME   <- NAME STR_PARAMS?
			FIELDS     <- (FIELD (',' FIELD)*)?
			FIELD      <- NAME ':' TYPE
			TYPE       <- REF / ARRAY / FUNC / POLYMORPH / NAME 
			REF        <- 'ref' TYPE
			ARRAY      <- '[' TYPE ']' 
			POLYMORPH  <- NAME '<' (TYPE (',' TYPE)*)? '>'
			FUNC       <- '(' FUN_ARGS ')' '->' TYPE
			FUN_ARGS   <- (FUN_ARG (',' FUN_ARG)*)?
			FUN_ARG    <- NAME ':' TYPE / TYPE
			STR_PARAMS <- '<' (QUESTIONS (',' QUESTIONS)*)? '>'
			QUESTIONS  <- '?'+
			NAME       <- < (![:()<>,\[\]] .)+ >

			%whitespace <- [ \t\r\n]*
		)";
	}

public:
	StructDefParser() : parser(mi_result_grammar()) {
		if (!parser) {
			QTextStream(stderr) << "Struct definition grammar is not correct\n";
			exit(1);
		}
		parser["STRUCT"] = [](const peg::SemanticValues& sv) {
			auto p = sv[0].get<pair<QString, QString>>();
			return StructDef{p.first, p.second, sv[1].get<QVector<FieldDef>>()};
		};
		parser["STR_NAME"] = [](const peg::SemanticValues& sv) {
			return pair<QString, QString>(sv[0].get<QString>(), QString::fromStdString(sv.token()));
		};
		parser["FIELDS"] = [](const peg::SemanticValues& sv) {
			return QVector<FieldDef>::fromStdVector(sv.transform<FieldDef>());
		};
		parser["FIELD"] = [](const peg::SemanticValues& sv) {
			return FieldDef{sv[0].get<QString>(), sv[1].get<QString>()};
		};
		parser["TYPE"] = [](const peg::SemanticValues& sv) {
			return QString::fromStdString(sv.token());
		};
		parser["NAME"] = [](const peg::SemanticValues& sv) {
			return QString::fromStdString(sv.token());
		};
	}
	StructDef parse(const QString& str) {
		StructDef ret;
		if (!parser.parse<StructDef>(str.toStdString().c_str(), ret)) {
			QTextStream(stdout) << "Error parsing struct definition: " << str << "\n";
		}
		return ret;
	}

private:
	peg::parser parser;
};

StructDef struct_def_parse(const QString& str) {
	static StructDefParser parser;
	return parser.parse(str);
}

StructDef DebugSymbols::findDef(QString name) const {
	StructDef ret = structDefs.value(name, StructDef());
	if (!ret) {
		QTextStream(stdout) << "Cannot find struct '" << name << "' definition\n";
	}
	return ret;
}

void DebugSymbols::loadIdFile(QString name) {
	structDefs.clear();
	QFile file(name);
	if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return;
	}
    while (!file.atEnd()) {
        QString line = QString::fromLatin1(file.readLine());
        if (line.startsWith(QLatin1String("struct"))) {
			StructDef structDef = struct_def_parse(line);
        	structDefs[structDef.baseName] = structDef;
        }
    }
}

}
