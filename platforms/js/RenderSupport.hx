import js.Browser;
import js.html.Element;
import js.html.IFrameElement;

import pixi.core.display.DisplayObject;
import pixi.core.display.Bounds;
import pixi.core.renderers.Detector;
import pixi.core.renderers.canvas.CanvasRenderer;
import pixi.core.renderers.webgl.WebGLRenderer;
import pixi.core.renderers.webgl.filters.Filter;
import pixi.core.math.Point;
import pixi.core.text.TextStyle;

import MacroUtils;
import Platform;
import ProgressiveWebTools;
import BlurFilter;

using DisplayObjectHelper;

class RenderSupport {
	public static var RendererType : String = Util.getParameter("renderer") != null ? Util.getParameter("renderer") : untyped Browser.window.useRenderer;
	public static var RenderContainers : Bool = Util.getParameter("containers") == "1";
	public static var FiltersEnabled : Bool = Util.getParameter("filters") != "0";

	public static var PixiView : Dynamic;
	public static var PixiStage : FlowContainer = new FlowContainer(true);
	public static var PixiRenderer : Dynamic;

	public static var TouchPoints : Dynamic;
	public static var MousePos : Point = new Point(0.0, 0.0);
	public static var PixiStageChanged : Bool = true;
	private static var TransformChanged : Bool = true;
	private static var isEmulating : Bool = false;
	private static var AnimationFrameId : Int = -1;
	private static var PageWasHidden = false;
	private static var IsLoading = true;

	// Renderer options
	public static var AccessibilityEnabled : Bool = Util.getParameter("accessenabled") == "1";
	public static var EnableFocusFrame : Bool = false;
	/* Antialiasing doesn't work correctly on mobile devices */
	public static var Antialias : Bool = Util.getParameter("antialias") != null ? Util.getParameter("antialias") == "1" : !Native.isTouchScreen() && (RendererType != "webgl" || detectExternalVideoCard());
	public static var RoundPixels : Bool = Util.getParameter("roundpixels") != null ? Util.getParameter("roundpixels") != "0" : RendererType != "html";
	public static var TransparentBackground : Bool = Util.getParameter("transparentbackground") == "1";

	public static var DropCurrentFocusOnMouse : Bool;
	// Renders in a higher resolution backing store and then scales it down with css (e.g., ratio = 2 for retina displays)
	// Resolution < 1.0 makes web fonts too blurry
	// NOTE: Pixi Text.resolution is readonly == renderer.resolution
	public static var backingStoreRatio : Float = getBackingStoreRatio();
	public static var browserZoom : Float = 1.0;

	// In fact that is needed for android to have dimensions without screen keyboard
	// Also it covers iOS Chrome and PWA issue with innerWidth|Height
	private static var WindowTopHeightPortrait : Int = -1;
	private static var WindowTopHeightLandscape : Int = -1;

	public static var hadUserInteracted = false;

	public static var WebFontsConfig = null;

	private static var RenderSupportInitialised : Bool = init();

	public function new() {}

	@:overload(function(event : String, fn : Dynamic -> Void, ?context : Dynamic) : Void {})
	public static function on(event : String, fn : Void -> Void, ?context : Dynamic) : Void {
		PixiStage.on(event, fn, context);
	}

	@:overload(function(event : String, fn : Dynamic -> Void, ?context : Dynamic) : Void {})
	public static function off(event : String, fn : Void -> Void, ?context : Dynamic) : Void {
		PixiStage.off(event, fn, context);
	}

	@:overload(function(event : String, fn : Dynamic -> Void, ?context : Dynamic) : Void {})
	public static function once(event : String, fn : Void -> Void, ?context : Dynamic) : Void {
		PixiStage.once(event, fn, context);
	}

	public static function emit(event : String, ?a1 : Dynamic, ?a2 : Dynamic, ?a3 : Dynamic, ?a4 : Dynamic, ?a5 : Dynamic) : Bool {
		return PixiStage.emit(event, a1, a2, a3, a4, a5);
	}

	public static function setRendererType(rendererType : String) : Void {
		if (RendererType != rendererType) {
			RendererType = rendererType;
			RoundPixels = Util.getParameter("roundpixels") != null ? Util.getParameter("roundpixels") != "0" : RendererType != "html";
			Antialias = Util.getParameter("antialias") != null ? Util.getParameter("antialias") == "1" :
				!Native.isTouchScreen() && (RendererType != "webgl" || detectExternalVideoCard());

			untyped __js__("PIXI.TextMetrics.METRICS_STRING = (Platform.isMacintosh || (Platform.isIOS && RenderSupport.RendererType != 'html')) ? '|Éq█Å' : '|Éq'");

			PixiWorkarounds.workaroundGetContext();

			createPixiRenderer();
		}
	}

	public static function setKeepTextClips(keep : Bool) : Void {
		TextClip.KeepTextClips = keep;
	}

	public static function getRendererType() : String {
		return RendererType;
	}

	private static function roundPlus(x : Float, n : Int) : Float {
		var m = Math.pow(10, n);
		return Math.fround(x * m) / m;
	}

	private static var accessibilityZoom : Float = Std.parseFloat(Native.getKeyValue("accessibility_zoom", "1.0"));
	private static var accessibilityZoomValues : Array<Float> = [0.25, 0.33, 0.5, 0.66, 0.75, 0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 4.0, 5.0];

	public static function getAccessibilityZoom() : Float {
		return RendererType == "html" && accessibilityZoom > 0.0 ? accessibilityZoom : 1.0;
	}

	public static function setAccessibilityZoom(zoom : Float) : Void {
		if (accessibilityZoom != zoom) {
			accessibilityZoom = zoom;
			Native.setKeyValue("accessibility_zoom", Std.string(zoom));

			PixiStage.broadcastEvent("resize", backingStoreRatio);
			InvalidateLocalStages();

			showAccessibilityZoomTooltip();
		}
	}

	private static var accessibilityZoomTooltip : Dynamic;

	public static function showAccessibilityZoomTooltip() : Void {
		if (accessibilityZoomTooltip != null) {
			Browser.document.body.removeChild(accessibilityZoomTooltip);
			accessibilityZoomTooltip = null;
		}

		if (browserZoom != 1.0) {
			return;
		}

		var p = Browser.document.createElement("p");
		Browser.document.body.appendChild(p);

		p.classList.add('nativeWidget');
		p.classList.add('textWidget');
		p.textContent = "Zoom: " + Math.round(accessibilityZoom * 100) + "%";
		p.style.fontSize = "12px";
		p.style.zIndex = "1000";
		p.style.background = "#424242";
		p.style.color = "#FFFFFF";
		p.style.padding = "8px";
		p.style.paddingTop = "4px";
		p.style.paddingBottom = "4px";
		p.style.borderRadius = "4px";
		p.style.left = "50%";
		p.style.top = "8px";
		p.style.transform = "translate(-50%, 0)";

		accessibilityZoomTooltip = p;

		Native.timer(2000, function() {
			if (accessibilityZoomTooltip != null && accessibilityZoomTooltip == p) {
				accessibilityZoomTooltip = null;
				Browser.document.body.removeChild(p);
			}
		});
	}

	public static function onKeyDownAccessibilityZoom(e : Dynamic) : Void {
		if (browserZoom != 1.0) {
			return;
		}

		if (Platform.isMacintosh ? e.metaKey == true : e.ctrlKey == true) {
			if (e.which == '61' || e.which == "107" || e.which == "187") {
				e.preventDefault();
				setAccessibilityZoom(Lambda.fold(accessibilityZoomValues, function(a, b) { return a < b && a > getAccessibilityZoom() ? a : b; }, 5.0));
			} else if (e.which == '173' || e.which == "109" || e.which == "189") {
				e.preventDefault();
				setAccessibilityZoom(Lambda.fold(accessibilityZoomValues, function(a, b) { return a > b && a < getAccessibilityZoom() ? a : b; }, 0.25));
			}
		}
	}

	private static var onMouseWheelAccessibilityZoomEnabled = true;

	public static function onMouseWheelAccessibilityZoom(e : Dynamic, dx : Float, dy : Float) : Bool {
		if (browserZoom != 1.0 || Platform.isMacintosh) {
			return false;
		}

		if (Platform.isMacintosh ? e.metaKey == true : e.ctrlKey == true) {
			if (dy > 0) {
				e.preventDefault();

				if (onMouseWheelAccessibilityZoomEnabled) {
					onMouseWheelAccessibilityZoomEnabled = false;
					setAccessibilityZoom(Lambda.fold(accessibilityZoomValues, function(a, b) { return a < b && a > getAccessibilityZoom() ? a : b; }, 5.0));
					once("drawframe", function() {
						onMouseWheelAccessibilityZoomEnabled = true;
					});
				}

				return true;
			} else if (dy < 0) {
				e.preventDefault();

				if (onMouseWheelAccessibilityZoomEnabled) {
					onMouseWheelAccessibilityZoomEnabled = false;
					setAccessibilityZoom(Lambda.fold(accessibilityZoomValues, function(a, b) { return a > b && a < getAccessibilityZoom() ? a : b; }, 0.25));
					once("drawframe", function() {
						onMouseWheelAccessibilityZoomEnabled = true;
					});
				}

				return true;
			}
		}

		return false;
	}

	private static var UserStyleTestElement = null;
	private static function createUserStyleTestElement() : Void {
		if (UserStyleTestElement == null) {
			UserStyleTestElement = Browser.document.createElement("p");
			UserStyleTestElement.setAttribute("role", "presentation");
			UserStyleTestElement.style.visibility = "hidden";
			Browser.document.body.appendChild(UserStyleTestElement);
		}
	}
	private static var UserDefinedFontSize : Float = null;
	private static function getUserDefinedFontSize() : Float {
		if (UserDefinedFontSize == null) {
			createUserStyleTestElement();
			var style = Browser.window.getComputedStyle(UserStyleTestElement);

			UserDefinedFontSize = Std.parseFloat(style.fontSize);
		}

		if (Math.isNaN(UserDefinedFontSize)) {
			UserDefinedFontSize = 16.0;
		}

		return UserDefinedFontSize;
	}

	private static var UserDefinedLetterSpacing = 0.0;
	private static function getUserDefinedLetterSpacing() : Float {
		createUserStyleTestElement();
		var style = Browser.window.getComputedStyle(UserStyleTestElement);

		UserDefinedLetterSpacing = style.letterSpacing != "normal"
			? (new String(style.letterSpacing).indexOf("em") >= 0 ? 0.0 : Std.parseFloat(style.letterSpacing))
			: 0.0;

		return UserDefinedLetterSpacing;
	}

	private static var UserDefinedLineHeightPercent = 1.15;
	private static function getUserDefinedLineHeightPercent() : Float {
		createUserStyleTestElement();
		var style = Browser.window.getComputedStyle(UserStyleTestElement);

		UserDefinedLineHeightPercent = style.lineHeight != "normal"
			? (new String(style.lineHeight).indexOf("em") >= 0 ? Std.parseFloat(style.lineHeight) : Std.parseFloat(style.lineHeight) / Std.parseFloat(style.fontSize))
			: 1.15;

		return UserDefinedLineHeightPercent;
	}

	private static var UserDefinedWordSpacingPercent = 0.0;
	private static function getUserDefinedWordSpacingPercent() : Float {
		createUserStyleTestElement();
		var style = Browser.window.getComputedStyle(UserStyleTestElement);

		UserDefinedWordSpacingPercent = style.wordSpacing != "normal"
			? (new String(style.wordSpacing).indexOf("em") >= 0 ? Std.parseFloat(style.wordSpacing) : Std.parseFloat(style.wordSpacing) / Std.parseFloat(style.fontSize))
			: 0.0;

		return UserDefinedWordSpacingPercent;
	}

	private static var UserDefinedLetterSpacingPercent = 0.0;
	private static function getUserDefinedLetterSpacingPercent() : Float {
		createUserStyleTestElement();
		var style = Browser.window.getComputedStyle(UserStyleTestElement);

		UserDefinedLetterSpacingPercent = style.letterSpacing != "normal"
			? (new String(style.letterSpacing).indexOf("em") >= 0 ? Std.parseFloat(style.letterSpacing) : 0.0)
			: 0.0;

		return UserDefinedLetterSpacingPercent;
	}

	private static var UserStylePending = false;
	public static function emitUserStyleChanged() {
		if (!UserStylePending) {
			UserStylePending = true;
			var userStyleChanged = RenderSupport.checkUserStyleChanged();
			RenderSupport.once("drawframe", function() {
				if (userStyleChanged) {
					RenderSupport.emit("userstylechanged");
				}
				UserStylePending = false;
			});
		}
	}

	public static function checkUserStyleChanged() : Bool {
		return (untyped (UserDefinedLetterSpacing != getUserDefinedLetterSpacing()) | (UserDefinedLetterSpacingPercent != getUserDefinedLetterSpacingPercent()) |
			(UserDefinedWordSpacingPercent != getUserDefinedWordSpacingPercent()) | (UserDefinedLineHeightPercent != getUserDefinedLineHeightPercent()));
	}

	public static function isInsideFrame() : Bool {
		try {
			return untyped __js__("window.self !== window.top");
		} catch (e : Dynamic) {
			return true;
		}
	}

	public static function monitorUserStyleChanges() : Void -> Void {
		return Native.setInterval(1000, emitUserStyleChanged);
	}

	public static function setPrintPageSize(wd : Float, hgt : Float) : Void -> Void {
		var style = Browser.document.createElement('style');
		style.setAttribute('type', 'text/css');

		style.innerHTML = "@page { size: " + wd + "px " + hgt + "px !important; margin:0 !important; padding:0 !important; } " +
			".print-page { width: 100% !important; height: 100% !important; overflow: hidden !important; }";
		Browser.document.head.appendChild(style);

		return function () {
			Browser.document.head.removeChild(style);
		}
	}

	public static function getClipHTML(clip : DisplayObject) : String {
		if (!printMode) {
			printMode = true;
			prevInvalidateRenderable = DisplayObjectHelper.InvalidateRenderable;
			DisplayObjectHelper.InvalidateRenderable = false;
		}

		clip.initNativeWidget();
		PixiStage.forceClipRenderable();
		forceRender();
		var nativeWidget : Dynamic = untyped clip.nativeWidget;
		var content = nativeWidget ? nativeWidget.innerHTML : '';

		if (printMode) {
			printMode = false;
			DisplayObjectHelper.InvalidateRenderable = prevInvalidateRenderable;
		}

		return content;
	}

	public static function showPrintDialog() : Void {
		if (!printMode) {
			printMode = true;
			prevInvalidateRenderable = DisplayObjectHelper.InvalidateRenderable;
			DisplayObjectHelper.InvalidateRenderable = false;
		}

		PixiStage.forceClipRenderable();
		emit("beforeprint");
		forceRender();

		PixiStage.onImagesLoaded(function () {
			Browser.window.print();
		});
	}

	private static function getBackingStoreRatio() : Float {
		var ratio = (Browser.window.devicePixelRatio != null ? Browser.window.devicePixelRatio : 1.0) *
			(Util.getParameter("resolution") != null ? Std.parseFloat(Util.getParameter("resolution")) : 1.0);
		browserZoom = Browser.window.outerWidth / Browser.window.innerWidth;

		if (!Platform.isMobile && browserZoom != 1.0) {
			accessibilityZoom = 1.0;
			Native.setKeyValue("accessibility_zoom", "1.0");
		}

		if (Platform.isSafari && !Platform.isMobile) { // outerWidth == 0 on mobile safari (and most other mobiles)
			ratio *= browserZoom;
		}

		return Math.max(roundPlus(ratio, 2), 1.0);
	}

	private static function defer(fn : Void -> Void, ?time : Int = 10) : Void {
		untyped __js__("setTimeout(fn, time)");
	}

	private static function preventDefaultFileDrop() {
		Browser.window.ondragover = Browser.window.ondrop =
			function (event) {
				if (event.dataTransfer.dropEffect != "copy")
					event.dataTransfer.dropEffect = "none";

				event.preventDefault();
				return false;
			}
	}

	//
	//	Pixi renderer initialization
	//
	public static function init() : Bool {
		if (Util.getParameter("oldjs") != "1") {
			initPixiRenderer();
		} else {
			defer(StartFlowMain);
		}

		return true;
	}

	private static function printOptionValues() : Void {
		if (AccessibilityEnabled) Errors.print("Flow Pixi renderer DEBUG mode is turned on");
	}

	public static function detectExternalVideoCard() : Bool {
		var canvas = Browser.document.createElement('canvas');
		var gl = untyped __js__("canvas.getContext('webgl') || canvas.getContext('experimental-webgl')");

		if (gl == null) {
			return false;
		}

		var debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
		var vendor = gl.getParameter(debugInfo.UNMASKED_VENDOR_WEBGL);
		var renderer = gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL);

		return renderer.toLowerCase().indexOf("nvidia") >= 0 || renderer.toLowerCase().indexOf("ati") >= 0 || renderer.toLowerCase().indexOf("radeon") >= 0;
	}

	private static function disablePixiPlugins() {
		untyped __js__("delete PIXI.CanvasRenderer.__plugins.accessibility");
		untyped __js__("delete PIXI.CanvasRenderer.__plugins.tilingSprite");
		untyped __js__("delete PIXI.CanvasRenderer.__plugins.mesh");
		untyped __js__("delete PIXI.CanvasRenderer.__plugins.particle");
		untyped __js__("delete PIXI.CanvasRenderer.__plugins.prepare");

		untyped __js__("delete PIXI.WebGLRenderer.__plugins.accessibility");
		untyped __js__("delete PIXI.WebGLRenderer.__plugins.extract");
		untyped __js__("delete PIXI.WebGLRenderer.__plugins.tilingSprite");
		untyped __js__("delete PIXI.WebGLRenderer.__plugins.mesh");
		untyped __js__("delete PIXI.WebGLRenderer.__plugins.particle");
		untyped __js__("delete PIXI.WebGLRenderer.__plugins.prepare");

		// Destroy default pixi ticker
		untyped PIXI.ticker.shared.autoStart = false;
		untyped PIXI.ticker.shared.stop();
		untyped PIXI.ticker.shared.destroy();
	}

	private static function createPixiRenderer() {
		backingStoreRatio = getBackingStoreRatio();

		if (PixiRenderer != null) {
			if (untyped PixiRenderer.gl != null && PixiRenderer.gl.destroy != null) {
				untyped PixiRenderer.gl.destroy();
			}

			PixiRenderer.destroy();
		}

		if (PixiView != null && PixiView.parentNode != null) {
			PixiView.parentNode.removeChild(PixiView);
		}

		if (RendererType == "html") {
			PixiView = Browser.document.createElement('div');
			PixiView.style.background = "white";
		} else if (RendererType != "canvas") {
			PixiView = null;
		}

		var options = {
			antialias : Antialias,
			transparent : TransparentBackground,
			backgroundColor : TransparentBackground ? 0 : 0xFFFFFF,
			preserveDrawingBuffer : false,
			resolution : backingStoreRatio,
			roundPixels : RoundPixels,
			autoResize : true,
			view : PixiView
		};

		var width : Int = Browser.window.innerWidth;
		var height : Int = Browser.window.innerHeight;

		if (RendererType == "webgl" /*|| (RendererType == "canvas" && RendererType == "auto" && detectExternalVideoCard() && !Platform.isIE)*/) {
			PixiRenderer = new WebGLRenderer(width, height, options);

			RendererType = "webgl";
		} else if (RendererType == "auto") {
			PixiRenderer = Detector.autoDetectRenderer(options, width, height);

			if (untyped HaxeRuntime.instanceof(PixiRenderer, WebGLRenderer)) {
				RendererType = "webgl";
			} else {
				RendererType = "canvas";
			}
		} else if (RendererType == "html") {
			PixiRenderer = new CanvasRenderer(width, height, options);
		} else {
			PixiRenderer = new CanvasRenderer(width, height, options);

			RendererType = "canvas";
		}

		if (RendererType == "canvas") {
			untyped PixiRenderer.context.fillStyle = "white";
			untyped PixiRenderer.context.fillRect(0, 0, PixiRenderer.view.width, PixiRenderer.view.height);
			untyped PixiRenderer.plugins.interaction.mouseOverRenderer = true;

			var tempPlugins = untyped WebGLRenderer.__plugins;
			untyped WebGLRenderer.__plugins = [];
			untyped WebGLRenderer.__plugins = tempPlugins;
		} else if (RendererType == "webgl") {
			untyped PixiRenderer.gl.viewport(0, 0, untyped PixiRenderer.gl.drawingBufferWidth, untyped PixiRenderer.gl.drawingBufferHeight);
			untyped PixiRenderer.gl.clearColor(1.0, 1.0, 1.0, 1.0);
			untyped PixiRenderer.gl.clear(untyped PixiRenderer.gl.COLOR_BUFFER_BIT);
		} else if (RendererType == "html") {
			untyped PixiRenderer.plugins.interaction.removeEvents();
			untyped PixiRenderer.plugins.interaction.interactionDOMElement = PixiView;
		}

		PixiView = PixiRenderer.view;

		PixiView.tabIndex = 1;
		PixiView.onfocus = function(e) {
			var accessWidget = AccessWidget.tree.getFirstAccessWidget();

			if (accessWidget != null && accessWidget.element != null && accessWidget.clip != null && accessWidget.element != e.relatedTarget) {
				setFocus(accessWidget.clip, true);
			} else {
				accessWidget = AccessWidget.tree.getLastAccessWidget();

				if (accessWidget != null && accessWidget.element != null && accessWidget.clip != null && accessWidget.element != e.relatedTarget) {
					setFocus(accessWidget.clip, true);
				}
			}
		}

		if (IsLoading) {
			PixiView.style.display = "none";
		}

		// Make absolute position for canvas for Safari to fix fullscreen API
		if (Platform.isSafari) {
			PixiView.style.position = "absolute";
			PixiView.style.top = "0px";
		}

		PixiView.style.zIndex = AccessWidget.zIndexValues.canvas;
		Browser.document.body.insertBefore(PixiView, Browser.document.body.firstChild);

		// Enable browser canvas rendered image smoothing
		var ctx = untyped PixiRenderer.context;
		if (ctx != null) {
			ctx.mozImageSmoothingEnabled = true;
			ctx.webkitImageSmoothingEnabled = true;
			ctx.imageSmoothingQuality = if (Platform.isChrome) "high" else "medium";
			ctx.msImageSmoothingEnabled = true;
			ctx.imageSmoothingEnabled = true;
		}
	}

	private static var webFontsLoadingStartAt : Float;
	private static function initPixiRenderer() {
		disablePixiPlugins();

		if (untyped PIXI.VERSION != "4.8.2") {
			untyped __js__("document.location.reload(true)");
		}

		untyped __js__("PIXI.TextMetrics.METRICS_STRING = (Platform.isMacintosh || (Platform.isIOS && RenderSupport.RendererType != 'html')) ? '|Éq█Å' : '|Éq'");

		PixiWorkarounds.workaroundGetContext();
		PixiWorkarounds.workaroundTextMetrics();

		PixiWorkarounds.workaroundRendererDestroy();
		PixiWorkarounds.workaroundProcessInteractive();

		if (Platform.isIE) {
			PixiWorkarounds.workaroundIEArrayFromMethod();
			PixiWorkarounds.workaroundIECustomEvent();
		}

		createPixiRenderer();

		preventDefaultFileDrop();
		initPixiStageEventListeners();
		initBrowserWindowEventListeners();
		initMessageListener();
		initFullScreenEventListeners();

		webFontsLoadingStartAt = NativeTime.timestamp();
		WebFontsConfig = FontLoader.loadWebFonts(StartFlowMainWithTimeCheck);

		initClipboardListeners();
		initCanvasStackInteractions();

		printOptionValues();

		render();
		requestAnimationFrame();
	}

	private static function StartFlowMainWithTimeCheck() {
		Errors.print("Web fonts loaded in " + (NativeTime.timestamp() - webFontsLoadingStartAt) + " ms");
		StartFlowMain();
	}

	//
	//	Browser window events
	//

	private static var keysPending : Map<Int, Dynamic> = new Map<Int, Dynamic>();
	private static var printMode = false;
	private static var prevInvalidateRenderable = false;
	private static inline function initBrowserWindowEventListeners() {
		calculateMobileTopHeight();
		Browser.window.addEventListener('resize', Platform.isWKWebView ? onBrowserWindowResizeDelayed : onBrowserWindowResize, false);
		Browser.window.addEventListener('blur', function () {
			PageWasHidden = true;

			for (key in keysPending) {
				key.preventDefault = function() {};
				emit("keyup", key);
			}
		}, false);
		Browser.window.addEventListener('focus', function () { InvalidateLocalStages(); requestAnimationFrame(); }, false);
		Browser.window.addEventListener('beforeprint', function () {
			if (!printMode) {
				printMode = true;
				prevInvalidateRenderable = DisplayObjectHelper.InvalidateRenderable;
				DisplayObjectHelper.InvalidateRenderable = false;
				PixiStage.forceClipRenderable();
				emit("beforeprint");
				forceRender();
			}
		}, false);

		Browser.window.addEventListener('afterprint', function () {
			if (printMode) {
				DisplayObjectHelper.InvalidateRenderable = prevInvalidateRenderable;
				printMode = false;
				emit("afterprint");
				forceRender();
			}
		}, false);

		// Make additional resize for mobile fullscreen mode
		if (Platform.isMobile) {
			on("fullscreen", function(isFullScreen) {
				var size = isFullScreen ? getScreenSize() : {width: Browser.window.innerWidth, height: Browser.window.innerHeight};
				onBrowserWindowResize({target: {innerWidth: size.width, innerHeight: size.height}});
			});
		}
	}

	private static inline function isPortaitOrientation() {
		return Browser.window.matchMedia("(orientation: portrait)").matches || (Platform.isAndroid && Browser.window.orientation == 0);
	}

	private static inline function calculateMobileTopHeight() {
		var topHeight = cast (getScreenSize().height - Browser.window.innerHeight);

		// Calculate top height only once for each orientation
		if (isPortaitOrientation()) {
			if (WindowTopHeightPortrait == -1)
				WindowTopHeightPortrait = topHeight;
		} else {
			if (WindowTopHeightLandscape == -1)
				WindowTopHeightLandscape = topHeight;
		}
	}

	public static function setApplicationLanguage(languageCode : String) {
		Browser.document.documentElement.setAttribute("lang", languageCode);
		Browser.document.documentElement.setAttribute("xml:lang", languageCode);
	}

	public static function getSafeArea() : Array<Float> {
		var viewport = Browser.document.querySelector('meta[name="viewport"]');

		if (viewport != null && viewport.getAttribute("content").indexOf("viewport-fit=cover") >= 0) {
			var l = Std.parseFloat(Browser.window.getComputedStyle(Browser.document.documentElement).getPropertyValue("--sal"));
			var t = Std.parseFloat(Browser.window.getComputedStyle(Browser.document.documentElement).getPropertyValue("--sat"));
			var r = Std.parseFloat(Browser.window.getComputedStyle(Browser.document.documentElement).getPropertyValue("--sar"));
			var b = Std.parseFloat(Browser.window.getComputedStyle(Browser.document.documentElement).getPropertyValue("--sab"));

			return [
				Math.isNaN(l) ? 0.0 : l,
				Math.isNaN(t) ? 0.0 : t,
				Math.isNaN(r) ? 0.0 : r,
				Math.isNaN(b) ? 0.0 : b
			];
		} else {
			return [0.0, 0.0, 0.0, 0.0];
		}
	}

	private static inline function initCanvasStackInteractions() {
		var onmove = function(e) {
			var localStages = PixiStage.children;
			var currentInteractiveLayerZorder = 0;

			var i = localStages.length - 1;
			while(i > 0) {
				if (untyped localStages[i].view.style.pointerEvents == "all") {
					currentInteractiveLayerZorder = i;
				}

				i--;
			}

			if (currentInteractiveLayerZorder == 0)
				return;

			var pos = Util.getPointerEventPosition(e);

			i = localStages.length - 1;
			while(i > currentInteractiveLayerZorder) {
				if (getClipAt(localStages[i], pos, true, 0.0) != null &&
					untyped localStages[i].view.style.pointerEvents != "all") {

					untyped localStages[i].view.style.pointerEvents = "all";
					untyped localStages[currentInteractiveLayerZorder].view.style.pointerEvents = "none";

					untyped RenderSupport.PixiRenderer.view = untyped localStages[i].view;

					if (e.type == "touchstart") {
						emitMouseEvent(PixiStage, "mousedown", pos.x, pos.y);
						emitMouseEvent(PixiStage, "mouseup", pos.x, pos.y);
					}

					return;
				}

				i--;
			}

			if (getClipAt(localStages[currentInteractiveLayerZorder], pos, true, 0.0) == null) {
				untyped localStages[currentInteractiveLayerZorder].view.style.pointerEvents = "none";
			}
		};

		Browser.document.addEventListener('mousemove', onmove, false);
		if (Native.isTouchScreen())
			Browser.document.addEventListener('touchstart', onmove, false);
	}

	private static inline function getMobileTopHeight() {
		if (isPortaitOrientation()) {
			return WindowTopHeightPortrait;
		} else {
			return WindowTopHeightLandscape;
		}
	}

	private static inline function initClipboardListeners() {
		var handler = function handlePaste (e : Dynamic) {
			if (untyped Browser.window.clipboardData && untyped Browser.window.clipboardData.getData) { // IE
				Native.clipboardData = untyped Browser.window.clipboardData.getData('Text');
				Native.clipboardDataHtml = ""; // IE does not support HTML from clipboard
			} else if (e.clipboardData && e.clipboardData.getData) {
				Native.clipboardData = e.clipboardData.getData('text/plain');
				Native.clipboardDataHtml = e.clipboardData.getData('text/html');
			} else {
				Native.clipboardData = "";
				Native.clipboardDataHtml = "";
			}

			var files : Array<Dynamic> = new Array<Dynamic>();
			if (!Platform.isIE && !Platform.isEdge)
				for (i in 0...e.clipboardData.files.length) {
					files[i] = e.clipboardData.files[i];
				}

			emit("paste", files);
		};

		Browser.document.addEventListener('paste', handler, false);
	}

	private static inline function initMessageListener() {
		Browser.window.addEventListener('message', receiveWindowMessage, false);
	}

	private static inline function initFullScreenEventListeners() {
		if (untyped Browser.document.body.requestFullscreen != null)
			Browser.document.addEventListener('fullscreenchange', fullScreenTrigger, false);
		else if (untyped Browser.document.body.mozRequestFullScreen != null)
			Browser.document.addEventListener('mozfullscreenchange', fullScreenTrigger, false);
		else if (untyped Browser.document.body.webkitRequestFullscreen != null)
			Browser.document.addEventListener('webkitfullscreenchange', fullScreenTrigger, false);
		else if (untyped Browser.document.body.msRequestFullscreen != null)
			Browser.document.addEventListener('MSFullscreenChange', fullScreenTrigger, false);
		else if (untyped Browser.document.body.webkitEnterFullScreen != null)
			Browser.document.addEventListener('webkitfullscreenchange', fullScreenTrigger, false);
	}

	private static function receiveWindowMessage(e : Dynamic) {
		emit("message", e);

		var hasNestedWindow : Dynamic = null;
		hasNestedWindow = function(iframe : IFrameElement, win : js.html.Window) {
			try {
				if (iframe.contentWindow == win) return true;
				var iframes = iframe.contentWindow.document.getElementsByTagName("iframe");
				for (i in 0...iframes.length) if (hasNestedWindow(iframes[i], win)) return true;
			} catch(e : Dynamic) { Errors.print(e); /* Likely Cross-Domain restriction */ }

			return false;
		}

		var content_win = e.source;
		var all_iframes = Browser.document.getElementsByTagName("iframe");

		for (i in 0...all_iframes.length) {
			var f : js.html.Node = all_iframes[i];
			if (hasNestedWindow(f, content_win)) {
				untyped f.callflow(["postMessage", e.data]);
				return;
			}
		}
	}

	private static inline function getScreenSize() {
		if (Platform.isIOS && (Platform.isChrome || Platform.isSafari || ProgressiveWebTools.isRunningPWA())) {
			var is_portrait = isPortaitOrientation();
			return is_portrait ?
				{ width : Browser.window.screen.width, height : Browser.window.screen.height} :
				{ height : Browser.window.screen.width, width : Browser.window.screen.height};
		} else {
			return { width : Browser.window.screen.width, height : Browser.window.screen.height};
		}
	}

	// Delay is required due to issue in WKWebView
	// https://bugs.webkit.org/show_bug.cgi?id=170595
	private static inline function onBrowserWindowResizeDelayed(e : Dynamic) : Void {
		Native.timer(100, function() {
			onBrowserWindowResize(e);
		});
	}

	private static inline function onBrowserWindowResize(e : Dynamic) : Void {
		if (printMode) return;

		backingStoreRatio = getBackingStoreRatio();

		if (backingStoreRatio != PixiRenderer.resolution) {
			createPixiRenderer();
		} else {
			var win_width = e.target.innerWidth;
			var win_height = e.target.innerHeight;

			if (Platform.isAndroid || (Platform.isIOS && (Platform.isChrome || ProgressiveWebTools.isRunningPWA()))) {
				calculateMobileTopHeight();

				// Still send whole window size - without reducing by screen kbd
				// for flow does not resize the stage. The stage will be
				// scrolled by this renderer if needed or by the browser when it is supported.
				// Assume that WindowTopHeight is equal for both landscape and portrait and
				// browser window is fullscreen
				var screen_size = getScreenSize();
				win_width = screen_size.width;
				win_height = screen_size.height - cast getMobileTopHeight();

				if (Platform.isAndroid) {
					PixiStage.y = 0.0; // Layout emenets without shift to test overalap later
					// Assume other mobile browsers do it theirselves
					ensureCurrentInputVisible(); // Test overlap and shift if needed
				}
			}

			PixiView.width = win_width * backingStoreRatio;
			PixiView.height = win_height * backingStoreRatio;

			PixiView.style.width = win_width;
			PixiView.style.height = win_height;

			PixiRenderer.resize(win_width, win_height);
		}

		PixiStage.broadcastEvent("resize", backingStoreRatio);
		InvalidateLocalStages();

		// Render immediately - Avoid flickering on Safari and some other cases
		render();
	}

	private static function dropCurrentFocus() : Void {
		if (Browser.document.activeElement != null && !isEmulating)
			Browser.document.activeElement.blur();
	}

	private static function setDropCurrentFocusOnMouse(drop : Bool) : Void {
		if (DropCurrentFocusOnMouse != drop) {
			DropCurrentFocusOnMouse = drop;

			var event_name = Platform.isMobile ? "touchend" : "mousedown";
			if (drop)
				on(event_name, dropCurrentFocus);
			else
				off(event_name, dropCurrentFocus);
		}
	}

	private static function pixiStageOnMouseMove() : Void {
		if (!isEmulating) switchFocusFramesShow(false);
	}

	public static var MouseUpReceived : Bool = true;

	public static function addNonPassiveEventListener(element : Element, event : String, fn : Dynamic -> Void) : Void {
		untyped __js__("element.addEventListener(event, fn, { passive : false })");
	}

	public static function removeNonPassiveEventListener(element : Element, event : String, fn : Dynamic -> Void) : Void {
		untyped __js__("element.removeEventListener(event, fn, { passive : false })");
	}

	private static inline function initPixiStageEventListeners() {
		var onpointerdown = function(e : Dynamic) {
			// Prevent default drop focus on canvas
			// Works incorrectly in Edge
			e.preventDefault();

			if (e.touches != null) {
				TouchPoints = e.touches;
				emit("touchstart");

				if (e.touches.length == 1) {
					MousePos.x = e.touches[0].pageX;
					MousePos.y = e.touches[0].pageY;

					if (MouseUpReceived) emit("mousedown");
				} else if (e.touches.length > 1) {
					GesturesDetector.processPinch(new Point(e.touches[0].pageX, e.touches[0].pageY), new Point(e.touches[1].pageX, e.touches[1].pageY));
				}
			} else if (!Platform.isMobile || e.pointerType == null || e.pointerType != 'touch' || MousePos.x != e.pageX || MousePos.y != e.pageY) {
				MousePos.x = e.pageX;
				MousePos.y = e.pageY;

				if (e.which == 3 || e.button == 2) {
					emit("mouserightdown");
				} else if (e.which == 2 || e.button == 1) {
					emit("mousemiddledown");
				} else if (e.which == 1 || e.button == 0) {
					if (MouseUpReceived) emit("mousedown");
				}
			}
		};

		var onpointerup = function(e : Dynamic) {
			if (e.touches != null) {
				TouchPoints = e.touches;
				emit("touchend");

				GesturesDetector.endPinch();

				if (e.touches.length == 0) {
					if (!MouseUpReceived) emit("mouseup");
				}
			} else if (!Platform.isMobile || e.pointerType == null || e.pointerType != 'touch' || MousePos.x != e.pageX || MousePos.y != e.pageY) {
				MousePos.x = e.pageX;
				MousePos.y = e.pageY;

				if (e.which == 3 || e.button == 2) {
					emit("mouserightup");
				} else if (e.which == 2 || e.button == 1) {
					emit("mousemiddleup");
				} else if (e.which == 1 || e.button == 0) {
					if (!MouseUpReceived) emit("mouseup");
				}
			}
		};

		var onpointermove = function(e : Dynamic) {
			if (e.touches != null) {
				e.preventDefault();

				TouchPoints = e.touches;
				emit("touchmove");

				if (e.touches.length == 1) {
					MousePos.x = e.touches[0].pageX;
					MousePos.y = e.touches[0].pageY;

					emit("mousemove");
				} else if (e.touches.length > 1) {
					GesturesDetector.processPinch(new Point(e.touches[0].pageX, e.touches[0].pageY), new Point(e.touches[1].pageX, e.touches[1].pageY));
				}
			} else if (!Platform.isMobile || e.pointerType == null || e.pointerType != 'touch' || MousePos.x != e.pageX || MousePos.y != e.pageY) {
				MousePos.x = e.pageX;
				MousePos.y = e.pageY;

				emit("mousemove");
			}
		};

		var onpointerout = function(e : Dynamic) {
			if (e.relatedTarget == Browser.document.documentElement) {
				if (!MouseUpReceived) emit("mouseup");
			}
		};

		if (Platform.isMobile) {
			if (Platform.isAndroid || (Platform.isSafari && Platform.browserMajorVersion >= 13)) {
				addNonPassiveEventListener(Browser.document.body, "pointerdown", onpointerdown);
				addNonPassiveEventListener(Browser.document.body, "pointerup", onpointerup);
				addNonPassiveEventListener(Browser.document.body, "pointermove", onpointermove);
				addNonPassiveEventListener(Browser.document.body, "pointerout", onpointerout);
			}

			addNonPassiveEventListener(Browser.document.body, "touchstart", onpointerdown);
			addNonPassiveEventListener(Browser.document.body, "touchend", onpointerup);
			addNonPassiveEventListener(Browser.document.body, "touchmove", onpointermove);
		} else if (Platform.isSafari) {
			addNonPassiveEventListener(Browser.document.body, "mousedown", onpointerdown);
			addNonPassiveEventListener(Browser.document.body, "mouseup", onpointerup);
			addNonPassiveEventListener(Browser.document.body, "mousemove", onpointermove);
			addNonPassiveEventListener(Browser.document.body, "mouseout", onpointerout);
		} else if (Platform.isIE) {
			Browser.document.body.onpointerdown = onpointerdown;
			Browser.document.body.onpointerup = onpointerup;
			Browser.document.body.onpointermove = onpointermove;
			Browser.document.body.onpointerout = onpointerout;
		} else {
			addNonPassiveEventListener(Browser.document.body, "pointerdown", onpointerdown);
			addNonPassiveEventListener(Browser.document.body, "pointerup", onpointerup);
			addNonPassiveEventListener(Browser.document.body, "pointermove", onpointermove);
			addNonPassiveEventListener(Browser.document.body, "pointerout", onpointerout);
		}

		addNonPassiveEventListener(Browser.document.body, "keydown", function(e : Dynamic) {
			if (RendererType == "html") {
				onKeyDownAccessibilityZoom(e);
			}

			MousePos.x = e.clientX;
			MousePos.y = e.clientY;

			emit("keydown", parseKeyEvent(e));
		});

		addNonPassiveEventListener(Browser.document.body, "keyup", function(e : Dynamic) {
			MousePos.x = e.clientX;
			MousePos.y = e.clientY;

			emit("keyup", parseKeyEvent(e));
		});

		setStageWheelHandler(function (p : Point) { emit("mousewheel", p); emitMouseEvent(PixiStage, "mousemove", MousePos.x, MousePos.y); });

		on("mousedown", function (e) { hadUserInteracted = true; MouseUpReceived = false; });
		on("mouseup", function (e) { MouseUpReceived = true; });

		switchFocusFramesShow(false);
		setDropCurrentFocusOnMouse(true);
	}

	private static function setStageWheelHandler(listener : Point -> Void) : Void {
		var event_name = untyped __js__("'onwheel' in document.createElement('div') ? 'wheel' : // Modern browsers support 'wheel'
			document.onmousewheel !== undefined ? 'mousewheel' : // Webkit and IE support at least 'mousewheel'
			'DOMMouseScroll'; // let's assume that remaining browsers are older Firefox");


		var wheel_cb = function(event) {
			var sX = 0.0, sY = 0.0,	// spinX, spinY
				pX = 0.0, pY = 0.0;	// pixelX, pixelY

			// prevents swipe back for Safari
			if (Platform.isSafari && event.deltaX < 0 && Math.abs(event.deltaX) > Math.abs(event.deltaY)) {
				event.preventDefault();
			}

			// Legacy
			if (event.detail != null) { sY = event.detail; }
			if (event.wheelDelta != null) { sY = -event.wheelDelta / 120; }
			if (event.wheelDeltaY != null) { sY = -event.wheelDeltaY / 120; }
			if (event.wheelDeltaX != null) { sX = -event.wheelDeltaX / 120; }

			// side scrolling on FF with DOMMouseScroll
			if (event.axis != null && untyped HaxeRuntime.strictEq(event.axis, event.HORIZONTAL_AXIS)) {
				sX = sY;
				sY = 0.0;
			}

			pX = sX * PIXEL_STEP;
			pY = sY * PIXEL_STEP;

			if (event.deltaY != null) { pY = event.deltaY; }
			if (event.deltaX != null) { pX = event.deltaX; }

			if ((pX != 0.0 || pY != 0.0) && event.deltaMode != null) {
				if (event.deltaMode == 1) {	// delta in LINE units
					pX *= LINE_HEIGHT;
					pY *= LINE_HEIGHT;
				} else { // delta in PAGE units
					pX *= PAGE_HEIGHT;
					pY *= PAGE_HEIGHT;
				}
			}

			// Fall-back if spin cannot be determined
			if (pX != 0.0 && sX == 0.0) { sX = (pX < 1.0) ? -1.0 : 1.0; }
			if (pY != 0.0 && sY == 0.0) { sY = (pY < 1.0) ? -1.0 : 1.0; }

			if (event.shiftKey != null && event.shiftKey && sX == 0.0) {
				sX = sY;
				sY = 0.0;
			}

			if (RendererType != "html" || !onMouseWheelAccessibilityZoom(event, -sX, -sY)) {
				listener(new Point(-sX, -sY));
			}

			return false;
		};

		Browser.window.addEventListener(event_name, wheel_cb, false);
		if ( event_name == "DOMMouseScroll" ) {
			Browser.window.addEventListener("MozMousePixelScroll", wheel_cb, false);
		}
	}


	private static function emitForInteractives(clip : DisplayObject, event : String) : Void {
		if (clip.interactive)
			clip.emit(event);

		if (untyped clip.children != null) {
			var childs : Array<DisplayObject> = untyped clip.children;
			for (c in childs) {
				emitForInteractives(c, event);
			}
		}
	}

	public static function provideEvent(e : js.html.Event) {
		try {
			if (Platform.isIE) {
				PixiView.dispatchEvent(untyped __js__("new CustomEvent(e.type, e)"));
			} else {
				PixiView.dispatchEvent(untyped __js__("new e.constructor(e.type, e)"));
			}
		} catch (er : Dynamic) {
			Errors.report("Error in provideEvent: " + er);
		}
	}

	public static function emulateMouseClickOnClip(clip : DisplayObject) : Void {
		var b = clip.getBounds();
		MousePos = clip.toGlobal(new Point( b.width / 2.0, b.height / 2.0));

		// Expicitly emulate user action with mouse
		emulateEvent("mousemove");
		emulateEvent("mouseover", 100, clip);
		emulateEvent("mousedown", 400);
		emulateEvent("mouseup", 500);
		emulateEvent("mouseout", 600, clip);
	}

	private static function forceRollOverRollOutUpdate() : Void {
		if (RendererType != "html") {
			untyped PixiRenderer.plugins.interaction.mouseOverRenderer = true;
			untyped PixiRenderer.plugins.interaction.update(Browser.window.performance.now());
		}
	}

	public static function emitMouseEvent(clip : DisplayObject, event : String, x : Float, y : Float) : Void {
		MousePos.x = x;
		MousePos.y = y;

		if (event == "mousemove") {
			var me = {
				clientX : Std.int(x),
				clientY : Std.int(y),
			};

			var e = Platform.isIE || Platform.isSafari
				? untyped __js__("new CustomEvent('pointermove', me)")
				: new js.html.PointerEvent("pointermove", me);

			Browser.window.document.dispatchEvent(e);
			forceRollOverRollOutUpdate();
		}

		if (Util.isMouseEventName(event)) {
			emit(event);
		} else {
			clip.emit(event);
		}
	}

	public static function emitKeyEvent(clip : DisplayObject, event : String, key : String, ctrl : Bool, shift : Bool, alt : Bool, meta : Bool, keyCode : Int) : Void {
		var activeElement = Browser.document.activeElement;

		var ke = {key : key, ctrl : ctrl, shift : shift, alt : alt, meta : meta, keyCode : keyCode, preventDefault : function () {}};
		emit(event, ke);

		if (activeElement.tagName.toLowerCase() == "input" || activeElement.tagName.toLowerCase() == "textarea") {
			var ke = {key : key, ctrlKey : ctrl, shiftKey : shift, altKey : alt, metaKey : meta, keyCode : keyCode};

			if ((event == "keydown" || event == "keypress") && (key.length == 1 || keyCode == 8/*backspace*/ || keyCode == 46/*delete*/)) {
				var selectionStart = untyped activeElement.selectionStart != null ? untyped activeElement.selectionStart : untyped activeElement.value.length;
				var selectionEnd = untyped activeElement.selectionEnd != null ? untyped activeElement.selectionEnd : untyped activeElement.value.length;

				activeElement.dispatchEvent(Platform.isIE ? untyped __js__("new CustomEvent(event, ke)") : new js.html.KeyboardEvent(event, ke));

				if (selectionStart == selectionEnd) {
					untyped activeElement.value =
						keyCode == 8 ? untyped activeElement.value.substr(0, selectionStart - 1) + untyped activeElement.value.substr(selectionStart) :
						keyCode == 46 ? untyped activeElement.value.substr(0, selectionStart) + untyped activeElement.value.substr(selectionStart + 1) :
						untyped activeElement.value.substr(0, selectionStart) + key + untyped activeElement.value.substr(selectionStart);
				} else {
					untyped activeElement.value =
						keyCode == 8 || keyCode == 46 ? untyped activeElement.value.substr(0, selectionStart) + untyped activeElement.value.substr(selectionEnd) :
						untyped activeElement.value.substr(0, selectionStart) + key + untyped activeElement.value.substr(selectionEnd);
				}

				var ie : Dynamic = untyped __js__("{
					data : activeElement.value,
					inputType : 'insertText',
					isComposing : false,
					bubbles : true,
					composed : true,
					isTrusted : true
				}");

				activeElement.dispatchEvent(Platform.isIE || Platform.isEdge ? untyped __js__("new CustomEvent('input', ie)") : untyped __js__("new InputEvent('input', ie)"));
			} else {
				activeElement.dispatchEvent(Platform.isIE ? untyped __js__("new CustomEvent(event, ke)") : new js.html.KeyboardEvent(event, ke));
			}
		}
	}

	private static function emulateEvent(event : String, delay : Int = 10, clip : DisplayObject = null) : Void {
		defer(function() {
			isEmulating = true;

			if (event == "mouseover" || event == "mouseout") {
				if (clip != null)
					emitForInteractives(clip, event);
			} else {
				emit(event);
			}

			isEmulating = false;
		}, delay);
	}

	public static function ensureCurrentInputVisible() : Void {
		var focused_node = Browser.document.activeElement;
		if (focused_node != null) {
			var node_name : String = focused_node.nodeName;
			node_name = node_name.toLowerCase();
			if (node_name == "input" || node_name == "textarea") {
				//ios doesn't update window height when virtual keyboard is shown
				var visibleAreaHeight = if (Platform.isIOS) Browser.window.innerHeight / 4 else Browser.window.innerHeight;
				var rect = focused_node.getBoundingClientRect();
				if (rect.bottom > visibleAreaHeight) { // Overlaped by screen keyboard
					if (Platform.isIOS) {
						Browser.window.scrollTo(0, rect.bottom - visibleAreaHeight);
					} else {
						var mainStage = PixiStage.children[0];
						mainStage.y = visibleAreaHeight - rect.bottom;
						var onblur : Dynamic = function () {};
						onblur = function() {
							mainStage.y = 0;
							focused_node.removeEventListener("blur", onblur);
						};
						focused_node.addEventListener("blur", onblur);
					}
				}
			}
		}
	}

	private static var FocusFramesShown = null;
	private static function switchFocusFramesShow(toShowFrames : Bool) : Void {
		if (FocusFramesShown != toShowFrames) {
			FocusFramesShown = toShowFrames;
			// Interrupt of executing that not handle repeatable pressing tab key when focus frames are shown
			var pixijscss : js.html.CSSStyleSheet = null;

			// Get flowpixijs.css
			for (css in Browser.document.styleSheets) {
				if (css.href != null && css.href.indexOf("flowjspixi.css") >= 0) pixijscss = untyped css;
			}

			if (pixijscss != null) {
				var newRuleIndex = 0;
				if (!toShowFrames) {
					pixijscss.insertRule(".focused { outline: none !important; box-shadow: none !important; }", newRuleIndex);
					off("mousemove", pixiStageOnMouseMove); // Remove mouse event listener that not handle it always when focus frames are hidden
				} else {
					pixijscss.deleteRule(newRuleIndex);
					on("mousemove", pixiStageOnMouseMove);
				}
			}
		}
	}

	private static inline var FlowMainFunction = #if (flow_main) MacroUtils.parseDefine("flow_main") #else "flow_main" #end ;
	private static function StartFlowMain() {
		Errors.print("Starting flow main.");
		untyped Browser.window[FlowMainFunction]();
	}

	private static var rendering = false;

	private static function requestAnimationFrame() {
		Browser.window.cancelAnimationFrame(AnimationFrameId);
		AnimationFrameId = Browser.window.requestAnimationFrame(animate);
	}

	public static var Animating = false;

	private static function animate(?timestamp : Float) {
		if (timestamp != null) {
			emit("drawframe", timestamp);
		}

		if (PageWasHidden) {
			PageWasHidden = false;
			InvalidateLocalStages();
		} else if (Browser.document.hidden) {
			PageWasHidden = true;
		}

		if (VideoClip.NeedsDrawing() || PixiStageChanged) {
			Animating = true;
			PixiStageChanged = false;

			if (RendererType == "html") {
				TransformChanged = false;

				AccessWidget.updateAccessTree();

				for (child in PixiStage.children) {
					untyped child.render(untyped PixiRenderer);
				}
			} else {
				TransformChanged = false;

				if (RendererType == "canvas") {
					for (child in PixiStage.children) {
						untyped child.updateView();
					}
				}

				AccessWidget.updateAccessTree();

				for (child in PixiStage.children) {
					untyped child.render(untyped PixiRenderer);
				}
			}

			untyped PixiRenderer._lastObjectRendered = PixiStage;
			PixiStageChanged = false; // to protect against recursive invalidations
			Animating = false;

			emit("stagechanged", timestamp);
		} else {
			AccessWidget.updateAccessTree();
		}

		requestAnimationFrame();
	}

	public static inline function render() : Void {
		animate();
	}

	public static function forceRender() : Void {
		for (child in PixiStage.getClipChildren()) {
			child.invalidateTransform("forceRender", true);
		}

		render();
	}

	public static function addPasteEventListener(fn : Array<Dynamic> -> Void) : Void -> Void {
		on("paste", fn);
		return function() { off("paste", fn); };
	}

	public static function addMessageEventListener(fn : String -> String -> Void) : Void -> Void {
		var handler = function(e) {
			if (untyped __js__('typeof e.data == "string"'))
				fn(e.data, e.origin);
		};

		on("message", handler);
		return function() { off("message", handler); };
	}

	public static function InvalidateLocalStages() {
		for (child in PixiStage.children) {
			child.invalidateTransform('InvalidateLocalStages', true);
		}

		render();
	}

	public static function getPixelsPerCm() : Float {
		return 96.0 / 2.54;
	}

	public static function getBrowserZoom() : Float {
		return browserZoom;
	}

	public static function isDarkMode() : Bool {
		return Platform.isDarkMode;
	}

	public static function setHitboxRadius(radius : Float) : Bool {
		return false;
	}

	public static function setAccessibilityEnabled(enabled : Bool) : Void {
		AccessibilityEnabled = enabled && Platform.AccessiblityAllowed;
	}

	public static function setEnableFocusFrame(show : Bool) : Void {
		EnableFocusFrame = show;
	}

	public static function setAccessAttributes(clip : DisplayObject, attributes : Array<Array<String>>) : Void {
		var attributesMap = new Map<String, String>();

		for (kv in attributes) {
			attributesMap.set(kv[0], kv[1]);
		}

		var accessWidget : AccessWidget = untyped clip.accessWidget;

		if (accessWidget == null) {
			if (AccessibilityEnabled || attributesMap.get("tag") == "form") {
				if (RendererType == "html") {
					clip.initNativeWidget();
				}

				var nativeWidget : Element = untyped clip.nativeWidget;

				// Create DOM node for access. properties
				if (nativeWidget != null) {
					accessWidget = new AccessWidget(clip, nativeWidget);
					untyped clip.accessWidget = accessWidget;
					accessWidget.addAccessAttributes(attributesMap);
				} else {
					AccessWidget.createAccessWidget(clip, attributesMap);
				}
			}
		} else {
			accessWidget.addAccessAttributes(attributesMap);
		}
	}

	public static function setClipStyle(clip : DisplayObject, name : String, value : String) : Void {
		var accessWidget : AccessWidget = untyped clip.accessWidget;

		if (accessWidget == null) {
			if (AccessibilityEnabled || RendererType == "html") {
				if (RendererType == "html") {
					clip.initNativeWidget();
				}

				var nativeWidget : Element = untyped clip.nativeWidget;

				// Create DOM node for access. properties
				if (nativeWidget != null) {
					accessWidget = new AccessWidget(clip, nativeWidget);
					untyped clip.accessWidget = accessWidget;
					untyped accessWidget.element.style[name] = value;
				}
			}
		} else {
			untyped accessWidget.element.style[name] = value;
		}
	}

	public static function removeAccessAttributes(clip : Dynamic) : Void {
		if (clip.accessWidget != null) {
			AccessWidget.removeAccessWidget(clip.accessWidget);
		}
	}

	public static function setAccessCallback(clip : Dynamic, callback : Void -> Void) : Void {
		clip.accessCallback = callback;
	}

	public static function setClipTagName(clip : Dynamic, tagName : String) : Void {
		if (clip.nativeWidget != null) {
			clip.nativeWidget = null;
			clip.tagName = tagName;
			clip.createNativeWidget(tagName);

			if (clip.updateNativeWidgetStyle != null) {
				clip.updateNativeWidgetStyle();
			}

			DisplayObjectHelper.invalidateTransform(clip);
		} else {
			clip.tagName = tagName;
		}
	}

	public static function setClipClassName(clip : DisplayObject, className : String) : Void {
		untyped clip.className = className;

		if (untyped clip.nativeWidget == null) {
			clip.initNativeWidget();
		} else {
			untyped clip.nativeWidget.classList.add(className);
		}
	}

	private static function setShouldPreventFromBlur(clip : Dynamic) : Void {
		if (clip.nativeWidget != null && clip.shouldPreventFromBlur != null) {
			clip.shouldPreventFromBlur = true;
		}

		var children : Array<Dynamic> = untyped clip.children;
		if (children != null) {
			for (child in children) {
				setShouldPreventFromBlur(child);
			}
		}
	}

	// native currentClip : () -> flow = FlashSupport.currentClip;
	public static function currentClip() : DisplayObject {
		return PixiStage;
	}

	public static function mainRenderClip() : FlowContainer {
		if (PixiStage.children.length == 0) {
			var stage = new FlowContainer();
			addChild(PixiStage, stage);

			return stage;
		} else {
			return cast(PixiStage.children[0], FlowContainer);
		}
	}

	public static function enableResize() : Void {
		IsLoading = false;
		if (PixiView != null) {
			PixiView.style.display = 'block';
		}

		// The first flow render call. Hide loading progress indicator.
		Browser.document.body.style.backgroundImage = "none";
		var indicator = Browser.document.getElementById("loading_js_indicator");
		if (indicator != null) {
			Browser.document.body.removeChild(indicator);
		}
	}

	public static function getStageWidth() : Float {
		return PixiRenderer.width / backingStoreRatio / getAccessibilityZoom();
	}

	public static function getStageHeight() : Float {
		return PixiRenderer.height / backingStoreRatio / getAccessibilityZoom();
	}

	public static function makeTextField(fontFamily : String) : TextClip {
		return new TextClip();
	}

	public static function setTextAndStyle(clip : TextClip, text : String, fontFamily : String, fontSize : Float, fontWeight : Int, fontSlope : String,
		fillColor : Int, fillOpacity : Float, letterSpacing : Float, backgroundColor : Int, backgroundOpacity : Float) : Void {
		clip.setTextAndStyle(text, fontFamily, fontSize, fontWeight, fontSlope,
			fillColor, fillOpacity, letterSpacing, backgroundColor, backgroundOpacity);
	}

	public static function setEscapeHTML(clip : TextClip, escapeHTML : Bool) : Void {
		clip.setEscapeHTML(escapeHTML);
	}

	public static function setAdvancedText(clip : TextClip, sharpness : Int, antialiastype : Int, gridfittype : Int) : Void {
		// NOP
	}

	public static function makeVideo(metricsFn : Float -> Float -> Void, playFn : Bool -> Void, durationFn : Float -> Void, positionFn : Float -> Void) : DisplayObject {
		return new VideoClip(metricsFn, playFn, durationFn, positionFn);
	}

	public static function setVideoVolume(clip : VideoClip, volume : Float) : Void {
		clip.setVolume(volume);
	}

	public static function setVideoLooping(clip : VideoClip, loop : Bool) : Void {
		clip.setLooping(loop);
	}

	public static function setVideoControls(clip : VideoClip, controls : Dynamic) : Void {
		// STUB; only implemented in C++/OpenGL
	}

	public static function setVideoSubtitle(clip: Dynamic, text : String, fontfamily : String, fontsize : Float, fontweight : Int,
		fontslope : String, fillcolor : Int, fillopacity : Float, letterspacing : Float, backgroundcolour : Int, backgroundopacity : Float,
		alignBottom : Bool, bottomBorder : Float, scaleMode : Bool, scaleModeMin : Float, scaleModeMax : Float, escapeHTML : Bool) : Void {
		clip.setVideoSubtitle(text, fontfamily, fontsize, fontweight, fontslope, fillcolor, fillopacity, letterspacing, backgroundcolour,
			backgroundopacity, alignBottom, bottomBorder, scaleMode, scaleModeMin, scaleModeMax, escapeHTML);
	}

	public static function setVideoPlaybackRate(clip : VideoClip, rate : Float) : Void {
		clip.setPlaybackRate(rate);
	}

	public static function setVideoTimeRange(clip: VideoClip, start : Float, end : Float) : Void {
		clip.setTimeRange(start, end);
	}

	public static function playVideo(vc : VideoClip, filename : String, startPaused : Bool) : Void {
		vc.playVideo(filename, startPaused);
	}

	public static function playVideoFromMediaStream(vc : VideoClip, mediaStream : Dynamic, startPaused : Bool) : Void {
		vc.playVideoFromMediaStream(mediaStream, startPaused);
	}

	public static function seekVideo(clip : VideoClip, seek : Float) : Void {
		clip.setCurrentTime(seek);
	}

	public static function getVideoPosition(clip : VideoClip) : Float {
		return clip.getCurrentTime();
	}

	public static function getVideoCurrentFrame(clip : VideoClip) : String {
		return clip.getCurrentFrame();
	}

	public static function pauseVideo(clip : VideoClip) : Void {
		clip.pauseVideo();
	}

	public static function resumeVideo(clip : VideoClip) : Void {
		clip.resumeVideo();
	}

	public static function closeVideo(clip : VideoClip) : Void {
		// NOP for this target
	}

	public static function getTextFieldCharXPosition(textclip : TextClip, charIdx: Int) : Float {
		return textclip.getCharXPosition(charIdx);
	}

	public static function findTextFieldCharByPosition(textclip : TextClip, x: Float, y: Float) : Int {
		/* Assuming exact glyph codes used to form each clip's text. */
		var EPSILON = 0.1; // Why not, pixel precision assumed.
		var clip = getClipAt(textclip, new Point(x, y));
		try {
			textclip = cast(clip, TextClip);
		} catch(exc: String) {
			clip = textclip;
		};
		if (textclip == null) return -1;
		var clipGlyphs = textclip.getContentGlyphs();
		var clipStyle : TextStyle = textclip.getStyle();
		var leftVal: Float = 0;
		var mtxWidth: Float = TextClip.measureTextModFrag(clipGlyphs, clipStyle, 0, clipGlyphs.text.length);
		var rightVal: Float = mtxWidth;
		if (Math.abs(leftVal-rightVal) < EPSILON) return 0;
		var org = clip.toGlobal(new Point(0.0, 0.0));
		var localX = Math.min(mtxWidth, Math.max(0.0, x - org.x));
		if (TextClip.getStringDirection(clipGlyphs.text, textclip.getTextDirection()) == "rtl") localX = rightVal - localX;
		var leftPos: Float = 0;
		var rightPos: Float = clipGlyphs.modified.length;
		var midVal: Float = -1.0;
		var midPos: Float = -1;
		var oldPos: Float = rightPos;
		while (Math.abs(localX-midVal) >= EPSILON && Math.round(midPos) != Math.round(oldPos)) {
			oldPos = midPos;
			midPos = leftPos + (rightPos - leftPos) * (localX - leftVal) / (rightVal-leftVal);
			if (midPos<leftPos) break;
			mtxWidth = TextClip.measureTextModFrag(clipGlyphs, clipStyle, Math.floor(leftPos), Math.ceil(leftPos));
			midVal = leftVal - mtxWidth * (leftPos - Math.floor(leftPos));
			mtxWidth = TextClip.measureTextModFrag(clipGlyphs, clipStyle, Math.floor(leftPos), Math.floor(midPos));
			midVal += mtxWidth;
			mtxWidth = TextClip.measureTextModFrag(clipGlyphs, clipStyle, Math.floor(midPos), Math.ceil(midPos));
			midVal += mtxWidth * (midPos - Math.floor(midPos));
			leftPos = midPos;
			leftVal = midVal;
		}
		var mappingOffset = 0.0;
		for (i in 0...Math.round(midPos)) {
			if (i < Math.ceil(midPos)-1)
				mappingOffset += clipGlyphs.difPositionMapping[i];
			else
				mappingOffset += clipGlyphs.difPositionMapping[i] * (midPos-Math.floor(midPos));
		}
		return Math.round(midPos + mappingOffset) + textclip.charIdx;
	}

	public static function getTextFieldWidth(clip : TextClip) : Float {
		return untyped clip.isInput ? clip.getWidth() : clip.getClipWidth();
	}

	public static function getTextFieldMaxWidth(clip : TextClip) : Float {
		return clip.getMaxWidth();
	}

	public static function setTextFieldWidth(clip : TextClip, width : Float) : Void {
		// NOTE : It is called by flow only for textinputs
		clip.setWidth(width);
	}

	public static function getTextFieldHeight(clip : TextClip) : Float {
		return untyped clip.isInput ? clip.getHeight() : clip.getClipHeight();
	}

	public static function setTextFieldHeight(clip : TextClip, height : Float) : Void {
		// This check is needed for cases when we get zero height for input field. Flash and cpp
		// ignore height (flash ignores it at all, cpp takes it into account only when input has
		// has a focus), so we have to have some workaround here.
		// TODO: Find a better fix
		if (height > 0.0)
			clip.setHeight(height);
	}

	public static function setTextFieldCropWords(clip : TextClip, crop : Bool) : Void {
		clip.setCropWords(crop);
	}

	public static function setTextFieldCursorColor(clip : TextClip, color : Int, opacity : Float) : Void {
		clip.setCursorColor(color, opacity);
	}

	public static function setTextFieldCursorWidth(clip : TextClip, width : Float) : Void {
		clip.setCursorWidth(width);
	}

	public static function setTextEllipsis(clip : TextClip, lines : Int, cb : Bool -> Void) : Void {
		clip.setEllipsis(lines, cb);
	}

	public static function setTextFieldInterlineSpacing(clip : TextClip, spacing : Float) : Void {
		clip.setInterlineSpacing(spacing);
	}

	public static function setTextDirection(clip : TextClip, direction : String) : Void {
		clip.setTextDirection(direction);
	}

	public static function setAutoAlign(clip : TextClip, autoalign : String) : Void {
		clip.setAutoAlign(autoalign);
	}

	public static function setTextInput(clip : TextClip) : Void {
		clip.setTextInput();
	}

	public static function setTextInputType(clip : TextClip, type : String) : Void {
		clip.setTextInputType(type);
	}

	public static function setTextInputAutoCompleteType(clip : TextClip, type : String) : Void {
		clip.setTextInputAutoCompleteType(type);
	}

	public static function setTextInputStep(clip : TextClip, step : Float) : Void {
		clip.setTextInputStep(step);
	}

	public static function setTabIndex(clip : TextClip, index : Int) : Void {
		clip.setTabIndex(index);
	}

	public static function setTabEnabled(enabled : Bool) : Void {
		// STUB; usefull only in flash
	}

	public static function getContent(clip : TextClip) : String {
		return clip.getContent();
	}

	public static function getCursorPosition(clip : TextClip) : Int {
		return clip.getCursorPosition();
	}

	public static function getFocus(clip : NativeWidgetClip) : Bool {
		return clip.getFocus();
	}

	public static function getScrollV(clip : TextClip) : Int {
		return 0;
	}

	public static function setScrollV(clip : TextClip, suggestedPosition : Int) : Void {
	}

	public static function getBottomScrollV(clip : TextClip) : Int {
		return 0;
	}

	public static function getNumLines(clip : TextClip) : Int {
		return 0;
	}

	public static function setFocus(clip : DisplayObject, focus : Bool) : Void {
		AccessWidget.updateAccessTree();
		if (focus) {
			render();
		}

		clip.setClipFocus(focus);
	}

	public static function setMultiline(clip : TextClip, multiline : Bool) : Void {
		clip.setMultiline(multiline);
	}

	public static function setWordWrap(clip : TextClip, wordWrap : Bool) : Void {
		clip.setWordWrap(wordWrap);
	}

	public static function setDoNotInvalidateStage(clip : TextClip, dontInvalidate : Bool) : Void {
		clip.setDoNotInvalidateStage(dontInvalidate);
	}

	public static function getSelectionStart(clip : TextClip) : Int {
		return clip.getSelectionStart();
	}

	public static function getSelectionEnd(clip : TextClip) : Int {
		return clip.getSelectionEnd();
	}

	public static function setSelection(clip : TextClip, start : Int, end : Int) : Void {
		clip.setSelection(start, end);
	}

	public static function setReadOnly(clip: TextClip, readOnly: Bool) : Void {
		clip.setReadOnly(readOnly);
	}

	public static function setMaxChars(clip : TextClip, maxChars : Int) : Void {
		clip.setMaxChars(maxChars);
	}

	public static function addTextInputFilter(clip : TextClip, filter : String -> String) : Void -> Void {
		return clip.addTextInputFilter(filter);
	}

	public static function addTextInputKeyEventFilter(clip : TextClip, event : String, filter : String -> Bool -> Bool -> Bool -> Bool -> Int -> Bool) : Void -> Void {
		if (event == "keydown")
			return clip.addTextInputKeyDownEventFilter(filter);
		else
			return clip.addTextInputKeyUpEventFilter(filter);
	}

	public static function addChild(parent : FlowContainer, child : Dynamic) : Void {
		parent.addChild(child);
	}

	public static function addChildAt(parent : FlowContainer, child : Dynamic, id : Int) : Void {
		parent.addChildAt(child, id);
	}

	public static function removeChild(parent : Dynamic, child : Dynamic) : Void {
		if (parent.removeElementChild != null) {
			parent.removeElementChild(child);
		} else if (child.parent == parent || child.parentElement == parent) {
			parent.removeChild(child);
		}
	}

	public static function removeChildren(parent : FlowContainer) : Void {
		for (child in parent.children) {
			parent.removeChild(child);
		}
	}

	public static function makeClip() : FlowContainer {
		return new FlowContainer();
	}

	public static function makeCanvasClip() : FlowCanvas {
		return new FlowCanvas();
	}

	public static function setClipCallstack(clip : DisplayObject, callstack : Dynamic) : Void {
		// stub
	}

	public static function setClipX(clip : DisplayObject, x : Float) : Void {
		clip.setClipX(x);
	}

	public static function setClipY(clip : DisplayObject, y : Float) : Void {
		clip.setClipY(y);
	}

	public static function setClipScaleX(clip : DisplayObject, scale : Float) : Void {
		clip.setClipScaleX(scale);
	}

	public static function setClipScaleY(clip : DisplayObject, scale : Float) : Void {
		clip.setClipScaleY(scale);
	}

	public static function setClipRotation(clip : DisplayObject, r : Float) : Void {
		clip.setClipRotation(r * 0.0174532925 /*radians*/);
	}

	public static function setClipOrigin(clip : DisplayObject, x : Float, y : Float) : Void {
		clip.setClipOrigin(x, y);
	}

	public static function getGlobalTransform(clip : DisplayObject) : Array<Float> {
		if (clip.parent != null) {
			var a = clip.worldTransform;
			var az = getAccessibilityZoom();
			return [a.a / az, a.b, a.c, a.d / az, a.tx / az, a.ty / az];
		} else {
			return [1.0, 0.0, 0.0, 1.0, 0.0, 0.0];
		}
	}

	public static function addClipAnimation(clip : DisplayObject, keyframes : Array<Array<String>>, options : Array<Array<String>>, onFinish : Void -> Void, fallbackAnimation : Void -> (Void -> Void)) : Void -> Void {
		if (RendererType == "html" && Browser.document.body.animate != null && Util.getParameter("native_animation") != "0") {
			if (untyped clip.nativeWidget == null) {
				clip.initNativeWidget();
			}

			if (untyped clip.nativeWidget == null) {
				return fallbackAnimation();
			} else {
				try {
					if (untyped !clip.hasAnimation) {
						untyped clip.hasAnimation = true;
						clip.invalidateTransform("addClipAnimation");
					}

					var nativeWidget = untyped clip.nativeWidget;
					var optionsObject : Dynamic = {};
					var disposed = false;

					if (clip.isClipOnStage()) {
						clip.updateNativeWidget();
					}

					function isNormalInteger(str) {
						var n = Math.floor(Std.parseInt(str));
						return n != Math.POSITIVE_INFINITY && Std.string(n) == str && n >= 0;
					}

					for (option in options) {
						if (isNormalInteger(option[1])) {
							untyped optionsObject[option[0]] = Std.parseInt(option[1]);
						} else {
							untyped optionsObject[option[0]] = option[1];
						}
					}

					var animation : Dynamic =
						nativeWidget.animate(
							keyframes.map(
								function(keyframe : Array<String>) {
									var o : Dynamic = {};
									var ii : Int = Std.int(keyframe.length / 2);
									for (i in 0...ii) {
										untyped o[keyframe[i * 2]] = keyframe[i * 2 + 1];
									}
									return o;
								}
							),
							optionsObject
						);


					animation.oncancel = function() {
						if (!disposed) {
							disposed = true;
							onFinish();
						}

						if (clip.isClipOnStage()) {
							clip.updateNativeWidget();
						}
					}

					animation.onremove = function() {
						if (!disposed) {
							disposed = true;
							onFinish();
						}

						if (clip.isClipOnStage()) {
							clip.updateNativeWidget();
						}
					}

					animation.onfinish = function() {
						if (!disposed) {
							disposed = true;
							onFinish();
						}

						if (clip.isClipOnStage()) {
							clip.updateNativeWidget();
						}
					}

					return function() {
						if (animation != null) {
							animation.cancel();
						}
					}
				} catch (e : Dynamic) {
					trace("addClipAnimation error:");
					trace(e);

					return fallbackAnimation();
				}
			}
		} else {
			return fallbackAnimation();
		}
	}

	public static function deferUntilRender(fn : Void -> Void) : Void {
		once("drawframe", fn);
	}

	public static function interruptibleDeferUntilRender(fn0 : Void -> Void) : Void -> Void {
		var alive = true;
		var fn = function() {
			if (alive) {
				fn0();
			}
		}

		once("drawframe", fn);
		return function() {
			alive = false;
			off("drawframe", fn);
		};
	}

	public static function setClipAlpha(clip : DisplayObject, a : Float) : Void {
		clip.setClipAlpha(a);
	}

	private static function getFirstVideoWidget(clip : FlowContainer) : Dynamic {
		if (untyped HaxeRuntime.instanceof(clip, VideoClip)) return clip;

		if (clip.children != null) {
			for (c in clip.children) {
				var video = getFirstVideoWidget(untyped c);
				if (video != null) return video;
			}
		}

		return null;
	}

	public static function setClipMask(clip : FlowContainer, mask : Dynamic) : Void {
		clip.setClipMask(mask);
	}

	public static function setClipViewBounds(clip : NativeWidgetClip, minX : Float, minY : Float, maxX : Float, maxY : Float) : Void {
		var bounds = new Bounds();

		bounds.minX = minX;
		bounds.minY = minY;
		bounds.maxX = maxX;
		bounds.maxY = maxY;

		clip.setViewBounds(bounds);
	}

	public static function setClipWidth(clip : NativeWidgetClip, width : Float) : Void {
		clip.setWidth(width);
	}

	public static function setClipHeight(clip : NativeWidgetClip, height : Float) : Void {
		clip.setHeight(height);
	}

	public static function getClipWidth(clip : NativeWidgetClip) : Float {
		return clip.getWidth != null ? clip.getWidth() : clip.getWidgetWidth();
	}

	public static function getClipHeight(clip : NativeWidgetClip) : Float {
		return clip.getHeight != null ? clip.getHeight() : clip.getWidgetHeight();
	}

	public static function setClipResolution(clip : TextClip, resolution : Float) : Void {
		clip.setResolution(resolution);
	}

	public static function startProfile(name : String) : Void {
		Browser.console.profile(name);
	}

	public static function endProfile() : Void {
		Browser.console.profileEnd();
	}

	public static function getStage() : Dynamic {
		return PixiStage;
	}

	private static function modifierStatePresent(e : Dynamic, m : String) : Bool {
		return e.getModifierState != null && e.getModifierState(m) != null;
	}

	// See
	// http://unixpapa.com/js/key.html
	public static function parseKeyEvent(e : Dynamic) : Dynamic {
		var shift = false;
		var alt = false;
		var ctrl = false;
		var meta = false;
		var charCode = -1;
		var s : String = "";

		if (modifierStatePresent(e, "Shift")) {
			shift = e.getModifierState("Shift");
		} else if (e.shiftKey != null) {
			shift = e.shiftKey;
		}

		if (modifierStatePresent(e, "Alt")) {
			alt = e.getModifierState("Alt");
		} else if (e.altKey != null) {
			alt = e.altKey;
		} else if (modifierStatePresent(e, "AltGraph")) {
			alt = e.getModifierState("AltGraph");
		}

		if (modifierStatePresent(e, "Control")) {
			ctrl = e.getModifierState("Control");
		} else if (e.ctrlKey != null) {
			ctrl = e.ctrlKey;
		}

		if (modifierStatePresent(e, "Meta")) {
			meta = e.getModifierState("Meta");
		} else if (modifierStatePresent(e, "OS")) {
			meta = e.getModifierState("OS");
		} else if (e.metaKey != null) {
			meta = e.metaKey;
		}

		// Swap meta with ctrl for macOS
		if (Platform.isMacintosh) {
			var buf : Bool = meta;
			meta = ctrl;
			ctrl = buf;
		}

		if (e.charCode != null && e.charCode > 0) {
			charCode = e.charCode;
		} else if (e.which != null) {
			charCode = e.which;
		} else if (e.keyCode != null) {
			charCode = e.keyCode;
		}

		if (e.key != null && (Std.string(e.key).length == 1 || e.key == "Meta")) {
			s = if (e.key == "Meta") Platform.isMacintosh ? "ctrl" : "meta" else e.key;
		} else if (e.code != null && (Std.string(e.code).length == 1 || e.key == "MetaLeft" || e.key == "MetaRight")) {
			s = if (e.code == "MetaLeft" || e.code == "MetaRight") Platform.isMacintosh ? "ctrl" : "meta" else e.code;
		} else if (charCode >= 96 && charCode <= 105) {
			s = Std.string(charCode - 96);
		} else if (charCode >= 112 && charCode <= 123) {
			s = "F" + (charCode - 111);
		} else {
			s = switch (charCode) {
				case 13:
					// TODO: uncomment when it is fully supported
					//if (untyped Browser.document.activeElement != null) return; // Donot call cb if there is selected item
					"enter";
				case 27: "esc";
				case 8: "backspace";
				case 9: {
					switchFocusFramesShow(EnableFocusFrame);

					"tab";
				}
				case 12: "clear";
				case 16: "shift";
				case 17: Platform.isMacintosh ? "meta" : "ctrl";
				case 18: "alt";
				case 19: "pause/break";
				case 20: "capslock";
				case 33: "pageup";
				case 34: "pagedown";
				case 35: "end";
				case 36: "home";
				case 37: "left";
				case 38: "up";
				case 39: "right";
				case 40: "down";
				case 45: "insert";
				case 46: "delete";
				case 48: if (shift) ")" else "0";
				case 49: if (shift) "!" else "1";
				case 50: if (shift) "@" else "2";
				case 51: if (shift) "#" else "3";
				case 52: if (shift) "$" else "4";
				case 53: if (shift) "%" else "5";
				case 54: if (shift) "^" else "6";
				case 55: if (shift) "&" else "7";
				case 56: if (shift) "*" else "8";
				case 57: if (shift) "(" else "9";
				case 91: Platform.isMacintosh ? "ctrl" : "meta";
				case 92: "meta";
				case 93: Platform.isMacintosh ? "ctrl" : "context";
				case 106: "*";
				case 107: "+";
				case 109: "-";
				case 110: ".";
				case 111: "/";
				case 144: "numlock";
				case 145: "scrolllock";
				case 186: if (shift) ":" else ";";
				case 187: if (shift) "+" else "=";
				case 188: if (shift) "<" else ",";
				case 189: if (shift) "_" else "-";
				case 190: if (shift) ">" else ".";
				case 191: if (shift) "?" else "/";
				case 192: if (shift) "~" else "`";
				case 219: if (shift) "{" else "[";
				case 220: if (shift) "|" else "\\";
				case 221: if (shift) "}" else "]";
				case 222: if (shift) "\"" else "'";
				case 226: if (shift) "|" else "\\";

				default: {
					var keyUTF = charCode >= 0 ? String.fromCharCode(charCode) : "";

					if (modifierStatePresent(e, "CapsLock")) {
						if (e.getModifierState("CapsLock"))
							keyUTF.toUpperCase();
						else
							keyUTF.toLowerCase();
					} else {
						keyUTF;
					}

				}
			}
		}

		return {
			key : s,
			ctrl : ctrl,
			shift : shift,
			alt : alt,
			meta : meta,
			keyCode : e.keyCode,
			preventDefault : e.preventDefault.bind(e)
		}
	}

	public static function addKeyEventListener(clip : DisplayObject, event : String,
		fn : String -> Bool -> Bool -> Bool -> Bool -> Int -> (Void -> Void) -> Bool) : Void -> Void {
		var keycb = function(ke) {
			if (event == "keydown") {
				keysPending.set(ke.keyCode, ke);
			} else {
				keysPending.remove(ke.keyCode);
			}

			fn(ke.key, ke.ctrl, ke.shift, ke.alt, ke.meta, ke.keyCode, ke.preventDefault);
		}

		on(event, keycb);
		return function() { off(event, keycb); }
	}

	public static function addStreamStatusListener(clip : VideoClip, fn : String -> Void) : Void -> Void {
		return clip.addStreamStatusListener(fn);
	}

	public static function addVideoSource(clip : VideoClip, src : String, type : String) : Void {
		clip.addVideoSource(src, type);
	}

	public static function addEventListener(clip : Dynamic, event : String, fn : Void -> Void) : Void -> Void {
		if (event == "userstylechanged" || event == "beforeprint" || event == "afterprint") {
			on(event, fn);
			return function () {
				off(event, fn);
			}
		} else if (untyped HaxeRuntime.instanceof(clip, Element)) {
			clip.addEventListener(event, fn);
			return function() { if (clip != null) clip.removeEventListener(event, fn); }
		} else {
			return addDisplayObjectEventListener(clip, event, fn);
		}
	}

	private static var pointerOverClips : Array<DisplayObject> = [];

	public static function addDisplayObjectEventListener(clip : DisplayObject, event : String, fn : Void -> Void) : Void -> Void {
		if (event == "transformchanged") {
			clip.on("transformchanged", fn);
			return function() { clip.off("transformchanged", fn); }
		} else if (event == "resize") {
			on("resize", fn);
			return function() { off("resize", fn); }
		} else if (event == "mousedown" || event == "mousemove" || event == "mouseup" || event == "mousemiddledown" || event == "mousemiddleup"
			|| event == "touchstart" || event == "touchmove" || event == "touchend") {
			on(event, fn);
			return function() { off(event, fn); }
		} else if (event == "mouserightdown" || event == "mouserightup") {
			// When we register a right-click handler, we turn off the browser context menu.
			PixiView.oncontextmenu = function (e) { e.stopPropagation(); return false; };

			on(event, fn);
			return function() { off(event, fn); }
		} else if (event == "rollover") {
			var checkFn = function() {
					if (untyped !clip.pointerOver) {
						untyped clip.pointerOver = true;
						if (Platform.isSafari && RenderSupport.pointerOverClips.indexOf(clip) < 0) {
							var clipsToRemove = [];

							for (pointerOverClip in RenderSupport.pointerOverClips) {
								if (untyped pointerOverClip.pointerOver && !pointerOverClip.destroyed) {
									if (!pointerOverClip.isParentOf(clip) && !clip.isParentOf(pointerOverClip)) {
										pointerOverClip.emit("pointerout");
										clipsToRemove.push(pointerOverClip);
									}
								} else {
									clipsToRemove.push(pointerOverClip);
								}
							}

							for (pointerOverClip in clipsToRemove) {
								RenderSupport.pointerOverClips.remove(pointerOverClip);
							}

							RenderSupport.pointerOverClips.push(clip);
						}
						fn();
					}
				}

			clip.on("pointerover", checkFn);
			clip.invalidateInteractive();
			return function() {
				clip.off("pointerover", checkFn);
				clip.invalidateInteractive();
			};
		} else if (event == "rollout") {
			var checkFn = function() {
				if (untyped clip.pointerOver) {
					untyped clip.pointerOver = false;

					if (Platform.isSafari && RenderSupport.pointerOverClips.indexOf(clip) < 0) {
						RenderSupport.pointerOverClips.remove(clip);
					}

					fn();
				}
			}

			clip.on("pointerout", checkFn);
			clip.invalidateInteractive();
			return function() {
				clip.off("pointerout", checkFn);
				clip.invalidateInteractive();
			};
		} else if (event == "scroll") {
			clip.on("scroll", fn);
			return function() { clip.off("scroll", fn); };
		} else if (event == "change") {
			clip.on("input", fn);
			return function() { clip.off("input", fn); };
		} else if (event == "focusin") {
			clip.on("focus", fn);
			return function() { clip.off("focus", fn); };
		} else if (event == "focusout") {
			clip.on("blur", fn);
			return function() { clip.off("blur", fn); };
		} else if (event == "visible"){
			clip.on("visible", fn);
			return function() { clip.off("visible", fn); }
		} else {
			Errors.report("Unknown event: " + event);
			return function() {};
		}
	}

	public static function addFileDropListener(clip : FlowContainer, maxFilesCount : Int, mimeTypeRegExpFilter : String, onDone : Array<Dynamic> -> Void) : Void -> Void {
		if (Platform.isMobile) {
			return function() { };
		} else if (RenderSupport.RendererType != "html") {
			var dropArea = new DropAreaClip(maxFilesCount, mimeTypeRegExpFilter, onDone);

			clip.addChild(dropArea);
			return function() { clip.removeChild(dropArea); };
		} else {
			return clip.addFileDropListener(maxFilesCount, mimeTypeRegExpFilter, onDone);
		}
	}

	public static function addVirtualKeyboardHeightListener(fn : Float -> Void) : Void -> Void {
		return function() {};
	}

	public static function addExtendedEventListener(clip : Dynamic, event : String, fn : Array<Dynamic> -> Void) : Void -> Void {
		if (event == "childfocused") {
			var parentFn = function(child : Dynamic) {
				var bounds = child.getBounds(true);
				var localPosition = clip.toLocal(new Point(bounds.x, bounds.y));
				fn([localPosition.x, localPosition.y, bounds.width, bounds.height]);
			};

			clip.on(event, parentFn);
			return function() { clip.off(event, parentFn); }
		} else {
			Errors.report("Unknown event: " + event);
			return function() {};
		}
	}

	public static function addDrawFrameEventListener(fn : Float -> Void) : Void -> Void {
		on("drawframe", fn);
		return function() { off("drawframe", fn); };
	}

	// Reasonable defaults
	private static var PIXEL_STEP = 10;
	private static var LINE_HEIGHT = 40;
	private static var PAGE_HEIGHT = 800;

	public static function addMouseWheelEventListener(clip : Dynamic, fn : Float -> Float -> Void) : Void -> Void {
		var cb = function (p) { fn(p.x, p.y); };
		on("mousewheel", cb);
		return function() { off("mousewheel", cb); };
	}

	public static function addFinegrainMouseWheelEventListener(clip : Dynamic, f : Float -> Float -> Void) : Void -> Void {
		return addMouseWheelEventListener(clip, f);
	}

	public static function getMouseX(?clip : DisplayObject) : Float {
		if (clip == null || clip == PixiStage)
			return MousePos.x;
		else
			return untyped __js__('clip.toLocal(RenderSupport.MousePos, null, null, true).x');
	}

	public static function getMouseY(?clip : DisplayObject) : Float {
		if (clip == null || clip == PixiStage)
			return MousePos.y;
		else
			return untyped __js__('clip.toLocal(RenderSupport.MousePos, null, null, true).y');
	}

	public static function getTouchPoints(?clip : DisplayObject) : Array<Array<Float>> {
		var touches = [];

		for (i in 0...TouchPoints.length) {
			touches.push([TouchPoints[i].pageX, TouchPoints[i].pageY]);
		}

		if (clip != null && clip != PixiStage) {
			return Lambda.array(Lambda.map(touches, function(t : Dynamic) {
				t = untyped __js__('clip.toLocal(new PIXI.Point(t[0], t[1]), null, null, true)');
				return [t.x, t.y];
			}));
		} else {
			return touches;
		}
	}

	public static function setMouseX(x : Float) {
		MousePos.x = x;
	}

	public static function setMouseY(y : Float) {
		MousePos.y = y;
	}

	public static function hittest(clip : DisplayObject, x : Float, y : Float) : Bool {
		if (!clip.getClipRenderable() || clip.parent == null) {
			return false;
		}

		clip.invalidateLocalBounds();

		var point = new Point(x, y);
		return hittestMask(clip.parent, point) && doHitTest(clip, point);
	}

	private static function hittestMask(clip : DisplayObject, point : Point) : Bool {
		if (untyped clip.viewBounds != null) {
			if (untyped clip.worldTransformChanged) {
				untyped clip.transform.updateTransform(clip.parent.transform);
			}

			var local : Point = untyped __js__('clip.toLocal(point, null, null, true)');
			var viewBounds = untyped clip.viewBounds;

			return viewBounds.minX <= local.x && viewBounds.minY <= local.y && viewBounds.maxX >= local.x && viewBounds.maxY >= local.y;
		} else if (untyped clip.scrollRect != null && !hittestGraphics(untyped clip.scrollRect, point)) {
			return false;
		} else if (clip.mask != null && !hittestGraphics(clip.mask, point)) {
			return false;
		} else {
			return clip.parent == null || hittestMask(clip.parent, point);
		}
	}

	private static function hittestGraphics(clip : FlowGraphics, point : Point, ?checkAlpha : Float) : Bool {
		var graphicsData : Array<Dynamic> = clip.graphicsData;

		if (graphicsData == null || graphicsData.length == 0) {
			return false;
		}

		var data = graphicsData[0];

		if (data.fill && data.shape != null && (checkAlpha == null || data.fillAlpha > checkAlpha)) {
			if (untyped clip.worldTransformChanged) {
				untyped clip.transform.updateTransform(clip.parent.transform);
			}

			var local : Point = untyped __js__('clip.toLocal(point, null, null, true)');

			return data.shape.contains(local.x, local.y);
		} else {
			return false;
		}
	}

	private static function doHitTest(clip : DisplayObject, point : Point) : Bool {
		return getClipAt(clip, point, false) != null;
	}

	public static function getClipAt(clip : DisplayObject, point : Point, ?checkMask : Bool = true, ?checkAlpha : Float) : DisplayObject {
		if (!clip.getClipRenderable() || untyped clip.isMask) {
			return null;
		} else if (checkMask && !hittestMask(clip, point)) {
			return null;
		} else if (clip.mask != null && !hittestGraphics(clip.mask, point)) {
			return null;
		}

		if (untyped HaxeRuntime.instanceof(clip, NativeWidgetClip) || untyped HaxeRuntime.instanceof(clip, FlowSprite)) {
			if (untyped clip.worldTransformChanged) {
				untyped clip.transform.updateTransform(clip.parent.transform);
			}

			var local : Point = untyped __js__('clip.toLocal(point, null, null, true)');
			var clipWidth = untyped clip.getWidth();
			var clipHeight = untyped clip.getHeight();
			if (checkAlpha != null && untyped HaxeRuntime.instanceof(clip, FlowSprite)) {
				try {
					var tempCanvas = Browser.document.createElement('canvas');
					untyped tempCanvas.width = clipWidth;
					untyped tempCanvas.height = clipHeight;
					var ctx = untyped tempCanvas.getContext('2d');
					untyped ctx.drawImage(clip.nativeWidget, 0, 0, clipWidth, clipHeight);
					var pixel = ctx.getImageData(local.x, local.y, 1, 1);
					if (pixel.data[3] * clip.worldAlpha / 255 < checkAlpha) return null;
				} catch (e : Dynamic) {}
			}

			if (local.x >= 0.0 && local.y >= 0.0 && local.x <= clipWidth && local.y <= clipHeight) {
				return clip;
			}
		} else if (untyped HaxeRuntime.instanceof(clip, FlowContainer)) {
			if (untyped clip.worldTransformChanged) {
				untyped clip.transform.updateTransform(clip.parent.transform);
			}

			var local : Point = untyped __js__('clip.toLocal(point, null, null, true)');
			var localBounds = untyped clip.localBounds;

			if (local.x < localBounds.minX && local.y < localBounds.minY && local.x >= localBounds.maxX && local.y >= localBounds.maxY) {
				return null;
			}

			var children : Array<DisplayObject> = untyped clip.children;
			var i = children.length - 1;

			while (i >= 0) {
				var child = children[i];
				i--;

				var clipHit = getClipAt(child, point, false, checkAlpha);

				if (clipHit != null) {
					return clipHit;
				}
			}
		} else if (untyped HaxeRuntime.instanceof(clip, FlowGraphics)) {
			if (hittestGraphics(untyped clip, point, checkAlpha)) {
				return clip;
			}
		}

		return null;
	}

	public static function makeGraphics() : FlowGraphics {
		return new FlowGraphics();
	}

	public static function getGraphics(parent : FlowContainer) : FlowGraphics {
		var clip = new FlowGraphics();
		addChild(parent, clip);
		return clip;
	}

	public static function clearGraphics(graphics : FlowGraphics) : Void {
		graphics.clear();
	}

	public static function setLineStyle(graphics : FlowGraphics, width : Float, color : Int, opacity : Float) : Void {
		graphics.lineStyle(width, removeAlphaChannel(color), opacity);
	}

	public static function beginFill(graphics : FlowGraphics, color : Int, opacity : Float) : Void {
		graphics.beginFill(removeAlphaChannel(color), opacity);
	}

	// native beginLineGradientFill : (graphics : native, colors : [int], alphas: [double], offsets: [double], matrix : native) -> void = RenderSupport.beginFill;
	public static function beginGradientFill(graphics : FlowGraphics, colors : Array<Int>, alphas : Array<Float>, offsets: Array<Float>, matrix : Dynamic, type : String) : Void {
		graphics.beginGradientFill(colors, alphas, offsets, matrix, type);
	}

	// native setLineGradientStroke : (graphics : native, colors : [int], alphas: [double], offsets: [double]) -> void = RenderSupport.beginFill;
	public static function setLineGradientStroke(graphics : FlowGraphics, colours : Array<Int>, alphas : Array<Float>, offsets : Array<Float>, matrix : Dynamic) : Void {
		graphics.lineGradientStroke(colours, alphas, offsets, matrix);
	}

	public static function makeMatrix(width : Float, height : Float, rotation : Float, xOffset : Float, yOffset : Float) : Dynamic {
		return { width : width, height : height, rotation : rotation, xOffset : xOffset, yOffset : yOffset };
	}

	public static function moveTo(graphics : FlowGraphics, x : Float, y : Float) : Void {
		graphics.moveTo(x, y);
	}

	public static function lineTo(graphics : FlowGraphics, x : Float, y : Float) : Void {
		graphics.lineTo(x, y);
	}

	public static function curveTo(graphics : FlowGraphics, cx : Float, cy : Float, x : Float, y : Float) : Void {
		graphics.quadraticCurveTo(cx, cy, x, y);
	}

	public static function makeCSSColor(color : Int, alpha : Float) : Dynamic {
		return "rgba(" + ((color >> 16) & 255) + "," + ((color >> 8) & 255) + "," + (color & 255) + "," + (alpha) + ")" ;
	}

	public static function endFill(graphics : FlowGraphics) : Void {
		graphics.endFill();
	}

	public static function drawRect(graphics : FlowGraphics, x : Float, y : Float, width : Float, height : Float) : Void {
		graphics.drawRect(x, y, width, height);
	}

	public static function drawRoundedRect(graphics : FlowGraphics, x : Float, y : Float, width : Float, height : Float, radius : Float) : Void {
		graphics.drawRoundedRect(x, y, width, height, radius);
	}

	public static function drawEllipse(graphics : FlowGraphics, x : Float, y : Float, width : Float, height : Float) : Void {
		graphics.drawEllipse(x, y, width, height);
	}

	public static function drawCircle(graphics : FlowGraphics, x : Float, y : Float, radius : Float) : Void {
		graphics.drawCircle(x, y, radius);
	}

	public static function makePicture(url : String, cache : Bool, metricsFn : Float -> Float -> Void, errorFn : String -> Void, onlyDownload : Bool, altText : String) : Dynamic {
		return new FlowSprite(url, cache, metricsFn, errorFn, onlyDownload, altText);
	}

	public static function setPictureUseCrossOrigin(picture : FlowSprite, useCrossOrigin : Bool) : Void {
		picture.switchUseCrossOrigin(useCrossOrigin);
	}

	public static function cursor2css(cursor : String) : String {
		return switch (cursor) {
			case "arrow": "default";
			case "auto": "auto";
			case "finger": "pointer";
			case "move": "move" ;
			case "text": "text";
			case "crosshair" : "crosshair";
			case "help" : "help";
			case "wait" : "wait";
			case "context-menu" : "context-menu";
			case "progress" : "progress";
			case "copy" : "copy";
			case "not-allowed" : "not-allowed";
			case "all-scroll" : "all-scroll";
			case "col-resize" : "col-resize";
			case "row-resize" : "row-resize";
			case "n-resize" : "n-resize";
			case "e-resize" : "e-resize";
			case "s-resize" : "s-resize";
			case "w-resize" : "w-resize";
			case "ne-resize" : "ne-resize";
			case "nw-resize" : "nw-resize";
			case "sw-resize" : "sw-resize";
			case "ew-resize" : "ew-resize";
			case "ns-resize" : "ns-resize";
			case "nesw-resize" : "nesw-resize";
			case "nwse-resize" : "nwse-resize";
			case "zoom-in" : "zoom-in";
			case "zoom-out" : "zoom-out";
			case "grab" : "grab";
			case "grabbing" : "grabbing";
			default: "inherit";
		};
	}

	public static function setCursor(cursor : String) : Void {
		PixiView.style.cursor = cursor2css(cursor);
	}

	public static function getCursor() : String {
		return switch (PixiView.style.cursor) {
			case "default": "arrow";
			case "auto": "auto";
			case "pointer": "finger";
			case "move": "move" ;
			case "text": "text";
			default: "default";
		}
	}

	// native addFilters(native, [native]) -> void = RenderSupport.addFilters;
	public static function addFilters(clip : DisplayObject, filters : Array<Filter>) : Void {
		if (!FiltersEnabled) {
			return;
		}

		if (RendererType == "html") {
			untyped clip.filterPadding = 0.0;
			var filterCount = 0;

			clip.off("childrenchanged", clip.invalidateTransform);

			untyped clip.filters = filters.filter(function(f) {
				if (f == null) {
					return false;
				} else if (f.padding != null) {
					untyped clip.filterPadding = Math.max(f.padding, untyped clip.filterPadding);
					filterCount++;
				}

				return true;
			});
			untyped clip.filterPadding = clip.filterPadding * filterCount;
			if (untyped clip.updateNativeWidgetGraphicsData != null) {
				untyped clip.updateNativeWidgetGraphicsData();
			}

			if (clip.filters.length > 0) {
				clip.updateEmitChildrenChanged();
				clip.on("childrenchanged", clip.invalidateTransform);
			}

			clip.initNativeWidget();

			var children : Array<DisplayObject> = untyped clip.children;
			if (children != null) {
				for (child in children) {
					child.invalidateTransform('addFilters -> child');
				}
			}

			clip.invalidateTransform('addFilters');
		} else {
			untyped clip.filterPadding = 0.0;
			untyped clip.glShaders = false;

			var filterCount = 0;

			filters = filters.filter(function(f) {
				if (f == null) {
					return false;
				}

				if (f.padding != null) {
					untyped clip.filterPadding = Math.max(f.padding, untyped clip.filterPadding);
					filterCount++;
				}

				if (f.uniforms != null && (f.uniforms.time != null || f.uniforms.seed != null || f.uniforms.bounds != null)) {
					var fn = function () {
						if (f.uniforms.time != null) {
							f.uniforms.time = f.uniforms.time == null ? 0.0 : f.uniforms.time + 0.01;
						}

						if (f.uniforms.seed != null) {
							f.uniforms.seed = Math.random();
						}

						if (f.uniforms.bounds != null) {
							var bounds = clip.getBounds(true);

							f.uniforms.bounds = [bounds.x, bounds.y, bounds.width, bounds.height];
						}

						clip.invalidateStage();
					};

					clip.onAdded(function () {
						PixiStage.on("drawframe", fn);

						return function () { PixiStage.off("drawframe", fn); };
					});
				}

				if (untyped !HaxeRuntime.instanceof(f, DropShadowFilter) && untyped !HaxeRuntime.instanceof(f, BlurFilter)) {
					untyped clip.glShaders = true;
					if (untyped PixiRenderer.gl == null) {
						try {
							untyped PixiRenderer.gl = new WebGLRenderer(0, 0, {
								transparent : true,
								autoResize : false,
								antialias : Antialias,
								roundPixels : RoundPixels
							});
						} catch (e : Dynamic) { }
					}
				}

				return true;
			});

			untyped clip.filterPadding = clip.filterPadding * filterCount;
			clip.filters = filters.length > 0 ? filters : null;

			if (RendererType == "canvas") {
				untyped clip.canvasFilters = clip.filters;
			}
		}
	}

	public static function makeBevel(angle : Float, distance : Float, radius : Float, spread : Float,
							color1 : Int, alpha1 : Float, color2 : Int, alpha2 : Float, inside : Bool) : Dynamic {
		return null;
	}

	public static function makeBlur(radius : Float, spread : Float) : Dynamic {
		return new BlurFilter(spread, 4, backingStoreRatio, 5);
	}

	public static function makeBackdropBlur(spread : Float) : Dynamic {
		return new BlurBackdropFilter(spread);
	}

	public static function makeDropShadow(angle : Float, distance : Float, radius : Float, spread : Float,color : Int, alpha : Float, inside : Bool) : Dynamic {
		return new DropShadowFilter(angle, distance, radius, color, alpha);
	}

	public static function makeGlow(radius : Float, spread : Float, color : Int, alpha : Float, inside : Bool) : Dynamic {
		return null;
	}

	public static function makeShader(vertex : Array<String>, fragment : Array<String>, uniforms : Array<Array<String>>) : Filter {
		var v = StringTools.replace(vertex.join(""), "a_VertexPos", "aVertexPosition");
		v = StringTools.replace(v, "a_VertexTexCoord", "aTextureCoord");
		v = StringTools.replace(v, "v_texCoord", "vTextureCoord");
		v = StringTools.replace(v, "u_cmatrix", "projectionMatrix");
		v = StringTools.replace(v, "s_tex", "uSampler");
		v = StringTools.replace(v, "texture(", "texture2D(");
		v = StringTools.replace(v, "in ", "varying ");
		v = StringTools.replace(v, "out ", "varying ");
		v = StringTools.replace(v, "frag_highp", "highp");

		var f = StringTools.replace(fragment.join(""), "a_VertexPos", "aVertexPosition");
		f = StringTools.replace(f, "a_VertexTexCoord", "aTextureCoord");
		f = StringTools.replace(f, "v_texCoord", "vTextureCoord");
		f = StringTools.replace(f, "u_cmatrix", "projectionMatrix");
		f = StringTools.replace(f, "s_tex", "uSampler");
		f = StringTools.replace(f, "texture(", "texture2D(");
		f = StringTools.replace(f, "in ", "varying ");
		f = StringTools.replace(f, "out ", "varying ");
		f = StringTools.replace(f, "frag_highp", "highp");

		var u : Dynamic = {};

		for (uniform in uniforms) {
			untyped __js__("u[uniform[0]] = { type : uniform[1], value : JSON.parse(uniform[2]) }");
		}

		u.u_out_pixel_size = {
			type : "vec2",
			value : [1, 1]
		};

		u.u_out_offset = {
			type : "vec2",
			value : [0, 0]
		};

		u.u_in_pixel_size = {
			type : "vec2",
			value : [1, 1]
		};

		u.u_in_offset = {
			type : "vec2",
			value : [0, 0]
		};

		return new Filter(v, f, u);
	}

	public static function setScrollRect(clip : FlowContainer, left : Float, top : Float, width : Float, height : Float) : Void {
		clip.setScrollRect(left, top, width, height);
	}

	public static function setContentRect(clip : FlowContainer, width : Float, height : Float) : Void {
		clip.setContentRect(width, height);
	}

	public static function listenScrollRect(clip : FlowContainer, cb : Float -> Float -> Void) : Void -> Void {
		return clip.listenScrollRect(cb);
	}

	public static function getTextMetrics(clip : TextClip) : Array<Float> {
		return clip.getTextMetrics();
	}

	public static function makeBitmap() : Dynamic {
		return null;
	}

	public static function bitmapDraw(bitmap : Dynamic, clip : DisplayObject, width : Int, height : Int) : Void {
	}

	public static function getClipVisible(clip : DisplayObject) : Bool {
		return clip.getClipVisible();
	}

	public static function setClipVisible(clip : DisplayObject, visible : Bool) : Void {
		return clip.setClipVisible(visible);
	}

	public static function getClipRenderable(clip : DisplayObject) : Bool {
		return clip.getClipRenderable();
	}

	public static function setClipCursor(clip : DisplayObject, cursor : String) : Void {
		clip.setClipCursor(cursor2css(cursor));
	}

	public static function setClipDebugInfo(clip : DisplayObject, key : String, value : Dynamic) : Void {
		untyped clip.info = HaxeRuntime.typeOf(value).toString();
	}

	public static function fullScreenTrigger() {
		IsFullScreen = isFullScreen();
		emit("fullscreen", IsFullScreen);
	}

	public static function fullWindowTrigger(fw : Bool) {
		IsFullWindow = fw;
		emit("fullwindow", fw);
	}

	private static var FullWindowTargetClip : DisplayObject = null;
	public static function setFullWindowTarget(clip : DisplayObject) : Void {
		if (FullWindowTargetClip != clip) {
			if (IsFullWindow && FullWindowTargetClip != null) {
				toggleFullWindow(false);
				FullWindowTargetClip = clip;

				if (clip != null) {
					toggleFullWindow(true);
				}
			} else {
				FullWindowTargetClip = clip;
			}
		}
	}

	public static function setFullScreenRectangle(x : Float, y : Float, w : Float, h : Float) : Void {
	}

	public static function resetFullWindowTarget() : Void {
		setFullWindowTarget(null);
	}

	private static var regularStageChildren : Array<DisplayObject> = null;
	private static var regularFullScreenClipParent : Dynamic = null;
	public static var IsFullScreen : Bool = false;
	public static var IsFullWindow : Bool = false;
	public static function toggleFullWindow(fw : Bool) : Void {
		if (FullWindowTargetClip != null && IsFullWindow != fw) {
			var mainStage : FlowContainer = cast(PixiStage.children[0], FlowContainer);

			if (fw) {
				setShouldPreventFromBlur(FullWindowTargetClip);

				for (child in mainStage.children) {
					child.setClipVisible(false);
				}

				regularFullScreenClipParent = FullWindowTargetClip.parent;
				mainStage.addChild(FullWindowTargetClip);
			} else {
				if (regularFullScreenClipParent != null) {
					regularFullScreenClipParent.addChild(FullWindowTargetClip);
					regularFullScreenClipParent = null;
				} else {
					mainStage.removeChild(FullWindowTargetClip);
				}

				for (child in mainStage.children) {
					child.setClipVisible(true);
				}
			}

			fullWindowTrigger(fw);
		}
	}

	public static function requestFullScreen(element : Dynamic) {
		if (element.requestFullscreen != null)
			element.requestFullscreen();
		else if (element.mozRequestFullScreen != null)
			element.mozRequestFullScreen();
		else if (element.webkitRequestFullscreen != null)
			element.webkitRequestFullscreen();
		else if (element.msRequestFullscreen != null)
			element.msRequestFullscreen();
		else if (element.webkitEnterFullScreen != null)
			element.webkitEnterFullScreen();
	}

	public static function exitFullScreen(element : Dynamic) {
		if (untyped HaxeRuntime.instanceof(element, js.html.CanvasElement)) {
			element = Browser.document;
		}

		if (IsFullScreen) {
			if (element.exitFullscreen != null)
				element.exitFullscreen();
			else if (element.mozCancelFullScreen != null)
				element.mozCancelFullScreen();
			else if (element.webkitExitFullscreen != null)
				element.webkitExitFullscreen();
			else if (element.msExitFullscreen != null)
				element.msExitFullscreen();
		}
	}

	public static function toggleFullScreen(fs : Bool) : Void {
		if (!hadUserInteracted) return;

		if (fs)
			requestFullScreen(Browser.document.body);
		else
			exitFullScreen(Browser.document);
	}

	public static function onFullScreen(fn : Bool -> Void) : Void -> Void {
		on("fullscreen", fn);
		return function () { off("fullscreen", fn); };
	}

	public static function isFullScreen() : Bool {
		return untyped Browser.document.fullScreen ||
			untyped Browser.document.mozFullScreen ||
			untyped Browser.document.webkitIsFullScreen ||
			untyped Browser.document.fullscreenElement != null ||
			untyped Browser.document.msFullscreenElement != null ||
			FullWindowTargetClip != null &&
			FullWindowTargetClip.nativeWidget != null &&
			FullWindowTargetClip.nativeWidget.webkitDisplayingFullscreen;
	}

	public static function onFullWindow(onChange : Bool -> Void) : Void -> Void {
		on("fullwindow", onChange);
		return function() { off("fullwindow", onChange); }
	}

	public static function isFullWindow() : Bool {
		return IsFullWindow;
	}

	public static function setWindowTitle(title : String) : Void {
		Browser.document.title = title;
	}

	public static function setFavIcon(url : String) : Void {
		var head = Browser.document.getElementsByTagName('head')[0];
		var oldNode = Browser.document.getElementById('app-favicon');
		var node = Browser.document.createElement('link');
		node.setAttribute("id", "app-favicon");
		node.setAttribute("rel", "shortcut icon");
		node.setAttribute("href", url);
		node.setAttribute("type", "image/ico");
		if (oldNode != null) {
			head.removeChild(oldNode);
		}
		head.appendChild(node);
	}

	public static function takeSnapshot(path : String) : Void {
		takeSnapshotBox(path, 0, 0, Std.int(getStageWidth()), Std.int(getStageHeight()));
	}

	public static function takeSnapshotBox(path : String, x : Int, y : Int, w : Int, h : Int) : Void {
		try {
			var base64 = getSnapshotBox(x, y, w, h).split(",")[1];
			var base64bytes = [];

			untyped __js__("
				const sliceSize = 512;
				const byteCharacters = atob(base64);

				for (var offset = 0; offset < byteCharacters.length; offset += sliceSize) {
					const slice = byteCharacters.slice(offset, offset + sliceSize);

					const byteNumbers = new Array(slice.length);
					for (var i = 0; i < slice.length; i++) {
						byteNumbers[i] = slice.charCodeAt(i);
					}

					const byteArray = new Uint8Array(byteNumbers);
					base64bytes.push(byteArray);
				}
			");

			FlowFileSystem.saveFileClient(path, base64bytes, "image/png");
		} catch(e : Dynamic) {}
	}

	public static function getSnapshot() : String {
		return getSnapshotBox(0, 0, Std.int(getStageWidth()), Std.int(getStageHeight()));
	}

	public static function getSnapshotBox(x : Int, y : Int, w : Int, h : Int) : String {
		var child : FlowContainer = untyped PixiStage.children[0];

		if (child == null) {
			return "";
		}

		untyped RenderSupport.LayoutText = true;
		emit("enable_sprites");
		child.removeScrollRect();
		child.setScrollRect(x, y, w, h);

		render();

		try {
			var img = PixiRenderer.plugins.extract.base64(PixiStage);
			child.removeScrollRect();
			untyped RenderSupport.LayoutText = false;
			emit("disable_sprites");

			render();

			return img;
		} catch(e : Dynamic) {
			child.removeScrollRect();
			untyped RenderSupport.LayoutText = false;
			emit("disable_sprites");

			render();

			return 'error';
		}
	}

	public static function compareImages(image1 : String, image2 : String, cb : String -> Void) : Void {
		if (untyped __js__("typeof resemble === 'undefined'")) {
			var head = Browser.document.getElementsByTagName('head')[0];
			var node = Browser.document.createElement('script');
			node.setAttribute("type","text/javascript");
			node.setAttribute("src", 'js/resemble.js');
			node.onload = function() {
				compareImages(image1, image2, cb);
			};
			head.appendChild(node);
		} else {
			untyped __js__("
				resemble(image1)
				.compareTo(image2)
				.setReturnEarlyThreshold(Platform.isIE?10:0)
				.ignoreAntialiasing()
				.outputSettings({
					errorType: 'movementDifferenceIntensity',
				})
				.onComplete(function(data) {
					cb(JSON.stringify(data));
				});
			");
		}
	}

	public static function getScreenPixelColor(x : Int, y : Int) : Int {
		var data = PixiView.getContext2d().getImageData(x * backingStoreRatio, y * backingStoreRatio, 1, 1).data;

		var rgb = data[0];
		rgb = (rgb << 8) + data[1];
		rgb = (rgb << 8) + data[2];

		return rgb;
	}

	//
	// cb - callback in the flow code which accepts [flow]
	// To call it in the embedded HTML use frameElement.callflow([args]))
	// Default web clip size = 100x100. Scale clip to resize
	public static function makeWebClip(url : String, domain : String, useCache : Bool, reloadBlock : Bool, cb : Array<String> -> String, ondone : String -> Void, shrinkToFit : Bool) : WebClip {
		return new WebClip(url, domain, useCache, reloadBlock, cb, ondone, shrinkToFit);
	}

	public static function webClipHostCall(clip : WebClip, name : String, args : Array<String>) : String {
		return clip.hostCall(name, args);
	}

	public static function setWebClipSandBox(clip : WebClip, value : String) : Void {
		clip.setSandBox(value);
	}

	public static function setWebClipDisabled(clip : WebClip, disabled : Bool) : Void {
		clip.setDisableOverlay(disabled);
	}

	public static function setWebClipNoScroll(clip : WebClip) : Void {
		clip.setNoScroll();
	}

	public static function webClipEvalJS(clip : Dynamic, code : String, cb : Dynamic -> Void) : Void {
		cb(clip.evalJS(code));
	}

	public static function makeHTMLStage(width : Float, height : Float) : HTMLStage {
		return new HTMLStage(width, height);
	}

	public static function createElement(tagName : String) : Element {
		return Browser.document.createElementNS(
				if (tagName.toLowerCase() == "svg" || tagName.toLowerCase() == "path" || tagName.toLowerCase() == "g") {
					"http://www.w3.org/2000/svg";
				} else {
					"http://www.w3.org/1999/xhtml";
				},
				tagName
			);
	}

	public static function createTextNode(text : String) : js.html.Text {
		return Browser.document.createTextNode(text);
	}

	public static function changeNodeValue(element : Element, value : String) : Void {
		element.nodeValue = value;
	}

	public static function setAttribute(element : Element, name : String, value : String) : Void {
		if (name == "innerHTML")
			element.innerHTML = value
		else
			element.setAttribute(name, value);
	}

	public static function removeAttribute(element : Element, name : String) : Void {
		element.removeAttribute(name);
	}

	public static function appendChild(element : Dynamic, child : Element) : Void {
		element.appendChild(child);
	}

	public static function insertBefore(element : Dynamic, child : Element, reference : Element) : Void {
		element.insertBefore(child, reference);
	}

	public static function removeElementChild(element : Dynamic, child : Element) : Void {
		removeChild(element, child);
	}

	public static function getNumberOfCameras() : Int {
		return 0;
	}

	public static function getCameraInfo(id : Int) : String {
		return "";
	}

	public static function makeCamera(uri : String, camID : Int, camWidth : Int, camHeight : Int, camFps : Float, vidWidth : Int, vidHeight : Int, recordMode : Int, cbOnReadyForRecording : Dynamic -> Void, cbOnFailed : String -> Void) : Array<Dynamic> {
		return [null, null];
	}

	public static function startRecord(str : Dynamic, filename : String, mode : String) : Void {
	}

	public static function stopRecord(str : Dynamic) : Void {
	}

	public static function cameraTakePhoto(cameraId : Int, additionalInfo : String, desiredWidth : Int, desiredHeight : Int, compressQuality : Int, fileName : String, fitMode : Int) : Void {
		// not implemented yet for js/flash
	}

	public static function addGestureListener(event : String, cb : Int -> Float -> Float -> Float -> Float -> Bool) : Void -> Void {
		if (event == "pinch") {
			return GesturesDetector.addPinchListener(cb);
		} else {
			return function() {};
		}
	}

	public static function setWebClipZoomable(clip : WebClip, zoomable : Bool) : Void {
		// NOP for these targets
	}

	public static function setWebClipDomains(clip : WebClip, domains : Array<String>) : Void {
		// NOP for these targets
	}

	public static function setInterfaceOrientation(orientation : String) : Void {
		var screen : Dynamic = Browser.window.screen;
		if (screen != null && screen.orientation != null && screen.orientation.lock != null) {
			if (orientation != "none") {
				screen.orientation.lock(orientation);
			} else {
				screen.orientation.unlock();
			}
		}
	}

	public static function setUrlHash(hash : String) : Void {
		Browser.window.location.hash = hash;
	}

	public static function getUrlHash() : String {
		return Browser.window.location.hash;
	}

	public static function addUrlHashListener(cb : String -> Void) : Void -> Void {
		var wrapper = function(e) { cb(Browser.window.location.hash); }
		untyped Browser.window.addEventListener("hashchange", wrapper);
		return function() { untyped Browser.window.removeEventListener("hashchange", wrapper); };
	}

	public static function setGlobalZoomEnabled(enabled : Bool) : Void {
		// NOP
	}

	public static inline function removeAlphaChannel(color : Int) : Int {
		// a lot of Graphics functions do not work correctly if color has alpha channel
		// (all other targets ignore it as well)
		return color & 0xFFFFFF;
	}
}