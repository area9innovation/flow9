#if (!(flow_nodejs || nwjs))
import js.Browser;
#end

class Platform {
#if (flow_nodejs || nwjs)
	public static var isAndroid : Bool = false;
	public static var isIEMobile : Bool = false;
	public static var isChrome : Bool = false;
	public static var isSafari : Bool = false;
	public static var isIOS : Bool = false;
	public static var isIE : Bool = false;
	public static var isEdge : Bool = false;
	public static var isFirefox : Bool = false;
	public static var isSamsung : Bool = false;
	public static var isMobile : Bool = false;
	public static var isRetinaDisplay : Bool = false;
	public static var isHighDensityDisplay : Bool = false;
	public static var isWKWebView : Bool = false;

	public static var isMacintosh : Bool = false;
	public static var isWindows : Bool = false;
	public static var isLinux : Bool = false;

	public static var isDarkMode = false;
	public static var isMouseSupported = false;

	public static var browserMajorVersion : Int = 0;

	public static var SupportsVideoTexture = false;
	public static var AccessiblityAllowed = false;
#else
	public static var isChrome : Bool = ~/chrome|crios/i.match(Browser.window.navigator.userAgent);
	public static var isSafari : Bool = ~/safari/i.match(Browser.window.navigator.userAgent) && !isChrome;
	public static var isIE : Bool = ~/MSIE|Trident/i.match(Browser.window.navigator.userAgent);
	public static var isEdge : Bool = ~/Edge/i.match(Browser.window.navigator.userAgent);
	public static var isFirefox : Bool = ~/firefox/i.match(Browser.window.navigator.userAgent);
	public static var isSamsung : Bool = ~/samsungbrowser/i.match(Browser.window.navigator.userAgent);

	public static var isIEMobile : Bool = ~/iemobile/i.match(Browser.window.navigator.userAgent);
	public static var isAndroid : Bool = ~/android/i.match(Browser.window.navigator.userAgent);
	public static var isIOS : Bool = ~/ipad|iphone|ipod/i.match(Browser.window.navigator.userAgent)
		|| (untyped HaxeRuntime.typeof(navigator.standalone) != 'undefined' && !!Browser.window.navigator.standalone)
		|| (Browser.window.navigator.platform == 'MacIntel' && Browser.window.navigator.maxTouchPoints > 1 && untyped !Browser.window.MSStream);
	public static var isMobile : Bool = ~/webOS|BlackBerry|Windows Phone/i.match(Browser.window.navigator.userAgent) || isIEMobile || isAndroid || isIOS;
	public static var isRetinaDisplay : Bool = getIsRetinaDisplay();
	public static var isHighDensityDisplay : Bool = isRetinaDisplay || getIsHighDensityDisplay();
	public static var isWKWebView : Bool = isIOS && untyped window.webkit && untyped window.webkit.messageHandlers;

	public static var isMacintosh : Bool = ~/Mac/i.match(Browser.window.navigator.platform);
	public static var isWindows : Bool = ~/Win/i.match(Browser.window.navigator.platform);
	public static var isLinux : Bool = ~/Linux/i.match(Browser.window.navigator.platform);

	public static var isDarkMode = Browser.window.matchMedia("(prefers-color-scheme: dark)").matches;
	public static var isMouseSupported = Browser.window.matchMedia("(any-pointer: fine)").matches;

	public static var browserMajorVersion : Int = untyped __js__("function() {
		var version = window.navigator.userAgent.match(/version\\/(\\d+)/i);
		return version && version.length > 1 ? parseInt(version[1]) || 0 : 0;
	}()");

	// IE Mobile on Windows Phones doesn't seem to support the HTML5 canvas drawImage
	// method from video elements (what PIXI ultimately relies on).
	// As of IE Mobile 11 on Windows Phone 8.1 Update 2. Tested on a Microsoft Lumia 735.
	public static var SupportsVideoTexture = !Platform.isIEMobile;
	public static var AccessiblityAllowed =
		Util.getParameter("accessenabled") == "1" ||
		((Platform.isFirefox || Platform.isChrome || Platform.isSafari) && !Platform.isEdge);

	private static function getIsRetinaDisplay() : Bool {
		if (Platform.isMacintosh && Browser.window.matchMedia != null) {
			return untyped __js__("((window.matchMedia && (window.matchMedia('only screen and (min-resolution: 192dpi), only screen and (min-resolution: 2dppx), only screen and (min-resolution: 75.6dpcm)').matches || window.matchMedia('only screen and (-webkit-min-device-pixel-ratio: 2), only screen and (-o-min-device-pixel-ratio: 2/1), only screen and (min--moz-device-pixel-ratio: 2), only screen and (min-device-pixel-ratio: 2)').matches)) || (window.devicePixelRatio && window.devicePixelRatio >= 2)) && /(iPad|iPhone|iPod)/g.test(navigator.userAgent)") || getIsHighDensity();
		} else {
			return false;
		}
	}

	private static function getIsHighDensityDisplay(){
		return untyped __js__("((window.matchMedia && (window.matchMedia('only screen and (min-resolution: 124dpi), only screen and (min-resolution: 1.3dppx), only screen and (min-resolution: 48.8dpcm)').matches || window.matchMedia('only screen and (-webkit-min-device-pixel-ratio: 1.3), only screen and (-o-min-device-pixel-ratio: 2.6/2), only screen and (min--moz-device-pixel-ratio: 1.3), only screen and (min-device-pixel-ratio: 1.3)').matches)) || (window.devicePixelRatio && window.devicePixelRatio > 1.3))");
	}

	private static function getIsWindows() { return isWindows; }
	private static function getIsMacOS() { return isMacintosh; }
	private static function getIsLinux() { return isLinux; }
	private static function getIsAndroid() { return isAndroid; }
	private static function getIsIos() { return isIOS; }
#end
}

