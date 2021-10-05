package com.area9innovation.flow;

import java.util.*;
import java.nio.charset.Charset;

@SuppressWarnings("unchecked")
public class SoundSupport extends NativeHost {
	public static Object noSound() {
		return null;
	}
	public static Object loadSound(String url,Func1<Object,String> onfail,Func0<Object> onok) {
		return null;
	}
	public static double getSoundLength(Object snd) {
		return 0;
	}
	public static double getSoundPosition(Object snd) {
		return 0;
	}
	public static Object playSound(Object snd,boolean loop,Func0<Object> donecb) {
		return null;
	}
	public static Object playSoundFrom(Object snd,double pos,Func0<Object> donecb) {
		return null;
	}
	public static Object stopSound(Object snd) {
		return null;
	}
	public static Object setVolume(Object snd, double val) {
		return null;
	}

	public static Func0<Object> addDeviceVolumeEventListener(Func1<Object,Double> callback) {
		return null;
	}
	public static String getAudioSessionCategory() {
		return "soloambient";
	}
	public static Object setAudioSessionCategory(String category) {
		return null;
	}
}
