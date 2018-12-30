using Area9Innovation.Flow;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices.WindowsRuntime;
using Windows.Foundation;
using Windows.Foundation.Collections;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;
using Windows.UI.Xaml.Controls.Primitives;
using Windows.UI.Xaml.Data;
using Windows.UI.Xaml.Input;
using Windows.UI.Xaml.Media;
using Windows.UI.Xaml.Navigation;
using Windows.UI.Text;
using Windows.Storage;
using System.Threading.Tasks;
using System.Diagnostics;
using Windows.ApplicationModel.Activation;
using Windows.ApplicationModel.Resources;

// The Blank Page item template is documented at http://go.microsoft.com/fwlink/?LinkId=234238

namespace WindowsApp
{
	/// <summary>
	/// An empty page that can be used on its own or navigated to within a Frame.
	/// </summary>
	public sealed partial class MainPage : Page
	{
		static Uri default_uri = new Uri("https://cloud1.area9.dk/flow/");

        Uri base_uri;
		flowgen.Program program;
		NativeXAML native;
		RenderSupportXAML rsupport;
		HttpSupportNet http;
		SoundSupportXAML sound;
		NotificationsSupportXAML notification;

		static MediaCache media;

		private void InitMediaCache()
		{
			if (media != null)
				return;

			StorageFolder media_dir = null;
			Task.Run(async () =>
			{
				media_dir = await ApplicationData.Current.LocalFolder.CreateFolderAsync("MediaCache", CreationCollisionOption.OpenIfExists);
			}).Wait();

			media = new MediaCache(media_dir, "MediaCache");
		}

		public MainPage()
		{
			this.InitializeComponent();

			InitMediaCache();
		}

		protected override void OnNavigatedTo(NavigationEventArgs e)
		{
			if (base_uri == null)
			{
				setBaseUri();

				// Override the query string parameters if app loading was triggered by a link
				if (e.Parameter is ProtocolActivatedEventArgs)
				{
					var args = (ProtocolActivatedEventArgs)e.Parameter;

					if (args.Uri.Query != null && args.Uri.Query.Length > 1)
					{
						UriBuilder ubld = new UriBuilder(default_uri);
						ubld.Query = args.Uri.Query.Substring(1);
						base_uri = ubld.Uri;
					}
				}

				this.Loaded += MainPage_Loaded;
			}

			base.OnNavigatedTo(e);
		}

		private void setBaseUri()
		{
			ResourceLoader rl = ResourceLoader.GetForCurrentView("AppSettings");
			string uri = rl.GetString("DEFAULT_BASE_URL");
			if (!String.IsNullOrEmpty(uri))
			{
				default_uri = new Uri(uri);;
			}
			base_uri = default_uri;
		}

		void MainPage_Loaded(object sender, RoutedEventArgs _e)
		{
			if (native != null)
				return;

			if (base_uri == null)
				setBaseUri();

			native = new NativeXAML();
			Debug.WriteLine(base_uri);
			native.setLoaderURL(base_uri);

			rsupport = new RenderSupportXAML(FlowScreen, base_uri, media);
			http = new HttpSupportNet(base_uri, media);
			sound = new SoundSupportXAML(FlowScreen, base_uri, media);
			notification = new NotificationsSupportXAML();

			program = new flowgen.Program();

			this.Unloaded += MainPage_Unloaded;

			RenderSupportXAML.registerFont("Book", "Assets/Book/FRABK.TTF#Franklin Gothic Book", FontStyle.Normal);
			RenderSupportXAML.registerFont("Italic", "Assets/Italic/FRABKIT.TTF#Franklin Gothic Book", FontStyle.Italic);
			RenderSupportXAML.registerFont("Demi", "Assets/Demi/FRADM.TTF#Franklin Gothic Demi", FontStyle.Normal);
			RenderSupportXAML.registerFont("Medium", "Assets/Medium/framd.ttf#Franklin Gothic Medium", FontStyle.Normal);
			RenderSupportXAML.registerFont("MediumItalic", "Assets/MediumItalic/FRAMDIT.TTF#Franklin Gothic Medium", FontStyle.Italic);

			RenderSupportXAML.registerFont("DejaVuSans", "Assets/DejaVuSans/DejaVuSans.ttf#Deja Vu Sans", FontStyle.Normal);
			RenderSupportXAML.registerFont("DejaVuSansOblique", "Assets/DejaVuSansOblique/DejaVuSans-Oblique.ttf#Deja Vu Sans", FontStyle.Oblique);
			RenderSupportXAML.registerFont("DejaVuSerif", "Assets/DejaVuSerif/DejaVuSerif.ttf#Deja Vu Serif", FontStyle.Normal);

			RenderSupportXAML.registerFont("Chess", "Assets/Chess/chess_merida_unicode.ttf#Chess Merida Unicode", FontStyle.Normal);
			RenderSupportXAML.registerFont("FeltTipRoman", "Assets/FeltTipRoman/felttiproman.ttf#Felt Tip Roman", FontStyle.Normal);

            RenderSupportXAML.registerFont("MaterialIcons", "Assets/MaterialIcons/MaterialIcons-Regular.ttf#Material Icons", FontStyle.Normal);
            RenderSupportXAML.registerFont("Roboto", "Assets/Roboto/Roboto-Regular.ttf#Roboto", FontStyle.Normal);
            RenderSupportXAML.registerFont("RobotoMedium", "Assets/RobotoMedium/Roboto-Medium.ttf#Roboto Medium", FontStyle.Normal);

#if DEBUG
			Application.Current.DebugSettings.EnableFrameRateCounter = true;
#endif
			try
			{
				program.start(makeHost);
			}
			catch (Exception e)
			{
				Debug.WriteLine(e.ToString());
			}
		}

		void MainPage_Unloaded(object sender, RoutedEventArgs e)
		{
			if (program == null)
				return;

			program.terminate();
			program = null;
		}

		NativeHost makeHost(Type type)
		{
			if (type == typeof(Native))
				return native;
			if (type == typeof(RenderSupport))
				return rsupport;
			if (type == typeof(HttpSupport))
				return http;
			if (type == typeof(SoundSupport))
				return sound;
			if (type == typeof(NotificationsSupport))
				return notification;
			return null;
		}

		public void Continue(IContinuationActivatedEventArgs args)
		{
			string action = (string)args.ContinuationData["Action"];
			if (action == "RenderSupport.cameraTakePhoto")
			{
				rsupport.continueCameraTakePhoto(args);
			}
		}
	}
}
