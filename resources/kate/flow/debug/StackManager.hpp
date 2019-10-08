#pragma once

#include <QTableWidget>

namespace flow {

class FlowValue;
class FlowView;

class StackManager : public QObject {
	Q_OBJECT
public:
    StackManager(QTableWidget* stack, FlowView& view);
    ~StackManager();

public Q_SLOTS:
    void slotStackInfo(const QString& description);

private:
    FlowView&     flowView_;
    QTableWidget* stack_;
};

}
