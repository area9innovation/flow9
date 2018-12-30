#include "mainwindow.h"

#include <QWindowStateChangeEvent>

void MainWindow::changeEvent(QEvent *e)
{
    if (e->type() == QEvent::WindowStateChange) {
        emit windowStateChanged(windowState());
    }
}
