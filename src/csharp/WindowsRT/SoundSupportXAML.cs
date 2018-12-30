using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading.Tasks;
using Windows.Storage;
using Windows.Storage.FileProperties;
using Windows.UI.Xaml.Controls;

namespace Area9Innovation.Flow
{
	public class SoundSupportXAML : SoundSupport
	{
		private Canvas container;
		private Uri base_url;
		private MediaCache cache;

		private class Sound
		{
			public readonly SoundSupportXAML owner;

			public readonly Uri link;
			public StorageFile cached;

			public double length;
			public List<SoundChannel> pending;

			public Sound(SoundSupportXAML owner, Uri link)
			{
				this.owner = owner;
				this.link = link;
				this.length = 0;
			}

			private async Task<string> computeLength(StorageFile file)
			{
				// Any metadata?
				try
				{
					var mp = await file.Properties.GetMusicPropertiesAsync();
					var msec = mp.Duration.TotalMilliseconds;
					if (msec > 0)
						return msec.ToString();
				}
				catch (Exception e)
				{
					Debug.WriteLine("Exception using GetMusicPropertiesAsync: " + e.ToString());
				}

				// Have to load the sound
				MediaElement element = new MediaElement();

				try
				{
					var tcs = new TaskCompletionSource<double>();
					var mediaStream = await file.OpenAsync(Windows.Storage.FileAccessMode.Read);

					/*element.CurrentStateChanged += (s, e) => {
						Debug.WriteLine(element.CurrentState.ToString());
					};*/
					element.MediaOpened += (s, e) => {
						tcs.SetResult(element.NaturalDuration.TimeSpan.TotalMilliseconds);
					};
					element.MediaFailed += (s, e) => {
						Debug.WriteLine("MediaFailed on " + link.ToString() + " trying to get length");
						tcs.SetResult(0);
					};

					owner.container.Children.Add(element);

					element.AutoPlay = false;
					//element.Source = MediaCache.fileToLink(file);

					element.SetSource(mediaStream, file.ContentType);

					var length = await tcs.Task;

					return length.ToString();
				}
				catch (Exception e)
				{
					Debug.WriteLine("Exception using MediaElement to get length: " + e.ToString());
					return "0";
				}
				finally
				{
					owner.container.Children.Remove(element);
				}
			}

			public async void startLoad(Func1 onfail, Func0 onok)
			{
				try
				{
					// Download to cache
					cached = await owner.cache.getCachedObjectAsync(link);

					if (!owner.runtime.IsRunning)
						return;

					// Compute length
					var length_str = await owner.cache.getCachedMetadataAsync(link, "sound_length", computeLength);

					if (!owner.runtime.IsRunning)
						return;

					if (!Double.TryParse(length_str, out length))
						Debug.WriteLine("Bad sound length metadata: " + length_str);

					// Play auto-play channels
					if (pending != null)
					{
						foreach (var c in pending)
							c.play();

						pending = null;
					}

					onok();
				}
				catch (Exception e)
				{
					onfail(e.ToString());
				}
			}
		}

		private class SoundChannel
		{
			public readonly Sound sound;
			public readonly MediaElement element;

			public Func0 donecb;
			public double start_at;

			public SoundChannel(Sound sound, Func0 donecb)
			{
				this.sound = sound;
				this.donecb = donecb;

				element = new MediaElement();
				//element.Visibility = Windows.UI.Xaml.Visibility.Collapsed;

				element.MediaOpened += element_MediaOpened;
				element.MediaFailed += element_MediaFailed;
				element.MediaEnded += element_MediaEnded;

				sound.owner.container.Children.Add(element);
			}

			public void play()
			{
				if (sound.cached == null)
				{
					if (sound.pending == null)
						sound.pending = new List<SoundChannel>();

					sound.pending.Add(this);
					return;
				}

				element.AutoPlay = (start_at == 0);
				element.Source = MediaCache.fileToLink(sound.cached);
			}

			public void stop()
			{
				element.Stop();
				sound.owner.container.Children.Remove(element);
			}

			void element_MediaEnded(object sender, Windows.UI.Xaml.RoutedEventArgs e)
			{
				sound.owner.container.Children.Remove(element);
				donecb();
			}

			void element_MediaFailed(object sender, Windows.UI.Xaml.ExceptionRoutedEventArgs e)
			{
				Debug.WriteLine("Could not play: " + sound.link);
				donecb();
			}

			void element_MediaOpened(object sender, Windows.UI.Xaml.RoutedEventArgs e)
			{
				sound.length = element.NaturalDuration.TimeSpan.TotalMilliseconds;

				if (start_at != 0)
				{
					element.Position = new TimeSpan((long)(start_at * TimeSpan.TicksPerMillisecond));
					element.Play();
				}
			}
		}

		public SoundSupportXAML(Canvas container, Uri base_url, MediaCache cache)
		{
			this.container = container;
			this.base_url = base_url;
			this.cache = cache;
		}

		public override Object noSound() {
			return null;
		}
		public override Object loadSound(String url, Func1 onfail, Func0 onok) {
			var obj = new Sound(this, new Uri(base_url, url));
			obj.startLoad(onfail, onok);
			return obj;
		}
		public override double getSoundLength(Object snd) {
			return (snd != null) ? ((Sound)snd).length : 0;
		}
		public override double getSoundPosition(Object snd) {
			var channel = (SoundChannel)snd;
			return channel.element.Position.TotalMilliseconds;
		}
		public override Object playSound(Object snd,bool loop,Func0 donecb) {
			var sound = (Sound)snd;
			var channel = new SoundChannel(sound, donecb);
			channel.element.IsLooping = loop;
			channel.play();
			return channel;
		}
		public override Object playSoundFrom(Object snd,double pos,Func0 donecb) {
			var sound = (Sound)snd;
			var channel = new SoundChannel(sound, donecb);
			channel.start_at = pos;
			channel.play();
			return channel;
		}
		public override Object stopSound(Object snd) {
			var channel = (SoundChannel)snd;
			channel.stop();
			return null;
		}
		public override Object setVolume(Object snd, double val) {
			var channel = (SoundChannel)snd;
			channel.element.Volume = val;
			return null;
		}
		public override Object play(string url) {
			var obj = new Sound(this, new Uri(base_url, url.TrimStart('/')));
			obj.startLoad((object x) => {
				return null;
			}, () => {
				playSound(obj, false, () => { return null; });
				return null;
			});
			return null;
		}
	}
}

