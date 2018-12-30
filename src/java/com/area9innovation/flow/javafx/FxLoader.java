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
	private FlowRuntime runtime;
	private FxNative natives;
	private FxRenderSupport renderer;

	@Override
	public void start(Stage primaryStage) throws Exception {
		String flowapp = getParameters().getNamed().get("flowapp");
		if (flowapp == null)
			flowapp = "javagen";
		final List<String> params = this.getParameters().getRaw();
		String[] params1 = params.toArray(new String[params.size()]);

		Class cl = Class.forName(flowapp+".Main");

		Constructor constructor =
			cl.getConstructor(new Class[]{String[].class});
		runtime = (FlowRuntime)constructor.newInstance((Object)params1);

		natives = new FxNative(this);
		renderer = new FxRenderSupport(this, primaryStage);

		runtime.start(new IHostFactory() {
			public NativeHost allocateHost(Class<? extends NativeHost> type) {
				if (type.isAssignableFrom(FxNative.class))
					return natives;
				if (type.isAssignableFrom(FxRenderSupport.class))
					return renderer;
				return null;
			}
		});
	}

	public static void main(String[] args) {
		launch(args);
	}
}
