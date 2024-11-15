package com.area9innovation.flow;

import java.util.*;

public class Callbacks {
	private int lastCallbackId = 0;
	private TreeMap<Integer, Callback> callbacks = new TreeMap<Integer, Callback>();
	private boolean debug = false;

	public class Callback {
		int id;
		Integer[] alternativeCallbackIds = null;	// For example alternative callback for onOK is onError
		private Func1<Object, Object> callbackFn;
		protected boolean ready = false;
		protected Object data = null;
		public void setReady(Object data) {
			ready = true;
			this.data = data;
		}
	}

	@SuppressWarnings("unchecked")
	public Callback make(Func1 callbackFn) {
		Callback callback = new Callback();
		lastCallbackId++;
		callback.id = lastCallbackId;
		callback.callbackFn = callbackFn;
		callbacks.put(lastCallbackId, callback);
		if (debug) {
			System.out.println("New callback " + lastCallbackId + ", total cnt " + callbacks.size());
		}
		return callback;
	}

	public boolean execute() {
		TreeSet<Integer> idsToRemove = new TreeSet<Integer>();
		ArrayList<Callback> toExecute = new ArrayList<Callback>();
		for (Iterator<Callback> iterator = callbacks.values().iterator(); iterator.hasNext(); ) {
			Callback callback = iterator.next();
			if (callback.ready) {
				toExecute.add(callback);
				iterator.remove();
				if (callback.alternativeCallbackIds != null) {
					for (Integer id : callback.alternativeCallbackIds) {
						idsToRemove.add(id);
					}
				}
			}
		}
		for (Iterator<Integer> iterator = idsToRemove.iterator(); iterator.hasNext(); ) {
			callbacks.remove(iterator.next());
		}
		for (Callback callback : toExecute) {
			callback.callbackFn.invoke(callback.data);
		}

		if (debug && !toExecute.isEmpty()) {
			System.out.println("Executed callbacks count: " + toExecute.size() + ", total cnt " + callbacks.size());
		}
		return !toExecute.isEmpty();
	}

	public boolean isEmpty() {
		return callbacks.isEmpty();
	}
}
