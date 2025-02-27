package com.area9innovation.flow;

import java.util.*;

public class Timers {
	private int executingCnt = 0;
	private int lastTimerId = 0;
	private TreeMap<Integer, Timer> timers = new TreeMap<Integer, Timer>();
	private static boolean debug = false;

	private class Timer {
		int id;
		double executeTime;	// 0 means do not execute. This is used to not run repeatable timer when it is already executing.
		boolean repeatable;
		double repeatInterval;
		String description;
		Func0<Object> callback;
		public String toString() {
			String s = "Timer " + id + ": callback " + callback.toString() + ", ";
			if (executeTime == 0) {
				s += "running";
			} else {
				s += "next start " + Native.time2string(executeTime);
			}
			if (description != null && !description.isEmpty()) {
				s += ", " + description;
			}
			return s;
		}
	}

	public int addTimer(double timeout, boolean repeatable, String description, Func0<Object> callback) {
		Timer timer = new Timer();
		lastTimerId++;
		timer.id = lastTimerId;
		timer.executeTime = System.currentTimeMillis() + timeout;
		timer.repeatable = repeatable;
		timer.repeatInterval = timeout;
		timer.description = description;
		timer.callback = callback;
		timers.put(lastTimerId, timer);
		if (debug) {
			System.out.println("New timer " + lastTimerId + ", total cnt " + timers.size() + ", tread " + FlowRuntime.getThreadIdLong());
		}
		return lastTimerId;
	}

	public void removeTimer(int timerId) {
		timers.remove(timerId);
		if (debug) {
			System.out.println("Removed timer: " + timerId + ", total cnt " + timers.size());
		}
	}

	public void execute(boolean allowRecursive) {
		if (!allowRecursive && executingCnt > 0) {
			return;
		}
		executingCnt++;
		TreeSet<Integer> timerIds = new TreeSet<Integer>();
		do {
			timerIds.clear();
			double tm = System.currentTimeMillis();
			for (Iterator<Timer> iterator = timers.values().iterator(); iterator.hasNext(); ) {
				Timer timer = iterator.next();
				if (timer.executeTime != 0 && timer.executeTime <= tm) {
					timerIds.add(timer.id);
				}
			}
			for (Iterator<Integer> iterator = timerIds.iterator(); iterator.hasNext(); ) {
				Integer timerId = iterator.next();
				Timer timer = timers.get(timerId);
				if (timer == null) {
					iterator.remove();
				} else {
					if (timer.repeatable) {
						timer.executeTime = 0;
					} else {
						timers.remove(timerId);
					}
					try {
						timer.callback.invoke();
					} catch (Exception ex) {
						System.err.println("Exception in timer callback: " + ex.getMessage());
					}
					if (timer.repeatable) {
						timer.executeTime = System.currentTimeMillis() + timer.repeatInterval;
					}
				}
			}
		} while (!timerIds.isEmpty());
		executingCnt--;
	}

	public boolean isEmpty() {
		return timers.isEmpty();
	}

	public int size() {
		return timers.size();
	}

	public String toString(String separator) {
		if (isEmpty()) {
			return "";
		}

		StringBuilder sb = new StringBuilder();
		for (Iterator<Timer> iterator = timers.values().iterator(); iterator.hasNext(); ) {
			Timer timer = iterator.next();
			sb.append(timer.toString());
			if (iterator.hasNext()) {
				sb.append(separator);
			}
		}
		return sb.toString();
	}

	public String toString() {
		return toString("\n");
	}
}
