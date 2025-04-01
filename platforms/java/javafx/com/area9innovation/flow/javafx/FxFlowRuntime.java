package com.area9innovation.flow.javafx;

import com.area9innovation.flow.*;

import javafx.application.Platform;

public abstract class FxFlowRuntime extends FlowRuntime {
	private static boolean isOpen = true; // is running

	public synchronized void start() {
		main();
		eventLoopFx();
	}

	public static void stop() {
		isOpen = false;
	}

	private static void eventLoopFx() {
		if (quitCode == null) {
			executeActions(true, true);
			if (!sleep("event loop fx")) return;
		}
		if (isOpen) {
			Platform.runLater(() -> eventLoopFx());
		}
	}

}
