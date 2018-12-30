#include "QGLTextEdit.h"
#include <QKeyEvent>
#include <qscrollbar.h>
#include <QTextBlock>
#include <qtimer.h>
#include <iostream>

QGLTextEdit::QGLTextEdit(QGLRenderSupport * owner_, QWidget *parent, GLTextClip * text_clip_) :
    QTextEdit(parent), owner(owner_), text_clip(text_clip_)
{
    QGLTextEdit::setViewportMargins(-4, -3, 4, 3);
    QGLTextEdit::setFrameStyle(QFrame::NoFrame);
    QTextEdit::setCursorWidth(0);

    line_spacing = 0;
    cursor_visible = true;
    cursor_width = 2;
    cursor_color = QColor(0, 0, 0, 255);
    real_text = unicode2qt(text_clip->getPlainText());

    onStateChange();

    QTimer *cursor_blink_timer = new QTimer(this);
    cursor_blink_timer->start(500);

    QGLTextEdit::connect(cursor_blink_timer, SIGNAL(timeout()), this, SLOT(toggleCursorBlink()));
    QGLTextEdit::connect(this, SIGNAL(textChanged()), this, SLOT(onTextChange()));
}

QGLTextEdit::~QGLTextEdit(){
    if(this->hasFocus()) {
        this->previousInFocusChain()->setFocus();
    }
}

void QGLTextEdit::setupBiDi() {
    // Makes correct word order when editing
    QTextCursor tc = textCursor();
    QTextBlockFormat tbf = tc.blockFormat();
    tbf.setLayoutDirection(text_clip->getTextDirection() == GLTextClip::RTL? Qt::RightToLeft : Qt::LeftToRight);
    tc.setBlockFormat(tbf);
    setTextCursor(tc);

    switch (text_clip->getAlignment()) {
        case GLTextClip::AlignNone:
            // Horizontal constant misnamed or misfunctional, meaning is Qt::AlignStart.
            QGLTextEdit::setAlignment(Qt::AlignLeft | Qt::AlignTop);
            break;
        case GLTextClip::AlignCenter:
            QGLTextEdit::setAlignment(Qt::AlignHCenter | Qt::AlignTop);
            break;
        case GLTextClip::AlignLeft:
            if (text_clip->getTextDirection() == GLTextClip::RTL)
                // Horizontal constant misnamed or misfunctional, meanings is Qt::AlignEnd.
                QGLTextEdit::setAlignment(Qt::AlignRight | Qt::AlignTop);
            else
                // Horizontal constant misnamed or misfunctional, meaning is Qt::AlignStart.
                QGLTextEdit::setAlignment(Qt::AlignLeft | Qt::AlignTop);
            break;
        case GLTextClip::AlignRight:
            if (text_clip->getTextDirection() == GLTextClip::RTL)
                // Horizontal constant misnamed or misfunctional, meaning is Qt::AlignStart.
                QGLTextEdit::setAlignment(Qt::AlignLeft | Qt::AlignTop);
            else
                // Horizontal constant misnamed or misfunctional, meanings is Qt::AlignEnd.
                QGLTextEdit::setAlignment(Qt::AlignRight | Qt::AlignTop);
            break;
    }
}

void QGLTextEdit::onStateChange()
{
    QTextEdit::blockSignals(true);

    setMultiline(text_clip->isMultiline());
    setWordWrapMode(text_clip->wordWrap() ? (text_clip->cropWords() ? QTextOption::WrapAnywhere : QTextOption::WordWrap) : QTextOption::NoWrap);
    setEchoMode(text_clip->isPassword() ? QLineEdit::Password : QLineEdit::Normal);
    setMaxLength(text_clip->getMaxChars());
    QTextEdit::setReadOnly(text_clip->isReadonly());
    setCursorColor(text_clip->getCursorColor());
    setCursorWidth(text_clip->getCursorWidth());
    setInterlineSpacing(text_clip->getInterlineSpacing());

    QString text = unicode2qt(text_clip->getPlainText());
    setText(text);

    QPalette p = QTextEdit::palette();
    p.setColor(QPalette::Text, vec2qColor(text_clip->getFontColor()));
    p.setColor(QPalette::HighlightedText, vec2qColor(text_clip->getFontColor()));
    p.setColor(QPalette::Base, vec2qColor(text_clip->getBackgroundColor()));
    QTextEdit::setPalette(p);

    setupBiDi();

    QTextCursor cursor = QTextEdit::textCursor();
    if (text_clip->getSelectionStart() == text_clip->getCursorPos()) {
        cursor.setPosition(text_clip->getSelectionEnd());
        cursor.setPosition(text_clip->getCursorPos(), QTextCursor::KeepAnchor);
    } else if (text_clip->getSelectionEnd() == text_clip->getCursorPos() && text_clip->getSelectionStart() != -1) {
        cursor.setPosition(text_clip->getSelectionStart());
        cursor.setPosition(text_clip->getCursorPos(), QTextCursor::KeepAnchor);
    } else {
        cursor.setPosition(text_clip->getCursorPos());
    }
    QTextEdit::setTextCursor(cursor);
    cursor_visible = true;
    onTextChange();

    QTextEdit::blockSignals(false);
}

void QGLTextEdit::setMaxLength(int length)
{
    if (max_chars != length) {
        max_chars = length;
        onTextChange();
    }
}

void QGLTextEdit::keyPressEvent(QKeyEvent *event)
{
    FlowKeyEvent flowKeyEvent = owner->keyEventToFlowKeyEvent(FlowKeyDown, event);

    if ((edit_multiline || flowKeyEvent.code != 13) && text_clip && text_clip->keyEventFilteredByFlowFilters(flowKeyEvent) &&
        (max_chars == -1
            || QTextEdit::toPlainText().length() < max_chars
            || event->text().length() == 0)) {
        QTextEdit::keyPressEvent(event);
    }

    if (event->isAccepted() == 1) {
        owner->translateFlowKeyEvent(flowKeyEvent);
    }
}

void QGLTextEdit::keyReleaseEvent(QKeyEvent *event)
{
    FlowKeyEvent flowKeyEvent = owner->keyEventToFlowKeyEvent(FlowKeyUp, event);

    if ((edit_multiline || flowKeyEvent.code != 13) && text_clip && text_clip->keyEventFilteredByFlowFilters(flowKeyEvent)) {
        QTextEdit::keyPressEvent(event);
    }

    if (event->isAccepted() == 1) {
        owner->translateFlowKeyEvent(flowKeyEvent);
    }
}

void QGLTextEdit::mouseMoveEvent(QMouseEvent * event) {
    QTextEdit::mouseMoveEvent(event);
    owner->dispatchMouseEventFromWidget(this, FlowMouseMove, event);
}

void QGLTextEdit::mousePressEvent(QMouseEvent * event) {
    QTextEdit::mousePressEvent(event);
    // Sending the normal FlowMouseDown event causes the text input to loose focus. We don't want that,
    // so we have a special event which is translated to the right thing later
    if (event->buttons() == Qt::LeftButton)
        owner->dispatchMouseEventFromWidget(this, FlowMouseDownInTextEdit, event);
    else if (event->buttons() == Qt::RightButton)
        owner->dispatchMouseEventFromWidget(this, FlowMouseRightDownInTextEdit, event);
    else if (event->buttons() == Qt::MiddleButton)
        owner->dispatchMouseEventFromWidget(this, FlowMouseMiddleDownInTextEdit, event);
}

void QGLTextEdit::mouseReleaseEvent(QMouseEvent * event) {
    QTextEdit::mouseReleaseEvent(event);
    if (event->button() == Qt::LeftButton)
        owner->dispatchMouseEventFromWidget(this, FlowMouseUp, event);
    else if (event->button() == Qt::RightButton)
        owner->dispatchMouseEventFromWidget(this, FlowMouseRightUp, event);
    else if (event->button() == Qt::MiddleButton)
        owner->dispatchMouseEventFromWidget(this, FlowMouseMiddleUp, event);
}

void QGLTextEdit::scrollContentsBy(int dx, int dy) {
    QTextEdit::scrollContentsBy(dx, dy);

    int newPosition = round((float) QTextEdit::verticalScrollBar()->sliderPosition() / (float) line_spacing) * line_spacing;
    QTextEdit::verticalScrollBar()->setSliderPosition(newPosition);
}

void QGLTextEdit::onTextChange() {
    QTextEdit::blockSignals(true);

    QString text = toPlainText();
    QGLTextEdit::filterText(text);

    for (QTextBlock block = QTextEdit::document()->begin(); block.isValid(); block = block.next()) {
        QTextBlockFormat fmt = block.blockFormat();
        if (fmt.lineHeight() != (qreal) line_spacing) {
            QTextCursor tc = QTextCursor(block);
            fmt.setLineHeight(line_spacing, QTextBlockFormat::FixedHeight);
            tc.setBlockFormat(fmt);
        }
    }

    switch (text_clip->getAlignment()) {
        case GLTextClip::AlignCenter:
            QGLTextEdit::setAlignment(Qt::AlignHCenter | Qt::AlignTop);
            break;
        case GLTextClip::AlignLeft:
            QGLTextEdit::setAlignment(Qt::AlignLeft | Qt::AlignTop);
            break;
        case GLTextClip::AlignRight:
            QGLTextEdit::setAlignment(Qt::AlignRight | Qt::AlignTop);
            break;
    }

    QTextEdit::blockSignals(false);
}

QString QGLTextEdit::toPlainText()
{
    QString text = QTextEdit::toPlainText();

    for (int it = 0; it != text.length(); ++it){
        if (text_clip->inputType() == "password" && text[it] == QChar(0x2022)) {
            text[it] = real_text[it];
        } else {
            if (real_text.length() < text.length()) {
                real_text.insert(it, text[it]);
            } else {
                real_text[it] = text[it];
            }
        }
    }

    real_text = real_text.mid(0, text.length());

    return real_text;
}

void QGLTextEdit::filterText(QString &text)
{
    int pos = QTextEdit::textCursor().position();

    if (max_chars > 0) {
        text = text.mid(0, max_chars);
    }

    if (text_clip) {
        text = unicode2qt(text_clip->textFilteredByFlowFilters(qt2unicode(text)));
    }

    if (!edit_multiline) {
        text = text.remove('\n');
    }

    if (text_clip->inputType() == "password") {
        text = QString(text.length(), QChar(0x2022));
    }

    if (text != QTextEdit::toPlainText()) {
        QTextEdit::setText(text);
        QTextCursor cursor = QTextEdit::textCursor();
        if (pos < text.length()) {
            cursor.setPosition(pos);
        } else {
            cursor.setPosition(text.length());
        }
        QTextEdit::setTextCursor(cursor);
    }
}

void QGLTextEdit::setFont(const QFont &font)
{
    QTextEdit::setFont(font);
    double font_spacing = font.pixelSize() * 1.2;

    if (line_spacing != font_spacing || QTextEdit::verticalScrollBar()->singleStep() != font_spacing) {
        line_spacing = font_spacing;
        QTextEdit::verticalScrollBar()->setSingleStep(line_spacing + interline_spacing);
        onTextChange();
    }
}

void QGLTextEdit::setInterlineSpacing(float interline_spacing)
{
    if (this->interline_spacing != interline_spacing || QTextEdit::verticalScrollBar()->singleStep() != line_spacing + interline_spacing) {
        this->interline_spacing = interline_spacing;
        QTextEdit::verticalScrollBar()->setSingleStep(line_spacing + interline_spacing);
        onTextChange();
    }
}

void QGLTextEdit::paintEvent(QPaintEvent* event)
 {
     QTextEdit::paintEvent(event);

     if (cursor_visible)
     {
         QRect r = cursorRect();
         r.setWidth(cursor_width);

         QPainter painter(viewport());
         painter.fillRect(r, QBrush(cursor_color));
     }
}

void QGLTextEdit::setEchoMode(QLineEdit::EchoMode mode)
{
    Qt::InputMethodHints imHints = inputMethodHints();
    imHints.setFlag(Qt::ImhHiddenText, mode == QLineEdit::Password || mode == QLineEdit::NoEcho);
    imHints.setFlag(Qt::ImhNoAutoUppercase, mode != QLineEdit::Normal);
    imHints.setFlag(Qt::ImhNoPredictiveText, mode != QLineEdit::Normal);
    imHints.setFlag(Qt::ImhSensitiveData, mode != QLineEdit::Normal);

    if (echo_mode != mode || QTextEdit::inputMethodHints() != imHints) {
        echo_mode = mode;
        QTextEdit::setInputMethodHints(imHints);
        QGLTextEdit::update();
    }
}

void QGLTextEdit::setCursorWidth(int width)
{
    if (cursor_width != width) {
        cursor_width = width;;
        QGLTextEdit::update();
    }
}

void QGLTextEdit::setCursorColor(vec4 color)
{
    QColor qColor = vec2qColor(color);

    if (cursor_color != qColor) {
        cursor_color = qColor;
        qColor.setAlpha(qColor.alpha() / 3.0f);

        QPalette p = QTextEdit::palette();
        p.setColor(QPalette::Highlight, qColor);
        QTextEdit::setPalette(p);

        QGLTextEdit::update();
    }
}

void QGLTextEdit::setMultiline(bool multiline)
{
    edit_multiline = multiline;
    setWordWrapMode(word_wrap_policy);

    if (edit_multiline) {
        if (QTextEdit::verticalScrollBarPolicy() != Qt::ScrollBarAsNeeded || QTextEdit::horizontalScrollBarPolicy() != Qt::ScrollBarAsNeeded) {
            QTextEdit::setVerticalScrollBarPolicy(Qt::ScrollBarAsNeeded);
            QTextEdit::setHorizontalScrollBarPolicy(Qt::ScrollBarAsNeeded);
            onTextChange();
        }
    } else {
        if (QTextEdit::verticalScrollBarPolicy() != Qt::ScrollBarAlwaysOff || QTextEdit::horizontalScrollBarPolicy() != Qt::ScrollBarAlwaysOff) {
            QTextEdit::setVerticalScrollBarPolicy(Qt::ScrollBarAlwaysOff);
            QTextEdit::setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOff);
            onTextChange();
        }
    }
}

void QGLTextEdit::setWordWrapMode(QTextOption::WrapMode policy) {
    word_wrap_policy = policy;

    if (edit_multiline) {
        if (QTextEdit::wordWrapMode() != word_wrap_policy) {
            QTextEdit::setWordWrapMode(word_wrap_policy);
            onTextChange();
        }
    } else {
        if (QTextEdit::wordWrapMode() != QTextOption::NoWrap) {
            QTextEdit::setWordWrapMode(QTextOption::NoWrap);
            onTextChange();
        }
    }
}

void QGLTextEdit::toggleCursorBlink()
{
    cursor_visible = !cursor_visible;
    QGLTextEdit::update();
}

void QGLTextEdit::resetCursorBlink()
{
    cursor_visible = true;
    QGLTextEdit::update();
}

void QGLTextEdit::setText(QString &text)
{
    filterText(text);
    onTextChange();
}

QColor QGLTextEdit::vec2qColor(vec4 color)
{
    return QColor(color.x * 255.0f, color.y * 255.0f, color.z * 255.0f, color.a * 255.0f);
}
