#include "QGLLineEdit.h"
#include <QKeyEvent>
#include <iostream>

QGLLineEdit::QGLLineEdit(QGLRenderSupport * owner_, QWidget * parent) :
    QLineEdit(parent), owner(owner_)
{
    setFocusPolicy(Qt::StrongFocus);
}

void QGLLineEdit::keyPressEvent(QKeyEvent *event)
{
    QLineEdit::keyPressEvent(event);
    if (event->isAccepted() == 1) {
        owner->translateKeyEvent(FlowKeyDown, event);
    }
}

void QGLLineEdit::mouseMoveEvent(QMouseEvent * event) {
    QLineEdit::mouseMoveEvent(event);
    owner->dispatchMouseEventFromWidget(this, FlowMouseMove, event);
}

void QGLLineEdit::mousePressEvent(QMouseEvent * event) {
    QLineEdit::mousePressEvent(event);
    // Sending the normal FlowMouseDown event causes the text input to loose focus. We don't want that,
    // so we have a special event which is translated to the right thing later
    if (event->buttons() == Qt::LeftButton)
        owner->dispatchMouseEventFromWidget(this, FlowMouseDownInTextEdit, event);
    else if (event->buttons() == Qt::RightButton)
        owner->dispatchMouseEventFromWidget(this, FlowMouseRightDownInTextEdit, event);
    else if (event->buttons() == Qt::MiddleButton)
        owner->dispatchMouseEventFromWidget(this, FlowMouseMiddleDownInTextEdit, event);
}

void QGLLineEdit::mouseReleaseEvent(QMouseEvent * event) {
    QLineEdit::mouseReleaseEvent(event);

    if (event->button() == Qt::LeftButton)
        owner->dispatchMouseEventFromWidget(this, FlowMouseUp, event);
    else if (event->button() == Qt::RightButton)
        owner->dispatchMouseEventFromWidget(this, FlowMouseRightUp, event);
    else if (event->button() == Qt::MiddleButton)
        owner->dispatchMouseEventFromWidget(this, FlowMouseMiddleUp, event);
}

bool QGLLineEdit::event(QEvent *event)
{
    if (event->type() == QEvent::KeyPress)
    {
        QKeyEvent *keyEvent = static_cast<QKeyEvent *>(event);
        if (keyEvent->key() == Qt::Key_Tab || keyEvent->key() == Qt::Key_Backtab)
            owner->translateKeyEvent(FlowKeyDown, keyEvent);
    }

    return QLineEdit::event(event);
}
