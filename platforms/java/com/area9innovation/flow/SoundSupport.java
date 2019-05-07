package com.area9innovation.flow;

import java.util.*;
import java.nio.charset.Charset;

@SuppressWarnings("unchecked")
public class SoundSupport extends NativeHost {
	public Object noSound() {
		return null;
	}
	public Object loadSound(String url,Func1<Object,String> onfail,Func0<Object> onok) {
		return null;
	}
	public double getSoundLength(Object snd) {
		return 0;
	}
	public double getSoundPosition(Object snd) {
		return 0;
	}
	public Object playSound(Object snd,boolean loop,Func0<Object> donecb) {
		return null;
	}
	public Object playSoundFrom(Object snd,double pos,Func0<Object> donecb) {
		return null;
	}
	public Object stopSound(Object snd) {
		return null;
	}
	public Object setVolume(Object snd, double val) {
		return null;
	}

	public Func0<Object> addDeviceVolumeEventListener(Func1<Object,Double> callback) {
		return null;
	}
	public String getAudioSessionCategory() {
		return "soloambient";
	}
	public Object setAudioSessionCategory(String category) {
		return null;
	}
}
