#pragma once

#include <KTextEditor/MainWindow>
#include <KTextEditor/Plugin>

namespace flow {

class KatePluginFlow : public KTextEditor::Plugin {
	Q_OBJECT
public:
    explicit KatePluginFlow(QObject* parent, const QList<QVariant>&);
    virtual ~KatePluginFlow() override;

    QObject* createView(KTextEditor::MainWindow* mainWindow) Q_DECL_OVERRIDE;
};

}
