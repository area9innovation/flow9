#include <QTextStream>

#include "CompilerTextEdit.hpp"

namespace flow {

CompilerTextEdit::CompilerTextEdit(QWidget* parent) : QPlainTextEdit(parent) {
	setTextInteractionFlags(Qt::TextSelectableByMouse | Qt::TextSelectableByKeyboard);
}

CompilerTextEdit::~CompilerTextEdit() {
}

void CompilerTextEdit::mousePressEvent(QMouseEvent *e) {
	QTextCursor cursor = cursorForPosition(e->pos());
	cursor.select(QTextCursor::LineUnderCursor);
	QString line = cursor.selectedText();
	static QRegExp errorPosExp(QLatin1String("^(([A-Za-z]:/)?[^:]*):([0-9]*)(:([0-9]*):?)?.*"));
	if (errorPosExp.exactMatch(line)) {
		QString file = errorPosExp.cap(1);
		int line = errorPosExp.cap(3).toInt() - 1;
		int col = errorPosExp.cap(5).toInt();
		if (line > -1) {
			emit signalCompilerLocation(file, line, col);
		}
	}
	QPlainTextEdit::mousePressEvent(e);
}

}
