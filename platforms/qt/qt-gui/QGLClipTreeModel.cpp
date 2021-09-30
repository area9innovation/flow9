#include "QGLClipTreeModel.h"
#include "gl-gui/GLClip.h"
#include "gl-gui/GLGraphics.h"

#include <sstream>

QGLClipTreeModel::QGLClipTreeModel(QGLRenderSupport *renderer, QObject *parent) : QAbstractItemModel(parent), renderer(renderer)
{
    connect(renderer, SIGNAL(runnerReset(bool)), SLOT(runnerReset(bool)), Qt::DirectConnection);
    connect(renderer, SIGNAL(clipDataChanged(GLClip*)), SLOT(clipDataChanged(GLClip*)), Qt::DirectConnection);
    connect(renderer, SIGNAL(clipAboutToChangeParent(GLClip*,GLClip*,GLClip*)), SLOT(clipAboutToChangeParent(GLClip*,GLClip*,GLClip*)), Qt::DirectConnection);
    connect(renderer, SIGNAL(clipChangedParent(GLClip*,GLClip*,GLClip*)), SLOT(clipChangedParent(GLClip*,GLClip*,GLClip*)), Qt::DirectConnection);
}

QGLClipTreeModel::~QGLClipTreeModel()
{

}

GLClip *QGLClipTreeModel::getItem(const QModelIndex &index) const
{
    if (index.isValid()) {
        GLClip *item = static_cast<GLClip*>(index.internalPointer());
        if (item) return item;
    }

    return NULL;
}

QModelIndex QGLClipTreeModel::findItemPath(GLClip *item, int column) const
{
    if (!item || !item->isAttachedToStage() || item->checkFlag(GLClip::IsStageClipObject))
        return QModelIndex();

    const std::vector<GLClip*> &pchild = item->getParent()->getChildren();
    for (size_t i = 0; i < pchild.size(); i++)
        if (pchild[i] == item)
            return createIndex(i, column, item);

    return QModelIndex();
}

void QGLClipTreeModel::runnerReset(bool /*dtor*/)
{
    beginResetModel();
    endResetModel();
}

void QGLClipTreeModel::clipDataChanged(GLClip *clip)
{
    QModelIndex index = findItemPath(clip);
    if (index.isValid())
        dataChanged(index, index.sibling(index.row(), 2));
}

void QGLClipTreeModel::clipAboutToChangeParent(GLClip *clip, GLClip *newparent, GLClip *oldparent)
{
    if (newparent && oldparent)
    {
        QModelIndex iindex = findItemPath(clip);
        QModelIndex pindex = findItemPath(newparent);
        QModelIndex cpindex = findItemPath(oldparent);
        size_t pos = newparent->getChildren().size();

        beginMoveRows(cpindex, iindex.row(), iindex.row(), pindex, pos);
    }
    else if (newparent && !oldparent)
    {
        QModelIndex pindex = findItemPath(newparent);
        size_t pos = newparent->getChildren().size();

        beginInsertRows(pindex, pos, pos);
    }
    else if (!newparent && oldparent)
    {
        QModelIndex index = findItemPath(clip);

        beginRemoveRows(index.parent(), index.row(), index.row());
    }
}

void QGLClipTreeModel::clipChangedParent(GLClip* /*clip*/, GLClip *newparent, GLClip *oldparent)
{
    if (newparent && oldparent)
    {
        endMoveRows();
    }
    else if (newparent && !oldparent)
    {
        endInsertRows();
    }
    else if (!newparent && oldparent)
    {
        endRemoveRows();
    }
}

QModelIndex QGLClipTreeModel::index(int row, int column, const QModelIndex &parent) const
{
    if (parent.isValid() && parent.column() != 0)
        return QModelIndex();

    GLClip *clip = parent.isValid() ? getItem(parent) : renderer->getStage();

    if (clip && unsigned(row) < clip->getChildren().size())
        return createIndex(row, column, clip->getChildren()[row]);

    return QModelIndex();
}

QModelIndex QGLClipTreeModel::parent(const QModelIndex &index) const
{
    GLClip *child = getItem(index);

    if (child)
        return findItemPath(child->getParent(), 0);

    return QModelIndex();
}

int QGLClipTreeModel::rowCount(const QModelIndex &parent) const
{
    GLClip *clip = parent.isValid() ? getItem(parent) : renderer->getStage();

    if (clip)
        return clip->getChildren().size();
    else
        return 0;
}

int QGLClipTreeModel::columnCount(const QModelIndex & /* parent */) const
{
    return 3;
}

Qt::ItemFlags QGLClipTreeModel::flags(const QModelIndex &index) const
{
    GLClip *item = getItem(index);
    if (!item)
        return Qt::ItemFlags();

    Qt::ItemFlags flags = Qt::ItemIsEnabled | Qt::ItemIsSelectable;
    switch (index.column()) {
    case 1:
        if (!item->getMaskOwner())
            flags |= Qt::ItemIsEditable;
        return flags;
    default:
        return flags;
    }
}

QVariant QGLClipTreeModel::headerData(int section, Qt::Orientation orientation,
                               int role) const
{
    if (orientation == Qt::Horizontal && role == Qt::DisplayRole) {
        switch (section) {
        case 0:
            return QString("ID");
        case 1:
            return QString("Visible");
        case 2:
            return QString("Info");
        }
    }

    return QVariant();
}

QVariant QGLClipTreeModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid())
        return QVariant();

    if (role != Qt::DisplayRole && role != Qt::EditRole)
        return QVariant();

    GLClip *item = getItem(index);

    if (!item)
        return QVariant();

    switch (index.column()) {
    case 0:
    {
        QString id = QString("%1").arg(item->getFlowValue().GetNativeValId());

        if (item->getMaskOwner())
            id = "mask " + id;
        if (item->getMask())
            id = "masked " + id;

        FlowNativeValueType *vtype = item->getFlowValueType();
        if (vtype != FLOW_VALUE_TYPE(GLClip*))
            id += QString(" (%1)").arg(QString::fromLatin1(vtype->name()));

        StackSlot form = safeMapAt(item->getDebugInfo(), "form", StackSlot::MakeVoid());
        if (!form.IsVoid())
        {
            std::stringstream ss;
            renderer->getFlowRunner()->PrintData(ss, form, 1, 3);
            id += ": "+QString::fromUtf8(ss.str().c_str());
        }

        return id;
    }
    case 1:
        if (item->getMaskOwner())
            return QString("");
        else
            return QVariant(item->isVisible());
    case 2:
    {
        QString str = "";
        if (item->getFlowStack())
            str += "S";
        if (item->getFilters().size())
            str += "F";
        if (GLGraphics *g = item->getGraphicsData())
        {
            str += "G";
            if (g->usesStencil())
                str += "!";
        }
        if (item->checkFlag(GLClip::HasNativeWidget))
            str += "W";
        return str;
    }
    default:
        return QVariant();
    }
}

bool QGLClipTreeModel::setData(const QModelIndex &index, const QVariant &value, int role)
{
    if (!index.isValid() || !value.isValid() || role != Qt::EditRole)
        return false;

    GLClip *item = getItem(index);
    if (!item)
        return false;

    switch (index.column()) {
    case 1:
        if (item->getMaskOwner())
            return false;
        item->setVisible(value.toBool());
        //dataChanged(index, index);
        return true;
    default:
        return false;
    }
}
