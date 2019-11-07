#if js
import js.Browser;
import FlowFontStyle;
import RenderSupportJSPixi;
#end

#if js
enum GraphOp {
	MoveTo(x : Float, y : Float);
	LineTo(x : Float, y : Float);
	CurveTo(x : Float, y : Float, cx : Float, cy : Float);
}
#end

#if flash
import flash.desktop.Clipboard;
import flash.desktop.ClipboardFormats;
import flash.events.Event;
#end

class RenderSupport {
	#if js
	static var CurrentClip : Dynamic;
	static var TempClip : Dynamic;
	static var ImageCache : Map<String,Dynamic>;
	static var PendingImages : Map<String, Array< Dynamic > >;

	private static var typekitTryCount : Int = 0;

	private static var MouseX : Float;
	private static var MouseY : Float;

	static var AriaClips : Array<Dynamic>; // Clips which have WAI ARIA role
	static var AriaDialogsStack : Array<Dynamic>; // The last added is the current modal dialog.

	private static var StageScale : Float;

	private static inline var WebClipInitSize = 100.0;
	#end

	#if flash
	private static var pictureCache: PictureCache;
	private static var pictureSizeCache : Map<String,Array<Float>>; // [width, height]
	static var mouseHidden : Bool;
	private static var finegrainMouseWheelCbs : Array<Float->Float->Void>;
	private static var UrlHashListeners : Array<String -> Void>;
	#end

	public function new() {
		#if flash
		oldinit();
		#end
	}

	#if js
	private static function loadWebFonts() {
		var webfontconfig : Dynamic = haxe.Json.parse(haxe.Resource.getString("webfontconfig"));

		Reflect.setField(webfontconfig, "active", function() { Errors.print("Web fonts are loaded");});
		Reflect.setField(webfontconfig, "loading", function() { Errors.print("Loading web fonts...");});

		WebFont.load(webfontconfig);
	}

	public static function __init__() {
		if (Util.getParameter("oldjs") == "1") {
			oldinit();
		} else {
			untyped __js__ ("window.RenderSupport = window.RenderSupportJSPixi");
		}
	}
	#end

	private static function oldinit() {
		#if js

		// Hide splash
		haxe.Timer.delay( function() {Browser.document.body.style.backgroundImage = "none"; }, 100);
		var indicator : Dynamic = Browser.document.getElementById("loading_js_indicator");
		if (null != indicator) indicator.style.display = "none";

		prepareCurrentClip();
		makeTempClip();
		startMouseListening();
		ImageCache = new Map();
		PendingImages = new Map();
		StageScale = 1.0;

		if ("1" == Util.getParameter("svg")) {
			Errors.print("Using SVG rendering");
			Graphics.svg = true;
		} else {
			Errors.print("Using HTML 5 rendering");
			Graphics.svg = false;
		}

		loadWebFonts();

		AriaClips = new Array<Dynamic>();
		AriaDialogsStack = new Array<Dynamic>();

		addGlobalKeyHandlers();

		attachEventListener(getStage(), "focusin", function() { // Tracking the active element
			// FF doesnot call this but it draws outline correctly - wraps nested elements
            var selected = Browser.document.activeElement;
           	if (selected != null && selected.getAttribute("role") != null) { // Update metrics for outline
           		var h = getElementHeight(selected);
           		var w = getElementWidth(selected);
           		var global_scale = getGlobalScale(selected);
				h = h / global_scale.scale_y;
           		w = w / global_scale.scale_x;
				selected.style.height = "" + h + "px";
           		selected.style.width = "" + w + "px";
           	}
		});

		// Init listener for cross-domain calls
		var receiveMessage = function(e : Dynamic) {
			var hasNestedWindow : Dynamic = null;
			hasNestedWindow = function(iframe : Dynamic, win : Dynamic) {
				try {
					if (iframe.contentWindow == win) return true;
					var iframes : Dynamic = iframe.contentWindow.document.getElementsByTagName("iframe");
					for (i in 0...iframes.length) if (hasNestedWindow(iframes[i], win)) return true;
				} catch( e: Dynamic) { Errors.print(e); /* Likely Cross-Domain restriction */ }

				return false;
			}

			var content_win = e.source;
			var all_iframes = Browser.document.getElementsByTagName("iframe");

			for (i in 0...all_iframes.length) {
				var f : Dynamic = all_iframes[i];
				if (hasNestedWindow(f, content_win)) {
					f.callflow(["postMessage", e.data]);
					return;
				}
			}

			Errors.report("Warning: unknown message source");
		}

		Browser.window.addEventListener('message', receiveMessage);

		#elseif flash

		builtinFonts = new Map();
		builtinFonts.set("Roboto", true);
		builtinFonts.set("RobotoMedium", true);
		builtinFonts.set("MaterialIcons", true);

		// Check if we have a resource with the font names. If so, register all of those
		var fonts = haxe.Resource.getString("fontnames");
		if (fonts != null) {
			for (font in fonts.split("\n")) {
				if (font != "") {
					builtinFonts.set(font, true);
				}
			}
		}
		mouseHidden = false;
		if (pictureCache == null) {
			pictureCache = new PictureCache();
			pictureSizeCache = new Map();
		}
		finegrainMouseWheelCbs = new Array();
		if (flash.external.ExternalInterface.available) {
			flash.external.ExternalInterface.addCallback("onJsScroll", onJsScroll);
		}

		getStage().stageFocusRect = false;

		WebClipListeners = new Array<Dynamic>();
		updateBrowserZoom();

		// URL hash handlers
		UrlHashListeners = new Array<String -> Void>();
		if (flash.external.ExternalInterface.available) {
			flash.external.ExternalInterface.addCallback("onhashchanged", function(hash : String) {
				for (cb in UrlHashListeners) cb(hash);
			});
		}

		addPasteClipboardListener(getStage());
/*
		flash.system.IME.enabled = true;

		var on_ime_composition = function(e) {
			// should be called when IME panel is closed
			Native.println("on_ime_composition! ");
		};

		flash.system.System.ime.addEventListener(flash.events.IMEEvent.IME_COMPOSITION, on_ime_composition);

		try {
			flash.system.IME.conversionMode = flash.system.IMEConversionMode.CHINESE;
		} catch (e : Dynamic) {
			Native.println("crash " + e);
		}

		//flash.system.IME.conversionMode = flash.system.IMEConversionMode.CHINESE;
		Native.println("supported " +  flash.system.IME.isSupported);
		Native.println("enabled " +  flash.system.IME.enabled);
		Native.println("has ime " +  flash.system.Capabilities.hasIME);
		Native.println("conversion mode " + flash.system.IME.conversionMode);
*/
		#end
	}

	public static function getPixelsPerCm() : Float {
		return 96.0/2.54;
	}

	public static function setHitboxRadius(radius : Float) : Bool {
		return false;
	}

	#if flash
	public static function onJsScroll(dx : Float, dy : Float) {
		for (cb in finegrainMouseWheelCbs) {
			cb(dx, dy);
		}
	}

	private static function addPasteClipboardListener(clip : Dynamic) {
		var pasteFromClipboard = function(e)  {
			if(Clipboard.generalClipboard.hasFormat(ClipboardFormats.TEXT_FORMAT)) {
                Native.clipboardData = Clipboard.generalClipboard.getData(ClipboardFormats.TEXT_FORMAT);
            } else if(Clipboard.generalClipboard.hasFormat(ClipboardFormats.HTML_FORMAT)) {
                Native.clipboardData = Clipboard.generalClipboard.getData(ClipboardFormats.HTML_FORMAT);
            } else {
				Native.clipboardData = "";
			}
		};

		clip.addEventListener(Event.PASTE, pasteFromClipboard); //Ctrl+V on stage
	}
	#end

	#if js
	// JavaScript specific private methods
	private static function hideWaitMessage() : Void {
		try {
			Browser.document.getElementById("wait_message").style.display = "none";
		} catch (e : Dynamic) {

		}
	}

	private static inline function updateCSSTransform(clip : Dynamic) {
		var transform =  "translate(" + clip.x + "px," + clip.y + "px) scale(" + clip.scale_x + "," +
			clip.scale_y + ") rotate(" + clip.rot + "deg)";
		clip.style.WebkitTransform = transform;
		clip.style.msTransform = transform;
		clip.style.transform = transform;
	}

	private static function isFirefox() : Bool {
		var useragent : String = Browser.window.navigator.userAgent;
		return useragent.indexOf("Firefox") >= 0;
	}

	private static function isWinFirefox() : Bool {
		var useragent : String = Browser.window.navigator.userAgent;
		return useragent.indexOf("Firefox") >= 0 && useragent.indexOf("Windows") >= 0;
	}

	private static function isTouchScreen() : Bool {
		return Native.isTouchScreen();
	}

	private static function addGlobalKeyHandlers() {
		attachEventListener(getStage(), "keydown", function(e) {
			if (e.which == 13 || e.which == 32 || e.which == 113) { // Enter || space || F2 (some screenreaders catch #13 and #32)
				var active = untyped Browser.document.activeElement;
				if (active != null && isAriaClip(active)){
					simulateClickForClip(active);
                }
            } else if (e.ctrlKey && e.which == 38 /*up*/) {
            	if (StageScale < 2.0) {
            		StageScale = 2.0;
            		Browser.document.body.style.overflow = "auto"; // Show scrollbars
            		setClipScaleX(CurrentClip, StageScale); setClipScaleY(CurrentClip, StageScale);
            	}
        	} else if (e.ctrlKey && e.which == 40 /*dn*/) {
        		if (StageScale > 1.0) {
            		StageScale = 1.0;
            		Browser.document.body.scrollLeft = Browser.document.body.scrollTop = 0;
            		Browser.document.body.style.overflow = "hidden";
            		setClipScaleX(CurrentClip, StageScale); setClipScaleY(CurrentClip, StageScale);
            	}
        	}
		});
	}

	private static function isAriaClip(clip : Dynamic) : Bool {
		var role = clip.getAttribute("role");
		return role == "button" || role == "checkbox" || role == "dialog";
	}

	private static function addAriaClip(clip : Dynamic) : Void {
		var role = clip.getAttribute("role");
		if (role == "dialog") {
			AriaDialogsStack.push(clip);
		} else {
			AriaClips.push(clip);
		}
	}

	private static function removeAriaClip(clip : Dynamic) : Void {
		var role = clip.getAttribute("role");
		if (role == "dialog") {
			AriaDialogsStack.remove(clip);
		} else {
			AriaClips.remove(clip);
		}
	}

	private static function simulateClickForClip(clip : Dynamic) : Void {
		MouseX = getElementX(clip) + 2.0;
		MouseY = getElementY(clip) + 2.0;
		var stage = getStage();
		if (stage.flowmousedown != null) stage.flowmousedown();
		if (stage.flowmouseup != null) stage.flowmouseup();
	}

	private static function prepareCurrentClip() : Void
	{
		CurrentClip = js.Browser.document.getElementById("flow");

		CurrentClip.x = CurrentClip.y = CurrentClip.rot = 0;
		CurrentClip.scale_x = CurrentClip.scale_y = 1.0;
		// The same for stage to have the same behaviour like for other clips
		var stage = getStage();
		stage.x = stage.y = stage.rot = 0;
		stage.scale_x = stage.scale_y = 1.0;

		//
		// For Chrome and FF sometimes there are
		// issues for canvas rendering. Ugly workaraund
		// for that is to hide and show each 1/2 sec to
		// force redrawing
		if ("1" == Util.getParameter("forceredraw")) { // It looks like with CSS transform it is useless
			Errors.report("Turning on workaround for Chrome & FF rendering issue");
			var needs_redraw = false;
			var redraw_timer = new haxe.Timer(500);

			redraw_timer.run = function() {
				if (needs_redraw) {
					CurrentClip.style.display='none';
					CurrentClip.offsetHeight; // no need to store this anywhere, the reference is enough
					CurrentClip.style.display='block';
					needs_redraw = false;
				}
			}

			CurrentClip.addEventListener("DOMNodeInserted", function() { needs_redraw = true; }, true);
		}
	}

	private static function makeTempClip()
	{
		TempClip = makeClip();
		TempClip.setAttribute("aria-hidden", "true"); // Disable reading by AT tools
		TempClip.style.opacity = 0.0;
		TempClip.style.zIndex = -1000;
		js.Browser.document.body.appendChild(TempClip);
	}

	private static inline function attachEventListener(item : Dynamic, event : String, cb : Dynamic) : Void
	{
		if (isFirefox() && event == "mousewheel")
			item.addEventListener("DOMMouseScroll", cb, true)
		else if (item.addEventListener)
			item.addEventListener(event, cb, true);
		else if (untyped item.attachEvent)
			if (item == Browser.window)
				untyped Browser.document.attachEvent("on" + event, cb);
			else
				item.attachEvent("on" + event, cb);

	}

	private static inline function detachEventListener(item : Dynamic, event : String, cb : Dynamic) : Void
	{
		item.removeEventListener(event, cb, false);
	}

	private static function startMouseListening()
	{
		if (!isTouchScreen()) {
			attachEventListener(Browser.window,
				"mousemove",
				function(e) {
					MouseX = untyped e.clientX + Browser.window.pageXOffset;
					MouseY = untyped e.clientY + Browser.window.pageYOffset;
				} );
		} else {
			attachEventListener(Browser.window,
				"touchmove",
				function(e) {
					if ( e.touches.length != 1) return; // Only one finger
					MouseX = untyped e.touches[0].clientX + Browser.window.pageXOffset;
					MouseY = untyped e.touches[0].clientY + Browser.window.pageYOffset;
				} );
			attachEventListener(Browser.window, // There may be touchstart without touchmove before
				"touchstart",
				function(e) {
					if ( e.touches.length != 1) return; // Only one finger
					MouseX = untyped e.touches[0].clientX + Browser.window.pageXOffset;
					MouseY = untyped e.touches[0].clientY + Browser.window.pageYOffset;
				} );
		}
	}

	// Cross brouser text selection disabling
	private static function setSelectable(element : Dynamic, selectable : Bool) : Void
	{
		if (selectable) {
			element.style.WebkitUserSelect = "text";
			element.style.MozUserSelect = "text";
			element.style.MsUserSelect = "text";
		} else {
			element.style.WebkitUserSelect = "none";
			element.style.MozUserSelect = "none";
			element.style.MsUserSelect = "none";
		}
	}

	private static function getElementWidth(el : Dynamic) : Float
	{
		var width : Dynamic = el.getBoundingClientRect().width;
		var childs : Array<Dynamic> = el.children;

		if (childs == null) return width;

		for (c in childs) {
			var cw = getElementWidth(c) + (c.x != null ? c.x : 0.0);
			if (cw > width) width = cw;
		}

		return width;
	}

	private static function getElementHeight(el : Dynamic) : Float {
		var height : Dynamic = el.getBoundingClientRect().height;
		var childs : Array<Dynamic> = el.children;

		if (childs == null) return height;

		for (c in childs) {
			var ch = getElementHeight(c) + (c.y != null ? c.y : 0.0);
			if (ch > height) height = ch;
		}

		return height;
	}

	private static function getElementX( el : Dynamic) : Float {
		if (el == Browser.window) return 0;
		var rect : Dynamic = el.getBoundingClientRect();
		return rect.left;
	}

	private static function getElementY( el : Dynamic) : Float {
		if (el == Browser.window) return 0;
		var rect : Dynamic = el.getBoundingClientRect();
		return rect.top;
	}

	private static function getGlobalScale( el : Dynamic) : Dynamic {
		var scale : Dynamic = {scale_x : 1.0, scale_y : 1.0};

		while (el != null && el.scale_x != null && el.scale_y != null) {
			scale.scale_x *= el.scale_x;
			scale.scale_y *= el.scale_y;
			el = el.parentNode;
		}

		return scale;
	}

	private static function makeCanvasWH(w : Int, h : Int) : Dynamic {
		var canvas : Dynamic = Browser.document.createElement("canvas");
		canvas.height = h;
		canvas.width = w;
		canvas.x0 = canvas.y0 = 0.0;
		return canvas;
	}

	public static function makeCSSColor(color : Int, alpha : Float) : Dynamic
	{
		return "rgba(" + ((color >> 16) & 255)  + "," + ((color >> 8) & 255) + "," + (color & 255) + "," + (alpha) + ")" ;
	}

	private static function loadImage(clip : Dynamic, url : String, error_cb : Dynamic, metricsFn : Dynamic) : Void
	{
		var image_loaded = function(cl : Dynamic, mFn : Dynamic, img : Dynamic) {
				mFn(img.width, img.height);
				cl.appendChild(img.cloneNode(false));
		};

		if (ImageCache.exists(url)) {
			image_loaded(clip, metricsFn, ImageCache.get(url));
		} else if ( PendingImages.exists(url) ) {
			PendingImages.get(url).push( {c: clip, m: metricsFn, e : error_cb } ); // Add new listener
		} else {
			PendingImages.set(url, [{c: clip, m: metricsFn, e : error_cb }]);

			var img = untyped __js__ ("new Image()");

			img.onload = function() {
				ImageCache.set(url, img);

				var listeners : Array<Dynamic> = PendingImages.get(url);

				for (i in 0...listeners.length) {
					var listener = listeners[i];
					image_loaded(listener.c, listener.m, img);
				}

				PendingImages.remove(url);
			};

			img.onerror = function() {
				var listeners : Array<Dynamic> = PendingImages.get(url);
				for (i in 0...listeners.length)
					listeners[i].e();
				PendingImages.remove(url);
			};

			img.src = url + "?" + StringTools.htmlEscape("" + Date.now().getTime()); // Force onload event
		}
	}

	private static function loadSWF(clip : Dynamic, url : String, error_cb : Dynamic, metricsFn : Dynamic) : Void
	{
		// Due to crossdomain restrictions only relative links are allowed for SWFs
		// Try to convert absolute url to relative
		// It is supposed that currentdomain/path.swf is accessible for http://www.domain/path.swf
		if (StringTools.startsWith(url, "http://www")) {
			var domain_and_path = url.substr(7);
			url = domain_and_path.substr(domain_and_path.indexOf("/"));
		}

		var swf : Dynamic = Browser.document.createElement("OBJECT");
		swf.type = "application/x-shockwave-flash";
		swf.data = url + "?" + StringTools.htmlEscape("" + Date.now().getTime()); // Force onload event;
		clip.appendChild(swf);

		var load_time = Date.now().getTime();
		var try_swf_access = null;
		try_swf_access = function() {
			if ((Date.now().getTime() - load_time) > 5000)  {
				error_cb();
				return;
			}

			if (swf == null || swf.TGetProperty == null) {
				haxe.Timer.delay(try_swf_access, 450); // Try again
				return;
			}

			var width = 4.0 / 3.0 * swf.TGetProperty("/", 8); // pt -> px
			var height = 4.0 / 3.0 * swf.TGetProperty("/", 9);

			swf.style.width = "" + width + "px";
			swf.style.height = "" + height + "px";

			metricsFn(width, height);
		}

		haxe.Timer.delay( try_swf_access, 450 );
	}
	#end // #if js

	// Exported methods
	// setAccessAttributes(clip, type {"button" | "live" | "checkbox"}, description, tooltip, tabindex)
	// native setAccessAttributes : io (native, type : string, description : string, tooltip : string, tabindex : int) -> void = RenderSupport.setAccessAttributes;

	static public function setAccessCallback(clip : Dynamic, callback : Void -> Void) : Void { /* STUB */ }

	#if flash
	static private var UpdateAccessTimer : haxe.Timer;
	#end
	static public function setAccessAttributes(clip : Dynamic, properties : Array<Array<String>>) : Void {
		#if js
			var setClipRole = function(role : String) {
				if (role == "live") {
					clip.setAttribute("aria-live", "polite");
					clip.setAttribute("relevant", "additions");
					clip.setAttribute("role", "aria-live");
				} else {
					clip.setAttribute("role", role);
				}
			}

			for (p in properties) {
				var key = p[0]; var value : String = p[1];
				if (key == "role") {
					setClipRole(value);
				} else if (key == "tooltip") {
					clip.setAttribute("title", value);
				} else if (key == "tabindex" && Std.parseInt(value) >= 0) {
					if (clip.input) clip.children[0].setAttribute("tabindex", Std.parseInt(value)) else clip.setAttribute("tabindex", Std.parseInt(value));
				} else if (key == "description") {
					clip.setAttribute("aria-label", value);
				} else if (key == "state") {
					if (value == "checked") clip.setAttribute("aria-checked", "true");
					else if (value == "unchecked") clip.setAttribute("aria-checked", "false");
				} else if (key == "selectable") {
					setSelectable(clip, "true" == value);
				}
			}
		#elseif flash
			var setClipDescription = function(descr : String) {
				if (flash.accessibility.Accessibility.active)
				{
					if (UpdateAccessTimer != null)
						UpdateAccessTimer.stop();

					UpdateAccessTimer = haxe.Timer.delay( function() {
						flash.accessibility.Accessibility.updateProperties();
					}, 1000 );

					// To inspect these tags, consider
					// http://accessibility.linuxfoundation.org/a11yweb/util/accprobe/

					var ap = new flash.accessibility.AccessibilityProperties();
					ap.description = descr;
					clip.accessibilityProperties = ap;
				}
			}

			for (p in properties) {
				var key = p[0]; var value = p[1];
				if (key == "description") {
					setClipDescription(value);
				}
			}

		#end

	}

	// native currentClip : () -> flow = FlashSupport.currentClip;
	public static function currentClip() : Dynamic  {
		#if js
			return CurrentClip;
		#elseif flash
			return flash.Lib.current;
		#else
	     	return null;
		#end
	}

	// native enableResize() -> void;
	public static function enableResize() : Void {
		#if js
			hideWaitMessage(); // The first flow render() was called -> hide message
		#elseif flash
			var stage = flash.Lib.current.stage;
			stage.scaleMode = flash.display.StageScaleMode.NO_SCALE;
			stage.align = flash.display.StageAlign.TOP_LEFT;
		#end
	}

	public static function getStageWidth() : Float {
		#if js
			return Browser.window.innerWidth; // IE 9+ supports this (but not in quirks mode!)
		#elseif flash
			return flash.Lib.current.stage.stageWidth;
		#else
			return 0.0;
		#end
	}

	public static function getStageHeight() : Float {
		#if js
			return  Browser.window.innerHeight;
		#elseif flash
			return flash.Lib.current.stage.stageHeight;
		#else
			return 0.0;
		#end
	}

	// native makeTextfield : (fontfamily : String) -> native
	public static function makeTextField(fontfamily : String) : Dynamic  {
		#if js
			var field : Dynamic = makeClip();
			TempClip.appendChild(field); // To have width and height field must be visible
			return field;
		#elseif flash
			var textfield = new flash.text.TextField();
			textfield.selectable = false;
			textfield.sharpness = -400;
			textfield.antiAliasType = flash.text.AntiAliasType.ADVANCED;
			textfield.gridFitType = flash.text.GridFitType.NONE;
			textfield.autoSize = flash.text.TextFieldAutoSize.LEFT;
			textfield.multiline = true;
			textfield.x = -2;
			textfield.y = -2;
			return textfield;
		#else
			return null;
		#end
	}

	#if js
	private static function setStyleByFlowFont(style : Dynamic, fontfamily : String) : Void {
		var fs : FontStyle = FlowFontStyle.fromFlowFont(fontfamily);
		if (fs != null) {
			style.fontFamily = fs.family;
			style.fontWeight = fs.weight;
			style.fontStyle = fs.style;
		} else {
			style.fontFamily = fontfamily;
		}
	}
	#end

	public static function setTextAndStyle(
		textfield : Dynamic, text : String, fontfamily : String,
		fontsize : Float, fontweight : Int, fontslope : String,
		fillcolour : Int, fillopacity : Float, letterspacing : Float,
		backgroundcolour : Int, backgroundopacity : Float
	) : Dynamic  {
		#if js
			// Make font smaller to look as flash one.
			// It seems flash font engine use special spacing or weight
			fontsize = fontsize * 0.97;
			var style = if (textfield.input) textfield.children[0].style else textfield.style;
			setStyleByFlowFont(style, fontfamily);

			style.fontSize = "" + Math.floor( fontsize ) + "px";
			style.opacity = "" + fillopacity;
			style.color = "#" + StringTools.hex(fillcolour, 6);
			style.fontWeight = fontweight;
			style.fontStyle = fontslope;
			if (letterspacing != 0)
				style.letterSpacing = "" + letterspacing + "px";

			if (backgroundopacity != 0.0)
				style.backgroundColor = "#" + StringTools.hex(backgroundcolour, 6);

			textfield.font_size = fontsize; // Store it to scale later

			if (textfield.input) {
				if (textfield.children[0].value != text) textfield.children[0].value = text;
			} else {
				if (textfield.innerHTML != text)
					textfield.innerHTML = text;

				patchTextFormatting(textfield);
			}
			return null;
		#elseif flash
			// Special flash names for fonts
			if (fontfamily == "sans-serif") fontfamily = "_sans";

			// Set the embedded flag for the fonts we recognize as built-in
			textfield.embedFonts = isEmbeddedFont(fontfamily);

			if (textfield.type == TextFieldType.INPUT) {
				setHtmlText(textfield, text, fontfamily, fontsize, letterspacing);

				setTextColors(textfield, fillcolour, fillopacity, backgroundcolour, backgroundopacity);
			} else {
				setTextColors(textfield, fillcolour, fillopacity, backgroundcolour, backgroundopacity);

				setHtmlText(textfield, text, fontfamily, fontsize, letterspacing);
			}
			return null;
		#else
			return null;
		#end
	}

	public static function setTextDirection(textfield : Dynamic, direction : String) : Void {
		#if js
			var input_ = textfield.input ? textfield.children[0] : textfield;
			input_.style.direction = switch (direction) {
				case "RTL" : "rtl";
				case "rtl" : "rtl";
				default : "ltr";
			}
		#elseif flash
			// Not sure there are things to do, hence flash target is obsolete.
		#end
	}

	#if flash
	private static function isEmbeddedFont(fontfamily : String) {
		// Special cases for a few universal fonts, which are not embedded
		// if (fontfamily != "_sans" && fontfamily != "Courier") return true;

		return builtinFonts.get(fontfamily) == true;
	}
	#end

	#if js
	private static function patchTextFormatting(node : Dynamic) : Void {
		if (node.tagName == "FONT") {
			node.style.fontSize = node.size + "px";
			node.size = "";
			setStyleByFlowFont(node.style, node.face);
			node.face = "";
		}

		var childs : Array<Dynamic> = node.children;
		if (childs.length == 0) {
			node.innerHTML = StringTools.replace(node.innerHTML , " ", "&nbsp;");
			node.innerHTML = StringTools.replace(node.innerHTML, "\n", "<br>");
		} else {
			for (c in childs) patchTextFormatting(c);
		}
	}
	#end

	#if flash
	private static function setTextColors(textfield : Dynamic, fillcolour : Int, fillopacity : Float, backgroundcolour : Int, backgroundopacity : Float) : Void {
		// TODO: Use a tag for this instead. Requires hex printing
			textfield.textColor = fillcolour;
			if (fillopacity != 1.0) textfield.alpha = fillopacity;

			if (backgroundopacity != 0.0) {
				textfield.backgroundColor = backgroundcolour;
				textfield.background = true;
			}
	}

	private static function setHtmlText(textfield : Dynamic, text : String, fontfamily : String, fontsize : Float, letterspacing : Float) : Void {
		var letterspacingParameter : String = "";

		if (letterspacing != 0) {
			letterspacingParameter = ' letterspacing="' + letterspacing + '"';
		}

		if (text == "") {  // trick for initialization by empty string:
			var html = '<font face="' + fontfamily + '" size="' + fontsize + '"' + letterspacingParameter + '>' + ' ' + '</font>';
			textfield.htmlText = html;
			textfield.setSelection(textfield.length, textfield.length);
			textfield.text = "";
		} else {
			var html = '<font face="' + fontfamily + '" size="' + fontsize + '"' + letterspacingParameter + '>' + text + '</font>';
			if (textfield.htmlText != html) { textfield.htmlText = html; }
		}
	}
	#end

	static public var builtinFonts : Map<String, Bool>;

	public static function setAdvancedText(textfield : Dynamic, sharpness : Int, antialiastype : Int, gridfittype : Int) : Void  {
		#if flash
			textfield.sharpness = sharpness;

			if (antialiastype == 0)
				textfield.antiAliasType = flash.text.AntiAliasType.NORMAL;
			else if (antialiastype == 1)
				textfield.antiAliasType = flash.text.AntiAliasType.ADVANCED;

			if (gridfittype == 0)
				textfield.gridFitType = flash.text.GridFitType.NONE;
			else if (gridfittype == 1)
				textfield.gridFitType = flash.text.GridFitType.PIXEL;
			else if (gridfittype == 2)
				textfield.gridFitType = flash.text.GridFitType.SUBPIXEL;
		#end
	}

	public static function makeVideo(width : Int, height : Int, metricsFn : Int -> Int -> Void, durationFn : Float -> Void) : Array<Dynamic> {
		#if flash
			var strictSize = width != 0 && height != 0;
			try {
				var vid = new flash.media.Video(width, height);
				var nc = new flash.net.NetConnection();
				nc.connect(null);
				var ns = new flash.net.NetStream(nc);

				if (strictSize)
					metricsFn(width, height);

				ns.client = {
					//This event is triggered after a call to play()
					onMetaData: function (o) {
						if (!strictSize) {
							try {
								if (o != null && o.width != 0) {
									vid.width = o.width;
								}
								if (o != null && o.height != 0) {
									vid.height = o.height;
								}
								metricsFn(cast(vid.width), cast(vid.height));
							} catch (e:Dynamic) {}
						}

						try {
							if (o != null && o.duration != 0)
								durationFn(cast(o.duration+0.0));
						} catch (e : Dynamic) {}
					},
					// Prevent error #2044: Unhandled AsyncErrorEvent
					onCuePoint: function (o) { },
					onXMPData: function (o) { }
				}

				vid.attachNetStream(ns);
				vid.smoothing = true;
				return [ns, vid];
			} catch (e : Dynamic) {
				return [null, null];
			}
		#elseif js
			var ve : Dynamic = Browser.document.createElement("VIDEO");
			if (width > 0.0) ve.width = width;
			if (height > 0.0) ve.height = height;
			ve.addEventListener('loadedmetadata', function(e : Dynamic) {
  				durationFn(ve.duration);
  				metricsFn(ve.videoWidth, ve.videoHeight);
			}, false);
			return [ve, ve];
		#else
			return [null, null];
		#end
	}

	public static function setVideoVolume(str: Dynamic, volume : Float) : Void {
		#if js
			str.volume = volume;
		#elseif flash
			var stream: flash.net.NetStream = str;
			stream.soundTransform = new flash.media.SoundTransform(volume);
		#end
	}

	public static function setVideoLooping(str: Dynamic, loop : Bool) : Void {
		// STUB; only implemented in C++/OpenGL
	}

	public static function setVideoControls(str: Dynamic, controls : Dynamic) : Void {
		// STUB; only implemented in C++/OpenGL
	}

	public static function setVideoSubtitle(str: Dynamic, text : String, size : Float, color : Int) : Void {
		// STUB; only implemented in C++/OpenGL
	}

	public static function playVideo(str : Dynamic, filename : String, startPaused : Bool) : Void {
		#if js
			str.src = filename;
			if (!startPaused) str.play();
		#elseif flash
			var stream : flash.net.NetStream = str;
			stream.play(filename);
			if (startPaused)
				stream.pause();
		#end
	}

	public static function seekVideo(str : Dynamic, seek : Float) : Void  {
		#if js
			str.currentTime = seek;
		#elseif flash
			var stream : flash.net.NetStream = str;
			stream.seek(seek);
		#end
	}

	public static function getVideoPosition(str : Dynamic) : Float  {
		#if flash
			var stream : flash.net.NetStream = str;
			return stream.time;
		#elseif js
			return str.currentTime;
		#else
			return 0.0;
		#end
	}

	public static function pauseVideo(str : Dynamic) : Void {
		#if js
			str.pause();
		#elseif flash
			var stream : flash.net.NetStream = str;
			stream.pause();
		#end
	}

	public static function resumeVideo(str : Dynamic) : Void {
		#if js
			str.play();
		#elseif flash
			var stream : flash.net.NetStream = str;
			stream.resume();
		#end
	}

	public static function closeVideo(str : Dynamic) : Void {
		#if js
		#elseif flash
			var stream : flash.net.NetStream = str;
			stream.close();
		#end
	}

	public static function getTextFieldWidth(textfield : Dynamic) : Float {
		#if js
			if (textfield.input == true)
				return textfield.width;
			else
				return textfield.offsetWidth;
		#elseif flash
			var textfield_ : flash.text.TextField = textfield;
			return textfield_.width - 4.0;
		#else
			return 0.0;
		#end
	}

	public static function setTextFieldWidth(textfield : Dynamic, width : Float) : Void {
		#if js
			if (textfield.input) {
				textfield.width = width;
				textfield.children[0].style.width = "" + width + "px";
			}
		#elseif flash
			var textfield_ : flash.text.TextField = textfield;
			textfield.width = width + 4.0;
		#end
	}

	public static function getTextFieldHeight(textfield : Dynamic) : Float {
		#if js
			if (textfield.input == true)
				return textfield.height;
			else
				return textfield.offsetHeight;
		#elseif flash
			var textfield_ : flash.text.TextField = textfield;
			return textfield_.height - 4.0;
		#else
			return 0.0;
		#end
	}

	public static function setTextFieldHeight(textfield : Dynamic, height : Float) : Void {
		#if js
			if (textfield.input) {
				textfield.height = height;
				textfield.children[0].style.height = "" + height + "px";
			}
		#elseif flash
			var textfield_ : flash.text.TextField = textfield;
			textfield_.height = height + 4.0;
		#end
	}

	public static function setAutoAlign(textfield : Dynamic, autoalign : String) : Void {
		#if js
			var input_ = textfield.input ? textfield.children[0] : textfield;
			input_.style.textAlign = switch (autoalign) {
				case "AutoAlignLeft" : "left";
				case "AutoAlignRight" : "right";
				case "AutoAlignCenter" : "center";
				case "AutoAlignNone" : "none";
				default : "left";
			}
		#elseif flash
			var textfield_ : flash.text.TextField = textfield;
			if (autoalign == "AutoAlignLeft") {
				textfield_.autoSize = flash.text.TextFieldAutoSize.LEFT;
			} else if (autoalign == "AutoAlignRight") {
				textfield_.autoSize = flash.text.TextFieldAutoSize.RIGHT;
			} else if (autoalign == "AutoAlignCenter") {
				textfield_.autoSize = flash.text.TextFieldAutoSize.CENTER;
			} else if (autoalign == "AutoAlignNone") {
				textfield_.autoSize = flash.text.TextFieldAutoSize.NONE;
			} else {
				Errors.report("Unknown AutoAlign type: " + autoalign);
			}
		#end
	}

	public static function setTextInput(textfield : Dynamic) : Void  {
		#if js
			var input : Dynamic = Browser.document.createElement("INPUT");
			input.type = "text";
			textfield.input = true;
			textfield.appendChild(input);
		#elseif flash
			textfield.tabEnabled = true;
			textfield.selectable = true;
			textfield.wordWrap = true; // wordWrap is the same as fixed width
			textfield.multiline = false; // multiline allows growing in height
			textfield.alwaysShowSelection = true;
			textfield.type = flash.text.TextFieldType.INPUT;
		#end
	}

	public static function setTextInputType(textfield : Dynamic, type : String) : Void {
		#if js
			if (textfield.input) {
				textfield.children[0].type = type;
			}
		#elseif flash
			var textfield_ : flash.text.TextField = textfield;
			switch (type.toLowerCase()) {
				case "password": textfield_.displayAsPassword = true;
				case "number": textfield_.restrict = "0-9\\-\\.\\+"; //number type in js allow to use "+" in input
				case "tel": textfield_.restrict = "0-9\\+"; //should we allow ".", " ", "/", "(", ")", "-" ?
				case "text": textfield_.restrict = null;
				case "url": textfield_.restrict = null;
				case "email": textfield_.restrict = null;
				case "search": textfield_.restrict = null;
			}
		#end
	}

	#if flash
	private static var TextInputFilters : Map< flash.text.TextField, Array<String -> Bool> > = new Map< flash.text.TextField, Array<String -> Bool> >();
	public static function addTextInputFilter(textfield : Dynamic, filter : String -> Bool) : Void -> Void {
		var old_content = textfield.text;
		var cb = function(e : Dynamic) {
			var t = textfield.text;
			var filters : Array<String -> Bool> = TextInputFilters[textfield];
			for (f in filters)
				if (!f(t)) {
					textfield.text = old_content;
					return;
				}
			old_content = t;
		};

		if (!TextInputFilters.exists(textfield)) {
			TextInputFilters.set(textfield, new Array());
			textfield.addEventListener("change", cb);
		}

		TextInputFilters[textfield].push(filter);

		return function() {
			TextInputFilters[textfield].remove(filter);
			if (TextInputFilters[textfield].length == 0) {
				TextInputFilters.remove(textfield);
				textfield.removeEventListener("change", cb);
			}
		};
	}
	#end

	public static function setTabIndex(textfield : Dynamic, index : Int) : Void {
		#if js
			if (index >= 0) {
				if (textfield.input) textfield.children[0].setAttribute("tabindex", index) else textfield.setAttribute("tabindex", index);
			}
		#elseif flash
			var textfield_ : flash.text.TextField = textfield;
			textfield_.tabIndex = index;
		#end
	}

	public static function setTabEnabled(textfield : Dynamic, enabled : Bool) : Void {
		#if js
			// stub;
		#elseif flash
			var textfield_ : flash.text.TextField = textfield;
			textfield_.tabEnabled = enabled;
		#end
	}

	public static function getContent(textfield : Dynamic) : String {
		#if js
			if (textfield.input)
				return textfield.children[0].value;
			else
				return textfield.innerHTML;
		#elseif flash
			var textfield_ : flash.text.TextField = textfield;

			var t = textfield_.text;
			t = StringTools.replace(t, "\r\n", "\n");
			t = StringTools.replace(t, "\r", "\n");

			return t;
		#else
			return "";
		#end
	}

	public static function getCursorPosition(textfield : Dynamic) : Int {
		#if flash
			var textfield_ : flash.text.TextField = textfield;
			return textfield_.caretIndex;
		#elseif js
			return getCaret(textfield.children[0]);
		#else
			return 0;
		#end
	}

	#if js
	static function getCaret(el : Dynamic) : Int {
		if (untyped el.selectionStart) {
			return el.selectionStart;
		} else if (untyped Browser.document.selection) {
			el.focus();

			var r : Dynamic = untyped Browser.document.selection.createRange();
			if (r == null) {
				return 0;
			}

			var re = el.createTextRange();
			var rc = re.duplicate();
			re.moveToBookmark(r.getBookmark());
			untyped rc.setEndPoint('EndToStart', re);
			return rc.text.length;
		}
		return 0;
	}

	#end

	public static function getFocus(clip : Dynamic) : Bool {
		#if flash
			return flash.Lib.current.stage.focus == clip;
		#elseif js
			var item = clip.input ? clip.children[0] : clip.focus();
			return Browser.document.activeElement == item;
		#else
			return false;
		#end
	}

	public static function getScrollV(textfield : Dynamic) : Int {
		#if flash
			var textfield_ : flash.text.TextField = textfield;
			return textfield_.scrollV;
		#else
			return 0;
		#end
	}

    public static function setScrollV(textfield : Dynamic, suggestedPosition : Int) : Void {
		#if js
		#elseif flash
			var textfield_ : flash.text.TextField = textfield;
			var numLines = textfield_.numLines;

			var positivePosition = if (suggestedPosition < 1) 1 else suggestedPosition;
			var newPosition = if (positivePosition > numLines) numLines else positivePosition;

			textfield_.scrollV = newPosition;
		#end
	}

	public static function getBottomScrollV(textfield : Dynamic) : Int {
		#if flash
			var textfield_ : flash.text.TextField = textfield;
			return textfield_.bottomScrollV;
		#else
			return 0;
		#end
	}

	public static function getNumLines(textfield : Dynamic) : Int {
		#if flash
			var textfield_ : flash.text.TextField = textfield;
			return textfield_.numLines;
		#else
			return 0;
		#end
	}

	public static function setFocus(clip : Dynamic, focus : Bool) : Void {
		#if js
			// Focusing on something from an event handler that,
			// itself, grants focus, is always problematic.
			// The general solution is to set focus after a timeout:
			haxe.Timer.delay( function() {
				var item = clip.input ? clip.children[0] : clip;
				if (focus) item.focus() else item.blur();
			}, 10);
		#elseif flash
			if (focus) {
				flash.Lib.current.stage.focus = clip;
				try {
					var textfield : flash.text.TextField = cast(clip);
					textfield.setSelection(0, textfield.length);
				} catch (e : Dynamic) {
					// This is fine, we want to be able to set the focus to other things than textfields
					// to make sure we keep focus inside Flash even when a Textinput with focus is
					// removed
				}
			} else {
				if (flash.Lib.current.stage.focus == clip)
					flash.Lib.current.stage.focus = null;
			}
		#end
	}

	public static function setMultiline(clip : Dynamic, multiline : Bool) : Void {
		#if js
		if (clip.input && multiline && !clip.multiline) {
			clip.removeChild(clip.children[0]); // Replace input with textarea
			var textarea : Dynamic = Browser.document.createElement("TEXTAREA");
			if (clip.width) textarea.style.width = "" + clip.width + "px";
			if (clip.height) textarea.style.height = "" + clip.height + "px";
			clip.appendChild(textarea);
			clip.multiline = true;
		}
		#elseif flash
			var textfield : flash.text.TextField = cast(clip);
			textfield.multiline = multiline;
		#end
	}

	public static function setWordWrap(clip : Dynamic, wordWrap : Bool) : Void {
		#if js
		#elseif flash
			var textfield : flash.text.TextField = cast(clip);
			textfield.wordWrap = wordWrap;
		#end
	}

	public static function setDoNotInvalidateStage(clip : Dynamic, value : Bool) : Void {
	}

	public static function getSelectionStart(textfield : Dynamic) : Int {
		#if flash
			var textfield_ : flash.text.TextField = textfield;
			return textfield_.selectionBeginIndex;
		#elseif js
			return (textfield.input == true) ? textfield.children[0].selectionStart : 0;
		#else
			return 0;
		#end
	}

	public static function getSelectionEnd(textfield : Dynamic) : Int {
		#if flash
			var textfield_ : flash.text.TextField = textfield;
			return textfield_.selectionEndIndex;
		#elseif js
			return (textfield.input == true) ? textfield.children[0].selectionEnd : 0;
		#else
			return 0;
		#end
	}

	public static function setSelection(textfield : Dynamic, start : Int, end : Int) : Void {
		#if js
			if (textfield.input == true) {
				haxe.Timer.delay( function() { // Workaround for Chrome to not fire blur event
					if (Browser.document.activeElement == textfield.children[0])
						textfield.children[0].setSelectionRange(start, end);
				}, 120 );
		}
		#elseif flash
			var textfield_ : flash.text.TextField = textfield;
			textfield_.setSelection(start, end);
		#end
	}

	public static function setReadOnly(textfield: Dynamic, readOnly: Bool) : Void {
		#if js
		if (textfield.input == true)
			textfield.children[0].disabled = readOnly;
		#elseif flash
			var textfield_ : flash.text.TextField = textfield;
			textfield_.type = readOnly ? flash.text.TextFieldType.DYNAMIC : flash.text.TextFieldType.INPUT;
		#end
	}

	public static function setMaxChars(textfield : Dynamic, maxChars : Int) : Void {
		#if js
			if (textfield.input)
				textfield.children[0].maxLength = maxChars;
		#elseif flash
			var textfield_ : flash.text.TextField = textfield;
			textfield_.maxChars = maxChars;
		#end
	}

	// native addChild : (parent : native, child : native) -> void
	public static function addChild(parent : Dynamic, child : Dynamic) : Void {
		#if js
			if (child == null || parent == null) return; // Just skip this case to avoid exception for video etc.
			parent.appendChild(child);

			if (isAriaClip(child))	addAriaClip(child);
		#elseif flash
			parent.addChild(child);
		#end
	}

	// native removeChild : (parent : native, child : native) -> void
	public static function removeChild(parent : Dynamic, child : Dynamic) : Void {
		#if js
			try {
				if (isAriaClip(child))	removeAriaClip(child);

				parent.removeChild(child);
			} catch (e : Dynamic) {
				// allow removing something that was already removed or similar corner-case errors
			}
		#elseif flash
			var parent_ : flash.display.Sprite = parent;
			try {
				parent_.removeChild(child);
			} catch (e : Dynamic) {
				// allow removing something that was already removed or similar corner-case errors
			}
		#end
	}

	public static function makeClip() : Dynamic  {
		#if js
			var clip : Dynamic = Browser.document.createElement("div");

			// Position and scaling members
			clip.x = 0.0;
			clip.y = 0.0;
			clip.scale_x = 1.0;
			clip.scale_y = 1.0;
			clip.rot = 0.0;

			return clip;
		#elseif flash
			var s = new flash.display.Sprite();
			s.mouseEnabled = false;
			// s.mouseChildren = false; This is too much, and we can not get it to work
			return s;
		#else
			return null;
		#end
	}

    public static function setClipCallstack(clip : Dynamic, callstack : Dynamic) : Void {
        // stub
    }

	public static function setClipX(clip : Dynamic, x : Float) : Void {
		#if js
			if (clip.x != x) {
				clip.x = x;
				updateCSSTransform(clip);
			}
		#elseif flash
			var parent : flash.display.DisplayObject = clip;
			if (Reflect.hasField(parent, "htmlText")) x -= 2.0; // Textfields need a -2.0 offset
			if (parent.x != x)  parent.x = x;
		#end
	}

	public static function setClipY(clip : Dynamic, y : Float) : Void {
		#if js
			if (clip.y != y) {
				clip.y = y;
				updateCSSTransform(clip);
			}
		#elseif flash
			var parent : flash.display.DisplayObject = clip;
			if (Reflect.hasField(parent, "htmlText")) y -= 2.0;
			if (parent.y != y) parent.y = y;
		#end
	}

	public static function setClipScaleX(clip : Dynamic, scale_x : Float) : Void {
		#if js
			if (clip.iframe != null) { // Not scale but resize it
				if (isIOS())
					clip.style.width = scale_x * WebClipInitSize + "px";
				clip.iframe.width = scale_x * WebClipInitSize;
			} else {
				if (clip.scale_x != scale_x) {
					clip.scale_x = scale_x;
					updateCSSTransform(clip);
				}
			}
		#elseif flash
			var parent : flash.display.DisplayObject = clip;
			if (parent.scaleX != scale_x )  parent.scaleX = scale_x;
		#end
	}

	public static function setClipScaleY(clip : Dynamic, scale_y : Float) : Void {
		#if js
			if (clip.iframe != null) {
				if (isIOS())
					clip.style.height = scale_y * WebClipInitSize + "px";
				clip.iframe.height = scale_y * WebClipInitSize;
			} else {
				if (clip.scale_y != scale_y) {
					clip.scale_y = scale_y;
					updateCSSTransform(clip);
				}
			}
		#elseif flash
			var parent : flash.display.DisplayObject = clip;
			if (parent.scaleY != scale_y )  parent.scaleY = scale_y;
		#end
	}

	public static function setClipRotation(clip : Dynamic, r : Float) : Void {
		#if js
		if (r != clip.rot) {
			clip.rot = r;
			updateCSSTransform(clip);
		}
		#elseif flash
			var parent : flash.display.DisplayObject = clip;
			if (parent.rotation != r)  parent.rotation = r;
		#end
	}

	public static function setClipAlpha(clip : Dynamic, a : Float) : Void {
		#if js
			clip.style.opacity = a;
			if (a <= 0.01) // hide clip
				clip.className = "hiddenByAlpha";
			else if (clip.className == "hiddenByAlpha")
				clip.className = "";

		#elseif flash
			var parent : flash.display.DisplayObject = clip;
			if (parent.alpha != a)  parent.alpha = a;
		#end
	}

	public static function setClipMask(clip : Dynamic, mask : Dynamic) : Void {
		#if js
			mask.style.display = "none"; // Just hide mask
		#elseif flash
			var clip_ : flash.display.DisplayObject = clip;
			var mask_ : flash.display.DisplayObject = mask;
			clip_.cacheAsBitmap = true; // needed for correct masking
			mask_.cacheAsBitmap = true;
			clip_.mask = mask_;
		#end
	}

	public static function getStage() : Dynamic  {
		#if js
			return Browser.window;
		#elseif flash
			return flash.Lib.current.stage;
		#else
			return null;
		#end
	}

	public static function addKeyEventListener(
		clip : Dynamic,
		event : String,
		fn : String -> Bool -> Bool -> Bool -> Bool -> Int -> (Void -> Void) -> Void) : Void -> Void {

		#if js
			// See
			// http://unixpapa.com/js/key.html
			var keycb = function(e) {
					var shift = e.shiftKey;
					var alt = e.altKey;
					var ctrl = e.ctrlKey;
					var meta = e.metaKey;
					var s : String = "";

					if (e.which == 13) {
						var active = untyped Browser.document.activeElement;
						if (active != null && isAriaClip(active)) return; // Donot call cb if there is selected item
						s = "enter";
					} else if (e.which == 27)
						s = "esc";
					else if (e.which == 9)
						s = "tab";
					else if (e.which == 16) // Modifier flag also will be set
						s = "shift";
					else if (e.which == 17) // Modifier flag also will be set
						s = "ctrl";
					else if (e.which == 18) // Modifier flag also will be set
						s = "alt";
					//TODO: support meta
					//else if (e.which == ??)
					//	s = "??"
					else if (e.which == 37)
						s = "left";
					else if (e.which == 38)
						s = "up";
					else if (e.which == 39)
						s = "right";
					else if (e.which == 40)
						s = "down";
					else if (e.which == 46)
						s = "delete";
					else if (e.which >= 112 && e.which <= 123)
						s = "F" + (e.which - 111);
					else
						s = String.fromCharCode(e.which);

					fn(s, ctrl, shift, alt, meta, e.keyCode, untyped e.preventDefault.bind(e));
				}

				attachEventListener(clip, event, keycb);

			return function() {
				detachEventListener(clip, event, keycb);
			}
		#elseif flash
			var cs = haxe.CallStack.callStack();
			var clip_ : flash.display.InteractiveObject = clip;
			var eventname = event;
			if (event == "keydown" || event == "keyup") {
				var keyevent = if (event == "keydown") {
					flash.events.KeyboardEvent.KEY_DOWN;
				} else {
					flash.events.KeyboardEvent.KEY_UP;
				}
				var keycb = function(e : flash.events.KeyboardEvent) {
					if (clip == null) {
						return;
					}
					var s = '';
					var shift = e.shiftKey;
					var alt = e.altKey;
					var ctrl = e.ctrlKey;
					var meta = false; //TODO: There is no metaKey in flash.events.KeyboardEvent. Add support via keyCode?
					if (e.charCode != 0) {
						if (e.keyCode < 32
							// Can be sent with ctrl or shift down, except for some special keys
							&& e.keyCode != 8 // Delete
							&& e.keyCode != 9 // Tab
							&& e.keyCode != 13 // Return
							&& e.keyCode != 27 // Escape
						) {
							s = String.fromCharCode(e.charCode + 96);
							ctrl = true;
						} else {
							if (e.charCode == 13) {
								s = "enter";
							} else if (e.charCode == 27) {
								s = "esc";
							} else if (e.charCode == 9) {
								s = "tab";
							} else if (e.charCode == 8) {
								s = "backspace";
							} else if (e.keyCode == 46) {
								s = "delete";
							} else if (e.keyCode == 45) {
								s = "insert";
							} else if (e.keyCode == 36) {
								s = "home";
							} else if (e.keyCode == 35) {
								s = "end";
							} else if (e.keyCode == 33) {
								s = "page up";
							} else if (e.keyCode == 34) {
								s = "page down";
							} else {
								s = String.fromCharCode(e.charCode);
								if (flash.ui.Keyboard.capsLock) {
									if (shift) s = s.toLowerCase() else s = s.toUpperCase();
								}
							}
						}
					} else {
						// Special cases: Get ctrl and shift to work on a mac
						if (e.keyCode == 16) {
							shift = true;
							s = "shift";
						} else if (e.keyCode == 17) {
							ctrl = true;
							s = "ctrl";
						} else if (112 <= e.keyCode && e.keyCode <= 123) {
							// Function keys
							s = "F" + (e.keyCode - 111);
						} else switch (e.keyCode) {
							case 33: s = "page up";
							case 34: s = "page down";
							case 35: s = "end";
							case 36: s = "home";
							case 37: s = "left";
							case 38: s = "up";
							case 39: s = "right";
							case 40: s = "down";
							case 45: s = "insert";
							case 46: s = "delete";
						}
					}
					var nop = function(){};
					try {
						fn(s, ctrl, shift, alt, meta, e.keyCode, nop);
					} catch (e : Dynamic) {
						var stackAsString = Assert.callStackToString(cs);
						var actualStack = Assert.callStackToString(haxe.CallStack.callStack());
						var eventDescription = "Event = " + eventname + " s = " + s + " ctrl = " + ctrl + " shift = " + shift + " alt = " + alt + " meta = " + meta + " keyCode = " + e.keyCode;
						var crashInfo = eventDescription + " " + e + "\nStack at handler registering:\n" + stackAsString + "\nStack:\n" + actualStack;
						Native.println("FATAL ERROR: Key handler reported: " + crashInfo);
						Assert.printStack(e);
						Native.callFlowCrashHandlers("[KeyEvent Handler]: " + crashInfo);
					}
				}

				enableMouseEvents(clip_);

				clip_.addEventListener(keyevent, keycb);
				return function() {
					if (clip_ != null) clip_.removeEventListener(eventname, keycb);
					clip_ = null;
				};
			} else {
				Errors.report("Unknown event");
				return function() {};
			}
		#else
			return function() {};
		#end
	}

	public static function addStreamStatusListener(clip : Dynamic, fn : String -> Void) : Void -> Void {
		#if flash
			var clip_ : flash.net.NetStream = clip;
			var cb = function(e : flash.events.NetStatusEvent) {
				fn(e.info.code);
			};
			clip_.addEventListener(flash.events.NetStatusEvent.NET_STATUS, cb);
			return function() {
				clip_.removeEventListener(flash.events.NetStatusEvent.NET_STATUS, cb);
			};
		#else
			var on_start = function() { fn("NetStream.Play.Start"); };
			var on_stop = function() { fn("NetStream.Play.Stop"); };
			var on_not_found = function() { fn("NetStream.Play.StreamNotFound"); };
			clip.addEventListener("loadeddata", on_start);
			clip.addEventListener("ended", on_stop);
			clip.addEventListener("error", on_not_found);
			return function() {
				clip.removeEventListener("loadeddata", on_start);
				clip.removeEventListener("ended", on_stop);
				clip.removeEventListener("error", on_not_found);
			};
		#end
	}

	public static function addEventListener(clip : Dynamic, event : String, fn : Void -> Void) : Void -> Void {
		#if js
			var eventname : String = "";
			if (event == "click") {
				eventname = "click";
			} else if (event == "mousedown") {
				eventname = "mousedown";
			} else if (event == "mouseup") {
				eventname = "mouseup";
			} else if (event == "mousemove") {
				eventname = "mousemove";
			} else if (event == "mouseenter") {
				eventname = "mouseover";
			} else if (event == "mouseleave") {
				eventname = "mouseout";
			} else if (event == "rollover") {
				eventname = "mouseover";
			} else if (event == "rollout") {
				eventname = "mouseout";
			} else if (event == "change") {
				eventname = "input";
			} else if (event == "focusin") {
				eventname = "focus";
			} else if (event == "focusout") {
				eventname = "blur";
			} else if (event == "resize") {
				attachEventListener(Browser.window, "resize", fn);
				return function() {
					detachEventListener(Browser.window, "resize", fn);
				}
			} else if (event == "scroll") {
				eventname = "scroll";
			} else {
				Errors.report("Unknown event");
				return function () { };
			}

			if ( isTouchScreen() && (eventname == "mousedown" || eventname == "mouseup") ) {
				if (eventname == "mousedown") {
					var touchstartWrapper = function(e)  {
						if (e.touches.length != 1) return;
						fn();
					}
					attachEventListener( clip, "touchstart", touchstartWrapper);
					return function () { detachEventListener(clip, eventname, touchstartWrapper); };
				} else {
					var touchendWrapper = function(e)  {
						if (e.touches.length != 0) return;
						fn();
					}
					attachEventListener( clip, "touchend", touchendWrapper);
					return function () { detachEventListener(clip, eventname, touchendWrapper); };
				}
			} else {
				attachEventListener( clip, eventname, fn );
				// Store listeners for stage to simulate ckicks later
				if (clip == Browser.window) {
					if (eventname == "mousedown") clip.flowmousedown = fn;
					else if (eventname == "mouseup") clip.flowmouseup = fn;
				}

				return function () { detachEventListener(clip, eventname, fn); };
			}
		#elseif flash
			var clip_ : flash.display.InteractiveObject = clip;
			var cs = haxe.CallStack.callStack();
			enableMouseEvents(clip_);
			var cb = function(e) {
				try {
					fn();
				} catch (e : Dynamic) {
					var stackAsString = Assert.callStackToString(cs);
					var actualStack = Assert.callStackToString(haxe.CallStack.callStack());
					var crashInfo = "Event = " + event + " " + e + "\nStack at event registering:\n" + stackAsString + "\nStack:\n" + actualStack;
					Native.println("FATAL ERROR: Event handler reported: " + crashInfo);
					Assert.printStack(e);
					Native.callFlowCrashHandlers("[Event Handler]: " + crashInfo);
				}
			};
			var eventname = event;
			if (event == "click") {
				eventname = flash.events.MouseEvent.CLICK;
			} else if (event == "mousedown") {
				eventname = flash.events.MouseEvent.MOUSE_DOWN;
			} else if (event == "mouseup") {
				eventname = flash.events.MouseEvent.MOUSE_UP;
			} else if (event == "mousemove") {
				eventname = flash.events.MouseEvent.MOUSE_MOVE;
			} else if (event == "mouseenter") {
				eventname = flash.events.MouseEvent.MOUSE_OVER;
			} else if (event == "mouseleave") {
				eventname = flash.events.MouseEvent.MOUSE_OUT;
			} else if (event == "rollover") {
				eventname = flash.events.MouseEvent.ROLL_OVER;
			} else if (event == "rollout") {
				eventname = flash.events.MouseEvent.ROLL_OUT;
			} else if (event == "change") {
				eventname = flash.events.Event.CHANGE;
			} else if (event == "scroll") {
				eventname = flash.events.Event.SCROLL;
			} else if (event == "focusin") {
				eventname = flash.events.FocusEvent.FOCUS_IN;
			} else if (event == "focusout") {
				eventname = flash.events.FocusEvent.FOCUS_OUT;
			} else if (event == "resize") {
				var stage = flash.Lib.current.stage;
				stage.addEventListener(flash.events.Event.RESIZE, cb);
				return function() {
					stage.removeEventListener(eventname, cb);
				};
			} else {
				Errors.report("Unknown event");
			}

			clip_.addEventListener(eventname, cb);

			return function() {
				clip_.removeEventListener(eventname, cb);
			};
		#else
			return function() {};
		#end
	}

	public static function addFileDropListener(clip : Dynamic, maxFilesCount : Int, mimeTypeRegExFilter : String, onDone : Array<Dynamic> -> Void) : Void -> Void {
		return function () { };
	}

	public static function addVirtualKeyboardHeightListener(fn : Float -> Void) : Void -> Void {
		return function () { };
	}

	public static function addMouseWheelEventListener(clip : Dynamic, fn : Float -> Void) : Void -> Void {
		#if js
			var wheel_cb = function(event) {
				var delta = 0.0;

				// Crossbrowser delta
				if (event.wheelDelta != null) {
					delta = event.wheelDelta / 120;
				} else if (event.detail != null) {
					delta = -event.detail / 3;
				}

				if (event.preventDefault != null) // Stop default scrolling
						 event.preventDefault();

				fn(delta);
			}

			untyped attachEventListener( Browser.window, "mousewheel", wheel_cb );
			return function() { detachEventListener( Browser.window, "mousewheel", wheel_cb); }
		#elseif flash
			var clip_ : flash.display.InteractiveObject = clip;
			var cb = function(e) {
				fn(e.delta);
			};
			var eventname = flash.events.MouseEvent.MOUSE_WHEEL;
			enableMouseEvents(clip_);
			clip_.addEventListener(eventname, cb);
			return function() {
				clip_.removeEventListener(eventname, cb);
			};
		#else
			return function() {};
		#end
	}

	public static function addFinegrainMouseWheelEventListener(clip : Dynamic, f : Float->Float->Void) : Void->Void {
		#if flash
		var clip_ : flash.display.InteractiveObject = clip;
		enableMouseEvents(clip_);
		finegrainMouseWheelCbs.push(f);
		//Errors.print("Registered FineGrain. n=" + finegrainMouseWheelCbs.length);
		return function() {
			var result = finegrainMouseWheelCbs.remove(f);
			//Errors.print("Unregistered FineGrain. n=" + finegrainMouseWheelCbs.length);
			result;
		}
		#else
		return addMouseWheelEventListener(clip, function(delta) { f(delta, 0); });
		#end
	}

	private static function hasChild(clip : Dynamic, child : Dynamic) : Bool {
		var childs : Array<Dynamic> = clip.children;

		if (childs != null) {
			for (c in childs) {
				if (c == child) return true;
				if (hasChild(c, child)) return true;
			}
		}

		return false;
	}

	#if js
	private static function isIOS() : Bool {
		return  Browser.window.navigator.userAgent.indexOf("iPhone") != -1 ||
				Browser.window.navigator.userAgent.indexOf("iPad") != -1 ||
				Browser.window.navigator.userAgent.indexOf("iPod") != -1;
	}
	#end

	public static function getMouseX(clip : Dynamic) : Float {
		#if js
			var gs = getGlobalScale(clip);
			return (MouseX - getElementX(clip)) / gs.scale_x;
		#elseif flash
			var clip_ : flash.display.DisplayObject = clip;
			return clip_.mouseX;
		#else
			return 0.0;
		#end
	}

	public static function getMouseY(clip : Dynamic) : Float {
		#if js
			var gs = getGlobalScale(clip);
			return (MouseY - getElementY(clip)) / gs.scale_y;
		#elseif flash
			var clip_ : flash.display.DisplayObject = clip;
			return clip_.mouseY;
		#else
			return 0.0;
		#end
	}

	public static function hittest(clip : Dynamic, x : Float, y : Float) : Bool {
		#if js
			var hitted = Browser.document.elementFromPoint(Math.round(x), Math.round(y));
			return (hitted == clip) || hasChild(clip, hitted);
		#elseif flash
			var clip_ : flash.display.DisplayObject = clip;
			return clip_.hitTestPoint(x, y, true);
		#else
			return false;
		#end
	}

	public static function getGraphics(clip : Dynamic) : Dynamic  {
		#if js
			return new Graphics(clip);
		#elseif flash
			return clip.graphics;
		#else
			return null;
		#end
	}

	public static function setLineStyle(graphics : Dynamic, width : Float, color : Int, opacity : Float) : Void {
		#if js
			graphics.setLineStyle(width, color, opacity);
		#elseif flash
			graphics.lineStyle(width, color, opacity);
		#end
	}

	public static function setLineStyle2(graphics : Dynamic, width : Float, color : Int, opacity : Float, pixelHinting : Bool) : Void {
		#if js
			graphics.setLineStyle(width, color, opacity);
		#elseif flash
			graphics.lineStyle(width, color, opacity, pixelHinting);
		#end
	}

	public static function beginFill(graphics : Dynamic, color : Int, opacity : Float) : Void {
		#if js
			graphics.setSolidFill(color, opacity);
		#elseif flash
			graphics.beginFill(color, opacity);
		#end
	}

	// native beginLineGradientFill : (graphics : native, colors : [int], alphas: [double], offsets: [double], matrix : native) -> void = RenderSupport.beginFill;
	public static function beginGradientFill(graphics : Dynamic, colors : Array<Int>, alphas : Array<Float>, offsets: Array<Float>, matrix : Dynamic, type : String) : Void {
		#if js
			graphics.setGradientFill(colors, alphas, offsets, matrix);
		#elseif flash
			var gradientType = flash.display.GradientType.LINEAR;
			if (type == "radial")
				gradientType = flash.display.GradientType.RADIAL;
			var matrix_ : flash.geom.Matrix = matrix;
			for (i in 0...offsets.length)
				offsets[i] = Math.round(255.0 * offsets[i]);

			graphics.beginGradientFill(gradientType, colors, alphas, offsets, matrix_);
		#end
	}

	// native setLineGradientStroke : (graphics : native, colors : [int], alphas: [double], offsets: [double]) -> void = RenderSupport.beginFill;
	public static function setLineGradientStroke(graphics : Dynamic, colours : Array<Int>, alphas : Array<Float>, offsets : Array<Float>, matrix : Dynamic) : Void {
		#if js
		#elseif flash
			var matrix_ : flash.geom.Matrix = matrix;
			for (i in 0...offsets.length)
				offsets[i] = Math.round(255.0 * offsets[i]);

			graphics.lineGradientStyle(flash.display.GradientType.LINEAR,
				colours, alphas, offsets, matrix_);
		#end
	}

	public static function makeMatrix(width : Float, height : Float, rotation : Float, xOffset : Float, yOffset : Float) : Dynamic {
		#if js
			return [ width, height, rotation, xOffset, yOffset ];
		#elseif flash
			var matrix = new flash.geom.Matrix();
			matrix.createGradientBox(width, height, Math.PI * rotation / 180.0 , xOffset, yOffset);
			return matrix;
		#else
			return null;
		#end
	}

	public static function moveTo(graphics : Dynamic, x : Float, y : Float) : Void {
		#if js
			graphics.addGraphOp(MoveTo(x, y));
		#elseif flash
			graphics.moveTo(x, y);
		#end
	}

	public static function lineTo(graphics : Dynamic, x : Float, y : Float) : Void {
		#if js
			graphics.addGraphOp(LineTo(x, y));
		#elseif flash
			graphics.lineTo(x, y);
		#end
	}

	public static function curveTo(graphics : Dynamic, cx : Float, cy : Float, x : Float, y : Float) : Void {
		#if js
			graphics.addGraphOp(CurveTo(x, y, cx, cy));
		#elseif flash
			graphics.curveTo(cx, cy, x, y);
		#end
	}

	public static function endFill(graphics : Dynamic) : Void {
		#if js
			graphics.render();
		#elseif flash
			graphics.endFill();
		#end
	}

	//native makePicture : (url : string, cache : bool, metricsFn : (width : double, height : double) -> void,
	// errorFn : (string) -> void, onlyDownload : bool) -> native = RenderSupport.makePicture;
	public static function makePicture(url : String, cache : Bool, metricsFn : Float -> Float -> Void, errorFn : String -> Void, onlyDownload : Bool) : Dynamic {
		#if js
			var error_cb = function() {
				errorFn("Error while loading image " + url);
			};

			var clip = makeClip();
			clip.setAttribute("role", "img"); // WAI-ARIA role

			if (url.substr(url.length - 3, 3).toLowerCase() == "swf") {
				var loaad_swf_if_no_png = function() {
					loadSWF(clip, url, error_cb, metricsFn);
				}

				loadImage(clip, StringTools.replace(url, ".swf", ".png"), loaad_swf_if_no_png, metricsFn);
			} else {
				loadImage(clip, url, error_cb, metricsFn);
			}

			return clip;
		#elseif flash
			var reportError = function(s) {
				errorFn(s);
			}

			var cachedPicture : flash.display.BitmapData = pictureCache.get(url);
			if (cachedPicture != null) {
				try {
					var bmp : flash.display.Bitmap = new flash.display.Bitmap(cachedPicture);
					bmp.smoothing = true;
					metricsFn(bmp.width, bmp.height);
					return bmp;
				} catch ( unknown : Dynamic ) {
					pictureCache.remove(url);
					trace("Error during restoring image " + url + " from cache : " + Std.string(unknown));
				}
			}
			var cachedPictureSize : Array<Float> = pictureSizeCache.get(url);
			if (cachedPictureSize != null) {
				metricsFn(cachedPictureSize[0], cachedPictureSize[1]);
			}

			var loader = new flash.display.Loader();
			var dis = loader.contentLoaderInfo;
			var request = new flash.net.URLRequest(url);
			dis.addEventListener(flash.events.IOErrorEvent.IO_ERROR, function (event : flash.events.IOErrorEvent) {
				reportError("[ERROR] IO Error with '" + url + "': " + event.text);
			});
			dis.addEventListener(flash.events.SecurityErrorEvent.SECURITY_ERROR, function (event : flash.events.SecurityErrorEvent) {
				reportError("[ERROR] Security Error with " + url + ": " + event.text);
			});

			dis.addEventListener(flash.events.Event.COMPLETE, function(event : flash.events.Event) {
				var loader : flash.display.Loader = event.target.loader;
				var width, height;

				try {
					var content : Dynamic = loader.content;
					width = content.width;
					height = content.height;

					if (Std.is(content, flash.display.Bitmap)) {
						// Bitmaps are not smoothed per default when loading. We take care of that here
						var image : flash.display.Bitmap = cast loader.content;
						image.smoothing = true;
						if (cache == true) {
							pictureCache.set(url, image.bitmapData);
						}
					} else {
						var className:String = untyped __global__["flash.utils.getQualifiedClassName"](content);
						if (className == "flash.display::AVM1Movie") {
							var pwidth = content.width;
							var pheight = content.height;
							var transparent = true;
							var bmpData : flash.display.BitmapData = new flash.display.BitmapData(pwidth, pheight, transparent, 0);
							bmpData.draw(content);
							if (cache == true) {
								pictureCache.set(url, bmpData);
							}
						} else {
							pictureSizeCache.set(url, [width, height]);
						}
					}
				} catch (e: Dynamic) {
					// When running locally, security errors can be called when we access the content
					// of loaded files, so in that case, we have lost, and can not use nice smoothing
					// There is a way, though, to obtain valid metrics of just loaded picture, so let's do that
					width = loader.contentLoaderInfo.width;
					height = loader.contentLoaderInfo.height;
				}
				metricsFn(width, height);
			});

			try {
				//# 33872. Solution from internet works. Let it be as before (i.e. not specified = false) for swf files which are more dangerous
				loader.load(request, new flash.system.LoaderContext(url.substr(url.length - 3, 3).toLowerCase() != "swf"));
			} catch (e : Dynamic) {
				reportError("[ERROR] Loading Error with " + url + ": " + e);
			}
			return loader;
		#else
			return null;
		#end
	}

	public static function setCursor(cursor : String) : Void {
		#if js
			var css_cursor =
				switch (cursor) {
					case "arrow": "default";
					case "auto": "auto";
					case "finger": "pointer";
					case "move": "move" ;
					case "text": "text";
					default: "default";
				}

			Browser.document.body.style.cursor = css_cursor;
		#elseif flash
			if (cursor != "none") {
				flash.ui.Mouse.show();
				mouseHidden = false;
				switch (cursor) {
					case "arrow": flash.ui.Mouse.cursor = flash.ui.MouseCursor.ARROW;
					case "auto": flash.ui.Mouse.cursor = flash.ui.MouseCursor.AUTO;
					case "finger": flash.ui.Mouse.cursor = flash.ui.MouseCursor.BUTTON;
					case "move": flash.ui.Mouse.cursor = flash.ui.MouseCursor.HAND;
					case "text": flash.ui.Mouse.cursor = flash.ui.MouseCursor.IBEAM;
				}
			} else {
				flash.ui.Mouse.hide();
				mouseHidden = true;
			}
		#end
	}

	public static function getCursor() : String {
		#if js
			return switch (Browser.document.body.style.cursor) {
				case "default": "arrow";
				case "auto": "auto";
				case "pointer": "finger";
				case "move": "move" ;
				case "text": "text";
				default: "default";
			}
		#elseif flash
			if (mouseHidden) {
					return "none";
			}
			var mouse = flash.ui.Mouse.cursor;
			return switch (mouse) {
				case flash.ui.MouseCursor.ARROW: "arrow";
				case flash.ui.MouseCursor.AUTO: "auto";
				case flash.ui.MouseCursor.BUTTON: "finger";
				case flash.ui.MouseCursor.HAND: "move";
				case flash.ui.MouseCursor.IBEAM: "text";
				default: "auto";
				};
		#else
			return "auto";
		#end
	}

	// native addFilters(native, [native]) -> void = RenderSupport.addFilters;
	public static function addFilters(clip : Dynamic, filters : Array<Dynamic>) : Void{
		#if js
			var filters_value = filters.join(" ");
			clip.style.WebkitFilter = filters_value;
			// clip.style.filter = filters_value; // Only for webkit for now
		#elseif flash
			var clip_ : flash.display.DisplayObject = clip;
			clip.filters = filters;
		#end
	}

	public static function makeBevel(angle : Float, distance : Float, radius : Float, spread : Float,
							color1 : Int, alpha1 : Float, color2 : Int, alpha2 : Float, inside : Bool) : Dynamic  {
		#if js
			// There is no built in bevel and custom filters are not supported by default
			return "drop-shadow(-1px -1px #888888)";
		#elseif flash
			return new flash.filters.BevelFilter(distance, angle, color1, alpha1, color2,
					alpha2, radius, radius, spread, 1,
					inside ? flash.filters.BitmapFilterType.INNER : flash.filters.BitmapFilterType.OUTER
				);
		#end
      return null;
	}

	public static function makeBlur(radius : Float, spread : Float) : Dynamic {
		#if js
			return "blur(" + radius + "px)";
		#elseif flash
			return new flash.filters.BlurFilter(radius, radius, Math.floor(spread));
		#end
      return null;
	}

	public static function makeDropShadow(angle : Float, distance : Float, radius : Float, spread : Float,
							color : Int, alpha : Float, inside : Bool) : Dynamic  {
		#if js
			return "drop-shadow(" + (Math.cos(angle) * distance) + "px " +
				 (Math.sin(angle) * distance) + "px " + radius + "px " + spread + "px " +
				 makeCSSColor(color, alpha) + ")";
		#elseif flash
			return new flash.filters.DropShadowFilter(distance, angle, color, alpha, radius, radius, spread, 1, inside);
		#end
      return null;
	}

	public static function makeGlow(radius : Float, spread : Float, color : Int, alpha : Float, inside : Bool) : Dynamic  {
		#if js
			return "";
		#elseif flash
			return new flash.filters.GlowFilter(color, alpha, radius, radius, cast(spread), 1, inside, false);
		#end
      return null;
	}

	public static function setScrollRect(clip : Dynamic, left : Float, top : Float, width : Float, height : Float) : Void  {
		#if js
			// Update position right here
			clip.style.top = "" + (-top) + "px";
			clip.style.left = "" + (-left) + "px";

			// Set rect clipping
			clip.rect_top = top;
			clip.rect_left = left;
			clip.rect_right = left + width;
			clip.rect_bottom = top + height;
			clip.style.clip = "rect(" + clip.rect_top  + "px," +
				clip.rect_right + "px," + clip.rect_bottom  + "px," +
				clip.rect_left + "px)";
		#elseif flash
			var clip_ : flash.display.DisplayObject = clip;
			clip_.scrollRect = new flash.geom.Rectangle(left, top, width, height);
			// Save current focus
			var stage = getStage();
			var focus = stage.focus;
			// BUG: If we do not do this, it does not work. Flash simply
			// does not refresh correctly.
			clip_.visible = false;
			clip_.visible = true;
			// We have to restore focus if we lost it
			if ((focus != null) && (stage.focus == null)) stage.focus = focus;
		#end
	}

	public static function getTextMetrics(textfield : Dynamic) : Array<Float> {
		#if js
			var font_size = 16.0;
			if (textfield.font_size != null) font_size = textfield.font_size;
			var ascent = 0.9 * font_size;
			var descent = 0.1 * font_size;
			var leading = 0.15 * font_size;
			return [ascent, descent, leading];
		#elseif flash
			var textfield_ : flash.text.TextField = textfield;
			var metrics : flash.text.TextLineMetrics = textfield_.getLineMetrics(0);
			return [metrics.ascent, metrics.descent, metrics.leading];
		#else
			return [0.0, 0.0, 0.0];
		#end
	}

	public static function makeBitmap() : Dynamic  {
		#if js
			return null;
		#elseif flash
			return new flash.display.Bitmap(null, flash.display.PixelSnapping.ALWAYS, true);
		#end
      return null;
	}

	public static function bitmapDraw(bitmap : Dynamic, clip : Dynamic, width : Int, height : Int) : Void {
		#if js
		#elseif flash
			var bitmap_ : flash.display.Bitmap = bitmap;
			var clip_ : flash.display.DisplayObject = clip;
			var bmpData = new flash.display.BitmapData(width, height, true, 0);
			bmpData.draw(clip_);
			bitmap_.bitmapData = bmpData;
		#end
	}

	public static function addPasteEventListener(callback : Array<Dynamic> -> Void) : (Void -> Void) {
		return function() {};
	}

	public static function getClipVisible(clip : Dynamic) : Bool {
		#if flash
			if (clip == null) return false;
			var stage = getStage();
			var p : flash.display.DisplayObject = clip;
			while (p != null && p != stage) {
				if (!p.visible) {
				   return false;
				}
				p = p.parent;
			}
			return true;
		#elseif js
			if (clip == null) return false;
			var p : Dynamic = clip;
			var stage = getStage();
			while (p != null && p != stage ) {
				if (p.style != null && p.style.display == "none")
				   return false;
				p = p.parentNode;
			}
			return true;
		#else
			return true;
		#end
	}

	public static function setClipVisible(clip : Dynamic, vis : Bool) : Void {
		#if flash
			var clip_ : flash.display.DisplayObject = clip;
			if (clip_.visible != vis) {
				clip_.visible = vis;
			}
		#elseif js
			clip.style.display = vis ? '' : "none";
		#end
	}

	public static function setFullScreenTarget(clip:Dynamic) : Void {
		#if flash
		var target:flash.display.DisplayObject = clip;
		flash.Lib.current.stage.fullScreenSourceRect  = target.getBounds(flash.Lib.current.stage);
		#else
		// happily doing nothing
		#end
	}

	public static function setFullScreenRectangle(x:Float, y:Float, w:Float, h:Float) : Void {
		#if flash
		flash.Lib.current.stage.fullScreenSourceRect = new flash.geom.Rectangle(x, y, w, h);
		#end
		return null;
	}

	public static function resetFullScreenTarget() : Void {
		#if flash
		flash.Lib.current.stage.fullScreenSourceRect = null;
		#end
	}

	public static function toggleFullScreen(fs:Bool) : Void {
		#if flash
		var state = flash.Lib.current.stage.displayState;
		if (state == flash.display.StageDisplayState.FULL_SCREEN) {
			flash.Lib.current.stage.displayState = flash.display.StageDisplayState.NORMAL;
		} else {
			flash.Lib.current.stage.displayState = flash.display.StageDisplayState.FULL_SCREEN;
		}
		#else
			// may be it's possible to toggle F11 from js
		#end
	}

	public static function setFullScreen(fs : Bool) : Void {
		// Not implemented
	}

	public static function onFullScreen(fn : Bool -> Void) : Void -> Void {
		#if flash
		var cb = function(e:flash.events.FullScreenEvent) {
			fn(e.fullScreen);
		};
		flash.Lib.current.stage.addEventListener(flash.events.FullScreenEvent.FULL_SCREEN, cb);
		return function() {
			flash.Lib.current.stage.removeEventListener(flash.events.FullScreenEvent.FULL_SCREEN, cb);
		}
		#else
		return function() {};
		#end
	}

	public static function isFullScreen() : Bool {
		#if flash
		return flash.Lib.current.stage.displayState == flash.display.StageDisplayState.FULL_SCREEN;
		#else
		return false;
		#end
	}

	public static function setWindowTitle(title : String) : Void {
		#if flash
		if (flash.external.ExternalInterface.available) {
			flash.external.ExternalInterface.call("setWindowTitle", title);
		}
		#elseif js
		Browser.document.title = title;
		#end
	}

	public static function setFavIcon(url : String) : Void {
		#if flash
		if (flash.external.ExternalInterface.available) {
			flash.external.ExternalInterface.call("setFavIcon", url);
		}
		#elseif js
		var head = Browser.document.getElementsByTagName('head')[0];
		var oldNode = Browser.document.getElementById('dynamic-favicon');
		var node = Browser.document.createElement('link');
		node.setAttribute("id", "dynamic-favicon");
		node.setAttribute("rel", "shortcut icon");
		node.setAttribute("href", url);
		node.setAttribute("type", "image/ico");
		if (oldNode != null) {
			head.removeChild(oldNode);
		}
		head.appendChild(node);
		#end
	}

	public static function takeSnapshot(path : String) : Void {
		// Empty for these targets
	}

	public static function getScreenPixelColor(x : Int, y : Int) : Int {
		#if flash
			var bmd : flash.display.BitmapData = new flash.display.BitmapData( getStage().stageWidth, getStage().stageHeight );
			bmd.draw( getStage() );
			var b : flash.display.Bitmap = new flash.display.Bitmap(bmd);
			return b.bitmapData.getPixel(x,y);
		#else
			return 0;
		#end
	}

	#if flash
	private static var WebClipListeners : Array<Dynamic>;

	private static inline function fixIframeMetrics() : Void {
		for (cb in WebClipListeners) cb(null);
	}

	private static var BrowserZoom : Float = 1.0;

	private static function updateBrowserZoom() : Void {
		// using jquery insetad of simple innerWidth to support IE8
		if (flash.external.ExternalInterface.available) {
			var innerWidth = flash.external.ExternalInterface.call("eval", "$(window).width()");
			var current_zoom = flash.Lib.current.stage.stageWidth /* That is not changed on zooming by user */ / innerWidth;
			if (current_zoom != BrowserZoom) {
				BrowserZoom = current_zoom;
				fixIframeMetrics();
			}
			haxe.Timer.delay(updateBrowserZoom, 1000);
		}
	}
	#end

	//
	// cb - callback in the flow code which accepts [flow]
	// To call it in the embedded HTML use frameElement.callflow([args]))
	// Default web clip size = 100x100. Scale clip to resize
	public static function makeWebClip(url : String, domain : String, useCache : Bool, reloadBlock : Bool, cb : Array<String> -> String, ondone : String -> Void, shrinkToFit : Bool) : Dynamic {
		// Note: ondone is not used for now for these targets
		// Reliable way to detect error is needed.

		#if flash
		var bridge_clip : flash.display.Sprite = makeClip();
		if (!flash.external.ExternalInterface.available) {
			return bridge_clip;
		}
		var iframe_id = flash.external.ExternalInterface.call("makeWebClip", url, domain, reloadBlock);
		bridge_clip.name = iframe_id; // id is a string

		// Register callback to call flow from JS
		flash.external.ExternalInterface.addCallback("callFlowForIframe_" + iframe_id, function(args : Dynamic) {
			// We have {0 : value0, 1 : value1 ...} here for JS array
			// Not an Array<Dynamic>
			var arr_args = []; var i = 0;
			do { if (args[i] != null) arr_args.push(args[i]); } while (args[i++] != null);
			return cb(arr_args);
		} );

		var top_left = new flash.geom.Point();
		var bottom_right = new flash.geom.Point();

		var test_top_left = new flash.geom.Point();
		var test_bottom_right = new flash.geom.Point(100.0, 100.0);
		var visible = bridge_clip.visible;

		var fix_iframe_metrics = function(e : Dynamic) {
			var new_top_left = bridge_clip.localToGlobal(test_top_left);
			var new_bottom_right = bridge_clip.localToGlobal(test_bottom_right);
			new_top_left.x /= BrowserZoom; new_top_left.y /= BrowserZoom;
			new_bottom_right.x /= BrowserZoom; new_bottom_right.y /= BrowserZoom;

			if ((!top_left.equals(new_top_left) || !new_bottom_right.equals(bottom_right)) && bridge_clip.visible) {
				top_left = new_top_left;
				bottom_right = new_bottom_right;
				flash.external.ExternalInterface.call("setWebClipMetrics",
					iframe_id, top_left.x, top_left.y,
					bottom_right.x - top_left.x, bottom_right.y - top_left.y);
			}
			if (bridge_clip.visible != visible)
			{
				visible = bridge_clip.visible;
				if (bridge_clip.visible) {
					flash.external.ExternalInterface.call("setWebClipMetrics",
						iframe_id, top_left.x, top_left.y,
						bottom_right.x - top_left.x, bottom_right.y - top_left.y);
				}
				else {
					flash.external.ExternalInterface.call("setWebClipMetrics",
						iframe_id, top_left.x, top_left.y,
						0, 0);
				}
			}
		};

		var on_load = function(e : Dynamic) {
			ondone("OK");
		}

		var on_removed = function(e : Dynamic) {
			flash.external.ExternalInterface.call("removeWebClip", bridge_clip.name);
			WebClipListeners.remove(fix_iframe_metrics);
		}

		bridge_clip.addEventListener(flash.events.Event.REMOVED_FROM_STAGE, on_removed);
		bridge_clip.addEventListener(flash.events.Event.ENTER_FRAME, fix_iframe_metrics);
		bridge_clip.addEventListener(flash.events.Event.ADDED_TO_STAGE, on_load);
		WebClipListeners.push(fix_iframe_metrics);

		return bridge_clip;
		#elseif js
		var clip = makeClip();
		if (isIOS()) {
			clip.style.webkitOverflowScrolling = 'touch';
			clip.style.overflowY = "scroll";
		}
		try { Browser.document.domain = domain; } catch(e : Dynamic) { Errors.report(e); }
		var iframe : Dynamic = Browser.document.createElement("iframe");
		iframe.width = iframe.height = WebClipInitSize;
		iframe.src = url;
		iframe.allowFullscreen = true;
		iframe.frameBorder = "no";
		clip.appendChild(iframe);
		clip.iframe = iframe;
		iframe.callflow = cb; // Store for crossdomain calls
		iframe.onload = function() {
			try {
				ondone("OK");
				iframe.contentWindow.callflow = cb;
				if (iframe.contentWindow.pushCallflowBuffer) iframe.contentWindow.pushCallflowBuffer();
			} catch(e : Dynamic) { Errors.report(e); }
		};
		return clip;
		#end
      return null;
	}

	public static function webClipHostCall(clip : Dynamic, name : String, args : Array<String>) : String {
		#if flash
		if (!flash.external.ExternalInterface.available) return null;
		return flash.external.ExternalInterface.call("webClipHostCall", clip.name, name, args);
		#elseif js
		return untyped clip.iframe.contentWindow[name].apply(clip.iframe.contentWindow, args);
		#end
	  return "";
	}

	public static function setWebClipSandBox(clip : Dynamic, value : String) : Void {
		#if js
		clip.iframe.sandbox = value;
		#end
	}

	public static function setWebClipDisabled(clip : Dynamic, value : Bool) : Void {
		//TODO : Implement
	}

	public static function webClipEvalJS(clip : Dynamic, code : String) : Dynamic {
      return null;
	}

	public static function setWebClipZoomable(clip : Dynamic, zoomable : Bool) : Void {
		// NOP for these targets
	}

	public static function setWebClipDomains(clip : Dynamic, domains : Array<String>) : Void {
		// NOP for these targets
	}

	public static function getNumberOfCameras() : Int {
		#if js
		#elseif flash
			return Camera.getNumberOfCameras();
		#end
	  return 0;
	}

	public static function getCameraInfo(id : Int) : String {
		#if js
		#elseif flash
			var camera : flash.media.Camera = flash.media.Camera.getCamera(id+"");
			if (camera == null) {
		    	return "";
			}else{
		    	camera.setMode(64000, 48000, 2400, false);
		    	return "FRONT;"+camera.width+";"+camera.height+";"+flash.media.Camera.names[id];
			}
		#end
	  return "";
	}

	public static function makeCamera(uri : String, camID : Int, camWidth : Int, camHeight : Int, camFps : Float, vidWidth : Int, vidHeight : Int, recordMode : Int, cbOnReadyForRecording : Dynamic -> Void, cbOnFailed : String -> Void) :  Array<Dynamic> {
		#if js
			return [null, null];
		#elseif flash
			try {
				var nc = new flash.net.NetConnection();
				var vid : flash.media.Video = new flash.media.Video();
				var ns : flash.net.NetStream = null;

				// 1. Start camera and microphone
				// 2. Set values for camera and microphone
				var camera : flash.media.Camera = CameraHx.startCamera(camID, camWidth, camHeight, camFps);
				var microphone : flash.media.Microphone = CameraHx.startMicrophone();

				// 3. if needed show video from camera
				if ((vidWidth > 0)&&(vidHeight > 0)) {
					vid = new flash.media.Video(vidWidth, vidHeight);
					vid.attachCamera(camera);
				}
				// 4. attach to the record stream video and/or audio
				if (uri != "") {
					nc.connect(uri);
					var checkConnection = function(event:flash.events.NetStatusEvent) {
						if(event.info.code == "NetConnection.Connect.Success")
						{
							ns = new flash.net.NetStream(nc);
							// attach the camera and microphone to the server
							if ((recordMode == 2)||(recordMode == 3)) {
								ns.attachCamera(camera);
							}
							if ((recordMode == 1)||(recordMode == 3)) {
								ns.attachAudio(microphone);
							}
							// set the buffer time to 3 seconds to buffer 3 seconds of video
							// data for better performance and higher quality video
							ns.bufferTime = 3;
							// add custom metadata to the header of the .flv file
							var metaData:Dynamic = {};
							Reflect.setField(metaData, "description", "Recorded using Area9 Camera API.");
							ns.send("@setDataFrame", "onMetaData", metaData);
							cbOnReadyForRecording(ns);
						}
						if(event.info.code == "NetConnection.Connect.Failed")
						{
							cbOnFailed(event.info.code);
						}
					};
					nc.addEventListener(flash.events.NetStatusEvent.NET_STATUS, checkConnection);
				} else {
					cbOnFailed("Media server URL is empty.");
				}
				return [ns, vid];
			} catch (e : Dynamic) {
				return [null, null];
			}
		#else
			return [null, null];
		#end
	}

	public static function startRecord(str : Dynamic, filename : String, mode : String) : Void {
		#if js
		#elseif flash
			var stream : flash.net.NetStream = str;
			stream.publish(filename, mode);
		#end
	}

	public static function stopRecord(str : Dynamic) : Void {
		#if js
		#elseif flash
			var stream : flash.net.NetStream = str;
			stream.publish(null);
		#end
	}

	public static function cameraTakePhoto(cameraId : Int, additionalInfo : String, desiredWidth : Int, desiredHeight : Int, compressQuality : Int, fileName : String, fitMode : Int) : Void {
		// not implemented yet for js/flash
	}

	public static function cameraTakeVideo(cameraId : Int, additionalInfo : String, duration : Int, size : Int, quality : Int, fileName : String) : Void {
		// not implemented yet for js/flash
	}

	public static function addGestureListener(event : String, cb : Int -> Float -> Float -> Float -> Float -> Bool) : Void -> Void {
		// NOP
		return function() {};
	}

	public static function setInterfaceOrientation(orientation : String) : Void {
		// NOP for these targets
	}

	#if flash
	private static inline function enableMouseEvents(clip : flash.display.InteractiveObject) : Void {
		if (clip != flash.Lib.current.stage) {
			clip.mouseEnabled = true;
			// clip.mouseChildren = true; // This does not work
		}
	}
	#end

	public static function setUrlHash(hash : String) : Void {
		#if flash
		if (flash.external.ExternalInterface.available)
			flash.external.ExternalInterface.call("setLocationHash", hash);
		#elseif js
		Browser.window.location.hash = hash;
		#end
	}

	public static function getUrlHash() : String {
		#if flash
		if (flash.external.ExternalInterface.available)
			return flash.external.ExternalInterface.call("getLocationHash");
		#elseif js
		return js.Browser.window.location.hash;
		#end
		return "";
	}

	public static function addUrlHashListener(cb : String -> Void) : Void -> Void {
		#if flash
		UrlHashListeners.push(cb);
		return function() { UrlHashListeners.remove(cb); };
		#elseif js
		var wrapper = function(e) { cb(Browser.window.location.hash); }
		untyped Browser.window.addEventListener("hashchange", wrapper);
		return function() { untyped Browser.window.removeEventListener("hashchange", wrapper); };
		#end
		return function() {};
	}

	public static function setGlobalZoomEnabled(enabled : Bool) : Void {
		// NOP
	}
}

#if flash
class PictureCache {
	private var pictureMap : Map<String,flash.display.BitmapData>;
	private var pictureLRU : LRU;
	private var cachedPixels : Int;
	private var maxCachedPixels : Int;	//appr. 7000 * 7000 pixels - 190Mb approx. ?
	private var debug : Bool;

	public function new() {
		pictureMap = new Map<String,flash.display.BitmapData>();
		pictureLRU = new LRU();
		cachedPixels = 0;
		maxCachedPixels = 50000000;
		debug = false;
		var imagePixels = Util.getParameter("imagepixels");
		if (imagePixels != null) {
			debug = true;
			var n = Std.parseInt(imagePixels);
			if (n>1) {
				maxCachedPixels = n;
			}
		}
	}

	public function set(url : String, b : flash.display.BitmapData) : Void {
		if (this.get(url) != null) {
			// There's no need to do anything else here, because we have this picture in the cache already
			return;
		}

		pictureMap.set(url, b);
		pictureLRU.set(url);
		cachedPixels += b.width * b.height;
		if (debug) trace("Added picture: " + url + " ("+b.width * b.height+").");

		while (cachedPixels > maxCachedPixels) {
			var removeUrl = pictureLRU.removeLRU();
			if (removeUrl == null) break;
			var rb = pictureMap.get(removeUrl);
			var removedSize = rb.width * rb.height;

			cachedPixels -= removedSize;
			pictureMap.remove(removeUrl);
			if (debug) trace("Removing picture: " + removeUrl + " ("+ removedSize +").");
		}

		if (debug) trace("Total pixels: "+cachedPixels+" / "+maxCachedPixels+" = "+(cachedPixels*100.0)/maxCachedPixels+"%");
	}

	public function get(url : String) : flash.display.BitmapData {
		var b = pictureMap.get(url);
		if (b != null) pictureLRU.set(url);
		return b;
	}

	public function remove(url : String) : Void {
		pictureMap.remove(url);
		pictureLRU.remove(url);
	}
}
#end

#if js
// Emulates flash graphics.
private class Graphics {
	var graphOps : Array<GraphOp>;

	var strokeWidth : Float;
	var strokeColor : Int;
	var strokeOpacity : Float;

	var fillColor : Int;
	var fillOpacity : Float;
	var fillGradientColors : Array<Int>;
	var fillGradientAlphas : Array<Float>;
	var fillGradientOffsets : Array<Float>;
	var fillGradientMatrix : Dynamic;
	var fillGradientType : String;

	var owner : Dynamic;

	public static var svg : Bool;

	public function new(clip : Dynamic) {
		owner = clip;
		graphOps = new Array<GraphOp>();
		strokeOpacity = fillOpacity = 0.0;
		strokeWidth = 0.0;
	}

	public function addGraphOp(op : GraphOp) {
		graphOps.push(op);
	}

	public function setLineStyle(width : Float, color : Int, opacity : Float) {
		strokeWidth = width; strokeColor = color; strokeOpacity = opacity;
	}

	public function setSolidFill(color : Int, opacity : Float) {
		fillColor = color; fillOpacity = opacity;
	}

	public function setGradientFill(colors : Array<Int>, alphas : Array<Float>, offsets: Array<Float>, matrix : Dynamic, type : String) {
		fillGradientColors = colors; fillGradientAlphas = alphas; fillGradientOffsets = offsets;
		fillGradientMatrix = matrix; fillGradientType = type;
	}

	private function measure() : Dynamic {
		var max_x = Math.NEGATIVE_INFINITY, max_y = Math.NEGATIVE_INFINITY;
		var min_x = Math.POSITIVE_INFINITY, min_y = Math.POSITIVE_INFINITY;

		for (i in 0...graphOps.length) {
			var op = graphOps[i];
			switch (op) {
				case MoveTo(x, y):
					if (x > max_x) max_x = x; if (x < min_x) min_x = x; if (y > max_y) max_y = y; if (y < min_y) min_y = y;
				case LineTo(x, y):
					if (i == 0) max_x = max_y = min_x = min_y = 0.0; // asssume moveto 0.0
					if (x > max_x) max_x = x; if (x < min_x) min_x = x; if (y > max_y) max_y = y; if (y < min_y) min_y = y;
				case CurveTo(x, y, cx, cy):
					if (i == 0) max_x = max_y = min_x = min_y = 0.0; // asssume moveto 0.0
					if (x > max_x) max_x = x; if (x < min_x) min_x = x; if (y > max_y) max_y = y;  if (y < min_y) min_y = y;
					if (cx > max_x) max_x = cx; if (cx < min_x) min_x = cx; if (cy > max_y) max_y = cy;  if (cy < min_y) min_y = cy;
			}
		}

		return {x0 : min_x, y0 : min_y, x1 : max_x + strokeWidth, y1 : max_y + strokeWidth};
	}

	private static inline var svgns = "http://www.w3.org/2000/svg";
	private function createSVGElement(name : String, attrs : Array<Dynamic> ) : Dynamic {
		var element : Dynamic = untyped Browser.document.createElementNS(svgns, name);
		for (a in attrs)
             element.setAttribute(a.n, a.v);
        return element;
	}

	private function addSVGGradient(svg : Dynamic, id : String) {
		var defs = createSVGElement("defs", []);
		svg.appendChild(defs);

		var width : Float = fillGradientMatrix[0]; var height : Float = fillGradientMatrix[1];
		var rotation : Float = fillGradientMatrix[2]; var xOffset : Float = fillGradientMatrix[3];
		var yOffset : Float = fillGradientMatrix[4];

		var grad = createSVGElement("linearGradient", [{n : "id", v : id},
			{n : "x1", v : xOffset}, {n : "y1", v : yOffset},
			{n : "x2", v : width * Math.cos(rotation / 180.0 * Math.PI)},
			{n : "y2", v : height * Math.sin(rotation / 180.0 * Math.PI)}]);

		defs.appendChild(grad);

		for (i in 0...fillGradientColors.length) {
			var stop_pt = createSVGElement("stop", [
				{n : "offset", v : "" + (fillGradientOffsets[i] * 100.0) + "%" },
				{n : "stop-color", v : RenderSupport.makeCSSColor(fillGradientColors[i], fillGradientAlphas[i]) }
			]);
			grad.appendChild(stop_pt);
		}
	}

	private function renderSVG() {
		var wh = measure();
		var svg = createSVGElement('svg', [{n : "xmlns", v : svgns},  {n : "version", v : "1.1"}/*, {n : "width", v : wh.x1}, {n : "height", v : wh.y1}*/]);

		var path_data = "";
		// Render path
		for (op in graphOps) {
			switch (op) {
				case MoveTo(x, y): path_data += "M " + x + " " + y + " ";
				case LineTo(x, y): path_data += "L " + x + " " + y + " ";
				case CurveTo(x, y, cx, cy): path_data += "S " + cx + " " + cy + " " + x + " " + y + " ";
			}
		}

		var svgpath_attr =  [{n : "d", v : path_data}];

		if (strokeOpacity != 0.0)
			svgpath_attr.push({n : "stroke", v : RenderSupport.makeCSSColor(strokeColor, strokeOpacity)});

		if (fillOpacity != 0.0) {
			svgpath_attr.push({n : "fill", v : RenderSupport.makeCSSColor(fillColor, fillOpacity)});
		} else if (fillGradientColors != null) {
			var id = "grad" + Date.now().getTime();
			addSVGGradient(svg, id);
			svgpath_attr.push({n : "fill", v : "url(#" + id + ")"});
		} else {
			svgpath_attr.push({n : "fill", v : RenderSupport.makeCSSColor(0xFFFFFF, 0.0)});
		}

		svgpath_attr.push({n : "transform", v: "translate(" + (-wh.x0) + "," + (-wh.y0) + ")"});

		var svgpath = createSVGElement("path",svgpath_attr);

		svg.setAttribute("width", wh.x1-wh.x0 );
		svg.setAttribute("height", wh.y1-wh.y0 );

		svg.appendChild(svgpath);

		svg.style.left = "" + wh.x0 + "px";
		svg.style.top = "" + wh.y0 + "px";

		owner.appendChild(svg);
	}

	private function renderCanvas() {
		var wh = measure();

		var canvas : Dynamic = Browser.document.createElement("CANVAS");
		var ctx = canvas.getContext("2d");
		owner.appendChild(canvas);

		canvas.height = wh.y1 - wh.y0;
		canvas.width = wh.x1 - wh.x0;
		canvas.style.top = "" + wh.y0 + "px";
		canvas.style.left = "" + wh.x0 + "px";
		canvas.x0 = wh.x0; canvas.y0 = wh.y0;
		canvas.style.width = "" + (wh.x1 - wh.x0) + "px"; // This fixes non-integer metrics
		canvas.style.height = "" + (wh.y1 - wh.y0) + "px";

		if (strokeOpacity != 0.0) {
			ctx.lineWidth = strokeWidth;
			ctx.strokeStyle = RenderSupport.makeCSSColor(strokeColor, strokeOpacity);
		}

		if (fillOpacity != 0.0) {
			ctx.fillStyle = RenderSupport.makeCSSColor(fillColor, fillOpacity);
		}

		if (fillGradientColors != null) {
			var width : Float = fillGradientMatrix[0]; var height : Float = fillGradientMatrix[1];
			var rotation : Float = fillGradientMatrix[2]; var xOffset : Float = fillGradientMatrix[3];
			var yOffset : Float = fillGradientMatrix[4];

			var gradient = ctx.createLinearGradient(xOffset, yOffset, width * Math.cos(rotation / 180.0 * Math.PI), height * Math.sin(rotation / 180.0 * Math.PI));

			for (i in 0...fillGradientColors.length)
				gradient.addColorStop(fillGradientOffsets[i], RenderSupport.makeCSSColor(fillGradientColors[i], fillGradientAlphas[i]) );

			ctx.fillStyle = gradient;
		}


		// Render path
		ctx.translate(-wh.x0, -wh.y0); // (x0, y0) -> (0, 0)
		ctx.beginPath();
		ctx.moveTo(0.0, 0.0);
		for (op in graphOps) {
			switch (op) {
				case MoveTo(x, y): ctx.moveTo(x, y);
				case LineTo(x, y): ctx.lineTo(x, y);
				case CurveTo(x, y, cx, cy): ctx.quadraticCurveTo(cx, cy, x, y);
			}
		}

		if (fillOpacity != 0.0 || fillGradientColors != null) {
			ctx.closePath();
			ctx.fill();
		}

		if (strokeOpacity != 0.0) ctx.stroke();
	}

	public function render() {
		if (svg) {
			renderSVG();
		} else {
			renderCanvas();
		}
	}
}
#end
