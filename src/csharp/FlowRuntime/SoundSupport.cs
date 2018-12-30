using System;

namespace Area9Innovation.Flow
{
	public class SoundSupport : NativeHost
	{
		public virtual Object noSound() {
			return null;
		}
		public virtual Object loadSound(String url, Func1 onfail, Func0 onok) {
			return null;
		}
		public virtual double getSoundLength(Object snd) {
			return 0;
		}
		public virtual double getSoundPosition(Object snd) {
			return 0;
		}
		public virtual Object playSound(Object snd,bool loop,Func0 donecb) {
			return null;
		}
		public virtual Object playSoundFrom(Object snd,double pos,Func0 donecb) {
			return null;
		}
		public virtual Object stopSound(Object snd) {
			return null;
		}
		public virtual Object setVolume(Object snd, double val) {
			return null;
		}
		public virtual Object play(string p) {
			return null;
		}
		public virtual Func0 addDeviceVolumeEventListener(Func1 callback) {
			return null;
		}
		public virtual string getAudioSessionCategory() {
			return "soloambient";
		}
		public virtual Object setAudioSessionCategory(string category) {
			return null;
		}
	}
}

