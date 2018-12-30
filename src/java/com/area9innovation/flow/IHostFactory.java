package com.area9innovation.flow;

public interface IHostFactory {
	NativeHost allocateHost(Class<? extends NativeHost> type) throws ReflectiveOperationException;
}
