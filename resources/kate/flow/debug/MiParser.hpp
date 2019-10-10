#pragma once

#include <QString>
#include <QVector>
#include <QTextStream>

namespace flow {

/*
MI Output grammar:
result   → variable "=" value
variable → string
value    → const | tuple | list
const    → c-string
tuple    → "{}" | "{" result ( "," result )* "}"
list     → "[]" | "[" value ( "," value )* "]" | "[" result ( "," result )* "]"
 */

class MiScalar;
class MiTuple;
class MiResList;
class MiValList;

struct MiValue {
	enum Type {NONE, SCALAR, TUPLE, RES_LIST, VAL_LIST};

	MiValue() : type_(NONE) { val_.scalar_ = nullptr; }
	MiValue(MiScalar* scalar) : type_(SCALAR) { val_.scalar_ = scalar; }
	MiValue(MiTuple* tuple) : type_(TUPLE) { val_.tuple_ = tuple; }
	MiValue(MiResList* rlist) : type_(RES_LIST) { val_.rlist_ = rlist; }
	MiValue(MiValList* vlist) : type_(VAL_LIST) { val_.vlist_ = vlist; }

	Type type() const { return type_; }
	QString string() const;

	MiScalar* scalar() {
		if (type_ != SCALAR) {
			QTextStream(stdout) << "wrong mi value type " << typeStr() << ", while scalar is required\n";
			return nullptr;
		}
		return val_.scalar_;
	}
	MiTuple* tuple() {
		if (type_ != TUPLE) {
			QTextStream(stdout) << "wrong mi value type " << typeStr() << ", while tuple is required\n";
			return nullptr;
		}
		return val_.tuple_;
	}
	MiResList* resList() {
		if (type_ != RES_LIST) {
			QTextStream(stdout) << "wrong mi value type " << typeStr() << ", while result list is required\n";
			return nullptr;
		}
		return val_.rlist_;
	}
	MiValList* valList() {
		if (type_ != VAL_LIST) {
			QTextStream(stdout) << "wrong mi value type " << typeStr() << ", while value list is required\n";
			return nullptr;
		}
		return val_.vlist_;
	}
	bool emptyList() const;

private:
	QString typeStr() const {
		switch (type_) {
		case NONE:     return QLatin1String("none");
		case SCALAR:   return QLatin1String("scalar");
		case TUPLE:    return QLatin1String("tuple");
		case RES_LIST: return QLatin1String("result list");
		case VAL_LIST: return QLatin1String("value  list");
		default: return QLatin1String("...");
		}
	}
	union Value {
		MiScalar*  scalar_;
		MiTuple*   tuple_;
		MiResList* rlist_;
		MiValList* vlist_;
	};
	Type type_;
	Value val_;
};

struct MiScalar {
	QString string;
};

struct MiResult {
	MiResult() : value_(nullptr) { }
	MiResult(QString var, MiValue* val, const QString& s) : variable_(var), value_(val), string_(s) { }
	QString variable() const { return variable_; }
	MiValue* value() {
		if (!value_) {
			QTextStream(stdout) << "null result value of '" << variable_ << "'\n";
		}
		return value_;
	}
	MiValue* value(QString var) {
		if (variable_ != var) {
			QTextStream(stdout) << "wrong variable name " << variable_ << ", should be " << var << "\n";
			return nullptr;
		}
		return value();
	}
	QString string() const { return string_; }
private:
	QString  variable_;
	MiValue* value_;
public:
	QString string_;
};

struct MiTuple {
	QVector<MiResult> elements_;
	QString string_;
	MiValue* getField(QString field, bool warn = false) {
		for (MiResult& res : elements_) {
			if (res.variable() == field) {
				return res.value();
			}
		}
		if (warn) {
			QTextStream(stdout) << "field " << field << " is not found\n";
		}
		return nullptr;
	}
};

struct MiResList {
	QVector<MiResult> list;
	QString string_;
};

struct MiValList {
	QVector<MiValue*> list;
	QString string_;
};

inline QString MiValue::string() const {
	switch (type_) {
	case SCALAR:   return val_.scalar_->string;
	case TUPLE:    return val_.tuple_->string_;
	case RES_LIST: return val_.rlist_->string_;
	case VAL_LIST: return val_.vlist_->string_;
	default: return QLatin1String("");
	}
}

inline bool MiValue::emptyList() const {
	switch (type_) {
	case RES_LIST: return val_.rlist_->list.isEmpty();
	case VAL_LIST: return val_.vlist_->list.isEmpty();
	default:
		QTextStream(stdout) << "wrong mi value type " << typeStr() << ", while list is required\n";
		return true;
	}
}

MiResult mi_parse(const QString&);

}

