#pragma once

#include <QString>
#include <QVector>
#include <QTextStream>

namespace flow {

class FlowScalar;
class FlowStruct;
class FlowArray;
class FlowRef;
class FlowClosure;
class FlowNative;

struct FlowValue {
	enum Kind {NONE, SCALAR, STRUCT, ARRAY, REF, CLOSURE, NATIVE};

	FlowValue() : kind_(NONE) { val_.scalar_ = nullptr; }
	FlowValue(FlowScalar* scalar) : kind_(SCALAR) { val_.scalar_ = scalar; }
	FlowValue(FlowStruct* str)    : kind_(STRUCT) { val_.struct_ = str; }
	FlowValue(FlowArray*  arr)    : kind_(ARRAY) { val_.array_ = arr; }
	FlowValue(FlowRef*    ref)    : kind_(REF) { val_.ref_ = ref; }
	FlowValue(FlowClosure* clo)   : kind_(CLOSURE) { val_.closure_ = clo; }
	FlowValue(FlowNative* nat)    : kind_(NATIVE) { val_.native_ = nat; }

	Kind kind() const { return kind_; }

	FlowScalar* scalar() {
		if (kind_ != SCALAR) {
			QTextStream(stdout) << "wrong mi value type " << type() << ", while scalar is required\n";
			return nullptr;
		}
		return val_.scalar_;
	}
	FlowStruct* _struct() {
		if (kind_ != STRUCT) {
			QTextStream(stdout) << "wrong mi value type " << type() << ", while struct is required\n";
			return nullptr;
		}
		return val_.struct_;
	}
	FlowArray* array() {
		if (kind_ != ARRAY) {
			QTextStream(stdout) << "wrong mi value type " << type() << ", while array is required\n";
			return nullptr;
		}
		return val_.array_;
	}
	FlowRef* ref() {
		if (kind_ != REF) {
			QTextStream(stdout) << "wrong mi value type " << type() << ", while ref is required\n";
			return nullptr;
		}
		return val_.ref_;
	}
	FlowClosure* closure() {
		if (kind_ != CLOSURE) {
			QTextStream(stdout) << "wrong mi value type " << type() << ", while closure is required\n";
			return nullptr;
		}
		return val_.closure_;
	}
	FlowNative* native() {
		if (kind_ != NATIVE) {
			QTextStream(stdout) << "wrong mi value type " << type() << ", while native is required\n";
			return nullptr;
		}
		return val_.native_;
	}
	QString type() const ;
	QString value() const ;

private:
	union Value {
		FlowScalar*  scalar_;
		FlowStruct*  struct_;
		FlowArray*   array_;
		FlowRef*     ref_;
		FlowClosure* closure_;
		FlowNative*  native_;
	};
	Kind kind_;
	Value val_;
};

struct FlowScalar {
	QString value_;
	QString type() const ;
};

struct FlowStruct {
	QString            name_;
	QVector<FlowValue> fields_;
	bool               hidden_;
	QString            value_;
	QString type() const { return name_; }
};

struct FlowArray {
	QVector<FlowValue> elements_;
	bool               hidden_;
	QString            value_;
	QString type() const;
};

struct FlowRef {
	FlowValue ref_;
	QString value_;
	QString type() const { return QLatin1String("ref ") + ref_.type(); }
};

struct FlowClosure {
	QString closure_;
	QString value_;
	QString type() const { return QLatin1String("closure ") + closure_; }
};

struct FlowNative {
	QString native_;
	QString value_;
	QString type() const { return QLatin1String("native ") + native_; }
};

FlowValue flow_value_parse(const QString&);

}

