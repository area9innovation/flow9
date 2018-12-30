#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    MainWindow() : QMainWindow() {}

Q_SIGNALS:
    void windowStateChanged(Qt::WindowStates windowState);

private:
    void changeEvent(QEvent* e);
};

#endif // MAINWINDOW_H
