#ifndef QGLLINEEDIT_H
#define QGLLINEEDIT_H

#include <QLineEdit>
#include "qt-gui/QGLRenderSupport.h"

class QGLLineEdit : public QLineEdit
{
    Q_OBJECT
public:
    explicit QGLLineEdit(QGLRenderSupport * owner_, QWidget * parent = 0);

protected:
    void keyPressEvent(QKeyEvent *);
    void mouseMoveEvent(QMouseEvent *);
    void mousePressEvent(QMouseEvent *);
    void mouseReleaseEvent(QMouseEvent *);
    bool event(QEvent *event);

    QGLRenderSupport * owner;
};

#endif // QGLLINEEDIT_H
