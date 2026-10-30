package com.area9innovation.flow;

import java.util.*;

public class FlowExceptions extends NativeHost {
	public static class FlowException extends RuntimeException {
		FlowException(Object data) {
			this.data = data;
		}
		Object data;
	}
	public static final <T1, T2> T2 throwException(T1 data) {
		throw new FlowException(data);
	}
	@SuppressWarnings("unchecked")
	public static final <T1, T2> T1 tryCatch(Func0<T1> _try, Func1<T1, T2> _catch) {
		try {
			return _try.invoke();
		} catch (FlowException ex) {
			return _catch.invoke((T2)ex.data);
		}
	}
}
