#include "debug/StackManager.hpp"

#include <QLabel>
#include <QTextStream>
#include <QHeaderView>

#include "common.hpp"
#include "debug/MiParser.hpp"
#include "DebugSymbols.hpp"
#include "FlowValueParser.hpp"
#include "FlowView.hpp"

namespace flow {

StackManager::StackManager(QTableWidget* stack, FlowView& view)
:   QObject(stack), flowView_(view), stack_(stack) {
	//QHeaderView* header = new QHeaderView(Qt::Horizontal);
	//header->setSectionResizeMode(QHeaderView::Stretch);
	//stack_->setHorizontalHeader(header);
}

StackManager::~StackManager() {
}

void StackManager::slotStackInfo(const QString& descr) {
	stack_->clearContents();
	MiResult locals = mi_parse(descr);
	if (!locals.value() || locals.value()->emptyList()) {
		return;
	}
	for (MiResult& frameDescr : locals.value(QLatin1String("stack"))->resList()->list) {
		if (frameDescr.variable() == QLatin1String("frame")) {
			MiTuple* frame = frameDescr.value()->tuple();
			QString level  = stripQuotes(frame->getField(QLatin1String("level"))? frame->getField(QLatin1String("level"))->string(): QString());
			QString addr   = stripQuotes(frame->getField(QLatin1String("addr")) ? frame->getField(QLatin1String("addr"))->string() : QString());
			QString func   = stripQuotes(frame->getField(QLatin1String("func")) ? frame->getField(QLatin1String("func"))->string() : QString());
			QString file   = stripQuotes(frame->getField(QLatin1String("file")) ? frame->getField(QLatin1String("file"))->string() : QString());
			QString line   = stripQuotes(frame->getField(QLatin1String("line")) ? frame->getField(QLatin1String("line"))->string() : QString());
			QString args   = stripQuotes(frame->getField(QLatin1String("args")) ? frame->getField(QLatin1String("args"))->string() : QString());
			QString upvars = stripQuotes(frame->getField(QLatin1String("upvars")) ? frame->getField(QLatin1String("upvars"))->string() : QString());

			int row = level.toInt();
			stack_->insertRow(row);
			stack_->setItem(row, 0, setNotEditable(new QTableWidgetItem(level)));
			stack_->setItem(row, 1, setNotEditable(new QTableWidgetItem(addr)));
			stack_->setItem(row, 2, setNotEditable(new QTableWidgetItem(func)));
			stack_->setItem(row, 3, setNotEditable(new QTableWidgetItem(upvars)));
			stack_->setItem(row, 4, setNotEditable(new QTableWidgetItem(args)));
			stack_->setItem(row, 5, setNotEditable(new QTableWidgetItem(file)));
			stack_->setItem(row, 6, setNotEditable(new QTableWidgetItem(line)));
		} else {
			QTextStream(stdout) << "wrong stack format: should be 'frame' but got: " << frameDescr.variable() << "\n";
		}
	}
}

}
