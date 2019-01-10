#pragma once

#include <QObject>
#include <QString>
#include <QTreeWidget>
#include <QTreeWidgetItem>

namespace flow {

class FlowValue;
class FlowView;

class LocalsManager : public QObject {
	Q_OBJECT
public:
    LocalsManager(QTreeWidget* tree, FlowView& view);
    ~LocalsManager();

public Q_SLOTS:
    void slotLocalsInfo(QString description);
    void slotArgsInfo(QString description, int frameIndex);

private:
    template<class T>
    void createItem(T* parent, const QString& name, FlowValue& value);
    FlowView&    flowView_;
    QTreeWidget* tree_;
};

}
