package com.area9innovation.flow.javafx;

import java.util.*;
import com.area9innovation.flow.*;

import javafx.application.Application;
import javafx.stage.Stage;

import java.lang.reflect.Constructor;

public class FxLoader extends Application {
	@Override
	@SuppressWarnings("unchecked")
	public void start(Stage primaryStage) throws Exception {
		String flowappMain = getParameters().getNamed().get("flowapp");
		if (flowappMain == null)
			flowappMain = "javagen.Main";
		final List<String> params = this.getParameters().getRaw();
		String[] params1 = params.toArray(new String[0]);
		FlowRuntime.program_args = params1;

		Class cl = Class.forName(flowappMain);
		Constructor constructor = cl.getConstructor();
		FlowRuntime runtime = (FlowRuntime) constructor.newInstance();

		new FxRenderSupport(primaryStage);

		runtime.start();
	}

	public static void main(String[] args) {
		launch(args);
	}
}
