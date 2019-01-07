#pragma once

#include <QPlainTextEdit>

namespace flow {

class CompilerTextEdit : public QPlainTextEdit {
	Q_OBJECT
public:
	CompilerTextEdit(QWidget* parent);
	~CompilerTextEdit();

Q_SIGNALS:
	void signalCompilerError(QString file, int line, int col);

protected:
	void mousePressEvent(QMouseEvent *e) override;
};

}
