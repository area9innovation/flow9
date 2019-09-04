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
	public static var isMobile : Bool = false;

	public static var isMacintosh : Bool = false;
	public static var isWindows : Bool = false;
	public static var isLinux : Bool = false;

	public static var SupportsVideoTexture = false;
	public static var AccessiblityAllowed = false;
#else
	public static var isAndroid : Bool = ~/android/i.match(Browser.window.navigator.userAgent);
	public static var isIEMobile : Bool = ~/iemobile/i.match(Browser.window.navigator.userAgent);
	public static var isChrome : Bool = ~/chrome|crios/i.match(Browser.window.navigator.userAgent);
	public static var isSafari : Bool = ~/safari/i.match(Browser.window.navigator.userAgent) && !isChrome;
	public static var isIOS : Bool = ~/ipad|iphone|ipod/i.match(Browser.window.navigator.userAgent);
	public static var isIE : Bool = ~/MSIE|Trident/i.match(Browser.window.navigator.userAgent);
	public static var isEdge : Bool = ~/Edge/i.match(Browser.window.navigator.userAgent);
	public static var isFirefox : Bool = ~/firefox/i.match(Browser.window.navigator.userAgent);
	public static var isMobile : Bool = ~/webOS|BlackBerry|Windows Phone/i.match(Browser.window.navigator.userAgent) || isIEMobile || isAndroid || isIOS;

	public static var isMacintosh : Bool = ~/Mac/i.match(Browser.window.navigator.platform);
	public static var isWindows : Bool = ~/Win/i.match(Browser.window.navigator.platform);
	public static var isLinux : Bool = ~/Linux/i.match(Browser.window.navigator.platform);

	// IE Mobile on Windows Phones doesn't seem to support the HTML5 canvas drawImage
	// method from video elements (what PIXI ultimately relies on).
	// As of IE Mobile 11 on Windows Phone 8.1 Update 2. Tested on a Microsoft Lumia 735.
	public static var SupportsVideoTexture = !Platform.isIEMobile;
	public static var AccessiblityAllowed = 
		Util.getParameter("accessenabled") == "1" ||
		((Platform.isFirefox || Platform.isChrome || Platform.isSafari) && !Platform.isMobile && !Platform.isEdge);
#end
}

