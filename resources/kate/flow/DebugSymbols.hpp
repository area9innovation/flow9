#pragma once

#include <QVector>
#include <QString>
#include <QMap>

namespace flow {

struct FieldDef {
	QString name;
	QString type;
};

struct StructDef {
	QString           baseName;
	QString           fullName;
	QVector<FieldDef> fields;
	operator bool() const { return !baseName.isEmpty(); }
};

struct DebugSymbols {
	StructDef findDef(QString name) const;
	void loadIdFile(QString name);
private:
	QMap<QString, StructDef> structDefs;
};

}
