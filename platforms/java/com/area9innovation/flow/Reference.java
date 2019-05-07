package com.area9innovation.flow;

public final class Reference<T> implements Comparable<Reference<T>> {
	public T value;

	public Reference(T init) {
		this.value = init;
	}

	public int compareTo(Reference<T> other) {
		return Integer.valueOf(this.hashCode()).compareTo(other.hashCode());
	}

	public String toString() {
		return "ref " + FlowRuntime.toString(value);
	}
}
