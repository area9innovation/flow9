#include "QGLClipTreeBrowser.h"
#include "GLClip.h"

#include <QSplitter>
#include <QVBoxLayout>
#include <QHeaderView>

QGLClipTreeBrowser::QGLClipTreeBrowser(QGLRenderSupport *parent) : QDialog(parent), renderer(parent)
{
    resize(800, 350);
    setWindowTitle("Clip Tree Browser");

    tree = new QGLClipTreeModel(renderer, this);

    tree_view = new QTreeView();
    tree_view->setModel(tree);
    tree_view->setAutoScroll(false);
    tree_view->setAlternatingRowColors(true);
    tree_view->header()->setStretchLastSection(false);
    tree_view->header()->setSectionResizeMode(0, QHeaderView::ResizeToContents);
    tree_view->header()->setSectionResizeMode(1, QHeaderView::ResizeToContents);
    tree_view->header()->setSectionResizeMode(2, QHeaderView::ResizeToContents);

    connect(tree_view, SIGNAL(clicked(const QModelIndex &)), SLOT(clipActivated(const QModelIndex &)));

    stack_view = new QTextEdit();
    stack_view->setReadOnly(true);
    stack_view->setWordWrapMode(QTextOption::NoWrap);

    QSplitter *resize = new QSplitter(this);
    resize->setChildrenCollapsible(false);
    resize->addWidget(tree_view);
    resize->addWidget(stack_view);
    resize->setStretchFactor(0, 100);

    QVBoxLayout* layout = new QVBoxLayout(this);
    layout->addWidget(resize);
}

QGLClipTreeBrowser::~QGLClipTreeBrowser()
{

}

void QGLClipTreeBrowser::clipActivated(const QModelIndex &index)
{
    GLClip *clip = tree->getItem(index);

    stack_view->clear();
    renderer->setDebugHighlight(clip);

    if (clip)
    {
        FlowStackSnapshot *stack = clip->getFlowStack();
        if (stack)
            stack_view->setText(QString::fromUtf8(stack->toString().c_str()));
    }
}
