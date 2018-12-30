package com.area9innovation.flow;

public final class Reference<T> implements Comparable<Reference<T>> {
	public T value;

	public Reference(T init) {
		this.value = init;
	}

	public int compareTo(Reference<T> other) {
		return FlowRuntime.compareByValue(value, other.value);
	}

	public String toString() {
		return "ref " + FlowRuntime.toString(value);
	}
}
