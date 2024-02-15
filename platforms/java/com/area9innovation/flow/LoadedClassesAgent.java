package com.area9innovation.flow;

import java.lang.instrument.Instrumentation;

public class LoadedClassesAgent {
	private static Instrumentation instrumentation;
	public static void agentmain(String agentArgs, Instrumentation inst) {
		instrumentation = inst;
	}
	public static Class<?>[] getAllLoadedClasses() {
		if (instrumentation == null) {
			return new Class[0];
		} else {
			return instrumentation.getAllLoadedClasses();
		}
	}
}
