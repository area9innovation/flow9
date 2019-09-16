#include <QTextStream>

#include <vector>
#include "peglib/peglib.h"

#include "MiParser.hpp"

namespace flow {

/*
MI Output grammar:
result → variable "=" value
variable → string
value → const | tuple | list
const → c-string
tuple → "{}" | "{" result ( "," result )* "}"
list → "[]" | "[" value ( "," value )* "]" | "[" result ( "," result )* "]"
 */

class MiParser {
	static const char* mi_result_grammar() {
		return R"(
			# MI output result grammar
		
			RESULT    <- VARIABLE '=' VALUE
			VALUE     <- SCALAR / TUPLE / VAL_LIST / RES_LIST 
			TUPLE     <- '{' (RESULT (',' RESULT)*)? '}'
			RES_LIST  <- '[' (RESULT (',' RESULT)*)? ']' 
			VAL_LIST  <- '[' (VALUE  (',' VALUE)*)?  ']'
			VARIABLE  <- < (!'=' .)+ >
			SCALAR    <- '"' CHAR * '"'
			CHAR      <- '\\"' / < (!'"' .) >

			%whitespace <- [ \t\r\n]*
		)";
	}

public:
	MiParser() : parser(mi_result_grammar()) {
		if (!parser) {
			QTextStream(stderr) << "MI output result grammar is not correct\n";
			exit(1);
		}
		parser["RESULT"] = [](const peg::SemanticValues& sv) {
			return MiResult(sv[0].get<QString>(), sv[1].get<MiValue*>(), QString::fromStdString(sv.token()));
		};
		parser["VALUE"] = [](const peg::SemanticValues& sv) {
			switch (sv.choice()) {
			case 0: return new MiValue(sv[0].get<MiScalar*>());
			case 1: return new MiValue(sv[0].get<MiTuple*>());
			case 2: return new MiValue(sv[0].get<MiValList*>());
			case 3: return new MiValue(sv[0].get<MiResList*>());
			default: throw std::out_of_range("impossible case");
			}
		};
		parser["TUPLE"] = [](const peg::SemanticValues& sv) {
			return new MiTuple{QVector<MiResult>::fromStdVector(sv.transform<MiResult>()), QString::fromStdString(sv.token())};
		};
		parser["RES_LIST"] = [](const peg::SemanticValues& sv) {
			return new MiResList{QVector<MiResult>::fromStdVector(sv.transform<MiResult>()), QString::fromStdString(sv.token())};
		};
		parser["VAL_LIST"] = [](const peg::SemanticValues& sv) {
			return new MiValList{QVector<MiValue*>::fromStdVector(sv.transform<MiValue*>()), QString::fromStdString(sv.token())};
		};
		parser["VARIABLE"] = [](const peg::SemanticValues& sv) {
			return QString(QLatin1String(sv.token().c_str()));
		};
		parser["SCALAR"] = [](const peg::SemanticValues& sv) {
			return new MiScalar{QString::fromStdString(sv.token())};
		};
	}
	MiResult parse(const QString& str) {
		MiResult ret;
		if (!parser.parse<MiResult>(str.toStdString().c_str(), ret)) {
			QTextStream(stdout) << "Error parsing result: " << str << "\n";
		}
		return ret;
	}

private:
	peg::parser parser;
};

MiResult mi_parse(const QString& str) {
	static MiParser parser;
	return parser.parse(str);
}

}

