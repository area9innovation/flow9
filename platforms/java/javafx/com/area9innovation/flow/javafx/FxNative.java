package com.area9innovation.flow.javafx;

import java.util.*;
import com.area9innovation.flow.*;

import javafx.application.Application;
import javafx.application.Platform;

public class FxNative extends Native {
	private Application app_object;

	FxNative(Application app) {
		this.app_object = app;
	}

	public void invokeCallback(Runnable cb) {
		Platform.runLater(cb);
	}

	public String getUrlParameter(String name) {
		// Grab the arguments
        final Application.Parameters params = app_object.getParameters();
		List<String> parameters = params.getRaw();
		for (String p : parameters) {
			if (p.startsWith(name + "=")) {
				String arg = p.substring(name.length() + 1);
				return arg;
			}
		}

		return "";
	}
}
