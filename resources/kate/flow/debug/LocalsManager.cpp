#include "debug/LocalsManager.hpp"

#include <QLabel>

#include "common.hpp"
#include "debug/MiParser.hpp"
#include "DebugSymbols.hpp"
#include "FlowValueParser.hpp"
#include "FlowView.hpp"

namespace flow {

LocalsManager::LocalsManager(QTreeWidget *tree, FlowView& view)
:   QObject(tree), flowView_(view), tree_(tree) {}

LocalsManager::~LocalsManager() {
}


template<class T>
void LocalsManager::createItem(T* parent, const QString& name, FlowValue& value) {
	enum { MAX_VALUE_LENGTH = 256 };
	QTreeWidgetItem *item = new QTreeWidgetItem(parent, QStringList(name));
	QString fullValueStr = value.value();
	QString valueStr = fullValueStr;
	if (valueStr.length() >= MAX_VALUE_LENGTH) {
		valueStr.truncate(MAX_VALUE_LENGTH);
		valueStr += QLatin1String("...");
	}
	tree_->setItemWidget(item, 1, new QLabel(valueStr));
    switch (value.kind()) {
    case FlowValue::SCALAR: break;
    case FlowValue::ARRAY: {
		int count = 0;
		for (FlowValue& child : value.array()->elements_) {
			createItem(item, QString::number(count++), child);
		}
		break;
    }
    case FlowValue::STRUCT:	{
    	QString structName = value._struct()->name_;
		int count = 0;
		StructDef structDef = flowView_.debugView_->symbols().findDef(structName);
		for (FlowValue& child : value._struct()->fields_) {
			FieldDef fieldDef = count < structDef.fields.count() ? structDef.fields[count++] : FieldDef();
			QString fname = (fieldDef.name.startsWith(QLatin1String("mutable "))) ? fieldDef.name.mid(8) : fieldDef.name;
			createItem(item, fname, child);
		}
		break;
    }
    default: break;
    }
}

void LocalsManager::slotArgsInfo(const QString& descr, int frameIndex) {
	tree_->clear();
	MiResult locals = mi_parse(descr);
	if (!locals.value() || locals.value()->emptyList()) {
		return;
	}
	for (MiResult& frameDescr : locals.value(QLatin1String("stack-args"))->resList()->list) {
		if (frameDescr.variable() == QLatin1String("frame")) {
			MiTuple* frame = frameDescr.value()->tuple();
			QString levelStr = stripQuotes(frame->getField(QLatin1String("level"))? frame->getField(QLatin1String("level"))->string(): QString());
			int level = levelStr.isEmpty() ? 0 : levelStr.toInt();
			if (level == frameIndex) {
				if (MiValue* upvar_vals = frame->getField(QLatin1String("upvars"))) {
					for (MiValue* upvarDescr : upvar_vals->valList()->list) {
						QString var = upvarDescr->tuple()->getField(QLatin1String("name"))->string();
						QString val = upvarDescr->tuple()->getField(QLatin1String("value"))->string();
						val = val.replace(QLatin1String("\\\""), QLatin1String("\""));
						val = val.mid(1, val.length() - 2); // Remove enclosing quotes
						FlowValue flowVal = flow_value_parse(val);
						if (var == QLatin1String("writer")) {
							QTextStream(stdout) << "writer: " << flowVal.show() << "\n";
						}
						createItem(tree_, var, flowVal);
					}
				}
				if (MiValue* arg_vals = frame->getField(QLatin1String("args"))) {
					for (MiValue* varDescr : arg_vals->valList()->list) {
						QString var = varDescr->tuple()->getField(QLatin1String("name"))->string();
						QString val = varDescr->tuple()->getField(QLatin1String("value"))->string();
						val = val.replace(QLatin1String("\\\""), QLatin1String("\""));
						val = val.mid(1, val.length() - 2); // Remove enclosing quotes
						FlowValue flowVal = flow_value_parse(val);
						createItem(tree_, var, flowVal);
					}
				}
			}
		} else {
			QTextStream(stdout) << "wrong stack format: should be 'frame' but got: " << frameDescr.variable() << "\n";
		}
	}
}
void LocalsManager::slotLocalsInfo(const QString& descr) {
	//tree_->clear();
	MiResult locals = mi_parse(descr);
	if (!locals.value() || locals.value()->emptyList()) {
		return;
	}
	for (MiValue* varDescr : locals.value(QLatin1String("locals"))->valList()->list) {
		QString var = varDescr->tuple()->getField(QLatin1String("name"))->string();
		QString val = varDescr->tuple()->getField(QLatin1String("value"))->string();
		val = val.replace(QLatin1String("\\\""), QLatin1String("\""));
		val = val.mid(1, val.length() - 2); // Remove enclosing quotes
		FlowValue flowVal = flow_value_parse(val);
		createItem(tree_, var, flowVal);
	}
}

}
