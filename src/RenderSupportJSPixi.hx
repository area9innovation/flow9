import js.Browser;
import js.html.Element;
import js.html.File;
import js.html.FileList;
import js.html.IFrameElement;

import pixi.core.renderers.SystemRenderer;
import pixi.core.display.DisplayObject;
import pixi.core.renderers.Detector;
import pixi.core.renderers.canvas.CanvasRenderer;
import pixi.core.renderers.webgl.WebGLRenderer;
import pixi.core.renderers.webgl.filters.Filter;
import pixi.core.math.Point;

import pixi.loaders.Loader;

import MacroUtils;
import Platform;

using DisplayObjectHelper;

class RenderSupportJSPixi {
	public static var PixiView : Dynamic;
	public static var PixiStage = new FlowContainer(true);
	public static var PixiRenderer : SystemRenderer;

	public static var AntialiasFont : Bool = Util.getParameter("antialiasfont") != null ? Util.getParameter("antialiasfont") == "1" : false;
	public static var RendererType : String = Util.getParameter("renderer") != null ? Util.getParameter("renderer") : untyped Browser.window.useRenderer;

	private static var MousePos : Point = new Point(0.0, 0.0);
	private static var PixiStageChanged : Bool = true;
	private static var isEmulating : Bool = false;
	private static var AnimationFrameId : Int = -1;

	// Renderer options
	public static var AccessibilityEnabled : Bool = false;
	private static var EnableFocusFrame : Bool = false;
	private static var CacheTextsAsBitmap : Bool = Util.getParameter("cachetext") == "1";
	private static var TransparentBackground : Bool = Util.getParameter("transparentbackground") == "1";
	/* Antialiasing doesn't work correctly on mobile devices */
	private static var Antialias : Bool = Util.getParameter("antialias") != null ? Util.getParameter("antialias") == "1" : !NativeHx.isTouchScreen() && (RendererType != "webgl" || detectExternalVideoCard());
	private static var RoundPixels : Bool = Util.getParameter("roundpixels") != null ? Util.getParameter("roundpixels") != "0" : true;
	private static var UseVideoTextures : Bool = Util.getParameter("videotexture") != "0";

	public static var DropCurrentFocusOnDown : Bool;
	// Renders in a higher resolution backing store and then scales it down with css (e.g., ratio = 2 for retina displays)
	// Resolution < 1.0 makes web fonts too blurry
	// NOTE: Pixi Text.resolution is readonly == renderer.resolution
	public static var backingStoreRatio : Float = getBackingStoreRatio();

	public static var UseDFont : Bool = Util.getParameter("dfont") == "1";

	public static var zIndexValues = {
		"canvas" : "0",
		"accessButton" : "2",
		"droparea" : "1",
		"nativeWidget" : "2"
	};

	// In fact that is needed only for android to have dimentions without
	// screen keyboard
	private static var WindowTopHeight : Int;
	private static var RenderSupportJSPixiInitialised : Bool = init();
	private static var RequestAnimationFrameId : Int = -1;

	// Font param constants
	public static inline var FONT_WEIGHT_THIN = 100;
	public static inline var FONT_WEIGHT_ULTRA_LIGHT = 200;
	public static inline var FONT_WEIGHT_LIGHT = 300;
	public static inline var FONT_WEIGHT_BOOK = 400;
	public static inline var FONT_WEIGHT_MEDIUM = 500;
	public static inline var FONT_WEIGHT_SEMI_BOLD = 600;
	public static inline var FONT_WEIGHT_BOLD = 700;
	public static inline var FONT_WEIGHT_EXTRA_BOLD = 800;
	public static inline var FONT_WEIGHT_BLACK = 900;

	public static inline var FONT_SLOPE_NORMAL = "normal";
	public static inline var FONT_SLOPE_ITALIC = "italic";
	public static inline var FONT_SLOPE_OBLIQUE = "oblique";

	private static function roundPlus(x : Float, n : Int) : Float {
		var m = Math.pow(10, n);
		return Math.fround(x * m) / m;
	}

	private static function getBackingStoreRatio() : Float {
		var ratio = ((Util.getParameter("resolution") != null) ?
			Std.parseFloat(Util.getParameter("resolution")) :
			((Browser.window.devicePixelRatio != null)? Browser.window.devicePixelRatio : 1.0));

		if (Platform.isSafari && !Platform.isMobile) { // outerWidth == 0 on mobile safari (and most other mobiles)
			ratio *= Browser.window.outerWidth / Browser.window.innerWidth;
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
		if (CacheTextsAsBitmap) { Errors.print("Caches all textclips as bitmap is turned on"); }
	}

	private static function workaroundRendererDestroy() : Void {
		untyped __js__("
			PIXI.WebGLRenderer.prototype.bindTexture = function(texture, location, forceLocation)
			{
				texture = texture || this.emptyTextures[location];
				texture = texture.baseTexture || texture;
				texture.touched = this.textureGC.count;

				if (!forceLocation)
				{
					// TODO - maybe look into adding boundIds.. save us the loop?
					for (let i = 0; i < this.boundTextures.length; i++)
					{
						if (this.boundTextures[i] === texture)
						{
							return i;
						}
					}

					if (location === undefined)
					{
						this._nextTextureLocation++;
						this._nextTextureLocation %= this.boundTextures.length;
						location = this.boundTextures.length - this._nextTextureLocation - 1;
					}
				}
				else
				{
					location = location || 0;
				}

				const gl = this.gl;
				const glTexture = texture._glTextures[this.CONTEXT_UID];

				if (!glTexture)
				{
					// this will also bind the texture..
					try {
						this.textureManager.updateTexture(texture, location);
					} catch (error) {
						// usually a crossorigin problem
					}
				}
				else
				{
					// bind the current texture
					this.boundTextures[location] = texture;
					gl.activeTexture(gl.TEXTURE0 + location);
					gl.bindTexture(gl.TEXTURE_2D, glTexture.texture);
				}

				return location;
			}

			PIXI.WebGLRenderer.prototype.destroy = function(removeView)
			{
				// this.destroyPlugins();

				// remove listeners
				this.view.removeEventListener('webglcontextlost', this.handleContextLost);
				this.view.removeEventListener('webglcontextrestored', this.handleContextRestored);

				this.textureManager.destroy();

				// call base destroy
				this.type = PIXI.RENDERER_TYPE.UNKNOWN;

				this.view = null;

				this.screen = null;

				this.resolution = 0;

				this.transparent = false;

				this.autoResize = false;

				this.blendModes = null;

				this.options = null;

				this.preserveDrawingBuffer = false;
				this.clearBeforeRender = false;

				this.roundPixels = false;

				this._backgroundColor = 0;
				this._backgroundColorRgba = null;
				this._backgroundColorString = null;

				this._tempDisplayObjectParent = null;
				this._lastObjectRendered = null;

				this.uid = 0;

				// destroy the managers
				this.maskManager.destroy();
				this.stencilManager.destroy();
				this.filterManager.destroy();

				this.maskManager = null;
				this.filterManager = null;
				this.textureManager = null;
				this.currentRenderer = null;

				this.handleContextLost = null;
				this.handleContextRestored = null;

				this._contextOptions = null;
				// this.gl.useProgram(null);

				// if (this.gl.getExtension('WEBGL_lose_context'))
				// {
				// 	this.gl.getExtension('WEBGL_lose_context').loseContext();
				// }

				this.gl = null;
			}
		");
	}
	private static function workaroundProcessInteractive() : Void {
		untyped __js__("
			PIXI.interaction.InteractionManager.prototype.processInteractive = function(interactionEvent, displayObject, func, hitTest, interactive)
			{
				if (!displayObject || !displayObject.visible)
				{
					return false;
				}

				const point = interactionEvent.data.global;

				// Took a little while to rework this function correctly! But now it is done and nice and optimised. ^_^
				//
				// This function will now loop through all objects and then only hit test the objects it HAS
				// to, not all of them. MUCH faster..
				// An object will be hit test if the following is true:
				//
				// 1: It is interactive.
				// 2: It belongs to a parent that is interactive AND one of the parents children have not already been hit.
				//
				// As another little optimisation once an interactive object has been hit we can carry on
				// through the scenegraph, but we know that there will be no more hits! So we can avoid extra hit tests
				// A final optimisation is that an object is not hit test directly if a child has already been hit.

				interactive = displayObject.interactive || interactive;

				let hit = false;
				let interactiveParent = interactive;

				// Flag here can set to false if the event is outside the parents hitArea or mask
				let hitTestChildren = true;

				// If there is a hitArea, no need to test against anything else if the pointer is not within the hitArea
				// There is also no longer a need to hitTest children.
				if (displayObject.hitArea)
				{
					if (hitTest)
					{
						displayObject.worldTransform.applyInverse(point, this._tempPoint);
						if (!displayObject.hitArea.contains(this._tempPoint.x, this._tempPoint.y))
						{
							hitTest = false;
							hitTestChildren = false;
						}
						else
						{
							hit = true;
						}
					}
					interactiveParent = false;
				}
				// If there is a mask, no need to test against anything else if the pointer is not within the mask
				else if (displayObject._mask)
				{
					if (hitTest)
					{
						if (!displayObject._mask.containsPoint(point))
						{
							hitTest = false;
							// hitTestChildren = false;
						}
					}
				}

				// ** FREE TIP **! If an object is not interactive or has no buttons in it
				// (such as a game scene!) set interactiveChildren to false for that displayObject.
				// This will allow PixiJS to completely ignore and bypass checking the displayObjects children.
				if (hitTestChildren && displayObject.interactiveChildren && displayObject.children)
				{
					const children = displayObject.children;

					for (let i = children.length - 1; i >= 0; i--)
					{
						const child = children[i];

						// time to get recursive.. if this function will return if something is hit..
						const childHit = this.processInteractive(interactionEvent, child, func, hitTest, interactiveParent);

						if (childHit)
						{
							// its a good idea to check if a child has lost its parent.
							// this means it has been removed whilst looping so its best
							if (!child.parent)
							{
								continue;
							}

							// we no longer need to hit test any more objects in this container as we we
							// now know the parent has been hit
							interactiveParent = false;

							// If the child is interactive , that means that the object hit was actually
							// interactive and not just the child of an interactive object.
							// This means we no longer need to hit test anything else. We still need to run
							// through all objects, but we don't need to perform any hit tests.

							if (childHit)
							{
								if (interactionEvent.target)
								{
									hitTest = false;
								}
								hit = true;
							}
						}
					}
				}

				// no point running this if the item is not interactive or does not have an interactive parent.
				if (interactive)
				{
					// if we are hit testing (as in we have no hit any objects yet)
					// We also don't need to worry about hit testing if once of the displayObjects children
					// has already been hit - but only if it was interactive, otherwise we need to keep
					// looking for an interactive child, just in case we hit one
					if (hitTest && !interactionEvent.target)
					{
						// already tested against hitArea if it is defined
						if (!displayObject.hitArea && displayObject.containsPoint)
						{
							if (displayObject.containsPoint(point))
							{
								hit = true;
							}
						}
					}

					if (displayObject.interactive)
					{
						if (hit && !interactionEvent.target)
						{
							interactionEvent.target = displayObject;
						}

						if (func)
						{
							func(interactionEvent, displayObject, !!hit);
						}
					}
				}

				return hit;
			}
		");
	}


	private static function workaroundIEArrayFromMethod() : Void {
		untyped __js__("
		if (!Array.from) {
			Array.from = (function () {
				var toStr = Object.prototype.toString;
				var isCallable = function (fn) {
					return typeof fn === 'function' || toStr.call(fn) === '[object Function]';
				};
				var toInteger = function (value) {
					var number = Number(value);
					if (isNaN(number)) { return 0; }
					if (number === 0 || !isFinite(number)) { return number; }
					return (number > 0 ? 1 : -1) * Math.floor(Math.abs(number));
				};
				var maxSafeInteger = Math.pow(2, 53) - 1;
				var toLength = function (value) {
					var len = toInteger(value);
					return Math.min(Math.max(len, 0), maxSafeInteger);
				};

				// The length property of the from method is 1.
				return function from(arrayLike/*, mapFn, thisArg */) {
					// 1. Let C be the this value.
					var C = this;

					// 2. Let items be ToObject(arrayLike).
					var items = Object(arrayLike);

					// 3. ReturnIfAbrupt(items).
					if (arrayLike == null) {
						throw new TypeError('Array.from requires an array-like object - not null or undefined');
					}

					// 4. If mapfn is undefined, then let mapping be false.
					var mapFn = arguments.length > 1 ? arguments[1] : void undefined;
					var T;
					if (typeof mapFn !== 'undefined') {
						// 5. else
						// 5. a If IsCallable(mapfn) is false, throw a TypeError exception.
						if (!isCallable(mapFn)) {
							throw new TypeError('Array.from: when provided, the second argument must be a function');
						}

						// 5. b. If thisArg was supplied, let T be thisArg; else let T be undefined.
						if (arguments.length > 2) {
							T = arguments[2];
						}
					}

					// 10. Let lenValue be Get(items, 'length').
					// 11. Let len be ToLength(lenValue).
					var len = toLength(items.length);

					// 13. If IsConstructor(C) is true, then
					// 13. a. Let A be the result of calling the [[Construct]] internal method of C with an argument list containing the single item len.
					// 14. a. Else, Let A be ArrayCreate(len).
					var A = isCallable(C) ? Object(new C(len)) : new Array(len);

					// 16. Let k be 0.
					var k = 0;
					// 17. Repeat, while k < len… (also steps a - h)
					var kValue;
					while (k < len) {
						kValue = items[k];
						if (mapFn) {
							A[k] = typeof T === 'undefined' ? mapFn(kValue, k) : mapFn.call(T, kValue, k);
						} else {
							A[k] = kValue;
						}
						k += 1;
					}
					// 18. Let putStatus be Put(A, 'length', len, true).
					A.length = len;
					// 20. Return A.
					return A;
				};
			}());
		}");
	}

	private static function workaroundIECustomEvent() : Void {
		untyped __js__("
		if ( typeof window.CustomEvent !== 'function' ) {
			function CustomEvent ( event, params ) {
				params = params || { bubbles: false, cancelable: false, detail: undefined };
				var evt = document.createEvent( 'CustomEvent' );
				evt.initCustomEvent( event, params.bubbles, params.cancelable, params.detail );

				for (var key in params) {
					evt[key] = params[key];
				}

				return evt;
			}

			CustomEvent.prototype = window.Event.prototype;

			window.CustomEvent = CustomEvent;
		};");
	}

	private static function workaroundDOMOverOutEventsTransparency() : Void {
		untyped __js__("
		var binder = function(fn) {
			return fn.bind(RenderSupportJSPixi.PixiRenderer.plugins.interaction);
		}

		var emptyFn = function() {};

		var old_pointer_over = PIXI.interaction.InteractionManager.prototype.onPointerOver;
		var old_pointer_out = PIXI.interaction.InteractionManager.prototype.onPointerOut;

		PIXI.interaction.InteractionManager.prototype.onPointerOver = emptyFn;
		PIXI.interaction.InteractionManager.prototype.onPointerOut = emptyFn;

		var pointer_over = function(e) {
			if (e.fromElement == null)
				binder(old_pointer_over)(e);
		}

		var mouse_move = function(e) {
			pointer_over(e);
			document.removeEventListener('mousemove', mouse_move);
		}

		// if mouse is already over document
		document.addEventListener('mousemove', mouse_move);

		document.addEventListener('mouseover', pointer_over);

		document.addEventListener('mouseout', function(e) {
			if (e.toElement == null)
				binder(old_pointer_out)(e);
		});

		document.addEventListener('pointerover', function (e) {
			if (e.fromElement == null)
				binder(old_pointer_over)(e);
		});
		document.addEventListener('pointerout', function (e) {
			if (e.toElement == null)
				binder(old_pointer_out)(e);
		});");
	}

	private static function workaroundTextMetrics() : Void {
		untyped __js__("
			PIXI.TextMetrics.measureFont = function(font)
			{
				// as this method is used for preparing assets, don't recalculate things if we don't need to
				if (PIXI.TextMetrics._fonts[font])
				{
					return PIXI.TextMetrics._fonts[font];
				}

				const properties = {};

				const canvas = PIXI.TextMetrics._canvas;
				const context = PIXI.TextMetrics._context;

				context.font = font;

				const metricsString = PIXI.TextMetrics.METRICS_STRING + PIXI.TextMetrics.BASELINE_SYMBOL;
				const width = Math.ceil(context.measureText(metricsString).width);
				let baseline = Math.ceil(context.measureText(PIXI.TextMetrics.BASELINE_SYMBOL).width) * 2;
				const height = 2 * baseline;

				baseline = baseline * PIXI.TextMetrics.BASELINE_MULTIPLIER | 0;

				canvas.width = width;
				canvas.height = height;

				context.fillStyle = '#f00';
				context.fillRect(0, 0, width, height);

				context.font = font;

				context.textBaseline = 'alphabetic';
				context.fillStyle = '#000';
				context.fillText(metricsString, 0, baseline);

				const imagedata = context.getImageData(0, 0, width, height).data;
				const pixels = imagedata.length;
				const line = width * 4;

				let i = 0;
				let idx = 0;
				let stop = false;

				// ascent. scan from top to bottom until we find a non red pixel
				for (i = 0; i < baseline; ++i)
				{
					for (let j = 0; j < line; j += 4)
					{
						if (imagedata[idx + j] !== 255)
						{
							stop = true;
							break;
						}
					}
					if (!stop)
					{
						idx += line;
					}
					else
					{
						break;
					}
				}

				properties.ascent = baseline - i;

				idx = pixels - line;
				stop = false;

				// descent. scan from bottom to top until we find a non red pixel
				for (i = height; i > baseline; --i)
				{
					for (let j = 0; j < line; j += 4)
					{
						if (imagedata[idx + j] !== 255)
						{
							stop = true;
							break;
						}
					}

					if (!stop)
					{
						idx -= line;
					}
					else
					{
						break;
					}
				}

				properties.descent = i - baseline;
				properties.fontSize = properties.ascent + properties.descent;

				PIXI.TextMetrics._fonts[font] = properties;

				return properties;
			}
		");
	}

	private static function detectExternalVideoCard() : Bool {
		var canvas = Browser.document.createElement('canvas');
		var gl = untyped __js__("canvas.getContext('webgl') || canvas.getContext('experimental-webgl')");
		var debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
		var vendor = gl.getParameter(debugInfo.UNMASKED_VENDOR_WEBGL);
		var renderer = gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL);

		trace("VideoCard information:");
		trace(vendor);
		trace(renderer);

		return renderer.toLowerCase().indexOf("nvidia") >= 0 || renderer.toLowerCase().indexOf("ati") >= 0 || renderer.toLowerCase().indexOf("radeon") >= 0;
	}

	private static function createPixiRenderer() {
		backingStoreRatio = getBackingStoreRatio();

		if (PixiRenderer != null) {
			PixiRenderer.destroy();
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

		if (RendererType == "webgl" /*|| (RendererType == "canvas" && RendererType == "auto" && detectExternalVideoCard() && !Platform.isIE)*/) {
			PixiRenderer = new WebGLRenderer(Browser.window.innerWidth + 1, Browser.window.innerHeight + 1, options);

			RendererType = "webgl";
		} else if (RendererType == "auto") {
			#if (pixijs <= "4.5.4")
				PixiRenderer = Detector.autoDetectRenderer(Browser.window.innerWidth + 1, Browser.window.innerHeight + 1, options);
			#else
				// With pixijs 4.5.5, this works:
				PixiRenderer = Detector.autoDetectRenderer(options, Browser.window.innerWidth + 1, Browser.window.innerHeight + 1);
			#end

			if (untyped __instanceof__(PixiRenderer, WebGLRenderer)) {
				RendererType = "webgl";
			} else {
				RendererType = "canvas";
			}
		} else {
			PixiRenderer = new CanvasRenderer(Browser.window.innerWidth + 1, Browser.window.innerHeight + 1, options);

			RendererType = "canvas";
		}

		// Disable Pixi's accessibility manager plugin.
		// Use own.
		if (PixiRenderer.plugins != null) {
			PixiRenderer.plugins.accessibility.destroy();
			PixiRenderer.plugins.prepare.destroy();

			untyped __js__("delete RenderSupportJSPixi.PixiRenderer.plugins.accessibility");
			untyped __js__("delete RenderSupportJSPixi.PixiRenderer.plugins.prepare");
		}

		// Destroy default pixi ticker
		untyped PIXI.ticker.shared.autoStart = false;
		untyped PIXI.ticker.shared.stop();
		untyped PIXI.ticker.shared.destroy();

		untyped PixiRenderer.plugins.interaction.mouseOverRenderer = true;

		PixiView = PixiRenderer.view;
		// Make absolute position for canvas for Safari to fix fullscreen API
		if (Platform.isSafari) {
			PixiView.style.position = "absolute";
			PixiView.style.top = "0px";
		}
	}

	private static function initPixiRenderer() {
		if (untyped PIXI.VERSION[0] > 3)
			workaroundDOMOverOutEventsTransparency();

		if (untyped PIXI.VERSION != "4.8.2") {
			untyped __js__("document.location.reload(true)");
		}

		workaroundTextMetrics();
		// Required for MaterialIcons measurements
		untyped __js__("PIXI.TextMetrics.METRICS_STRING = '|Éq█'");
		workaroundRendererDestroy();
		workaroundProcessInteractive();

		if (Platform.isIE) {
			workaroundIEArrayFromMethod();
			workaroundIECustomEvent();
		}

		createPixiRenderer();

		// Add specified Firefox property to say the canvas will never need to be transparent
		if (Platform.isFirefox)
			untyped PixiRenderer.view.mozOpaque = true;
		PixiRenderer.view.style.zIndex = RenderSupportJSPixi.zIndexValues.canvas;
		Browser.document.body.appendChild(PixiRenderer.view);

		preventDefaultFileDrop();
		initPixiStageEventListeners();
		initBrowserWindowEventListeners();
		initFullScreenEventListeners();
		FontLoader.LoadFonts(UseDFont, StartFlowMain);
		initClipboardListeners();

		TextField.cacheTextsAsBitmap = CacheTextsAsBitmap;

		printOptionValues();

		// Enable browser canvas rendered image smoothing
		var ctx = untyped PixiRenderer.context;
		if (ctx != null) {
			ctx.mozImageSmoothingEnabled = true;
			ctx.webkitImageSmoothingEnabled = true;
			ctx.imageSmoothingQuality = "medium";
			ctx.msImageSmoothingEnabled = true;
			ctx.imageSmoothingEnabled = true;
		}

		requestAnimationFrame();
	}

	//
	//	Browser window events
	//
	private static inline function initBrowserWindowEventListeners() {
		WindowTopHeight = cast (getScreenSize().height - Browser.window.innerHeight);
		Browser.window.addEventListener("resize", onBrowserWindowResize, false);
		Browser.window.addEventListener('message', receiveWindowMessage); // Messages from crossdomaid iframes
		Browser.window.addEventListener("focus", requestAnimationFrame, false);
	}

	private static inline function initClipboardListeners() {
		var handler = function handlePaste (e : Dynamic) {
			if (untyped Browser.window.clipboardData && untyped Browser.window.clipboardData.getData) { // IE
				NativeHx.clipboardData = untyped Browser.window.clipboardData.getData('Text');
				NativeHx.clipboardDataHtml = ""; // IE does not support HTML from clipboard
			} else if (e.clipboardData && e.clipboardData.getData) {
				NativeHx.clipboardData = e.clipboardData.getData('text/plain');
				NativeHx.clipboardDataHtml = e.clipboardData.getData('text/html');
			} else {
				NativeHx.clipboardData = "";
				NativeHx.clipboardDataHtml = "";
			}

			var files : Array<Dynamic> = new Array<Dynamic>();
			if (!Platform.isIE && !Platform.isEdge)
				for (i in 0...e.clipboardData.files.length) {
					files[i] = e.clipboardData.files[i];
				}

			PixiStage.emit("paste", files);
		};

		Browser.document.addEventListener('paste', handler, false);
	}

	private static inline function initFullScreenEventListeners() {
		for (e in ['fullscreenchange', 'mozfullscreenchange', 'webkitfullscreenchange', 'MSFullscreenChange']) {
			Browser.document.addEventListener(e, fullScreenTrigger, false);
		}
	}

	private static function receiveWindowMessage(e : Dynamic) {
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

		Errors.report("Warning: unknown message source");
	}

	private static inline function getScreenSize() {
		if (Platform.isIOS && Platform.isChrome) {
			var is_portrait = Browser.window.matchMedia("(orientation: portrait)").matches;
			return is_portrait ?
				{ width : Browser.window.screen.width, height : Browser.window.screen.height} :
				{ height : Browser.window.screen.width, width : Browser.window.screen.height};
		} else {
			return { width : Browser.window.screen.width, height : Browser.window.screen.height};
		}
	}

	private static inline function onBrowserWindowResize(e : Dynamic) : Void {
		InvalidateStage();

		backingStoreRatio = getBackingStoreRatio();

		if (backingStoreRatio != PixiRenderer.resolution) {
			createPixiRenderer();
		} else {
			var win_width = e.target.innerWidth;
			var win_height = e.target.innerHeight;

			if (Platform.isAndroid || (Platform.isIOS && Platform.isChrome)) {
				// Still send whole window size - without reducing by screen kbd
				// for flow does not resize the stage. The stage will be
				// scrolled by this renderer if needed or by the browser when it is supported.
				// Assume that WindowTopHeight is equal for both landscape and portrait and
				// browser window is fullscreen
				var screen_size = getScreenSize();
				win_width = screen_size.width + 1;
				win_height = screen_size.height + 1 - cast WindowTopHeight;

				if (Platform.isAndroid) {
					PixiStage.y = 0.0; // Layout emenets without shift to test overalap later
					// Assume other mobile browsers do it theirselves
					ensureCurrentInputVisible(); // Test overlap and shift if needed
				}
			}

			PixiRenderer.resize(win_width, win_height);
		}

		PixiStage.broadcastEvent("resize", backingStoreRatio);

		// Render immediately - Avoid flickering on Safari and some other cases
		PixiRenderer.render(PixiStage);
	}

	private static function dropCurrentFocus() : Void {
		if (Browser.document.activeElement != null && !isEmulating)
			Browser.document.activeElement.blur();
	}

	private static function setDropCurrentFocusOnDown(drop : Bool) : Void {
		if (DropCurrentFocusOnDown != drop) {
			DropCurrentFocusOnDown = drop;
			if (drop)
				PixiStage.on("mousedown", dropCurrentFocus);
			else
				PixiStage.off("mousedown", dropCurrentFocus);
		}
	}

	private static function pixiStageOnMouseMove() : Void {
		if (!isEmulating) switchFocusFramesShow(false);
	}

	private static inline function initPixiStageEventListeners() {
		if (untyped __js__("window.navigator.msPointerEnabled")) {
			setStagePointerHandler("MSPointerDown", function () { PixiStage.emit("mousedown"); });
			setStagePointerHandler("MSPointerUp", function () { PixiStage.emit("mouseup"); });
			setStagePointerHandler("MSPointerMove", function () { PixiStage.emit("mousemove"); });
		}

		if (NativeHx.isTouchScreen()) {
			setStagePointerHandler("touchstart", function () { PixiStage.emit("mousedown"); });
			setStagePointerHandler("touchend", function () { PixiStage.emit("mouseup"); });
			setStagePointerHandler("touchmove", function () { PixiStage.emit("mousemove"); });
		}

		if (!Platform.isMobile) {
			setStagePointerHandler("mousedown", function () { PixiStage.emit("mousedown"); });
			setStagePointerHandler("mouseup", function () { PixiStage.emit("mouseup"); });
			setStagePointerHandler("mouserightdown", function () { PixiStage.emit("mouserightdown"); });
			setStagePointerHandler("mouserightup", function () { PixiStage.emit("mouserightup"); });
			setStagePointerHandler("mousemiddledown", function () { PixiStage.emit("mousemiddledown"); });
			setStagePointerHandler("mousemiddleup", function () { PixiStage.emit("mousemiddleup"); });
			setStagePointerHandler("mousemove", function () { PixiStage.emit("mousemove"); });
			setStagePointerHandler("mouseout", function () { PixiStage.emit("mouseup"); }); // Emulate mouseup to release scrollable for example
			Browser.document.body.addEventListener("keydown", function (e) { PixiStage.emit("keydown", parseKeyEvent(e)); });
			Browser.document.body.addEventListener("keyup", function (e) { PixiStage.emit("keyup", parseKeyEvent(e)); });
		}

		PixiStage.on("mousedown", function (e) { VideoClip.CanAutoPlay = true; MouseUpReceived = false; });
		PixiStage.on("mouseup", function (e) { MouseUpReceived = true; });
		switchFocusFramesShow(false);
		setDropCurrentFocusOnDown(true);
	}

	private static var MouseUpReceived : Bool = false;

	private static function setStagePointerHandler(event : String, listener : Void -> Void) {
		var cb = switch (event) {
			case "touchstart" | "touchmove" | "MSPointerDown" | "MSPointerMove":
				function(e : Dynamic) {
					if (e.touches != null) {
						if (e.touches.length == 1) {
							MousePos.x = e.touches[0].pageX;
							MousePos.y = e.touches[0].pageY;
							listener();
						} else if (e.touches.length == 2) {
							GesturesDetector.processPinch(new Point(e.touches[0].pageX, e.touches[0].pageY), new Point(e.touches[1].pageX, e.touches[1].pageY));
						}
					}
				}
			case "touchend" | "MSPointerUp":
				function(e : Dynamic) { GesturesDetector.endPinch(); if (e.touches != null && e.touches.length == 0) listener(); }
			case "mouseout":
				// Some browsers may produce both mouseup and moseout for some cases.
				// For example window openning on button click in FF
				function(e : Dynamic) {
					if (MouseUpReceived)
						return;

					var checkElement = function (el) {
						if (el != null) {
							var tagName = el.tagName.toLowerCase();

							return tagName == "input"
								|| tagName == "textarea"
								|| tagName == "div" && el.classList.contains("droparea");
						}

						return false;
					}

					// Prevent from mouseout to native textfield or droparea element to allow dragging over
					if (checkElement(e.toElement) && e.fromElement != null || checkElement(e.fromElement) && e.toElement != null)
						return;

					listener();
				}
			case "mousedown" | "mouseup":
				function(e : Dynamic) {
					// Prevent default drop focus on canvas
					// Works incorrectly in Edge
					if (e.target == PixiRenderer.view)
						e.preventDefault();

					MousePos.x = e.pageX;
					MousePos.y = e.pageY;
					if (e.which == 1 || e.button == 0)
						listener();
				}
			case "mouserightdown" | "mouserightup":
				if (event == "mouserightdown")
					event = "mousedown";
				else
					event = "mouseup";

				function(e : Dynamic) {
					MousePos.x = e.pageX;
					MousePos.y = e.pageY;
					if (e.which == 3 || e.button == 2)
						listener();
				}
			case "mousemiddledown" | "mousemiddleup":
				if (event == "mousemiddledown")
					event = "mousedown";
				else
					event = "mouseup";

				function(e : Dynamic) {
					MousePos.x = e.pageX;
					MousePos.y = e.pageY;
					if (e.which == 2 || e.button == 1)
						listener();
				}
			default:
				function(e : Dynamic) {
					MousePos.x = e.pageX;
					MousePos.y = e.pageY;
					listener();
				}
		}


		if (event == "mouseout")
			// We should prevent mouseup from being called inside document area
			// To have drags over textinputs
			Browser.document.body.addEventListener(event, cb);
		else
			PixiRenderer.view.addEventListener(event, cb);
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
				PixiRenderer.view.dispatchEvent(untyped __js__("new CustomEvent(e.type, e)"));
			} else {
				PixiRenderer.view.dispatchEvent(untyped __js__("new e.constructor(e.type, e)"));
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

	public static function emitMouseEvent(clip : DisplayObject, event : String, x : Float, y : Float) : Void {
		MousePos.x = x;
		MousePos.y = y;

		if (event == "mousemove" || event == "mousedown" || event == "mouseup" || event == "mouserightdown" || event == "mouserightup" ||
			event == "mousemiddledown" || event == "mousemiddleup") {
			PixiStage.emit(event);
		} else {
			clip.emit(event);
		}
	}

	public static function emitKeyEvent(clip : DisplayObject, event : String, key : String, ctrl : Bool, shift : Bool, alt : Bool, meta : Bool, keyCode : Int) : Void {
		var activeElement = Browser.document.activeElement;

		var ke = {key : key, ctrl : ctrl, shift : shift, alt : alt, meta : meta, keyCode : keyCode, preventDefault : function () {}};
		PixiStage.emit(event, ke);

		if (activeElement.tagName.toLowerCase() == "input" || activeElement.tagName.toLowerCase() == "textarea") {
			var ke = {key : key, ctrlKey : ctrl, shiftKey : shift, altKey : alt, metaKey : meta, keyCode : keyCode};

			if ((event == "keydown" || event == "keypress") && (key.length == 1 || keyCode == 8/*backspace*/ || keyCode == 46/*delete*/)) {
				var selectionStart = untyped activeElement.selectionStart != null ? untyped activeElement.selectionStart : untyped activeElement.value.length;
				var selectionEnd = untyped activeElement.selectionEnd != null ? untyped activeElement.selectionEnd : untyped activeElement.value.length;

				activeElement.dispatchEvent(new js.html.KeyboardEvent(event, ke));
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
					inputType: 'insertText',
					isComposing: false,
					bubbles: true,
					composed : true,
					isTrusted : true
				}");
				activeElement.dispatchEvent(untyped __js__("new InputEvent('input', ie)"));
			} else {
				activeElement.dispatchEvent(new js.html.KeyboardEvent(event, ke));
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
				PixiStage.emit(event);
			}

			isEmulating = false;
		}, delay);
	}

	private static function ensureCurrentInputVisible() : Void {
		var focused_node = Browser.document.activeElement;
		if (focused_node != null) {
			var node_name : String = focused_node.nodeName;
			node_name = node_name.toLowerCase();
			if (node_name == "input" || node_name == "textarea") {
				var rect = focused_node.getBoundingClientRect();
				if (rect.bottom > Browser.window.innerHeight) { // Overlaped by screen keyboard
					PixiStage.y = Browser.window.innerHeight - rect.bottom;
					InvalidateStage();
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
					pixijscss.insertRule(".focused { border: none !important; box-shadow: none !important; }", newRuleIndex);
					PixiStage.off("mousemove", pixiStageOnMouseMove); // Remove mouse event listener that not handle it always when focus frames are hidden
				} else {
					pixijscss.deleteRule(newRuleIndex);
					PixiStage.on("mousemove", pixiStageOnMouseMove);
				}
			}
		}
	}

	private static inline var FlowMainFunction = #if (flow_main) MacroUtils.parseDefine("flow_main") #else "flow_main" #end ;
	private static function StartFlowMain() {
		Errors.print("Starting flow main.");
		untyped Browser.window[FlowMainFunction]();
	}

	private static function requestAnimationFrame() {
		Browser.window.cancelAnimationFrame(AnimationFrameId);
		AnimationFrameId = Browser.window.requestAnimationFrame(animate);
	}

	private static function animate(timestamp : Float) {
		if (AccessibilityEnabled) {
			AccessWidget.updateAccessTree();
		}

		PixiStage.emit("drawframe", timestamp);

		if (PixiStageChanged || VideoClip.NeedsDrawing()) {
			PixiRenderer.render(PixiStage);

			PixiStage.emit("stagechanged", timestamp);

			PixiStageChanged = false;
		}

		requestAnimationFrame();
	}

	public static function addPasteEventListener(fn : Array<Dynamic> -> Void) : Void -> Void {
		PixiStage.on("paste", fn);
		return function() { PixiStage.off("paste", fn); };
	}

	public static inline function InvalidateStage() : Void {
		PixiStageChanged = true;
	}

	//
	// Flow native functions implementation
	//
	public static function getPixelsPerCm() : Float {
		return 96.0 / 2.54;
	}

	public static function setHitboxRadius(radius : Float) : Bool {
		return false;
	}

	private static function addAccessAttributes(clip : Dynamic, attributes : Array< Array<String> >) : Void {
		var attributesMap = new Map<String, String>();

		for (kv in attributes) {
			attributesMap.set(kv[0], kv[1]);
		}

		clip.accessWidget.addAccessAttributes(attributesMap);
	}

	public static function setAccessibilityEnabled(enabled : Bool) : Void {
		AccessibilityEnabled = enabled && Platform.AccessiblityAllowed;
	}

	public static function setEnableFocusFrame(show : Bool) : Void {
		EnableFocusFrame = show;
	}

	public static function setAccessAttributes(clip : Dynamic, attributes : Array< Array<String> >) : Void {
		if (!AccessibilityEnabled) return;

		if (clip.accessWidget == null) {
			// Create DOM node for access. properties
			if (clip.nativeWidget != null) {
				clip.accessWidget = new AccessWidget(clip, clip.nativeWidget);
				addAccessAttributes(clip, attributes);
			} else {
				AccessWidget.createAccessWidget(clip, attributes);
			}
		} else {
			addAccessAttributes(clip, attributes);
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

	private static function hideFlowJSLoadingIndicator() {
		Browser.document.body.style.backgroundImage = "none";
		var indicator = Browser.document.getElementById("loading_js_indicator");
		if (indicator != null) {
			Browser.document.body.removeChild(indicator);
		}
	}

	// native enableResize() -> void;
	public static function enableResize() : Void {
		// The first flow render call. Hide loading progress indicator.
		hideFlowJSLoadingIndicator();
	}

	public static function getStageWidth() : Float {
		return PixiRenderer.width / backingStoreRatio;
	}

	public static function getStageHeight() : Float {
		return PixiRenderer.height / backingStoreRatio;
	}

	public static function makeTextField(fontFamily : String) : TextField {
		return (UseDFont && FontLoader.hasDFont(fontFamily))? new DFontTextClip() : new PixiText();
	}

	inline public static function capitalize(s : String) : String {
		return s.substr(0, 1).toUpperCase() + s.substr(1, s.length - 1);
	}

	// HACK due to unable remake builtin fonts
	public static function recognizeBuiltinFont(fontfamily: String, fontweight: Int, fontslope: String) : String {
		if (StringTools.startsWith(fontfamily, "'Material Icons")) {
			return "MaterialIcons";
		}
		else if (StringTools.startsWith(fontfamily, "'DejaVu Sans")) {
			return "DejaVuSans";
		}
		else if (StringTools.startsWith(fontfamily, "'Franklin Gothic")) {
			return fontslope == FONT_SLOPE_ITALIC? "Italic" : fontweight == FONT_WEIGHT_BOLD? "Bold" : "Book";
		} else if (StringTools.startsWith(fontfamily, "Roboto")) {
			return fontfamily +
				intFontWeight2StrSuffix(fontweight) +
				(fontslope == FONT_SLOPE_NORMAL? "" : capitalize(fontslope));
		}
		return "";
	}
	// ENDHACK

	public static function intFontWeight2StrSuffix(w: Int) : String {
		if (w <= FONT_WEIGHT_MEDIUM) {
			if (w <= FONT_WEIGHT_LIGHT) {
				if (w <= FONT_WEIGHT_THIN) return "Thin"
				else if (w <= FONT_WEIGHT_ULTRA_LIGHT) return "Ultra Light"
				else return "Light";
			} else
				if (w <= FONT_WEIGHT_BOOK) return "" // "Book"
				else return "Medium";
		} else if (w <= FONT_WEIGHT_BOLD) {
			if (w <= FONT_WEIGHT_SEMI_BOLD) return "Semi Bold"
			else return "Bold";
		} else if (w <= FONT_WEIGHT_EXTRA_BOLD) return "Extra Bold"
		else return "Black";
	}

	// Assumption : setTextAndStyle always follow setTextInput for text inputs
	// Pay attention that you cannot change font family (switch between system and built-in fonts)
	// after field has been created with makeTextField function.
	public static function setTextAndStyle(
		textfield : TextField, text : String, fontfamily : String,
		fontsize : Float, fontweight : Int, fontslope : String,
		fillcolour : Int, fillopacity : Float, letterspacing : Float,
		backgroundcolour : Int, backgroundopacity : Float
	) : Void {
		var maybeBuiltin = fontweight > 0 || fontslope != "" ? recognizeBuiltinFont(fontfamily, fontweight, fontslope) : fontfamily;
		if (maybeBuiltin != "") {
			fontfamily = maybeBuiltin;
			/*fontweight = FONT_WEIGHT_BOOK;
			fontslope = FONT_SLOPE_NORMAL;*/
		};
		textfield.setTextAndStyle(
			text, fontfamily, fontsize, fontweight, fontslope,
			fillcolour, fillopacity, letterspacing, backgroundcolour, backgroundopacity
		);
	}

	public static function setAdvancedText(textfield : TextField, sharpness : Int, antialiastype : Int, gridfittype : Int) : Void {
		// NOP
	}

	public static function makeVideo(metricsFn : Float -> Float -> Void, playFn : Bool -> Void, durationFn : Float -> Void, positionFn : Float -> Void) : DisplayObject {
		return new VideoClip(metricsFn, playFn, durationFn, positionFn);
	}

	public static function setVideoVolume(str : VideoClip, volume : Float) : Void {
		str.setVolume(volume);
	}

	public static function setVideoLooping(str : VideoClip, loop : Bool) : Void {
		str.setLooping(loop);
	}

	public static function setVideoControls(str : VideoClip, controls : Dynamic) : Void {
		// STUB; only implemented in C++/OpenGL
	}

	public static function setVideoSubtitle(str: Dynamic, text : String, fontfamily : String, fontsize : Float, fontweight : Int, fontslope : String,
		fillcolor : Int, fillopacity : Float, letterspacing : Float, backgroundcolour : Int, backgroundopacity : Float) : Void {
		str.setVideoSubtitle(text, fontfamily, fontsize, fontweight, fontslope, fillcolor, fillopacity, letterspacing, backgroundcolour, backgroundopacity);
	}

	public static function setVideoPlaybackRate(str : VideoClip, rate : Float) : Void {
		str.setPlaybackRate(rate);
	}

	public static function setVideoTimeRange(str: VideoClip, start : Float, end : Float) : Void {
		str.setTimeRange(start, end);
	}

	public static function playVideo(vc : VideoClip, filename : String, startPaused : Bool) : Void {
		vc.playVideo(filename, startPaused);
	}

	public static function seekVideo(str : VideoClip, seek : Float) : Void {
		str.setCurrentTime(seek);
	}

	public static function getVideoPosition(str : VideoClip) : Float {
		return str.getCurrentTime();
	}

	public static function pauseVideo(str : VideoClip) : Void {
		str.pauseVideo();
	}

	public static function resumeVideo(str : VideoClip) : Void {
		str.resumeVideo();
	}

	public static function closeVideo(str : VideoClip) : Void {
		// NOP for this target
	}

	public static function getTextFieldWidth(textfield : TextField) : Float {
		return textfield.getWidth();
	}

	public static function setTextFieldWidth(textfield : TextField, width : Float) : Void {
		// NOTE : It is called by flow only for textinputs
		textfield.setWidth(width);
	}

	public static function getTextFieldHeight(textfield : TextField) : Float {
		return textfield.getHeight();
	}

	public static function setTextFieldHeight(textfield : TextField, height : Float) : Void {
		// This check is needed for cases when we get zero height for input field. Flash and cpp
		// ignore height (flash ignores it at all, cpp takes it into account only when input has
		// has a focus), so we have to have some workaround here.
		// TODO: Find a better fix
		if (height > 0.0)
			textfield.setHeight(height);
	}

	public static function setTextFieldCropWords(textfield : TextField, crop : Bool) : Void {
		textfield.setCropWords(crop);
	}

	public static function setTextFieldCursorColor(textfield : TextField, color : Int, opacity : Float) : Void {
		textfield.setCursorColor(color, opacity);
	}

	public static function setTextFieldCursorWidth(textfield : TextField, width : Float) : Void {
		textfield.setCursorWidth(width);
	}

	public static function setTextFieldInterlineSpacing(textfield : TextField, spacing : Float) : Void {
		textfield.setInterlineSpacing(spacing);
	}

	public static function setTextDirection(textfield : TextField, direction : String) : Void {
		textfield.setTextDirection(direction);
	}

	public static function setAutoAlign(textfield : TextField, autoalign : String) : Void {
		textfield.setAutoAlign(autoalign);
	}

	public static function setTextInput(textfield : TextField) : Void {
		textfield.setTextInput();
	}

	public static function setTextInputType(textfield : TextField, type : String) : Void {
		textfield.setTextInputType(type);
	}

	public static function setTextInputStep(textfield : TextField, step : Float) : Void {
		textfield.setTextInputStep(step);
	}

	public static function setTabIndex(textfield : TextField, index : Int) : Void {
		textfield.setTabIndex(index);
	}

	public static function setTabEnabled(enabled : Bool) : Void {
		// STUB; usefull only in flash
	}

	public static function getContent(textfield : TextField) : String {
		return textfield.getContent();
	}

	public static function getCursorPosition(textfield : TextField) : Int {
		return textfield.getCursorPosition();
	}

	public static function getFocus(clip : NativeWidgetClip) : Bool {
		return clip.getFocus();
	}

	public static function getScrollV(textfield : TextField) : Int {
		return 0;
	}

	public static function setScrollV(textfield : TextField, suggestedPosition : Int) : Void {
	}

	public static function getBottomScrollV(textfield : TextField) : Int {
		return 0;
	}

	public static function getNumLines(textfield : TextField) : Int {
		return 0;
	}

	private static inline function getAccessElement(clip: DisplayObject) : Element {
		return if (untyped clip.accessWidget != null) untyped clip.accessWidget.element
			else if (untyped __instanceof__(clip, NativeWidgetClip) && untyped clip.nativeWidget != null) untyped clip.nativeWidget
			else null;
	}

	private static function findAccessibleChild(clip : Dynamic) : Element {
		var accessElement = getAccessElement(clip);
		if (accessElement != null) return accessElement;

		var children : Array<DisplayObject> = untyped clip.children;
		if (children != null)
			for (childclip in children) {
				var childElement = findAccessibleChild(childclip);
				if (childElement != null) return childElement;
			}

		return null;
	}

	public static function setFocus(clip : DisplayObject, focus : Bool) : Void {
		if (untyped clip.setFocus != null) {
			untyped clip.setFocus(focus);
		} else if (AccessibilityEnabled) {
			var accessWidget = findAccessibleChild(clip);
			if (accessWidget == null) return;
			// check if found element accepts focus.
			if (accessWidget.getAttribute("tabindex") == null
				|| accessWidget.getAttribute("tabindex").charAt(0) == "-"
				|| untyped accessWidget.disabled != false) {
					// Searching children which are focusable: not disabled and tabindex is positive
					accessWidget = untyped accessWidget.querySelector("*[tabindex]:not([disabled]):not([tabindex^='-'])") || accessWidget;
			}

			if (accessWidget != null) {
				if (AccessibilityEnabled && accessWidget.parentNode == null) {
					AccessWidget.updateAccessTree();
				}

				if (accessWidget.parentNode != null) {
					if (focus && accessWidget.focus != null) {
						accessWidget.focus();
						return;
					} else if (!focus && accessWidget.blur != null) {
						accessWidget.blur();
						return;
					}
				}
			}

			Errors.print("Can't set focus on element.");
			clip.emit("blur");
		}
	}

	public static function setMultiline(textfield : TextField, multiline : Bool) : Void {
		textfield.setMultiline(multiline);
	}

	public static function setWordWrap(textfield : TextField, wordWrap : Bool) : Void {
		textfield.setWordWrap(wordWrap);
	}

	public static function getSelectionStart(textfield : TextField) : Int {
		return textfield.getSelectionStart();
	}

	public static function getSelectionEnd(textfield : TextField) : Int {
		return textfield.getSelectionEnd();
	}

	public static function setSelection(textfield : TextField, start : Int, end : Int) : Void {
		textfield.setSelection(start, end);
	}

	public static function setReadOnly(textfield: TextField, readOnly: Bool) : Void {
		textfield.setReadOnly(readOnly);
	}

	public static function setMaxChars(textfield : TextField, maxChars : Int) : Void {
		textfield.setMaxChars(maxChars);
	}

	public static function addTextInputFilter(textfield : TextField, filter : String -> String) : Void -> Void {
		return textfield.addTextInputFilter(filter);
	}

	public static function addTextInputKeyEventFilter(textfield : TextField, event : String, filter : String -> Bool -> Bool -> Bool -> Bool -> Int -> Bool) : Void -> Void {
		if (event == "keydown")
			return textfield.addTextInputKeyDownEventFilter(filter);
		else
			return textfield.addTextInputKeyUpEventFilter(filter);
	}

	public static function findParentAccessibleWidget(clip : Dynamic) : Element {
		if (clip == null) {
			return null;
		} else if (clip == PixiStage) {
			return Browser.document.body;
		} else if (clip.accessWidget != null) {
			return clip.accessWidget.element;
		} else {
			return findParentAccessibleWidget(clip.parent);
		}
	}

	public static function findTopParent(clip : Dynamic) : Dynamic {
		if (clip.parent == null) {
			return clip;
		} else {
			return findTopParent(clip.parent);
		}
	}

	// native addChild : (parent : native, child : native) -> void
	public static function addChild(parent : FlowContainer, child : Dynamic) : Void {
		parent.addChild(child);
	}

	// native addChildAt : (parent : native, child : native, id : int) -> void
	public static function addChildAt(parent : FlowContainer, child : Dynamic, id : Int) : Void {
		parent.addChildAt(child, id);
	}

	// native removeChild : (parent : native, child : native) -> void
	public static function removeChild(parent : FlowContainer, child : Dynamic) : Void {
		parent.removeChild(child);
	}

	public static function makeClip() : FlowContainer {
		return new FlowContainer();
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

	public static function getGlobalTransform(clip : DisplayObject) : Array<Float> {
		if (clip.parent != null) {
			clip.forceUpdateTransform();
			var a = clip.worldTransform;
			return [a.a, a.b, a.c, a.d, a.tx, a.ty];
		} else {
			return [1.0, 0.0, 0.0, 1.0, 0.0, 0.0];
		}
	}

	public static function deferUntilRender(fn : Void -> Void) : Void {
		PixiStage.once("drawframe", fn);
	}

	public static function interruptibleDeferUntilRender(fn : Void -> Void) : Void -> Void {
		PixiStage.once("drawframe", fn);
		return function() {
			PixiStage.off("drawframe", fn);
		};
	}

	public static function setClipAlpha(clip : DisplayObject, a : Float) : Void {
		clip.setClipAlpha(a);
	}

	private static function getFirstVideoWidget(clip : FlowContainer) : Dynamic {
		if (untyped __instanceof__(clip, VideoClip)) return clip;

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
					if (Platform.isIE || Platform.isEdge)
						PixiStage.emit("preonfocus");

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
					var keyUTF = String.fromCharCode(charCode);

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
			fn(ke.key, ke.ctrl, ke.shift, ke.alt, ke.meta, ke.keyCode, ke.preventDefault);
		}

		PixiStage.on(event, keycb);
		return function() { PixiStage.off(event, keycb); }
	}

	public static function addStreamStatusListener(clip : VideoClip, fn : String -> Void) : Void -> Void {
		return clip.addStreamStatusListener(fn);
	}

	public static function addEventListener(clip : DisplayObject, event : String, fn : Void -> Void) : Void -> Void {
		if (event == "resize") {
			PixiStage.on("resize", fn);
			return function() { PixiStage.off("resize", fn); }
		} else if (event == "mousedown" || event == "mousemove" || event == "mouseup" || event == "mousemiddledown" || event == "mousemiddleup") {
			PixiStage.on(event, fn);
			return function() { PixiStage.off(event, fn); }
		} else if (event == "mouserightdown" || event == "mouserightup") {
			// When we register a right-click handler, we turn off the browser context menu.
			var blockContextMenuFn = function () {
				return false;
			}

			PixiRenderer.view.oncontextmenu = blockContextMenuFn;

			var dropareas = Browser.window.document.getElementsByClassName("droparea");
			for (droparea in dropareas) {
				droparea.oncontextmenu = blockContextMenuFn;
			}

			PixiStage.on(event, fn);
			return function() { PixiStage.off(event, fn); }
		} else if (event == "rollover") {
			clip.on("pointerover", fn);
			clip.updateClipInteractive();
			return function() {
				clip.off("pointerover", fn);
				clip.updateClipInteractive();
			};
		} else if (event == "rollout") {
			clip.on("pointerout", fn);
			clip.updateClipInteractive();
			return function() {
				clip.off("pointerout", fn);
				clip.updateClipInteractive();
			};
		} else if (event == "scroll") {
			clip.on("scroll", fn);
			return function() { clip.off("scroll", fn); };
		} else if (event == "change") {
			clip.on("input", fn);
			return function() { clip.off("input", fn); };
		} else if ( event == "focusin" ) {
			clip.on("focus", fn);
			return function() { clip.off("focus", fn); };
		} else if ( event == "focusout" ) {
			clip.on("blur", fn);
			return function() { clip.off("blur", fn); };
		} else {
			Errors.report("Unknown event: " + event);
			return function() {};
		}
	}

	public static function addFileDropListener(clip : Dynamic, maxFilesCount : Int, mimeTypeRegExpFilter : String, onDone : Array<Dynamic> -> Void) : Void -> Void {
		var regExp = new EReg(mimeTypeRegExpFilter, "g");

		/********* Create HTML block and setup metrics *********/

		var dropArea = Browser.document.createElement("div");
		dropArea.className = "droparea";
		dropArea.style.position = "absolute";
		dropArea.style.zIndex = RenderSupportJSPixi.zIndexValues.droparea;
		dropArea.oncontextmenu = PixiRenderer.view.oncontextmenu;

		clip.updateFileDropWidget = function() {
			if (cast(clip, DisplayObject).getClipVisible()) {
				var bounds = clip.getBounds();
				dropArea.style.left = "" + bounds.x + "px";
				dropArea.style.top = "" + bounds.y + "px";
				dropArea.style.width = "" + bounds.width + "px";
				dropArea.style.height = "" + bounds.height + "px";
			} else {
				dropArea.style.display = "none";
			}
		};

		clip.createFileDropWidget = function() {
			Browser.document.body.appendChild(dropArea);
			PixiStage.on("stagechanged", clip.updateFileDropWidget);
		};

		clip.deleteFileDropWidget = function() {
			try {
				Browser.document.body.removeChild(dropArea);
			} catch (e : Dynamic) {}
			PixiStage.off("stagechanged", clip.updateFileDropWidget);
		};

		clip.createFileDropWidget();
		clip.once("removed", function() clip.deleteFileDropWidget);

		/********* Provide mouse events to PixiRenderer view *********/

		var dropAreaProvideEvent = function (event : Dynamic) {
			event.preventDefault();
			dropArea.style.cursor = RenderSupportJSPixi.PixiRenderer.view.style.cursor;
			provideEvent(event);
		};

		dropArea.onmousemove = dropAreaProvideEvent;
		dropArea.onmousedown = dropAreaProvideEvent;
		dropArea.onmouseup = dropAreaProvideEvent;

		/********* Set up drag&drop event listeners *********/

		dropArea.ondragover = function (event) {
			event.dataTransfer.dropEffect = 'copy';
			return false;
		}

		dropArea.ondrop = function (event) {
			event.preventDefault();

			var files : FileList = event.dataTransfer.files;
			var fileArray : Array<File> = [];

			if (maxFilesCount < 0)
				maxFilesCount = files.length;

			for (idx in 0...Math.floor(Math.min(files.length, maxFilesCount))) {
				var file : File = files.item(idx);

				if (!regExp.match(file.type)) {
					maxFilesCount++;
					continue;
				}

				fileArray.push(file);
			}

			onDone(fileArray);
		}

		return clip.deleteFileDropWidget;
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
		PixiStage.on("drawframe", fn);
		return function() { PixiStage.off("drawframe", fn); };
	}

	// Reasonable defaults
	private static var PIXEL_STEP = 10;
	private static var LINE_HEIGHT = 40;
	private static var PAGE_HEIGHT = 800;

	public static function addMouseWheelEventListener(clip : Dynamic, fn : Float -> Float -> Void) : Void -> Void {
		var event_name = untyped __js__("'onwheel' in document.createElement('div') ? 'wheel' : // Modern browsers support 'wheel'
			document.onmousewheel !== undefined ? 'mousewheel' : // Webkit and IE support at least 'mousewheel'
			'DOMMouseScroll'; // let's assume that remaining browsers are older Firefox");


		var wheel_cb = function(event) {
			var sX = 0.0, sY = 0.0,	// spinX, spinY
				pX = 0.0, pY = 0.0;	// pixelX, pixelY

			// Legacy
			if (event.detail != null) { sY = event.detail; }
			if (event.wheelDelta != null) { sY = -event.wheelDelta / 120; }
			if (event.wheelDeltaY != null) { sY = -event.wheelDeltaY / 120; }
			if (event.wheelDeltaX != null) { sX = -event.wheelDeltaX / 120; }

			// side scrolling on FF with DOMMouseScroll
			if (event.axis != null && untyped __strict_eq__(event.axis, event.HORIZONTAL_AXIS)) {
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

			fn(-sX, -sY);

			return false;
		};

		Browser.window.addEventListener(event_name, wheel_cb, false);
		if ( event_name == "DOMMouseScroll" ) {
			Browser.window.addEventListener("MozMousePixelScroll", wheel_cb, false);
		}

		return function() {
			Browser.window.removeEventListener(event_name, wheel_cb);
			if ( event_name == "DOMMouseScroll" ) {
				Browser.window.removeEventListener("MozMousePixelScroll", wheel_cb);
			}
		}
	}

	public static function addFinegrainMouseWheelEventListener(clip : Dynamic, f : Float -> Float -> Void) : Void -> Void {
		return addMouseWheelEventListener(clip, f);
	}

	public static function getMouseX(clip : DisplayObject) : Float {
		if (clip == PixiStage)
			return MousePos.x;
		else
			return clip.toLocal(MousePos).x;
	}

	public static function getMouseY(clip : DisplayObject) : Float {
		if (clip == PixiStage)
			return MousePos.y;
		else
			return clip.toLocal(MousePos).y;
	}

	public static function setMouseX(x : Float) {
		MousePos.x = x;
	}

	public static function setMouseY(y : Float) {
		MousePos.y = y;
	}

	private static function hittestGraphics(g : FlowGraphics, global : Point) : Bool {
		var graphicsData : Array<Dynamic> = untyped g.graphicsData;
		if (graphicsData == null || graphicsData.length == 0) return false;
		var data = graphicsData[0]; // There may be only one shape when drawing with flow
		if(data.fill && data.shape != null) {
			var local = g.toLocal(global);
			return data.shape.contains(local.x, local.y);
		}
		return false;
	}

	public static function dohittest(clip : Dynamic, global : Point) : Bool {
		if (!cast(clip, DisplayObject).getClipWorldVisible() || clip.isMask) return false;
		if (clip.mask != null && !hittestGraphics(clip.mask, global)) return false;

		if (clip.graphicsData != null) { // Graphics
			if (hittestGraphics(clip, global)) { return true; }
		} else if (clip.texture != null) { // image or text sprite
			var w = clip.texture.frame.width; var h = clip.texture.frame.height;
			var local = clip.toLocal(global);
			if (local.x > 0.0 && local.y > 0.0 && local.x < w && local.y < h) { return true; }
		} else if (clip.tint != null) { // DFontTextNative
			var b = clip.getLocalBounds();
			var local = clip.toLocal(global);
			untyped local.y += clip.y; // DFontTextNative is shifted to fit baseline.
			if (local.x > 0.0 && local.y > 0.0 && local.x < b.width && local.y < b.height) { return true; }
		}

		if (clip.children != null) {
			var childs : Array<FlowContainer> = clip.children;
			for (c in childs) if (dohittest(c, global)) return true;
		}

		return false;
	}

	private static inline function clipOnTheStage(clip : DisplayObject) : Bool {
		// TO DO : check clip is on the stage more correctly
		return clip == PixiStage || clip.parent != null;
	}

	public static function getClipAt(p : Point, parent : FlowContainer = null) : Dynamic {
		// Use PixiStage as default clip for searching
		if (parent == null)
			parent = PixiStage;

		var cnt = parent.children.length;
		for (i in 0...cnt) {
			var child = parent.children[cnt - i - 1];
			if ( child.getClipWorldVisible() && (child.mask == null || hittestGraphics(cast child.mask, p) ) &&
				!(untyped child.isMask) && child.getBounds().contains(p.x, p.y)) {
				if (untyped __instanceof__(child, TextField)) {
					return child;
				} else if (untyped child.graphicsData != null && child.graphicsData.length > 0 &&
					child.graphicsData[0].fillAlpha > 0) { // ignore transparent graphics
					if (hittestGraphics(cast child, p)) return child;
				} else if (untyped child.texture != null) {
					return child;
				} else if (untyped child.children != null) {
					var r = getClipAt(p, untyped child);
					if (r != null) return r;
				}
			}
		}

		return null;
	}

	public static function hittest(clip : DisplayObject, x : Float, y : Float) : Bool {
		if (!clipOnTheStage(clip)) return false;

		var global = new Point(x, y);

		// Previous event handlers might change the stage tree.
		// Transforms will be updated only on the next animate
		// So lets do that here
		// TO DO: Optimize
		clip.updateTransform(); // Crashes if parent = null

		// TO DO : Check bounding rect at first?

		// Check toplevel masks
		var parent : Dynamic = clip.parent;
		while (parent != null) {
			if (parent.mask != null && !hittestGraphics(parent.mask, global)) return false; // Outside the mask
			parent = parent.parent;
		}

		return dohittest(clip, global);
	}

	public static function makeGraphics() : FlowGraphics {
		return new FlowGraphics();
	}

	public static function getGraphics(parent : FlowContainer) : FlowGraphics {
		var clip = new FlowGraphics();
		addChild(parent, clip);
		return clip;
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

	// native makePicture : (url : string, cache : bool, metricsFn : (width : double, height : double) -> void,
	// errorFn : (string) -> void, onlyDownload : bool) -> native = RenderSupport.makePicture;
	public static function makePicture(url : String, cache : Bool, metricsFn : Float -> Float -> Void, errorFn : String -> Void, onlyDownload : Bool) : Dynamic {
		return new FlowSprite(url, cache, metricsFn, errorFn, onlyDownload);
	}

	public static function setCursor(cursor : String) : Void {
		var css_cursor =
			switch (cursor) {
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
				default: "default";
			}

		PixiRenderer.view.style.cursor = css_cursor;
	}

	public static function getCursor() : String {
		return switch (PixiRenderer.view.style.cursor) {
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
		InvalidateStage();

		if (RendererType == "canvas") {
			filters = filters.filter(function(f) {
				return f != null && untyped (
					__instanceof__(f, DropShadowFilter) ||
					__instanceof__(f, BlurFilter)
				);
			});
			untyped clip.canvasFilters = filters;
		} else {
			var dropShadowPadding = 0.0;
			var dropShadowCount = 0;

			// Get rid of null filters (Bevel is not implemented)
			filters = filters.filter(function(f) {
				if (untyped __instanceof__(f, DropShadowFilter)) {
					dropShadowPadding = Math.max(untyped f.padding, dropShadowPadding);
					dropShadowCount++;
				}

				return f != null;
			});

			// Increase padding in case we have multiple DropShadowFilters
			if (dropShadowCount > 1) {
				filters = filters.filter(function(f) {
					if (untyped __instanceof__(f, DropShadowFilter)) {
						f.padding = dropShadowPadding * dropShadowCount;
					}

					return f != null;
				});
			}

			clip.filters = filters.length > 0 ? filters : null;
		}
	}

	public static function makeBevel(angle : Float, distance : Float, radius : Float, spread : Float,
							color1 : Int, alpha1 : Float, color2 : Int, alpha2 : Float, inside : Bool) : Dynamic {
		return null;
	}

	public static function makeBlur(radius : Float, spread : Float) : Dynamic {
		return new BlurFilter(spread);
	}

	public static function makeDropShadow(angle : Float, distance : Float, radius : Float, spread : Float,color : Int, alpha : Float, inside : Bool) : Dynamic {
		return new DropShadowFilter(90 - angle, distance, radius, color, alpha);
	}

	public static function makeGlow(radius : Float, spread : Float, color : Int, alpha : Float, inside : Bool) : Dynamic {
		return null;
	}

	public static function setScrollRect(clip : FlowContainer, left : Float, top : Float, width : Float, height : Float) : Void {
		clip.setScrollRect(left, top, width, height);
	}

	public static function getTextMetrics(textfield : TextField) : Array<Float> {
		return textfield.getTextMetrics();
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

	public static function setClipRenderable(clip : DisplayObject, renderable : Bool) : Void {
		return clip.setClipRenderable(renderable);
	}

	public static function fullScreenTrigger() {
		IsFullScreen = isFullScreen();
		PixiStage.emit("fullscreen", IsFullScreen);
	}

	public static function fullWindowTrigger(fw : Bool) {
		IsFullWindow = fw;
		PixiStage.emit("fullwindow", fw);
	}

	private static var FullWindowTargetClip : DisplayObject = null;
	public static function setFullWindowTarget(clip : DisplayObject) : Void {
		if (FullWindowTargetClip != clip) {
			if (IsFullWindow && FullWindowTargetClip != null) {
				toggleFullWindow(false);
				FullWindowTargetClip = clip;
				if (clip != null)
					toggleFullWindow(true);
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
			InvalidateStage();

			if (Platform.isIOS) {
				FullWindowTargetClip = untyped getFirstVideoWidget(untyped FullWindowTargetClip) || FullWindowTargetClip;
				if (untyped __instanceof__(FullWindowTargetClip, VideoClip)) {
					if (fw)
						requestFullScreen(untyped FullWindowTargetClip.nativeWidget)
					else
						exitFullScreen(untyped FullWindowTargetClip.nativeWidget);

					return;
				}
			}

			PixiStage.renderable = false;

			if (fw) {
				regularStageChildren = PixiStage.children;
				setShouldPreventFromBlur(FullWindowTargetClip);
				PixiStage.children = [];

				regularFullScreenClipParent = FullWindowTargetClip.parent;
				PixiStage.addChild(FullWindowTargetClip);

				var _clip_visible = untyped FullWindowTargetClip._visible;

				// Make other content invisible to prevent from mouse events
				for (child in regularStageChildren) {
					untyped child._flow_visible = untyped child._visible;
					child.setClipVisible(false);
				}

				FullWindowTargetClip.setClipVisible(_clip_visible);
				FullWindowTargetClip.updateTransform();
			} else {
				if (regularFullScreenClipParent != null && regularStageChildren.length != 0) {
					for (child in regularStageChildren) {
						child.setClipVisible(untyped child._flow_visible);
					}

					PixiStage.children = regularStageChildren;
					regularFullScreenClipParent.addChild(FullWindowTargetClip);
				}
			}

			PixiStage.renderable = true;

			fullWindowTrigger(fw);
		}
	}

	public static function requestFullScreen(element : Element) {
		if (untyped element.requestFullscreen != null)
			untyped element.requestFullscreen();
		else if (untyped element.mozRequestFullScreen != null)
			untyped element.mozRequestFullScreen();
		else if (untyped element.webkitRequestFullscreen != null)
			untyped element.webkitRequestFullscreen();
		else if (untyped element.msRequestFullscreen != null)
			untyped element.msRequestFullscreen();
		else if (untyped element.webkitEnterFullScreen != null)
			untyped element.webkitEnterFullScreen();
	}

	public static function exitFullScreen(element : Element) {
		if (untyped __instanceof__(element, js.html.CanvasElement)) {
			element = untyped Browser.document;
		}

		if (IsFullScreen) {
			if (untyped element.exitFullscreen != null)
				untyped element.exitFullscreen();
			else if (untyped element.mozCancelFullScreen != null)
				untyped element.mozCancelFullScreen();
			else if (untyped element.webkitExitFullscreen != null)
				untyped element.webkitExitFullscreen();
			else if (untyped element.msExitFullscreen != null)
				untyped element.msExitFullscreen();
		}
	}

	public static function toggleFullScreen(fs : Bool) : Void {
		if (!Platform.isIOS) {
			if (fs)
				requestFullScreen(PixiRenderer.view);
			else
				exitFullScreen(PixiRenderer.view);
		}
	}

	public static function onFullScreen(fn : Bool -> Void) : Void -> Void {
		PixiStage.on("fullscreen", fn);
		return function () { PixiStage.off("fullscreen", fn); };
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
		PixiStage.on("fullwindow", onChange);
		return function() { PixiStage.off("fullwindow", onChange); }
	}

	public static function isFullWindow() : Bool {
		return IsFullWindow;
	}

	public static function setWindowTitle(title : String) : Void {
		Browser.document.title = title;
	}

	public static function setFavIcon(url : String) : Void {
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
	}

	public static function takeSnapshot(path : String) : Void {
		// Empty for these targets
		trace("takeSnapshot isn't implemented in js");
		trace("use getSnapshot instead");
	}

	public static function getSnapshot() : String {
		var child : FlowContainer = untyped PixiStage.children[0];

		if (child == null) {
			return "";
		}

		child.setScrollRect(0, 0, getStageWidth(), getStageHeight());
		var img = PixiRenderer.plugins.extract.base64(PixiStage);
		child.removeScrollRect();

		return img;
	}

	public static function getScreenPixelColor(x : Int, y : Int) : Int {
		var data = PixiRenderer.view.getContext2d().getImageData(x * backingStoreRatio, y * backingStoreRatio, 1, 1).data;

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

	public static function webClipEvalJS(clip : Dynamic, code : String) : Dynamic {
		clip.evalJS(code);
		return null;
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