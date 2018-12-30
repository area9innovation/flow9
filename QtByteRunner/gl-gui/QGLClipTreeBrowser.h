#ifndef QGLCLIPTREEBROWSER_H
#define QGLCLIPTREEBROWSER_H

#include <QWidget>
#include <QDialog>
#include <QTreeView>
#include <QTextEdit>

#include "QGLClipTreeModel.h"

class QGLClipTreeBrowser : public QDialog
{
    Q_OBJECT

    QGLRenderSupport *renderer;
    QGLClipTreeModel *tree;

    QTreeView *tree_view;
    QTextEdit *stack_view;

public:
    explicit QGLClipTreeBrowser(QGLRenderSupport *parent);
    ~QGLClipTreeBrowser();

signals:

private slots:
    void clipActivated(const QModelIndex &);
};

#endif // QGLCLIPTREEBROWSER_H
