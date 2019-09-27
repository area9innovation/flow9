#include <QTextStream>

#include <vector>
#include "peglib/peglib.h"

#include "common.hpp"
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
			CHAR      <- '\\"' / (!'"' .)

			%whitespace <- [ \t\r\n]*
		)";
	}

public:
	MiParser() : parser(mi_result_grammar()) {
		if (!parser) {
			QTextStream(stderr) << "MI output result grammar is not correct\n";
			exit(1);
		}
		parser.log = [](size_t ln, size_t col, const std::string& err_msg) {
			QTextStream(stderr) << QString::fromStdString(err_msg) << ", line: " << ln << ", col: " << col << endl;
		};
		parser["RESULT"] = [](const peg::SemanticValues& sv) {
			QString var = sv[0].get<QString>();
			MiValue* val = sv[1].get<MiValue*>();
			return MiResult(var, val, QString::fromStdString(sv.token()));
		};
		parser["VALUE"] = [](const peg::SemanticValues& sv) {
			switch (sv.choice()) {
			case 0: return new MiValue(sv[0].get<MiScalar*>());  break;
			case 1: return new MiValue(sv[0].get<MiTuple*>());   break;
			case 2: return new MiValue(sv[0].get<MiValList*>()); break;
			case 3: return new MiValue(sv[0].get<MiResList*>()); break;
			default: throw std::out_of_range("impossible case");
			}
		};
		parser["TUPLE"] = [](const peg::SemanticValues& sv) {
			auto tuple = sv.transform<MiResult>();
			return new MiTuple{QVector<MiResult>::fromStdVector(tuple), QString::fromStdString(sv.token())};
		};
		parser["RES_LIST"] = [](const peg::SemanticValues& sv) {
			auto list = sv.transform<MiResult>();
			return new MiResList{QVector<MiResult>::fromStdVector(list), QString::fromStdString(sv.token())};
		};
		parser["VAL_LIST"] = [](const peg::SemanticValues& sv) {
			auto list = sv.transform<MiValue*>();
			return new MiValList{QVector<MiValue*>::fromStdVector(list), QString::fromStdString(sv.token())};
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
		parser.log = [&str](size_t ln, size_t col, const std::string& err_msg) {
			QTextStream(stdout) << "Mi fdb output " << QString::fromStdString(err_msg) << ", line: " << ln << ", col: " << col << endl;
			QTextStream(stdout) << str.mid(0, 64) << endl;
			QTextStream(stdout) << str.mid(col - 32, 64) << endl;
		};
		parser.parse<MiResult>(str.toStdString().c_str(), ret);
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

