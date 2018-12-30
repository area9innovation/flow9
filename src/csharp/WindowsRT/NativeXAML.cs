using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;
using Windows.UI.Xaml.Shapes;
using Windows.UI.Xaml.Media;
using Windows.Foundation;
using Windows.UI;
using Windows.Storage;
using Windows.Security.Cryptography.Core;
using Windows.Security.Cryptography;
using Windows.Storage.Streams;
using System.IO;
using Windows.System;
using System.Diagnostics;
using Windows.UI.Core;
using Windows.UI.Popups;
using Windows.Phone.UI.Input;

namespace Area9Innovation.Flow
{
	public sealed class NativeXAML : Native
	{
		private Dictionary<string, string> key_storage;
		private StorageFolder key_directory;

		delegate void PlatformEvent();
		private Dictionary<string, PlatformEvent> platform_events;

		// callback id => camera callback
		private Dictionary<string, Func5> camera_callbacks;

		public NativeXAML()
		{
			key_storage = new Dictionary<string, string>();
			platform_events = new Dictionary<string, PlatformEvent>();
			camera_callbacks = new Dictionary<string, Func5>(); 

			Task.Run(async () => {
				key_directory = await ApplicationData.Current.LocalFolder.CreateFolderAsync("KeyStore", CreationCollisionOption.OpenIfExists);
			}).Wait();
		}

		protected override void initialize()
		{
			base.initialize();

#if WINDOWS_8_1
			HardwareButtons.BackPressed += NativeXAML_BackRequested;
#elif WINDOWS_10
			SystemNavigationManager.GetForCurrentView().BackRequested += NativeXAML_BackRequested;
#endif
			// for debug
			//SystemNavigationManager.GetForCurrentView().AppViewBackButtonVisibility = AppViewBackButtonVisibility.Visible;
		}

		protected override void terminate()
		{
			base.terminate();

#if WINDOWS_8_1
			HardwareButtons.BackPressed -= NativeXAML_BackRequested;
#elif WINDOWS_10
			SystemNavigationManager.GetForCurrentView().BackRequested -= NativeXAML_BackRequested;
#endif
		}

#if WINDOWS_8_1
		private async void NativeXAML_BackRequested(object sender, BackPressedEventArgs e)
#elif WINDOWS_10
		private async void NativeXAML_BackRequested(object sender, BackRequestedEventArgs e)
#endif
		{
			e.Handled = true;

			PlatformEvent cur;
			if (platform_events.TryGetValue("devicebackbutton", out cur) && cur != null)
			{
				cur();
			}
			else
			{
				MessageDialog msgDialog = new MessageDialog("Please use navigation features within the application interface");
				await msgDialog.ShowAsync();
			}
		}

		public override string getTargetName()
		{
			return base.getTargetName() + ",xaml,mobile";
		}

		public override Func0 addPlatformEventListener(string name, Func0 cb)
		{
			return hostAddCallback(name, cb);
		}

		public override Func0 hostAddCallback(String name, Func0 cb)
		{
			PlatformEvent cur;
			if (!platform_events.TryGetValue(name, out cur))
				cur = null;

			PlatformEvent ecb = () => {
				try {
					cb();
				} catch (Exception e) {
					Debug.WriteLine(e);
				}
			};

			platform_events[name] = cur + ecb;

			return () => { platform_events[name] -= ecb; return null; };
		}

		public override object timer(int ms, Func0 cb)
		{
			if (ms < 10 && runtime.queueDeferred(cb))
				return null;

			execLater(ms, cb);
			return null;
		}

		public override object getUrl(String url, String target)
		{
			doGetUrl(url, target);
			return null;
		}

		private async void doGetUrl(String url, String target)
		{
			try
			{
				await Launcher.LaunchUriAsync(new Uri(url));
			}
			catch (Exception e)
			{
				Debug.WriteLine(e.ToString());
			}
		}

		private async void execLater(int ms, Func0 cb)
		{
			if (!runtime.IsRunning)
				return;

			if (ms < 10)
				await Task.Yield();
			else
				await Task.Delay(ms);

			if (!runtime.IsRunning)
				return;

			using (var ctx = new FlowRuntime.DeferredContext(runtime))
			{
				cb();
			}
		}

		public static string getHashedFilename(string key)
		{
			var alg = HashAlgorithmProvider.OpenAlgorithm(HashAlgorithmNames.Md5);
			var buff = CryptographicBuffer.ConvertStringToBinary(key, BinaryStringEncoding.Utf16LE);
			return CryptographicBuffer.EncodeToHexString(alg.HashData(buff));
		}

		public override bool setKeyValue(String key, String newval)
		{
			string val;
			if (newval == null)
				newval = "";

			if (!key_storage.TryGetValue(key, out val) || val != newval)
			{
				var ok = Task.Run<bool>(async () => {
					try
					{
						var filename = getHashedFilename(key);
						StorageFile file = await key_directory.CreateFileAsync(filename, CreationCollisionOption.ReplaceExisting);
						await FileIO.WriteTextAsync(file, newval, Windows.Storage.Streams.UnicodeEncoding.Utf16LE);
						return true;
					}
					catch
					{
						return false;
					}
				}).Result;

				if (ok)
					key_storage[key] = newval;
				else
					key_storage.Remove(key);

				return ok;
			}

			return true;
		}

		public override String getKeyValue(String key, String def)
		{
			string val;

			if (!key_storage.TryGetValue(key, out val))
			{
				key_storage[key] = val = Task.Run<string>(async () => {
					try
					{
						var filename = getHashedFilename(key);
						StorageFile file = await key_directory.GetFileAsync(filename);
						string rv = await FileIO.ReadTextAsync(file, Windows.Storage.Streams.UnicodeEncoding.Utf16LE);

						// For some reason empty string may come in with BOM intact
						if (rv == "\uFEFF")
							rv = "";
						return rv;
					}
					catch
					{
						return null;
					}
				}).Result;
			}

			return val == null ? def : val;
		}

		public override object removeKeyValue(String key)
		{
			key_storage[key] = null;

			Task.Run(async () => {
				try
				{
					var filename = getHashedFilename(key);
					StorageFile file = await key_directory.GetFileAsync(filename);
					await file.DeleteAsync();
				}
				catch {}
			}).Wait();

			return null;
		}

		public override Func0 addCameraPhotoEventListener(Func5 cb)
		{
			string cbId = Guid.NewGuid().ToString();
			camera_callbacks[cbId] = cb;

			return () => { camera_callbacks.Remove(cbId); return null; };
		}

		public override void notifyCameraEvent(int code, string message, string additionalInfo, int width, int height)
		{
			// Copy to avoid exception if disposer is called from a callback, in which
			// case it would be removed from the array while we are looping through it
			Dictionary<string, Func5> camera_callbacks_copy = new Dictionary<string, Func5>(camera_callbacks);
			foreach (KeyValuePair<string,Func5> cb in camera_callbacks_copy)
			{
				cb.Value(code, message, additionalInfo, width, height);
			}
		}
	}
}
