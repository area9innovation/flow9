package com.area9innovation.flow.javafx;

import com.area9innovation.flow.*;

import javafx.application.Platform;

public abstract class FxFlowRuntime extends FlowRuntime {

	public static void eventLoop(boolean isMainThread) {
		if (isMainThread) {
			if (quitCode == null) {
				executeActions(false);
				if (!sleep("event loop fx")) return;
			}
			Platform.runLater(() -> eventLoop(true));
		} else {
			FlowRuntime.eventLoop(false);
		}
	}

}
