#include <QTextStream>
#include <QRegExp>
#include <tuple>
#include "peglib/peglib.h"

#include "FlowValueParser.hpp"

namespace flow {

QString FlowValue::type() const {
	switch (kind_) {
	case SCALAR:  return val_.scalar_->type();
	case STRUCT:  return val_.struct_->type();
	case ARRAY:   return val_.array_->type();
	case REF:     return val_.ref_->type();
	case CLOSURE: return val_.closure_->type();
	case NATIVE:  return val_.native_->type();
	default:      return QLatin1String("?");
	}
}

QString FlowValue::value() const {
	switch (kind_) {
	case SCALAR:  return val_.scalar_->value_;
	case STRUCT:  return val_.struct_->value_;
	case ARRAY:   return val_.array_->value_;
	case REF:     return val_.ref_->value_;
	case CLOSURE: return val_.closure_->value_;
	case NATIVE:  return val_.native_->value_;
	default:      return QLatin1String("?");
	}
}

QString FlowScalar::type() const {
	static QRegExp stringExp(QLatin1String("\"(\\.|[^\"])*\""));
	static QRegExp integerExp(QLatin1String("-?\\d+"));
	static QRegExp doubleExp(QLatin1String("-?\\d+\\.\\d*"));
	static QRegExp boolExp(QLatin1String("true|false"));
	static QRegExp voidExp(QLatin1String("void"));
	if (stringExp.exactMatch(value_)) {
		return QLatin1String("string");
	} else if (integerExp.exactMatch(value_)) {
		return QLatin1String("int");
	} else if (doubleExp.exactMatch(value_)) {
		return QLatin1String("double");
	} else if (boolExp.exactMatch(value_)) {
		return QLatin1String("bool");
	} else if (voidExp.exactMatch(value_)) {
		return QLatin1String("void");
	} else {
		return QLatin1String("?");
	}
}

QString FlowArray::type() const {
	if (elements_.isEmpty()) {
		return QLatin1String("[?]");
	} else {
		const FlowValue& elemValue = elements_.first();
		return QLatin1String("[") + elemValue.type() + QLatin1String("]");
	}
}

class FlowValueParser {
	static const char* mi_result_grammar() {
		return R"(
			# Flow value result grammar

			VALUE       <- ARRAY / REF / CLOSURE / NATIVE / STRUCT / SCALAR
			ARRAY       <- '[' ('...' / VAL_LIST) ']'
			REF         <- '<ref' '#' NUM ':' VALUE '>'
			CLOSURE     <- '<closure' HEX ':' ID ('$' NUM)? '>'
			NATIVE      <- '<native' NUM ':' ID '>'
			STRUCT      <- ID '(' STRUCT_BODY ')'
			STRUCT_BODY <- '...' / VAL_LIST
			VAL_LIST    <- (VALUE (',' VALUE)*)?
			SCALAR      <- STRING / ID
			ID          <- < (![(,)$<>] .)+ >
			STRING      <- '"' STR_CHAR * '"'
			STR_CHAR    <- '\\"' / < (!'"' .) >
			NUM         <- < [0-9]+ >
			HEX         <- < '0x' [0-9a-fA-F]+ >

			%whitespace <- [ \t\r\n]*
		)";
	}

public:
	FlowValueParser() : parser(mi_result_grammar()) {
		if (!parser) {
			QTextStream(stderr) << "Flow value grammar is not correct\n";
			exit(1);
		}
		parser["VALUE"] = [](const peg::SemanticValues& sv) {
			switch (sv.choice()) {
			case 0: return FlowValue(sv[0].get<FlowArray*>());
			case 1: return FlowValue(sv[0].get<FlowRef*>());
			case 2: return FlowValue(sv[0].get<FlowClosure*>());
			case 3: return FlowValue(sv[0].get<FlowNative*>());
			case 4: return FlowValue(sv[0].get<FlowStruct*>());
			case 5: return FlowValue(sv[0].get<FlowScalar*>());
			default: throw std::out_of_range("impossible case");
			}
		};
		parser["REF"] = [](const peg::SemanticValues& sv) {
			return new FlowRef{sv[1].get<FlowValue>(), QString::fromStdString(sv.token())};
		};
		parser["CLOSURE"] = [](const peg::SemanticValues& sv) {
			return new FlowClosure{sv[1].get<QString>(), QString::fromStdString(sv.token())};
		};
		parser["NATIVE"] = [](const peg::SemanticValues& sv) {
			return new FlowNative{sv[1].get<QString>(), QString::fromStdString(sv.token())};
		};
		parser["STRUCT"] = [](const peg::SemanticValues& sv) {
			auto pair = sv[1].get<std::pair<bool, QVector<FlowValue>>>();
			return new FlowStruct{sv[0].get<QString>(), pair.second, pair.first, QString::fromStdString(sv.token())};
		};
		parser["STRUCT_BODY"] = [](const peg::SemanticValues& sv) {
			switch (sv.choice()) {
			case 0: return std::pair<bool, QVector<FlowValue>>(true, QVector<FlowValue>());
			case 1: return std::pair<bool, QVector<FlowValue>>(false, sv[0].get<QVector<FlowValue>>());
			default: throw std::out_of_range("impossible case");
			}
		};
		parser["ARRAY"] = [](const peg::SemanticValues& sv) {
			switch (sv.choice()) {
			case 0: return new FlowArray{QVector<FlowValue>(), true};
			case 1: return new FlowArray{sv[0].get<QVector<FlowValue>>(), false, QString::fromStdString(sv.token())};
			default: throw std::out_of_range("impossible case");
			}
		};
		parser["VAL_LIST"] = [](const peg::SemanticValues& sv) {
			return QVector<FlowValue>::fromStdVector(sv.transform<FlowValue>());
		};
		parser["SCALAR"] = [](const peg::SemanticValues& sv) {
			return new FlowScalar{QString::fromStdString(sv.token())};
		};
		parser["ID"] = [](const peg::SemanticValues& sv) {
			return QString::fromStdString(sv.token());
		};
		parser["STRING"] = [](const peg::SemanticValues& sv) {
			return new QString(QString::fromStdString(sv.token()));
		};
		parser["NUM"] = [](const peg::SemanticValues& sv) {
			return QString::fromStdString(sv.token()).toInt();
		};
	}
	FlowValue parse(const QString& str) {
		FlowValue ret;
		if (!parser.parse<FlowValue>(str.toStdString().c_str(), ret)) {
			QTextStream(stdout) << "Error parsing result: " << str << "\n";
		}
		return ret;
	}

private:
	peg::parser parser;
};

FlowValue flow_value_parse(const QString& str) {
	static FlowValueParser parser;
	return parser.parse(str);
}

}

