package com.area9innovation.flow;

import java.util.*;

public class Timers {
	private boolean executing = false;
	private int lastTimerId = 0;
	private TreeMap<Integer, Timer> timers = new TreeMap<Integer, Timer>();
	private boolean debug = false;

	private class Timer {
		int id;
		double executeTime;
		boolean repeatable;
		double repeatInterval;
		Func0<Object> callback;
	}

	public int addTimer(double timeout, boolean repeatable, Func0<Object> callback) {
		//execute();

		Timer timer = new Timer();
		lastTimerId++;
		timer.id = lastTimerId;
		timer.executeTime = System.currentTimeMillis() + timeout;
		timer.repeatable = repeatable;
		timer.repeatInterval = timeout;
		timer.callback = callback;
		timers.put(lastTimerId, timer);
		if (debug) {
			System.out.println("New timer " + lastTimerId + ", total cnt " + timers.size());
		}
		return lastTimerId;
	}

	public void removeTimer(int timerId) {
		timers.remove(timerId);
		if (debug) {
			System.out.println("Removed timer: " + timerId + ", total cnt " + timers.size());
		}
	}

	public void execute() {
		if (executing) {
			return;
		}
		executing = true;
		TreeSet<Integer> timerIds = new TreeSet<Integer>();
		do {
			timerIds.clear();
			double tm = System.currentTimeMillis();
			for (Iterator<Timer> iterator = timers.values().iterator(); iterator.hasNext(); ) {
				Timer timer = iterator.next();
				if (timer.executeTime <= tm) {
					timerIds.add(timer.id);
				}
			}
			for (Iterator<Integer> iterator = timerIds.iterator(); iterator.hasNext(); ) {
				Integer timerId = iterator.next();
				Timer timer = timers.get(timerId);
				if (timer == null) {
					iterator.remove();
				} else {
					try {
						timer.callback.invoke();
					} catch (Exception ex) {
						System.err.println("Exception in timer callback: " + ex.getMessage());
					}
					if (timer.repeatable) {
						timer.executeTime = System.currentTimeMillis() + timer.repeatInterval;
					} else {
						timers.remove(timerId);
					}
				}
			}
		} while (!timerIds.isEmpty());
		executing = false;
	}

	public boolean isEmpty() {
		return timers.isEmpty();
	}
}
