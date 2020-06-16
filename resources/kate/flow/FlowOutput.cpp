#include "FlowOutput.hpp"

namespace flow {

FlowOutput::FlowOutput(QWidget* parent) : QObject(parent) {
	ui.setupUi(new QWidget(parent));
	connect(ui.clearCompilerOutButton, SIGNAL(clicked()), ui.compilerOutTextEdit, SLOT(clear()));
	connect(ui.clearLaunchOutButton, SIGNAL(clicked()), ui.launchOutTextEdit, SLOT(clear()));
    connect(ui.clearDebugOutButton, SIGNAL(clicked()), ui.debugOutTextEdit, SLOT(clear()));
    connect(ui.clearFdbMiOutButton, SIGNAL(clicked()), ui.fdbMiOutTextEdit, SLOT(clear()));
}

FlowOutput::~FlowOutput() {

}

}
