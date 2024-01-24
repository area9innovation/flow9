package com.area9innovation.flow.javafx;

import com.area9innovation.flow.*;

import javafx.application.Platform;

public class FxNative extends Native {
	public static void invokeCallback(Runnable cb) {
		Platform.runLater(cb);
	}
}
