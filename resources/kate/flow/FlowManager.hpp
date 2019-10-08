#pragma once

#include "ui_RenameDialog.h"
#include "common.hpp"

namespace flow {

class FlowManager : public QObject {
	Q_OBJECT
public:
	FlowManager(FlowEnv e);

public Q_SLOTS:
	void slotCompile();
    void slotRun(int);
    void slotBuild(int);
    void slotDebug(int);
    void slotForceBuild(int);
    void slotLookupDefinition();
    void slotLookupType();
    void slotLookupUses();
    void slotStartRename();
    void slotCompleteRename();
    void slotOutline(KTextEditor::View* view);

private:
    FlowEnv env_;
	Ui::RenameDialog renameDialog_;
};

}
