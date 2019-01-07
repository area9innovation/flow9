#include <kpluginfactory.h>

#include "Plugin.hpp"
#include "FlowView.hpp"

K_PLUGIN_FACTORY_WITH_JSON (KatePluginFlowFactory, "kateflowplugin.json", registerPlugin<flow::KatePluginFlow>();)

#include "Plugin.moc"

namespace flow {

KatePluginFlow::KatePluginFlow(QObject* parent, const QList<QVariant>&): KTextEditor::Plugin(parent) {
}

KatePluginFlow::~KatePluginFlow() {
}

QObject* KatePluginFlow::createView(KTextEditor::MainWindow* mainWindow) {
    return new FlowView(this, mainWindow);
}

}
