#ifndef QGLTEXTEDIT_H
#define QGLTEXTEDIT_H

#include <QTextEdit>
#include <qlineedit.h>
#include "gl-gui/QGLRenderSupport.h"
#include "gl-gui/GLTextClip.h"

class QGLTextEdit : public QTextEdit
{
    Q_OBJECT
public:
    explicit QGLTextEdit(QGLRenderSupport * owner_, QWidget *parent = 0, GLTextClip * text_clip_ = 0);
    ~QGLTextEdit();
    void setMaxLength(int length);
    void setFont(const QFont &font);
    void scrollContentsBy(int dx, int dy);
    void paintEvent(QPaintEvent* event);
    void setEchoMode(QLineEdit::EchoMode mode);
    void setCursorWidth(int width);
    void setCursorColor(vec4 color);
    void setWordWrapMode(QTextOption::WrapMode policy);
    void setMultiline(bool multiline);
    void setText(QString text);
    void setInterlineSpacing(float interline_spacing);
    void resetCursorBlink();
    void onStateChange();
    QString toPlainText();

protected:
    int max_chars, cursor_width, line_spacing, interline_spacing;
    bool cursor_visible, edit_multiline;
    QColor cursor_color;
    QTextOption::WrapMode word_wrap_policy;
    GLTextClip * text_clip;
    QLineEdit::EchoMode echo_mode;
    QString real_text;

    void keyPressEvent(QKeyEvent *);
    void keyReleaseEvent(QKeyEvent *);
    void mouseMoveEvent(QMouseEvent *);
    void mousePressEvent(QMouseEvent *);
    void mouseReleaseEvent(QMouseEvent *);
    void filterText(QString text);

    QColor vec2qColor(vec4 color);

    QGLRenderSupport * owner;

    void setupBiDi();
protected slots:
    void onTextChange();
    void toggleCursorBlink();
};

#endif // QGLTEXTEDIT_H
