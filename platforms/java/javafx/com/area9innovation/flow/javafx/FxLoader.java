package com.area9innovation.flow.javafx;

import java.util.*;
import com.area9innovation.flow.*;

import javafx.application.Application;
import javafx.event.ActionEvent;
import javafx.event.EventHandler;
import javafx.scene.Scene;
import javafx.scene.control.Button;
import javafx.scene.layout.StackPane;
import javafx.stage.Stage;

import java.lang.reflect.Constructor;

public class FxLoader extends Application {
	private FxNative natives;
	private FxRenderSupport renderer;

	@Override
	public void start(Stage primaryStage) throws Exception {
		String flowappMain = getParameters().getNamed().get("flowapp");
		if (flowappMain == null)
			flowappMain = "javagen.Main";
		final List<String> params = this.getParameters().getRaw();
		String[] params1 = params.toArray(new String[0]);

		Class cl = Class.forName(flowappMain);

		Constructor constructor =
			cl.getConstructor(String[].class);
		FlowRuntime runtime = (FlowRuntime) constructor.newInstance((Object) params1);

		natives = new FxNative(this);
		renderer = new FxRenderSupport(primaryStage);

		runtime.start(type -> {
			if (type.isAssignableFrom(FxNative.class))
				return natives;
			if (type.isAssignableFrom(FxRenderSupport.class))
				return renderer;
			return null;
		});
	}

	public static void main(String[] args) {
		launch(args);
	}
}
