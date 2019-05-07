#ifndef FLOWCLIPTREEMODEL_H
#define FLOWCLIPTREEMODEL_H

#include <QAbstractItemModel>
#include <QModelIndex>
#include <QVariant>

#include "flowclip.h"

class FlowClipTreeModel : public QAbstractItemModel
{
    Q_OBJECT

public:
    FlowClipTreeModel(const QList<QGraphicsItem*> &roots, QObject *parent = 0);
    ~FlowClipTreeModel();

    QVariant data(const QModelIndex &index, int role) const;
    QVariant headerData(int section, Qt::Orientation orientation,
                        int role = Qt::DisplayRole) const;

    QModelIndex index(int row, int column,
                      const QModelIndex &parent = QModelIndex()) const;
    QModelIndex parent(const QModelIndex &index) const;

    int rowCount(const QModelIndex &parent = QModelIndex()) const;
    int columnCount(const QModelIndex &parent = QModelIndex()) const;

    Qt::ItemFlags flags(const QModelIndex &index) const;

    bool setData(const QModelIndex &index, const QVariant &value, int role);

    void addItem(QGraphicsItem *item);
    void removeItem(QGraphicsItem *item);
    void setItemParent(QGraphicsItem *item, QGraphicsItem *parent);
    void itemDataChanged(QGraphicsItem *item, int column);

private:
    QModelIndex findItemPath(QGraphicsItem *item, int column = 0) const;
    QGraphicsItem *getItem(const QModelIndex &index) const;

    QList<QGraphicsItem*> roots;
};

#endif // FLOWCLIPTREEMODEL_H
