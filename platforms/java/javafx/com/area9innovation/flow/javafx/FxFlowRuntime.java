package com.area9innovation.flow.javafx;

import com.area9innovation.flow.*;

import javafx.application.Platform;

public abstract class FxFlowRuntime extends FlowRuntime {
	private static boolean isOpen = true;

	public synchronized void start() {
		main();
		eventLoop(true);
	}

	public static void stop() {
		isOpen = false;
	}

	public static void eventLoop(boolean isMainThread) {
		if (isMainThread) {
			if (quitCode == null) {
				executeActions(false);
				if (!sleep("event loop fx")) return;
			}
			if (isOpen) {
				Platform.runLater(() -> eventLoop(true));
			}
		} else {
			FlowRuntime.eventLoop(false);
		}
	}

}
