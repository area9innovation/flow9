#ifndef QGLCLIPTREEMODEL_H
#define QGLCLIPTREEMODEL_H

#include <QAbstractItemModel>
#include <QModelIndex>
#include <QVariant>

#include "QGLRenderSupport.h"

class QGLClipTreeModel : public QAbstractItemModel
{
    Q_OBJECT

    QGLRenderSupport *renderer;

public:
    explicit QGLClipTreeModel(QGLRenderSupport *renderer, QObject *parent = 0);
    ~QGLClipTreeModel();

    GLClip *getItem(const QModelIndex &index) const;

    QModelIndex index(int row, int column,
                      const QModelIndex &parent = QModelIndex()) const;
    QModelIndex parent(const QModelIndex &index) const;

    int rowCount(const QModelIndex &parent = QModelIndex()) const;
    int columnCount(const QModelIndex &parent = QModelIndex()) const;

    Qt::ItemFlags flags(const QModelIndex &index) const;

    QVariant data(const QModelIndex &index, int role) const;
    QVariant headerData(int section, Qt::Orientation orientation,
                        int role = Qt::DisplayRole) const;

    bool setData(const QModelIndex &index, const QVariant &value, int role);

private:
    QModelIndex findItemPath(GLClip *item, int column = 0) const;

signals:

private slots:
    void runnerReset(bool dtor);
    void clipDataChanged(GLClip *clip);
    void clipAboutToChangeParent(GLClip *clip, GLClip *newparent, GLClip *oldparent);
    void clipChangedParent(GLClip *clip, GLClip *newparent, GLClip *oldparent);
};

#endif // QGLCLIPTREEMODEL_H
