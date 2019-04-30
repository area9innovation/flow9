#include <stdio.h>

#include "flowclip.h"
#include "FlowClipTreeModel.h"

#include "RenderSupport.h"

FlowClipTreeModel::FlowClipTreeModel(const QList<QGraphicsItem*> &roots, QObject *parent)
    : QAbstractItemModel(parent), roots(roots)
{
    // NO-OP
}

FlowClipTreeModel::~FlowClipTreeModel()
{
    // NO-OP
}

int FlowClipTreeModel::columnCount(const QModelIndex & /* parent */) const
{
    return 3;
}

QVariant FlowClipTreeModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid())
        return QVariant();

    if (role != Qt::DisplayRole && role != Qt::EditRole)
        return QVariant();

    QGraphicsItem *item = getItem(index);

    if (!item)
        return QVariant();

    FlowClip *clip = (item->type() == FlowClip::FlowClipType) ? (FlowClip*)item : NULL;

    switch (index.column()) {
    case 0:
        if (clip)
            return QString("Clip %1").arg(clip->id);
        else
            return QString("").sprintf("Item %lx", (unsigned long)(item));
    case 1:
        if (clip && clip->IsMask)
            return QString("mask");
        else
            return QVariant(item->isVisible());
    case 2:
    {
        QString str = "";
        if (clip) {
            if (clip->EventMap.contains(QEvent::GraphicsSceneHoverEnter))
                str += "e";
            if (clip->EventMap.contains(QEvent::GraphicsSceneHoverLeave))
                str += "l";
            if (clip->EventMap.contains(QEvent::GraphicsSceneMouseMove))
                str += "m";
            if (clip->EventMap.contains(QEvent::GraphicsSceneMousePress))
                str += "d";
            if (clip->EventMap.contains(QEvent::GraphicsSceneMouseRelease))
                str += "u";
            if (clip->EventMap.contains(QEvent::MouseButtonPress))
                str += "c";
            if (clip->EventMap.contains(QEvent::GraphicsSceneResize))
                str += "s";
            if (clip->EventMap.contains(QEvent::FocusIn))
                str += "i";
            if (clip->EventMap.contains(QEvent::FocusOut))
                str += "o";
        }
        return str;
    }
    default:
        return QVariant();
    }
}

Qt::ItemFlags FlowClipTreeModel::flags(const QModelIndex &index) const
{
    if (!index.isValid())
        return 0;
    QGraphicsItem *item = getItem(index);
    if (!item)
        return 0;
    FlowClip *clip = (item->type() == FlowClip::FlowClipType) ? (FlowClip*)item : NULL;
    Qt::ItemFlags flags = Qt::ItemIsEnabled | Qt::ItemIsSelectable;
    switch (index.column()) {
    case 1:
        if (!clip || !clip->IsMask)
            flags |= Qt::ItemIsEditable;
        return flags;
    default:
        return flags;
    }
}

bool FlowClipTreeModel::setData(const QModelIndex &index, const QVariant &value, int role)
{
    if (!index.isValid() || !value.isValid() || role != Qt::EditRole)
        return false;
    QGraphicsItem *item = getItem(index);
    if (!item)
        return false;
    FlowClip *clip = (item->type() == FlowClip::FlowClipType) ? (FlowClip*)item : NULL;
    switch (index.column()) {
    case 1:
        if (clip && clip->IsMask)
            return false;
        item->setVisible(value.toBool());
        dataChanged(index, index);
        return true;
    default:
        return false;
    }
}

QGraphicsItem *FlowClipTreeModel::getItem(const QModelIndex &index) const
{
    if (index.isValid()) {
        QGraphicsItem *item = static_cast<QGraphicsItem*>(index.internalPointer());
        if (item) return item;
    }

    return NULL;
}

QVariant FlowClipTreeModel::headerData(int section, Qt::Orientation orientation,
                               int role) const
{
    if (orientation == Qt::Horizontal && role == Qt::DisplayRole) {
        switch (section) {
        case 0:
            return QString("QGraphicsItem");
        case 1:
            return QString("Visible");
        case 2:
            return QString("Events");
        }
    }

    return QVariant();
}

QModelIndex FlowClipTreeModel::index(int row, int column, const QModelIndex &parent) const
{
    if (parent.isValid() && parent.column() != 0)
        return QModelIndex();

    QList<QGraphicsItem *> children;

    if (parent.isValid())
        children = getItem(parent)->childItems();
    else
        children = roots;

    if (row < children.count())
        return createIndex(row, column, children.at(row));
    else
        return QModelIndex();
}

QModelIndex FlowClipTreeModel::findItemPath(QGraphicsItem *item, int column) const
{
    if (!item)
        return QModelIndex();

    QGraphicsItem *root = item;
    while (root->parentItem())
        root = root->parentItem();

    int root_idx = roots.indexOf(root);
    if (root_idx < 0)
        return QModelIndex();

    if (item == root)
        return createIndex(root_idx, column, item);
    else
        return createIndex(item->parentItem()->childItems().indexOf(item), column, item);
}

QModelIndex FlowClipTreeModel::parent(const QModelIndex &index) const
{
    if (!index.isValid())
        return QModelIndex();

    QGraphicsItem *childItem = getItem(index);
    QGraphicsItem *parentItem = childItem->parentItem();

    if (parentItem == NULL)
        return QModelIndex();

    int idx;

    QGraphicsItem *grandparentItem = parentItem->parentItem();
    if (grandparentItem)
        idx = grandparentItem->childItems().indexOf(parentItem);
    else
        idx = roots.indexOf(parentItem);

    if (idx < 0)
        return QModelIndex();
    else
        return createIndex(idx, 0, parentItem);
}

int FlowClipTreeModel::rowCount(const QModelIndex &parent) const
{
    if (!parent.isValid())
        return roots.count();
    else if (parent.column() == 0)
        return getItem(parent)->childItems().count();
    else
        return 0;
}

void FlowClipTreeModel::addItem(QGraphicsItem *item) {
    if (findItemPath(item).isValid())
        return;
    beginInsertRows(QModelIndex(), roots.count(), roots.count());
    roots << item;
    endInsertRows();
}

void FlowClipTreeModel::removeItem(QGraphicsItem *item) {
    QModelIndex index = findItemPath(item);
    if (index.isValid()) {
        beginRemoveRows(index.parent(), index.row(), index.row());
        item->setParentItem(NULL);
        roots.removeOne(item);
        endRemoveRows();
    }
}

void FlowClipTreeModel::itemDataChanged(QGraphicsItem *item, int column)
{
    QModelIndex index = findItemPath(item, column);
    if (index.isValid())
        dataChanged(index, index);
}

void FlowClipTreeModel::setItemParent(QGraphicsItem *item, QGraphicsItem *parent)
{
    QGraphicsItem *cparent = item->parentItem();
    if (cparent == parent)
        return;

    QModelIndex iindex = findItemPath(item);
    QModelIndex pindex = findItemPath(parent);
    QModelIndex cpindex = findItemPath(cparent);

    if (iindex.isValid() && (parent == NULL || pindex.isValid())) {
        int cnt = parent ? parent->childItems().count() : roots.count();
        beginMoveRows(cpindex, iindex.row(), iindex.row(), pindex, cnt);
        item->setParentItem(parent);
        if (!parent)
            roots << item;
        else if (!cparent)
            roots.removeOne(item);
        endMoveRows();
    } else if (pindex.isValid()) {
        int cnt = parent->childItems().count();
        beginInsertRows(pindex, cnt, cnt);
        item->setParentItem(parent);
        endInsertRows();
    } else {
        item->setParentItem(parent);
    }
}
