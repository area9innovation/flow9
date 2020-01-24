#include "debug/FlowValueParser.hpp"

#include <QTextStream>
#include <QRegExp>
#include <tuple>
#include "peglib/peglib.h"


namespace flow {

QString FlowValue::type() const {
	switch (kind_) {
	case SCALAR:   return val_.scalar_->type();
	case STRUCT:   return val_.struct_->type();
	case ARRAY:    return val_.array_->type();
	case REF:      return val_.ref_->type();
	case CLOSURE:  return val_.closure_->type();
	case NATIVE:   return val_.native_->type();
	case ELLIPSIS: return val_.ellipsis_->type();
	default:       return QLatin1String("?");
	}
}


QString FlowValue::show() const {
	switch (kind_) {
	case SCALAR:   return val_.scalar_->show();
	case STRUCT:   return val_.struct_->show();
	case ARRAY:    return val_.array_->show();
	case REF:      return val_.ref_->show();
	case CLOSURE:  return val_.closure_->show();
	case NATIVE:   return val_.native_->show();
	case ELLIPSIS: return val_.ellipsis_->show();
	default:       return QLatin1String("NONE");
	}
}
QString FlowValue::value() const {
	switch (kind_) {
	case SCALAR:   return val_.scalar_->value_;
	case STRUCT:   return val_.struct_->value_;
	case ARRAY:    return val_.array_->value_;
	case REF:      return val_.ref_->value_;
	case CLOSURE:  return val_.closure_->value_;
	case NATIVE:   return val_.native_->value_;
	case ELLIPSIS: return val_.ellipsis_->value_;
	default:       return QLatin1String("?");
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

QString FlowStruct::show() const {
	QString ret = name_;
	ret += QLatin1String("(");
	bool first = true;
	for (auto& f : fields_) {
		if (!first) {
			ret += QLatin1String(", ");
		}
		ret += f.show();
		first = false;
	}
	ret += QLatin1String(")");
	return ret;
}

QString FlowArray::type() const {
	if (elements_.isEmpty()) {
		return QLatin1String("[?]");
	} else {
		const FlowValue& elemValue = elements_.first();
		return QLatin1String("[") + elemValue.type() + QLatin1String("]");
	}
}

QString FlowArray::show() const {
	QString ret;
	ret += QLatin1String("[");
	bool first = true;
	for (auto& e : elements_) {
		if (!first) {
			ret += QLatin1String(", ");
		}
		ret += e.show();
		first = false;
	}
	ret += QLatin1String("]");
	return ret;
}

class FlowValueParser {
	static const char* mi_result_grammar() {
		return R"(
			# Flow value result grammar

			VALUE       <- ELLIPSIS / ARRAY / REF / CLOSURE / NATIVE / STRUCT / SCALAR 
			ARRAY       <- '[' VAL_LIST ']' 
			REF         <- '<ref' '#' NUM ':' VALUE '>'
			CLOSURE     <- '<closure' HEX ':' ID ('$' NUM)? '>'
			NATIVE      <- '<native' NUM ':' ID '>'
			STRUCT      <- ID '(' VAL_LIST ')'
			VAL_LIST    <- (VALUE (',' VALUE)*)?
			SCALAR      <- STRING / ID
			ELLIPSIS    <- '...'
			ID          <- !('[' / "\"") < (![(,)$<>\]] .)+ >
			STRING      <- '"' STR_CHAR * '"'
			STR_CHAR    <- '\\"' / < (!'"' .) >
			NUM         <- < ('+'/'-')? [0-9]+ >
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
		parser.log = [](size_t ln, size_t col, const std::string& err_msg) {
			QTextStream(stderr) << QString::fromStdString(err_msg) << ", line: " << ln << ", col: " << col << endl;
		};
		parser["VALUE"] = [](const peg::SemanticValues& sv) {
			switch (sv.choice()) {
			case 0: return FlowValue(sv[0].get<FlowEllipsis*>());
			case 1: return FlowValue(sv[0].get<FlowArray*>());
			case 2: return FlowValue(sv[0].get<FlowRef*>());
			case 3: return FlowValue(sv[0].get<FlowClosure*>());
			case 4: return FlowValue(sv[0].get<FlowNative*>());
			case 5: return FlowValue(sv[0].get<FlowStruct*>());
			case 6: return FlowValue(sv[0].get<FlowScalar*>());
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
			return new FlowStruct{sv[0].get<QString>(), sv[1].get<QVector<FlowValue>>(), QString::fromStdString(sv.token())};
		};
		parser["ARRAY"] = [](const peg::SemanticValues& sv) {
			return new FlowArray{sv[0].get<QVector<FlowValue>>(), QString::fromStdString(sv.token())};
		};
		parser["VAL_LIST"] = [](const peg::SemanticValues& sv) {
			return QVector<FlowValue>::fromStdVector(sv.transform<FlowValue>());
		};
		parser["SCALAR"] = [](const peg::SemanticValues& sv) {
			return new FlowScalar{QString::fromStdString(sv.token())};
		};
		parser["ELLIPSIS"] = [](const peg::SemanticValues& sv) {
			return new FlowEllipsis{QString::fromStdString(sv.token())};
		};
		parser["ID"] = [](const peg::SemanticValues& sv) {
			return QString::fromStdString(sv.token());
		};
		parser["STRING"] = [](const peg::SemanticValues& sv) {
			std::string str = sv.token();
			//std::cout << "str: " << str << "\n";
			/*size_t i = 0;
			while (true) {
				i = str.find("\\", i);
				if (i == std::string::npos) {
					break;
				}
				str.replace(i, 2, "");
			};*/
			//std::cout << "replaced: " << str << "\n";
			return new QString(QString::fromStdString(str));
		};
		parser["NUM"] = [](const peg::SemanticValues& sv) {
			return QString::fromStdString(sv.token()).toInt();
		};

		QString test = QLatin1String("[A(...), ...]");

		FlowValue ret;
		if (!parser.parse<FlowValue>(test.toStdString().c_str(), ret)) {
			QTextStream(stdout) << "Error parsing test: \n";
			exit(1);
		}

	}
	FlowValue parse(const QString& str) {
		FlowValue ret;
		parser.log = [&str](size_t ln, size_t col, const std::string& err_msg) {
			QTextStream(stdout) << QLatin1String("Flow value ") << QString::fromStdString(err_msg) << ", line: " << ln << ", col: " << col << endl;
			QTextStream(stdout) << str.mid(col - 32, 64) << endl;
			QTextStream(stdout) << str << endl;
		};
		parser.parse<FlowValue>(str.toStdString().c_str(), ret);
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

