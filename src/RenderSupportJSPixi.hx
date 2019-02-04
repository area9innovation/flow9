import js.Browser;
import js.html.Element;
import js.html.File;
import js.html.FileList;
import js.html.IFrameElement;

import pixi.core.renderers.SystemRenderer;
import pixi.core.sprites.Sprite;
import pixi.core.display.DisplayObject;
import pixi.core.renderers.Detector;
import pixi.core.renderers.canvas.CanvasRenderer;
import pixi.core.renderers.webgl.WebGLRenderer;
import pixi.core.math.shapes.Rectangle;
import pixi.core.textures.Texture;
import pixi.core.renderers.webgl.filters.Filter;
import pixi.core.text.Text;
import pixi.core.math.Point;

import pixi.loaders.Loader;

import MacroUtils;
import Platform;
import FlowFontStyle;

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
	private static var ShowDebugClipsTree : Bool = Util.getParameter("clipstree") == "1";
	private static var CacheTextsAsBitmap : Bool = Util.getParameter("cachetext") == "1";
	private static var DebugAccessOrder : Bool = Util.getParameter("accessorder") == "1";
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
			transparent : false,
			backgroundColor : 0xFFFFFF,
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

		// Set selfZOrder of the body to allow updation of its zOrder inside updateAccessWidgetZOrder
		var accessWidget : Dynamic = untyped Browser.document.body;

		accessWidget.selfZOrder = 0;
		accessWidget.updateDisplay = function() {
			var newZorder : Int = accessWidget.zOrder;

			if (accessWidget.previousZorder != newZorder) {
				accessWidget.previousZorder = newZorder;

				var children : Array<Dynamic> = accessWidget.children;

				if (children != null) {
					for (child in children) {
						if (child.updateDisplay != null) {
							child.updateDisplay(accessWidget.zOrder);
						}
					}
				}
			}
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
			var is_portrait = Browser.window.innerWidth < Browser.window.innerHeight;
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
			var win_width = e.target.innerWidth + 1;
			var win_height = e.target.innerHeight + 1;

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

		PixiStage.on("mousedown", function (e) { MouseUpReceived = false; });
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

	private static function emulateMouseClickOnClip(clip : DisplayObject) : Void {
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
		PixiStage.emit("drawframe", timestamp);

		if (PixiStageChanged || VideoClip.NeedsDrawing()) {
			PixiRenderer.render(PixiStage);

			PixiStage.emit("stagechanged", timestamp);

			PixiStageChanged = false;

			if (ShowDebugClipsTree) {
				DebugClipsTree.getInstance().updateTree(PixiStage);
			}
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
		for (kv in attributes) {
			var key = kv[0];
			var val = kv[1];
			switch (key) {
				case "role": {
					clip.accessWidget.setAttribute("role", val);

					// Sets events
					if (accessRoleMap.get(val) == "button") {
						clip.accessWidget.onclick = function(e) {
							if (e.target == clip.accessWidget) {
								if (clip.accessCallback != null) {
									clip.accessCallback();
								} else {
									emulateMouseClickOnClip(clip);
								}
							}
						};

						var onFocus = clip.accessWidget.onfocus;
						var onBlur = clip.accessWidget.onblur;

						clip.accessWidget.onfocus = function(e) {
							if (onFocus != null) {
								onFocus(e);
							}

							clip.accessWidget.classList.add('focused');
						};

						clip.accessWidget.onblur = function(e) {
							if (onBlur != null) {
								onBlur(e);
							}

							clip.accessWidget.classList.remove('focused');
						};

						if (clip.accessWidget.tabIndex == null) {
							clip.accessWidget.tabIndex = 0;
						}
					} else if (val == "textbox") {
						clip.accessWidget.onkeyup = function(e) {
							if (e.keyCode == 13 && clip.accessCallback != null)
								clip.accessCallback();
						}

						if (clip.accessWidget.tabIndex == null) {
							clip.accessWidget.tabIndex = 0;
						}
					} else if (val == "iframe") {
						if (clip.accessWidget.tabIndex == null) {
							clip.accessWidget.tabIndex = 0;
						}
					}
				}
				case "description":
					if (val != "") clip.accessWidget.setAttribute("aria-label", val);
				case "zorder": {
					clip.accessWidget.selfZOrder = Std.parseInt(val);
					if (DebugAccessOrder) clip.accessWidget.setAttribute("selfzorder", val);

					if (clip.accessWidget.parentNode != null) {
						updateAccessWidgetZOrder(clip.accessWidget);
					}
				}
				case "id":
					clip.accessWidget.id = val;
				case "enabled":
					if (val == "true") {
						clip.accessWidget.removeAttribute("disabled");
						clip.accessWidget.setAttribute("aria-disabled", "false");
					} else {
						clip.accessWidget.setAttribute("disabled", "disabled");
						clip.accessWidget.setAttribute("aria-disabled", "true");
					}
				case "nodeindex": {
					var nodeindex_strings = ~/ /g.split(val);
					clip.accessWidget.nodeindex = new Array();
					if (DebugAccessOrder) clip.accessWidget.setAttribute("nodeindex", val);

					for (i in 0...nodeindex_strings.length) {
						clip.accessWidget.nodeindex = clip.accessWidget.nodeindex.concat([Std.parseInt(nodeindex_strings[i])]);
					}

					if (clip.accessWidget.parentNode != null) {
						addNode(clip.accessWidget.parentNode, clip.accessWidget);
					}
				}
				case "tabindex": {
					clip.accessWidget.tabIndex = Std.parseInt(val);
				}
				case "autocomplete": {
					clip.accessWidget.autocomplete = val;

					if (clip.setReadOnly != null) {
						clip.setReadOnly(clip.readOnly);
					}
				}
				default: {
					clip.accessWidget.setAttribute(key, val);
				}
			}
		}
	}

	public static function setAccessibilityEnabled(enabled : Bool) : Void {
		AccessibilityEnabled = enabled && Platform.AccessiblityAllowed;
	}

	public static function setEnableFocusFrame(show : Bool) : Void {
		EnableFocusFrame = show;
	}

	// ARIA-role to HTML tag map
	private static var accessRoleMap:Map<String, String> = [
		"button" => "button",
		"checkbox" => "button",
		"radio" => "button",
		"menu" => "button",
		"listitem" => "button",
		"menuitem" => "button",
		"tab" => "button",
		"banner" => "header",
		"main" => "section",
		"navigation" => "nav",
		"contentinfo" => "footer",
		"form" => "form",
		"textbox" => "input",
	];

	public static function setAccessAttributes(clip : Dynamic, attributes : Array< Array<String> >) : Void {
		if (!AccessibilityEnabled) return;

		if (clip.accessWidget == null) {
			// Create DOM node for access. properties
			if (clip.nativeWidget != null) {
				clip.accessWidget = clip.nativeWidget; // Just create a link
				addAccessAttributes(clip, attributes);
			} else {
				InvalidateStage();

				var tagName = "div";

				for (kv in attributes) {
					if (kv[0] == "role" && tagName == "div") {
						var mapval = accessRoleMap.get(kv[1]);

						if (mapval != null) {
							tagName = mapval;
						}
					} else if (kv[0] == "tag") {
						tagName = kv[1];
					}
				}

				clip.accessWidget = Browser.document.createElement(tagName);
				if (DebugAccessOrder) {
					clip.accessWidget.clip = clip;
				}

				// Add focus notification. Used for focus control
				clip.accessWidget.addEventListener("focus", function () {
					clip.emit("focus");

					var parent : DisplayObject = clip.parent;

					if (parent != null) {
						parent.emitEvent("childfocused", clip);
					}
				});

				// Add blur notification. Used for focus control
				clip.accessWidget.addEventListener("blur", function () {
					clip.emit("blur");
				});

				clip.accessWidget.setAttribute("aria-disabled", "false");
				// selfZOrder - self zOrder of the accessWidget that is set from flow
				// instead of zOrder field that contain max zOrder of the accessWidget and its children
				clip.accessWidget.selfZOrder = 0;
				clip.accessWidget.updateDisplay = function() {
					var newZorder : Int = untyped Browser.document.body.zOrder;

					if (clip.parent != null && clip.accessWidget != null) {
						clip.accessWidget.style.display = clip.accessWidget.zOrder >= newZorder && cast(clip, DisplayObject).getClipVisible() ? "block" : "none";

						var children : Array<Dynamic> = untyped clip.accessWidget.children;

						if (children != null) {
							for (child in children) {
								if (child.updateDisplay != null) {
									child.updateDisplay();
								}
							}
						}
					}
				}

				// adding human-meaningful attributes first so they appear earlier for easier reading HTML
				addAccessAttributes(clip, attributes);

				clip.accessWidget.style.zIndex = RenderSupportJSPixi.zIndexValues.accessButton;
				if (tagName == "button") {
					// setting temp. value so it will be easier to read in DOM
					if (clip.accessWidget.getAttribute("aria-label") == null) {
						clip.accessWidget.setAttribute("aria-label", "");
					}
					clip.accessWidget.classList.add("accessButton");
				} else if (tagName == "input") {
					clip.accessWidget.style.position = "fixed";
					clip.accessWidget.style.cursor = "inherit";
					clip.accessWidget.style.opacity = 0;
					clip.accessWidget.setAttribute("readonly", "");
				} else if (tagName == "form") {
					clip.accessWidget.onsubmit = function() { return false; }
				} else {
					clip.accessWidget.classList.add("accessElement");
				}

				clip.updateAccessWidget = function() if (clip.accessWidget != null && clip.accessWidget.parentNode != null) {
					if (cast(clip, DisplayObject).getClipVisible()) {
						var newZorder : Int = untyped Browser.document.body.zOrder;
						var transform = clip.accessWidget.parentNode.style.transform != "" && clip.accessWidget.parentNode.clip != null ?
							clip.worldTransform.clone().append(clip.accessWidget.parentNode.clip.worldTransform.clone().invert()) : clip.worldTransform;

						if (Platform.isIE) {
							clip.accessWidget.style.transform = "matrix(" + transform.a + "," + transform.b + "," + transform.c + "," + transform.d + ","
								+ 0 + "," + 0 + ")";

							clip.accessWidget.style.left = untyped "" + clip.worldTransform.tx + "px";
							clip.accessWidget.style.top = untyped "" + clip.worldTransform.ty + "px";
						} else {
							clip.accessWidget.style.transform = "matrix(" + transform.a + "," + transform.b + "," + transform.c + "," + transform.d + ","
								+ transform.tx + "," + transform.ty + ")";
						}

						clip.accessWidget.style.width = untyped "" + clip.width + "px";
						clip.accessWidget.style.height = untyped "" + clip.height + "px";

						clip.accessWidget.style.display = clip.accessWidget.zOrder >= newZorder ? "block" : "none";
					} else {
						clip.accessWidget.style.display = "none";
					}
				};

				clip.deleteAccessWidget = function() {
					// Removed from stage

					if (DebugAccessOrder)
						PixiStage.off("stagechanged", clip.updateAccessWidget);
					if (clip.accessWidget != null) {
						var parentNode = clip.accessWidget.parentNode;

						if (parentNode != null) {
							parentNode.removeChild(clip.accessWidget);
						}

						clip.accessWidget = null;

						if (parentNode != null) {
							updateAccessWidgetZOrder(parentNode);
						}

						clip.addAccessWidget = null;
						clip.updateAccessWidget = null;
						clip.deleteAccessWidget = null;
					};
				}

				clip.addAccessWidget = function() {
					if (clip.accessWidget != null) {
						var parentNode = findParentAccessibleWidget(clip.parent);

						if (parentNode == null) {
							findTopParent(clip).once("added", clip.addAccessWidget);
						} else {
							addNode(parentNode, clip.accessWidget);

							if (DebugAccessOrder)
								PixiStage.on("stagechanged", clip.updateAccessWidget);

							clip.once("removed", clip.deleteAccessWidget);
						}
					}
				}

				if (clip.parent != null) {
					clip.addAccessWidget();
				} else {
					clip.once("added", clip.addAccessWidget);
				}
			}
		} else {
			addAccessAttributes(clip, attributes);
		}
	}

	public static function removeAccessAttributes(clip : Dynamic) : Void {
		if (clip.deleteAccessWidget != null) {
			clip.deleteAccessWidget();
			clip.deleteAccessWidget = null;
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

	// Update zOrder fields of the accessWidget and its children
	// zOrder field contain max zOrder of the accessWidget and its children
	public static function updateAccessWidgetZOrder(accessWidget : Dynamic) : Void {
		if (accessWidget != null && accessWidget.selfZOrder != null) {
			var previousZOrder = accessWidget.zOrder;
			accessWidget.zOrder = accessWidget.selfZOrder;
			var children : Array<Dynamic> = untyped accessWidget.children;

			if (children != null) {
				for (child in children) {
					if (accessWidget.zOrder < child.zOrder)
						accessWidget.zOrder = child.zOrder;
				}
			}

			if (DebugAccessOrder) {
				accessWidget.setAttribute("zorder", accessWidget.zOrder);
				accessWidget.setAttribute("selfzorder", accessWidget.selfZOrder);
			}

			if (previousZOrder != accessWidget.zOrder && accessWidget != Browser.document.body) {
				updateAccessWidgetZOrder(accessWidget.parentNode);
			} else if (accessWidget.updateDisplay != null) {
				accessWidget.updateDisplay();
			}
		}
	}

	public static function updateAccessDisplay(clip : Dynamic) : Void {
		if (clip.accessWidget != null && clip.accessWidget.updateDisplay != null) {
			clip.accessWidget.updateDisplay();
 		} else if (clip.children != null) {
 			var children : Array<Dynamic> = clip.children;

			for (child in children) {
				updateAccessDisplay(child);
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
		return (UseDFont && FontLoader.hasDFont(fontFamily))? new DFontText() : new PixiText();
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

			if (accessWidget != null && accessWidget.parentNode != null) {
				if (focus && accessWidget.focus != null) {
					accessWidget.focus();
				} else if (!focus && accessWidget.blur != null) {
					accessWidget.blur();
				} else {
					Errors.print("Can't set focus on element.");
					clip.emit("blur");
				}
			} else {
				Errors.print("Can't set focus on element.");
				clip.emit("blur");
			}
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

	private static inline function getAccessElement(clip: DisplayObject) : Element {
		return if (untyped clip.accessWidget != null) untyped clip.accessWidget
			else if (untyped __instanceof__(clip, NativeWidgetClip) && untyped clip.nativeWidget != null) untyped clip.nativeWidget
			else null;
	}

	// Returns next access element after currentChild
	private static function getNextAccessElement(parent : Element, currentChild : Dynamic) : Element {
		return Lambda.find(untyped __js__("Array.from(parent.children)"), function(childclip : Dynamic) {

			if (currentChild != childclip && currentChild.nodeindex) {
				if (childclip.nodeindex) {
					var _g = 0;
					var childclipB = false;
					var stopCheck = false;

					while (!stopCheck && _g < childclip.nodeindex.length && _g < currentChild.nodeindex.length) {
						stopCheck = childclip.nodeindex[_g] != currentChild.nodeindex[_g];
						childclipB = childclip.nodeindex[_g] >= currentChild.nodeindex[_g];
						++_g;
					}

					return childclipB;
				} else {
					return false;
				}
			} else {
				return false;
			}
		});
	}

	public static function findParentAccessibleWidget(clip : Dynamic) : Element {
		if (clip == null) {
			return null;
		} else if (clip == PixiStage) {
			return Browser.document.body;
		} else if (clip.accessWidget != null) {
			return clip.accessWidget;
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

	// Check if nodeindex of the child starts with nodeindex of the parent (IOW can parent contain child with such nodeindex)
	private static function parentNodeIndex(parent : Dynamic, child : Dynamic) : Bool {
		var res = false;

		if (!child.contains(parent) && parent.nodeindex != null && child.nodeindex != null &&
			parent.nodeindex.length != 0 && child.nodeindex.length >= parent.nodeindex.length) {
			res = true;

			for (i in 0...parent.nodeindex.length) {
				if (parent.nodeindex[i] != child.nodeindex[i]) {
					res = false;
					break;
				}
			}
		}

		return res;
	}

	// Check if parent and child have equal nodeindex fields
	private static function equalNodeIndex(parent : Dynamic, child : Dynamic) : Bool {
		var res = false;

		if (parent.nodeindex != null && child.nodeindex != null && parent.nodeindex.length != 0 &&
			child.nodeindex.length == parent.nodeindex.length) {

			res = true;

			for (i in 0...parent.nodeindex.length) {
				if (parent.nodeindex[i] != child.nodeindex[i]) {
					res = false;
					break;
				}
			}
		}

		return res;
	}

	public static function addNode(parent : Dynamic, child : Dynamic) : Void {
		try {
			var nextAccessChild = getNextAccessElement(parent, child);
			var previousParentNode = child.parentNode;

			if (nextAccessChild != null) {
				if (parentNodeIndex(nextAccessChild, child)) {
					if (equalNodeIndex(nextAccessChild, child)) {
						if (nextAccessChild.nextSibling == null)
							parent.appendChild(child)
						else
							parent.insertBefore(child, nextAccessChild.nextSibling);
					} else {
						addNode(nextAccessChild, child);
					}
				} else {
					if (DebugAccessOrder && parent != Browser.document.body && !parentNodeIndex(parent, child)) {
						trace("Wrong accessWidget parentNode nodeindex");
						trace(parent);
						trace(child);
					}

					parent.insertBefore(child, nextAccessChild);
				}
			} else {
				if (DebugAccessOrder && parent != Browser.document.body && !parentNodeIndex(parent, child)) {
					trace("Wrong accessWidget parentNode nodeindex");
					trace(parent);
					trace(child);
				}

				parent.appendChild(child);
			}

			if (previousParentNode != child.parentNode) {
				updateAccessWidgetZOrder(previousParentNode);
				updateAccessWidgetZOrder(child.parentNode);
				updateAccessWidgetZOrder(child);
			}
		} catch (e : Dynamic) {
			if (DebugAccessOrder && parent != Browser.document.body && !parentNodeIndex(parent, child)) {
				trace("Wrong accessWidget parentNode nodeindex");
				trace(parent);
				trace(child);
			}

			if (parent.parentNode != null) {
				addNode(parent.parentNode, child);
			} else {
				addNode(Browser.document.body, child);
			}
		}
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
		return null;//new Filter(Shaders.VertexSrc.join('\n'), Shaders.GlowFragmentSrc.join('\n'), {});
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

				var _clip_visible = FullWindowTargetClip.visible;

				// Make other content invisible to prevent from mouse events
				for (child in regularStageChildren) {
					untyped child._flow_visible = child.visible;
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

private class NativeWidgetClip extends FlowContainer {
	private var nativeWidget : Dynamic;
	private var parentNode : Dynamic;

	// Returns metrics to set correct native widget size
	private function getWidth() : Float { return 0.0; }
	private function getHeight() : Float { return 0.0; }

	public function updateNativeWidget() {
		// Set actual HTML node metrics, opacity etc.
		if (getClipVisible()) {
			var transform = nativeWidget.parentNode.style.transform != "" && nativeWidget.parentNode.clip != null ?
				worldTransform.clone().append(nativeWidget.parentNode.clip.worldTransform.clone().invert()) : worldTransform;

			var tx = getClipWorldVisible() ? transform.tx : RenderSupportJSPixi.PixiRenderer.width;
			var ty = getClipWorldVisible() ? transform.ty : RenderSupportJSPixi.PixiRenderer.height;

			if (Platform.isIE) {
				nativeWidget.style.transform = "matrix(" + transform.a + "," + transform.b + "," + transform.c + "," + transform.d + ","
					+ 0 + "," + 0 + ")";

				nativeWidget.style.left = untyped "" + tx + "px";
				nativeWidget.style.top = untyped "" + ty + "px";
			} else {
				nativeWidget.style.transform = "matrix(" + transform.a + "," + transform.b + "," + transform.c + "," + transform.d + ","
					+ tx + "," + ty + ")";
			}

			nativeWidget.style.width = untyped "" + getWidth() + "px";
			nativeWidget.style.height = untyped "" + getHeight() + "px";

			nativeWidget.style.opacity = worldAlpha;
			nativeWidget.style.display = "block";
		}/* else if (!getClipWorldVisible()) {
			nativeWidget.style.display = "none";
		}*/
	}

	private function addNativeWidget() : Void {
		if (nativeWidget != null) {
			if (parentNode == null) {
				parentNode = RenderSupportJSPixi.findParentAccessibleWidget(parent);
			}

			if (parentNode != null) {
				nativeWidget.style.position = "fixed";
				nativeWidget.style.zIndex = RenderSupportJSPixi.zIndexValues.nativeWidget;

				RenderSupportJSPixi.addNode(parentNode, nativeWidget);

				RenderSupportJSPixi.PixiStage.on("stagechanged", updateNativeWidget);
				once("removed", deleteNativeWidget);
			} else {
				RenderSupportJSPixi.findTopParent(this).once("added", addNativeWidget);
			}
		}
	}

	private function createNativeWidget(node_name : String) : Void {
		deleteNativeWidget();

		nativeWidget = Browser.document.createElement(node_name);
		nativeWidget.style.transformOrigin = "top left";

		if (parent != null) {
			addNativeWidget();
		} else {
			once("added", addNativeWidget);
		}
	}

	private function deleteNativeWidget() : Void {
		RenderSupportJSPixi.PixiStage.off("stagechanged", updateNativeWidget);
		if (nativeWidget != null) {
			parentNode = nativeWidget.parentNode;

			if (parentNode != null) {
				parentNode.removeChild(nativeWidget);
			}

			nativeWidget = null;
		}
	}

	static private var lastFocusedClip : Dynamic = null;
	public function setFocus(focus : Bool) if (nativeWidget != null) {
		if (focus) nativeWidget.focus() else nativeWidget.blur();
	}

	public function getFocus() : Bool {
		return nativeWidget != null && Browser.document.activeElement == nativeWidget;
	}

	public function requestFullScreen() : Void {
		if (nativeWidget != null) {
			RenderSupportJSPixi.requestFullScreen(nativeWidget);
		}
	}

	public function exitFullScreen() : Void {
		if (nativeWidget != null) {
			RenderSupportJSPixi.exitFullScreen(nativeWidget);
		}
	}
}

private class VideoClip extends FlowContainer {

	private var nativeWidget : Dynamic;

	private var metricsFn : Float -> Float -> Void;
	private var playFn : Bool -> Void;
	private var durationFn : Float -> Void;
	private var positionFn : Float -> Void;
	private var streamStatusListener : Array<String -> Void> = new Array<String -> Void>();

	private var startTime : Float = 0;
	private var endTime : Float = 0;

	private var videoSprite : Sprite;
	private var videoTexture : Texture;
	private var fontFamily : String = '';
	private var textField : TextField;
	private var loaded : Bool = false;

	private static var playingVideos : Int = 0;

	public static inline function NeedsDrawing() : Bool {
		if (playingVideos != 0) {
			Browser.window.dispatchEvent(Platform.isIE ? untyped __js__("new CustomEvent('videoplaying')") : new js.html.Event('videoplaying'));
			return true;
		}

		return false;
	}

	public function new(metricsFn : Float -> Float -> Void, playFn : Bool -> Void, durationFn : Float -> Void, positionFn : Float -> Void) {
		super();

		this.metricsFn = metricsFn;
		this.playFn = playFn;
		this.durationFn = durationFn;
		this.positionFn = positionFn;
	}

	private static inline function determineCrossOrigin(url : String) {
		// data: and javascript: urls are considered same-origin
		if (url.indexOf('data:') == 0)
			return '';

		// default is window.location
		var loc = Browser.window.location;

		var tempAnchor : Dynamic = Browser.document.createElement('a');

		tempAnchor.href = url;

		var samePort = (!tempAnchor.port && loc.port == '') || (tempAnchor.port == loc.port);

		// if cross origin
		if (tempAnchor.hostname != loc.hostname || !samePort || tempAnchor.protocol != loc.protocol) {
			return 'anonymous';
		}

		return '';
	}

	public function updateNativeWidget() {
		if (!nativeWidget.paused) {
			checkTimeRange(nativeWidget.currentTime, true);
		}
	}

	private function checkTimeRange(currentTime : Float, videoResponse : Bool) : Void {
		try { // Crashes in IE sometimes
			if (currentTime < startTime && startTime < nativeWidget.duration) {
				nativeWidget.currentTime = startTime;
				positionFn(nativeWidget.currentTime);
			} else if (endTime > 0 && endTime > startTime && currentTime >= endTime) {
				if (nativeWidget.paused) {
					nativeWidget.currentTime = endTime;
				} else {
					nativeWidget.currentTime = startTime;
					if (!nativeWidget.loop) nativeWidget.pause();
				}
				positionFn(nativeWidget.currentTime);
			} else if (videoResponse) {
				positionFn(nativeWidget.currentTime);
			} else {
				nativeWidget.currentTime = currentTime;
			}
		} catch (e : Dynamic) {}

		if (videoTexture != null) {
			untyped videoTexture.baseTexture.update();
		}
	}

	private function createVideoClip(filename : String, startPaused : Bool) : Void {
		deleteVideoClip();

		nativeWidget = Browser.document.createElement("video");
		nativeWidget.crossorigin = determineCrossOrigin(filename);
		nativeWidget.autoplay = !startPaused;
		nativeWidget.src = filename;
		nativeWidget.setAttribute('playsinline', true);

		if (nativeWidget.autoplay) {
			playingVideos++;
		}

		videoTexture = Texture.fromVideo(nativeWidget);
		untyped videoTexture.baseTexture.autoPlay = !startPaused;
		untyped videoTexture.baseTexture.autoUpdate = false;
		videoSprite = new Sprite(videoTexture);
		untyped videoSprite._visible = true;
		addChild(videoSprite);

		RenderSupportJSPixi.PixiStage.on("drawframe", updateNativeWidget);
		once("removed", deleteVideoClip);

		createStreamStatusListeners();
		createFullScreenListeners();
	}

	private function deleteVideoClip() : Void {
		if (nativeWidget != null) {
			nativeWidget.autoplay = false;
			pauseVideo();

			// Force video unload
			nativeWidget.removeAttribute('src');
			nativeWidget.load();

			RenderSupportJSPixi.PixiStage.off("drawframe", updateNativeWidget);

			deleteVideoSprite();
			deleteSubtitlesClip();

			destroyStreamStatusListeners();
			destroyFullScreenListeners();

			if (nativeWidget != null) {
				var parentNode = nativeWidget.parentNode;

				if (parentNode != null) {
					parentNode.removeChild(nativeWidget);
				}

				nativeWidget = null;
			}
		}

		loaded = false;
	}

	public function getDescription() : String {
		return nativeWidget != null ? 'VideoClip (url = ${nativeWidget.url})' : '';
	}

	public function setVolume(volume : Float) : Void {
		if (nativeWidget != null) {
			nativeWidget.volume = volume;
		}
	}

	public function setLooping(loop : Bool) : Void {
		if (nativeWidget != null) {
			nativeWidget.loop = loop;
		}
	}

	public function playVideo(filename : String, startPaused : Bool) : Void {
		createVideoClip(filename, startPaused);
	}

	public function setTimeRange(start : Float, end : Float) : Void {
		startTime = start >= 0 ? start : 0;
		endTime = end > startTime ? end : nativeWidget.duration;
		checkTimeRange(nativeWidget.currentTime, true);
	}

	public function setCurrentTime(time : Float) : Void {
		checkTimeRange(time, false);
	}

	public function setVideoSubtitle(text : String, fontfamily : String, fontsize : Float, fontweight : Int, fontslope : String, fillcolor : Int,
		fillopacity : Float, letterspacing : Float, backgroundcolour : Int, backgroundopacity : Float) : Void {
		if (text == '') {
			deleteSubtitlesClip();
		} else {
			setVideoSubtitleClip(text, fontfamily, fontsize, fontweight, fontslope, fillcolor, fillopacity, letterspacing, backgroundcolour, backgroundopacity);
		};
	}

	public function setPlaybackRate(rate : Float) : Void {
		if (nativeWidget != null) {
			nativeWidget.playbackRate = rate;
		}
	}

	private function setVideoSubtitleClip(text : String, fontfamily : String, fontsize : Float, fontweight : Int, fontslope : String, fillcolor : Int,
		fillopacity : Float, letterspacing : Float, backgroundcolour : Int, backgroundopacity : Float) : Void {
		if (fontFamily != fontfamily && fontfamily != '') {
			fontFamily = fontfamily;
			deleteSubtitlesClip();
		}

		createSubtitlesClip();
		textField.setTextAndStyle(' ' + text + ' ', fontFamily, fontsize, fontweight, fontslope, fillcolor, fillopacity, letterspacing, backgroundcolour, backgroundopacity);
		updateSubtitlesClip();
	}

	private function createSubtitlesClip() : Void {
		if (textField == null) {
			textField = RenderSupportJSPixi.makeTextField(fontFamily);
			addChild(textField);
		};
	}

	private function updateSubtitlesClip() : Void {
		if (nativeWidget != null) {
			textField.x = (nativeWidget.width - textField.getWidth()) / 2;
			textField.y = (nativeWidget.height - textField.getHeight()) - 2;
		}
	}

	private function deleteSubtitlesClip() : Void {
		removeChild(textField);
		textField = null;
	}

	private function deleteVideoSprite() : Void {
		if (videoSprite != null) {
			videoSprite.destroy({ children: true, texture: true, baseTexture: true });
			removeChild(videoSprite);
			videoSprite = null;
		}

		if (videoTexture != null) {
			videoTexture.destroy(true);
			videoTexture = null;
		}
	}

	public function getCurrentTime() : Float {
		return nativeWidget != null ? nativeWidget.currentTime : 0;
	}

	public function pauseVideo() : Void {
		if (loaded && !nativeWidget.paused) {
		 	nativeWidget.pause();
			playingVideos--;
		}
	}

	public function resumeVideo() : Void {
		if (loaded && nativeWidget.paused) {
			nativeWidget.play();
			playingVideos++;
		}
	}

	private function onMetadataLoaded() {
		durationFn(nativeWidget.duration);

		nativeWidget.width = nativeWidget.videoWidth;
		nativeWidget.height = nativeWidget.videoHeight;
		metricsFn(nativeWidget.width, nativeWidget.height);

		checkTimeRange(nativeWidget.currentTime, true);

		RenderSupportJSPixi.InvalidateStage(); // Update the widget

		if (!nativeWidget.autoplay) nativeWidget.pause();

		if (textField != null) {
			swapChildren(videoSprite, textField);
			updateSubtitlesClip();
		};

		loaded = true;
	}

	private function onStreamLoaded() : Void {
		streamStatusListener.map(function (l) { l("NetStream.Play.Start"); });
	}

	private function onStreamEnded() : Void {
		if (!nativeWidget.autoplay) {
			playingVideos--;
		}

		streamStatusListener.map(function (l) { l("NetStream.Play.Stop"); });
	}

	private function onStreamError() : Void {
		streamStatusListener.map(function (l) { l("NetStream.Play.StreamNotFound"); });
	}

	private function onStreamPlay() : Void {
		if (nativeWidget != null && !nativeWidget.paused) {
			streamStatusListener.map(function (l) { l("FlowGL.User.Resume"); });

			playFn(true);
		}
	}

	private function onStreamPause() : Void {
		if (nativeWidget != null && nativeWidget.paused) {
			streamStatusListener.map(function (l) { l("FlowGL.User.Pause"); });

			playFn(false);
		}
	}

	private function onFullScreen() : Void {
		if (nativeWidget != null) {
			RenderSupportJSPixi.fullScreenTrigger();

			if (RenderSupportJSPixi.IsFullScreen) {
				Browser.document.body.appendChild(nativeWidget);
			} else {
				Browser.document.body.removeChild(nativeWidget);
			}

		}
	}


	public function addStreamStatusListener(fn : String -> Void) : Void -> Void {
		streamStatusListener.push(fn);
		return function () { streamStatusListener.remove(fn); };
	}

	private function createStreamStatusListeners() {
		if (nativeWidget != null) {
			nativeWidget.addEventListener('loadedmetadata', onMetadataLoaded, false);
			nativeWidget.addEventListener("loadeddata", onStreamLoaded, false);
			nativeWidget.addEventListener("ended", onStreamEnded, false);
			nativeWidget.addEventListener("error", onStreamError, false);
			nativeWidget.addEventListener("play", onStreamPlay, false);
			nativeWidget.addEventListener("pause", onStreamPause, false);
		}
	}

	private function destroyStreamStatusListeners() {
		if (nativeWidget != null) {
			nativeWidget.removeEventListener('loadedmetadata', onMetadataLoaded);
			nativeWidget.removeEventListener("loadeddata", onStreamLoaded);
			nativeWidget.removeEventListener("ended", onStreamEnded);
			nativeWidget.removeEventListener("error", onStreamError);
			nativeWidget.removeEventListener("play", onStreamPlay);
			nativeWidget.removeEventListener("pause", onStreamPause);
		}
	}

	private function createFullScreenListeners() {
		if (nativeWidget != null) {
			if (Platform.isIOS) {
				nativeWidget.addEventListener('webkitbeginfullscreen', onFullScreen, false);
				nativeWidget.addEventListener('webkitendfullscreen', onFullScreen, false);
			}

			nativeWidget.addEventListener('fullscreenchange', onFullScreen, false);
			nativeWidget.addEventListener('webkitfullscreenchange', onFullScreen, false);
			nativeWidget.addEventListener('mozfullscreenchange', onFullScreen, false);
		}
	}

	private function destroyFullScreenListeners() {
		if (nativeWidget != null) {
			if (Platform.isIOS) {
				nativeWidget.removeEventListener('webkitbeginfullscreen', onFullScreen);
				nativeWidget.removeEventListener('webkitendfullscreen', onFullScreen);
			}

			nativeWidget.removeEventListener('fullscreenchange', onFullScreen);
			nativeWidget.removeEventListener('webkitfullscreenchange', onFullScreen);
			nativeWidget.removeEventListener('mozfullscreenchange', onFullScreen);
		}
	}
}

private class WebClip extends NativeWidgetClip {
	private var iframe : Dynamic = null;
	private var disableOverlay : Dynamic = null;
	private var htmlPageWidth : Dynamic = null;
	private var htmlPageHeight : Dynamic = null;
	private var shrinkToFit : Dynamic = null;

	private static function isUrl(str) : Bool {
		return ~/^(\S+[.?][^\/\s]+(\/\S+|\/|))$/g.match(str);
	}

	private function appendReloadBlock() : Void {
		var div = Browser.document.createElement("div");
		div.style.cssText= "z-index: 101; position: absolute; top: 0; left: 0; width: 100%; height: 20px; opacity: 0.6;";

		var img = Browser.document.createElement("img");
		img.style.cssText = "position: absolute; height: 20px; width: 20px; top: 0; right: 0; background: #BEBEBE;";
		untyped img.src = "images/realhtml_reload.png";
		div.appendChild(img);

		var span = Browser.document.createElement("span");
		span.style.cssText = "position: absolute; right: 25px; top: 0px; color: white; display: none;";
		span.innerHTML = "Reload the page";
		div.appendChild(span);

		img.onmouseover = function(e : Dynamic) {
			div.style.background = "linear-gradient(to bottom right, #36372F, #ACA9A4)";
			span.style.display = "block";
			img.style.background = "none";
		}

		untyped img.onmouseleave = function(e : Dynamic) {
			div.style.background = "none";
			span.style.display = "none";
			img.style.background = "#BEBEBE";
		}

		div.onclick = function(e : Dynamic) {
			iframe.src = iframe.src;
		}

		nativeWidget.appendChild(div);
	}

	public function new(url : String, domain : String, useCache : Bool, reloadBlock : Bool, cb : Array<String> -> String, ondone : String -> Void, shrinkToFit : Bool) {
		super();

		if (domain != "") {
			try { Browser.document.domain = domain; } catch(e : Dynamic) { Errors.report("Can not set RealHTML domain" + e); }
		}

		createNativeWidget("div");

		if (Platform.isIOS) {
			// To restrict size of iframe
			untyped nativeWidget.style.webkitOverflowScrolling = 'touch';
			nativeWidget.style.overflowY = "scroll";
		}

		this.shrinkToFit = shrinkToFit;

		iframe = Browser.document.createElement("iframe");
		iframe.style.visibility = "hidden";

		if (isUrl(url) || Platform.isIE || Platform.isEdge) {
			iframe.src = url;
		} else {
			iframe.srcdoc = url;
		}

		iframe.allowFullscreen = true;
		iframe.frameBorder = "no";
		iframe.callflow = cb; // Store for crossdomain calls

		nativeWidget.appendChild(iframe);

		if (reloadBlock) appendReloadBlock();

		iframe.onload = function() {
			try {
				if (shrinkToFit) {
					try {
						this.htmlPageWidth = iframe.contentWindow.document.body.scrollWidth;
						this.htmlPageHeight = iframe.contentWindow.document.body.scrollHeight;
						applyShrinkToFit();
					} catch(e : Dynamic) {
						// if we can't get the size of the html page, we can't do shrink so disable it
						this.shrinkToFit = false;
						Errors.report(e);
						applyNativeWidgetSize();
					}
				}

				ondone("OK");
				if (Platform.isIOS && (url.indexOf("flowjs") >= 0 || url.indexOf("lslti_provider") >= 0)) iframe.scrolling = "no";
				iframe.contentWindow.callflow = cb;
				if (iframe.contentWindow.pushCallflowBuffer) iframe.contentWindow.pushCallflowBuffer();
				if (Platform.isIOS && iframe.contentWindow.setSplashScreen != null) iframe.scrolling = "no"; // Obviousely it is flow page.
			} catch(e : Dynamic) { Errors.report(e); }
		};
	}

	private function applyShrinkToFit() {
		if (getClipVisible() && nativeWidget != null && iframe != null && shrinkToFit && htmlPageHeight != null && htmlPageWidth != null) {
			var scaleH = nativeWidget.clientHeight / this.htmlPageHeight;
			var scaleW = nativeWidget.clientWidth / this.htmlPageWidth;
			var scaleWH = Math.min(1.0, Math.min(scaleH, scaleW));

			iframe.border = "0";
			iframe.style.position = "relative";
			untyped iframe.style["-ms-zoom"] = scaleWH;
			untyped iframe.style["-moz-transform"] = "scale(" + scaleWH + ")";
			untyped iframe.style["-moz-transform-origin"] = "0 0";
			untyped iframe.style["-o-transform"] = "scale(" + scaleWH + ")";
			untyped iframe.style["-o-transform-origin"] = "0 0";
			untyped iframe.style["-webkit-transform"] = "scale(" + scaleWH + ")";
			untyped iframe.style["-webkit-transform-origin"] = "0 0";
			untyped iframe.style["transform"] = "scale(" + scaleWH + ")";
			untyped iframe.style["transform-origin"] = "0 0";

			iframe.width = iframe.clientWidth = htmlPageWidth;
			iframe.height = iframe.clientHeight = htmlPageHeight;
			iframe.style.width = htmlPageWidth;
			iframe.style.height = htmlPageHeight;
			iframe.style.visibility = "visible";
		}
	}

	private function applyNativeWidgetSize() {
		if (getClipVisible() && nativeWidget != null && iframe != null) {
			// Explicitly set w/h (for iOS at least it does not work with "100%")
			iframe.style.width = nativeWidget.style.width;
			iframe.style.height = nativeWidget.style.height;
			iframe.style.visibility = "visible";
		}
	}

	public override function updateNativeWidget() {
		if (getClipVisible()) {
			var transform = nativeWidget.parentNode.style.transform != "" && nativeWidget.parentNode.clip != null ?
				worldTransform.clone().append(nativeWidget.parentNode.clip.worldTransform.clone().invert()) : worldTransform;

			var tx = getClipWorldVisible() ? transform.tx : RenderSupportJSPixi.PixiRenderer.width;
			var ty = getClipWorldVisible() ? transform.ty : RenderSupportJSPixi.PixiRenderer.height;

			if (Platform.isIE) {
				nativeWidget.style.transform = "matrix(" + 1 + "," + transform.b + "," + transform.c + "," + 1 + ","
					+ 0 + "," + 0 + ")";

				nativeWidget.style.left = untyped "" + tx + "px";
				nativeWidget.style.top = untyped "" + ty + "px";
			} else {
				nativeWidget.style.transform = "matrix(" + 1 + "," + transform.b + "," + transform.c + "," + 1 + ","
					+ tx + "," + ty + ")";
			}

			nativeWidget.style.width = untyped "" + getWidth() * transform.a + "px";
			nativeWidget.style.height = untyped "" + getHeight() * transform.d + "px";

			nativeWidget.style.opacity = worldAlpha;
			nativeWidget.style.display = "block";
		} else {
			nativeWidget.style.display = "none";
		}

		if (nativeWidget.getAttribute("tabindex") != null) {
			iframe.setAttribute("tabindex", nativeWidget.getAttribute("tabindex")); // Needed to the correct tab order of iframe elements
			nativeWidget.removeAttribute("tabindex"); // FF set focus to div if it has tabindex
		}

		if (getClipVisible()) {
			if (this.shrinkToFit) {
				applyShrinkToFit();
			} else {
				applyNativeWidgetSize();
			}

			if (disableOverlay && disableOverlay.style.display == "block") {
				disableOverlay.style.width = nativeWidget.style.width;
				disableOverlay.style.height = nativeWidget.style.height;
			}
		}
	}

	public function getDescription() : String {
		return 'WebClip (url = ${iframe.src})';
	}

	private override function getWidth() : Float { return 100.0; }
	private override function getHeight() : Float { return 100.0; }

	public function hostCall(name : String, args : Array<String>) : String {
		try {
			return untyped iframe.contentWindow[name].apply(iframe.contentWindow, args);
		} catch (e : Dynamic) {
			Errors.report("Error in hostCall: " + name + ", arg: " + Std.string(args));
			Errors.report(e);
		}
		return "";
	}

	public function setDisableOverlay(disable : Bool) : Void {
		if (disableOverlay && !disable) {
			nativeWidget.removeChild(disableOverlay);
		} else if (disable) {
			if (!disableOverlay) {
				disableOverlay = Browser.document.createElement("div");
				disableOverlay.style.cssText= "z-index: 100; background-color: rgba(0, 0, 0, 0.15);";
			}

			disableOverlay.style.display = "block";
			nativeWidget.appendChild(disableOverlay);
		}
	}

	public function setSandBox(value : String) : Void {
		iframe.sandbox = value;
	}

	public function evalJS(code : String) : Void {
		if (iframe.contentWindow != null) {
			iframe.contentWindow.postMessage(code, '*');
		}
	}

}

// NOTE :
// Assumed order of calls
// If setInput present it is the first
// setInput, setMultiline setWordWrap, setPasswordMode are called only once
// setWidth, setHeight, setPasswordMode is called only for inputs
private class TextField extends NativeWidgetClip {
	public static var cacheTextsAsBitmap : Bool = false; // Use cacheAsBitmap for all text clips

	private var text : String = "";
	private var fontFamily : String = "";
	private var fontSize : Float = 0.0;
	private var fontWeight : Int = 0;
	private var fontSlope : String = "";
	private var fillColor : Int = 0;
	private var fillOpacity : Float = 0.0;
	private var letterSpacing : Float = 0.0;
	private var backgroundColor : Int = 0;
	private var backgroundOpacity : Float = 0.0;
	private var cursorColor : Int = -1;
	private var cursorOpacity : Float = -1.0;
	private var cursorWidth : Float = 2;
	private var fontStyle : FontStyle = {weight : "", style : "", size : 0.0, family : ""};
	private var textDirection : String = "ltr";
	private var style : Dynamic = {};

	private var type : String = "text";
	private var wordWrap : Bool = false;
	private var fieldWidth : Float = -1.0;
	private var fieldHeight : Float = -1.0;
	private var cropWords : Bool = false;
	private var interlineSpacing : Float = 0.0;
	private var autoAlign : String = "AutoAlignNone";
	private var readOnly : Bool = false;
	private var maxChars : Int = -1;

	private var cursorPosition : Int = -1;
	private var selectionStart : Int = -1;
	private var selectionEnd : Int = -1;

	private var background : FlowGraphics = null;

	private var shouldPreventFromFocus : Bool = false;
	public var shouldPreventFromBlur : Bool = false;
	private var metrics : Dynamic;
	private var multiline : Bool = false;

	private var clipWidth : Float = 0.0;
	private var clipHeight : Float = 0.0;

	private var TextInputFilters : Array<String -> String> = new Array();
	private var TextInputKeyDownFilters : Array<String -> Bool -> Bool -> Bool -> Bool -> Int -> Bool> = new Array();
	private var TextInputKeyUpFilters : Array<String -> Bool -> Bool -> Bool -> Bool -> Int -> Bool> = new Array();

	public var accessWidget : Dynamic = null;
	private var preFocus : Bool = false;

	private function preOnFocus() { // Workaround for IE inputs readonly attribute
		if (isInput()) {
			this.preFocus = true;
			updateNativeWidgetStyle();
			haxe.Timer.delay(function() {
				this.preFocus = false;
				updateNativeWidgetStyle();
			}, 10);
		}
	}

	private override function createNativeWidget(nodeName : String) : Void {
		super.createNativeWidget(nodeName);
		if (Platform.isIE || Platform.isEdge)
			RenderSupportJSPixi.PixiStage.on("preonfocus", preOnFocus);
	}

	private override function deleteNativeWidget() : Void {
		if (Platform.isIE || Platform.isEdge)
			RenderSupportJSPixi.PixiStage.off("preonfocus", preOnFocus);
		if (!shouldPreventFromBlur && Browser.document.activeElement == nativeWidget)
			nativeWidget.blur();
		super.deleteNativeWidget();
	}

	public override function updateNativeWidget() {
		if (getClipVisible()) {
			var transform = !Platform.isIE && nativeWidget.parentNode.style.transform != "" && nativeWidget.parentNode.clip != null ?
				worldTransform.clone().append(nativeWidget.parentNode.clip.worldTransform.clone().invert()) : worldTransform;

			var tx = getClipWorldVisible() ? transform.tx : RenderSupportJSPixi.PixiRenderer.width;
			var ty = getClipWorldVisible() ? transform.ty : RenderSupportJSPixi.PixiRenderer.height;

			if (Platform.isIE) {
				nativeWidget.style.transform = "matrix(" + transform.a + "," + transform.b + "," + transform.c + "," + transform.d + ","
					+ 0 + "," + 0 + ")";

				nativeWidget.style.left = untyped "" + tx + "px";
				nativeWidget.style.top = untyped "" + ty + "px";
			} else {
				nativeWidget.style.transform = "matrix(" + transform.a + "," + transform.b + "," + transform.c + "," + transform.d + ","
					+ tx + "," + ty + ")";
			}

			nativeWidget.style.width = untyped "" + getWidth() + "px";
			nativeWidget.style.height = untyped "" + getHeight() + "px";

			if (isInput() && (!shouldPreventFromFocus || !Platform.isEdge)) {
				nativeWidget.style.opacity = preFocus && multiline && Platform.isEdge ? 1 : isNativeWidgetShown() ? fillOpacity * worldAlpha : 0;
				nativeWidget.style.display = "block";
			} else {
				nativeWidget.style.display = "none";
			}
		} else {
			nativeWidget.style.display = "none";
		}
	}

	public function setTextAndStyle(
		text : String, fontFamily : String, fontSize : Float, fontWeight: Int, fontSlope: String, fillColor : Int, fillOpacity : Float, letterSpacing : Float,
		backgroundColor : Int, backgroundOpacity : Float
	) : Void {
		this.text = StringTools.endsWith(text, "\n") ? text.substring(0, text.length - 1) : text;
		this.fontFamily = fontFamily;
		this.fontSize = fontSize;
		this.fontWeight = fontWeight;
		this.fontSlope = fontSlope;
		this.fillColor = fillColor;
		this.fillOpacity = fillOpacity;
		this.letterSpacing = letterSpacing;
		this.backgroundColor = backgroundColor;
		this.backgroundOpacity = backgroundOpacity;
		this.fontStyle = FlowFontStyle.fromFlowFont(fontFamily);

		updateNativeWidgetStyle();
	}

	private function updateNativeWidgetStyle() {
		if (isInput()) {
			setScrollRect(0, 0, 0, 0);
			nativeWidget.type = type;
			if (accessWidget != null && accessWidget.autocomplete != null && accessWidget.autocomplete != "")
				nativeWidget.autocomplete = accessWidget.autocomplete
			else if (type == "password" && nativeWidget.autocomplete == "")
				nativeWidget.autocomplete = "new-password";
			nativeWidget.value = text;
			nativeWidget.style.color = RenderSupportJSPixi.makeCSSColor(fillColor, fillOpacity);
			nativeWidget.style.letterSpacing = (RenderSupportJSPixi.UseDFont ? letterSpacing + 0.022 : letterSpacing) + "px";
			nativeWidget.style.fontFamily = fontStyle.family;
			nativeWidget.style.fontWeight = fontWeight != 400 ? fontWeight : fontStyle.weight;
			nativeWidget.style.fontStyle = fontSlope != "" ? fontSlope : fontStyle.style;
			nativeWidget.style.fontSize = fontSize + "px";
			nativeWidget.style.lineHeight = (fontSize * 1.2 + interlineSpacing) + "px";
			nativeWidget.style.backgroundColor = RenderSupportJSPixi.makeCSSColor(backgroundColor, backgroundOpacity);
			nativeWidget.style.cursor = "text";
			nativeWidget.style.opacity = preFocus && multiline && Platform.isEdge ? 1 : fillOpacity * worldAlpha;
			if (cursorColor >= 0) {
				nativeWidget.style.caretColor = RenderSupportJSPixi.makeCSSColor(cursorColor, cursorOpacity);
			}
			nativeWidget.readOnly = readOnly;
			if (maxChars >= 0) nativeWidget.maxLength = maxChars;
			if (tabIndex >= 0) nativeWidget.tabIndex = tabIndex;
			nativeWidget.style.pointerEvents = readOnly ? "none" : "auto";
			if (multiline) {
				nativeWidget.style.resize = "none";
				nativeWidget.wrap = wordWrap ? "soft" : "off";
			}
			nativeWidget.style.direction = switch (textDirection) {
				case "RTL" : "rtl";
				case "rtl" : "rtl";
				default : "ltr";
			}
			nativeWidget.style.textAlign = switch (autoAlign) {
				case "AutoAlignLeft" : "left";
				case "AutoAlignRight" : "right";
				case "AutoAlignCenter" : "center";
				case "AutoAlignNone" : "none";
				default : "left";
			}
		}
		if (!isNativeWidgetShown()) {
			if (isInput()) {
				nativeWidget.style.cursor = "inherit";
				nativeWidget.style.opacity = preFocus && multiline && Platform.isEdge ? 1 : 0;
				nativeWidget.readOnly = readOnly || !preFocus;
			}

			layoutText();
		}
	}

	private function layoutText() : Void {
		removeScrollRect();
		var i = children.length;
		while (i >= 0) {
			removeChild(children[i]);
			i--;
		}

		var lines = (isInput() && type == "password" ? getBulletsString(text.length) : text).split("\n");

		clipWidth = 0.0;
		clipHeight = 0.0;

		for (line in lines) {
			var line_width = 0.0;

			if (fieldWidth > 0.0 && wordWrap) {
				var words = line.split(" ");
				var x = 0.0;

				for (wordId in 0...words.length) {
					var word = wordId == words.length - 1 ? words[wordId] : words[wordId] + " ";

					var clip : Dynamic = makeTextClip(word, style);
					var textDimensions = getTextClipMetrics(clip);

					while (word.length > 0) {
						if (cropWords) {
							var currentLength = word.length;
							clip = makeTextClip(word, style);
							textDimensions = getTextClipMetrics(clip);

							while (textDimensions.width > fieldWidth) {
								--currentLength;
								clip = makeTextClip(word.substr(0, currentLength), style);
								textDimensions = getTextClipMetrics(clip);
							}

							word = word.substr(currentLength, word.length - currentLength);
							if (word == " ") word = "";
						} else {
							word = "";
						}

						if (x > 0.0 && (x + textDimensions.width > fieldWidth)) {
							x = 0.0;
							clipHeight += textDimensions.line_height * textDimensions.line_count + interlineSpacing;
						}

						clip.x += x;
						clip.y += clipHeight;
						addChild(clip);

						x += textDimensions.width;
						line_width = Math.max(line_width, x);
					}

					if (wordId == words.length - 1) {
						clipHeight += textDimensions.line_height * textDimensions.line_count + interlineSpacing;
					}
				}

				clipWidth = Math.max(clipWidth, line_width);
			} else {
				var clip : Dynamic = makeTextClip(line, style);
				var textDimensions = getTextClipMetrics(clip);

				var PART_SIZE = 2048;

				if (textDimensions.width > PART_SIZE) {
					var partLength = Math.floor(PART_SIZE * line.length / textDimensions.width);
					var partsAmount = Math.ceil(line.length / partLength);

					clipWidth = 0;

					for (partIndex in 0...partsAmount) {
						var partClip : Dynamic = makeTextClip(line.substr(partIndex * partLength, partLength), style);
						var partTextDimensions = getTextClipMetrics(partClip);

						partClip.x += clipWidth;
						partClip.y += clipHeight;
						addChild(partClip);

						clipWidth += partTextDimensions.width;

					}
				} else {
					clip.y += clipHeight;
					addChild(clip);
				}
				clipHeight += textDimensions.line_height * textDimensions.line_count + interlineSpacing;
				clipWidth = Math.max(clipWidth, textDimensions.width);
			}
		}

		if ((autoAlign == "AutoAlignRight" || autoAlign == "AutoAlignCenter") && fieldWidth > 0) {
			var textDimensions = 0;
			var newChildren = [];

			for (child in children) {
				if (child.x > 0) {
					textDimensions += getTextClipMetrics(child).width;
					newChildren.push(child);
				} else {
					if (newChildren.length > 0 && textDimensions < fieldWidth) {
						var widthDelta = fieldWidth - textDimensions;

						if (autoAlign == "AutoAlignCenter") {
							widthDelta = widthDelta / 2;
						}

						for (newChild in newChildren) {
							newChild.x = newChild.x + widthDelta;
						}
					}

					textDimensions = getTextClipMetrics(child).width;
					newChildren = [child];
				}
			}

			if (newChildren.length > 0 && textDimensions < fieldWidth) {
				var widthDelta = fieldWidth - textDimensions;

				if (autoAlign == "AutoAlignCenter") {
					widthDelta = widthDelta / 2;
				}

				for (newChild in newChildren) {
					newChild.x = newChild.x + widthDelta;
				}
			}

			clipWidth = Math.max(clipWidth, fieldWidth);
		}

		setTextBackground();
		setScrollRect(0, 0, getWidth(), getHeight());
	}

	private function makeTextClip(text : String, style : Dynamic) : Dynamic {
		return {};
	}

	private function getTextClipMetrics(clip : Dynamic) : Dynamic {
		return {};
	}

	private function setTextBackground() : Void {
		if (background != null) removeChild(background);

		if (backgroundOpacity > 0.0) {
			var text_bounds = getLocalBounds();
			background = new FlowGraphics();
			background.beginFill(backgroundColor, backgroundOpacity);
			background.drawRect(0.0, 0.0, text_bounds.width, text_bounds.height);

			addChildAt(background, 0);
		} else {
			background = null;
		}
	}

	public function setTextInputType(type : String) : Void {
		this.type = type;
		updateNativeWidgetStyle();
	}

	public function setWordWrap(wordWrap : Bool) : Void {
		this.wordWrap = wordWrap;
		updateNativeWidgetStyle();
	}

	public function setWidth(fieldWidth : Float) : Void {
		this.fieldWidth = fieldWidth;
		updateNativeWidgetStyle();
	}

	public function setHeight(fieldHeight : Float) : Void {
		this.fieldHeight = fieldHeight;
		updateNativeWidgetStyle();
	}

	public function setCropWords(cropWords : Bool) : Void {
		this.cropWords = cropWords;
		updateNativeWidgetStyle();
	}

	public function setCursorColor(color : Int, opacity : Float) : Void {
		this.cursorColor = color;
		this.cursorOpacity = opacity;
		updateNativeWidgetStyle();
	}

	public function setCursorWidth(width : Float) : Void {
		this.cursorWidth = width;
		updateNativeWidgetStyle();
	}

	public function setInterlineSpacing(interlineSpacing : Float) : Void {
		this.interlineSpacing = interlineSpacing;
		updateNativeWidgetStyle();
	}

	public function setTextDirection(direction : String) : Void {
		this.textDirection = direction;
		updateNativeWidgetStyle();
	}

	public function setAutoAlign(autoAlign : String) : Void {
		this.autoAlign = autoAlign;
		updateNativeWidgetStyle();
	}

	public function setTabIndex(tabIndex : Int) : Void {
		this.tabIndex = tabIndex;
		updateNativeWidgetStyle();
	}

	public function setReadOnly(readOnly : Bool) {
		this.readOnly = readOnly;
		updateNativeWidgetStyle();
	}

	public function setMaxChars(maxChars : Int) {
		this.maxChars = maxChars;
		updateNativeWidgetStyle();
	}

	public function setTextInput() {
		if (multiline) setWordWrap(true);
		createNativeWidget(multiline ? "textarea" : "input");
		shouldPreventFromFocus = false;

		nativeWidget.onmousemove = onMouseMove;
		nativeWidget.onmousedown = onMouseDown;
		nativeWidget.onmouseup = onMouseUp;

		if (NativeHx.isTouchScreen()) {
			nativeWidget.ontouchstart = onMouseDown;
			nativeWidget.ontouchend = onMouseUp;
		}

		nativeWidget.onfocus = onFocus;
		nativeWidget.onblur = onBlur;

		if (accessWidget != null) {
			accessWidget = nativeWidget;
		}

		nativeWidget.addEventListener("input", onInput);
		nativeWidget.addEventListener("scroll", onScroll);
		nativeWidget.addEventListener("keydown", onKeyDown);
		nativeWidget.addEventListener("keyup", onKeyUp);
		updateNativeWidgetStyle();
	}

	private function checkPositionSelection() : Void {
		var hasChanges = false;

		var cursorPosition = getCursorPosition();
		var selectionStart = getSelectionStart();
		var selectionEnd = getSelectionEnd();

		if (this.cursorPosition != cursorPosition) {
			this.cursorPosition = cursorPosition;
			hasChanges = true;
		}

		if (this.selectionStart != selectionStart) {
			this.selectionStart = selectionStart;
			hasChanges = true;
		}

		if (this.selectionEnd != selectionEnd) {
			this.selectionEnd = selectionEnd;
			hasChanges = true;
		}

		if (hasChanges) {
			emit("input");
		}
	}

	private function onMouseMove(e : js.html.MouseEvent) {
		// if (isNativeWidgetShown()) {
		// 	checkPositionSelection();
		// }

		nativeWidget.style.cursor = RenderSupportJSPixi.PixiRenderer.view.style.cursor;
		RenderSupportJSPixi.provideEvent(e);
	}

	private function onMouseDown(e : Dynamic) {
		if (isNativeWidgetShown()) {
			checkPositionSelection();
			return;
		}

		var point = e.touches != null && e.touches.length > 0 ? new Point(e.touches[0].pageX, e.touches[0].pageY) : new Point(e.pageX, e.pageY);
		nativeWidget.readOnly = shouldPreventFromFocus = RenderSupportJSPixi.getClipAt(point) != this;

		if (shouldPreventFromFocus) {
			e.preventDefault();
			RenderSupportJSPixi.provideEvent(e);
		}

		if ((Platform.isIE || Platform.isEdge) && !shouldPreventFromFocus) {
			// IE & Edge cannot handle onfocus completely
			// when we focus from another input
			preOnFocus();
			nativeWidget.focus();
		}
	}

	private function onMouseUp(e : js.html.MouseEvent) {
		if (isNativeWidgetShown()) {
			checkPositionSelection();
		}

		nativeWidget.readOnly = nativeWidget.readOnly && nativeWidget.autocomplete == "";

		RenderSupportJSPixi.provideEvent(e);
		shouldPreventFromFocus = false;
	}

	// focused - bring the widget to front
	private function onFocus(e : js.html.Event) : Void {
		if (isInput()) {
			if (shouldPreventFromFocus) {
				e.preventDefault();
				nativeWidget.blur();
				return;
			}

			emit("focus");
			if (parent != null) {
				parent.emitEvent("childfocused", this);
			}
			updateNativeWidgetStyle();
		}
	}

	// blured - hide the HTML widget
	private function onBlur(e : js.html.Event) : Void {
		if (isInput()) {
			if (shouldPreventFromBlur) {
				shouldPreventFromBlur = false;
				e.preventDefault();
				nativeWidget.focus();
				return;
			}

			if (Platform.isIE || Platform.isEdge || Browser.document.activeElement == nativeWidget) {
				nativeWidget.blur();

				if (Platform.isEdge) { // Workaround for blinking caret on inactive inputs
					shouldPreventFromFocus = true;
					updateNativeWidget();

					haxe.Timer.delay(function() {
						shouldPreventFromFocus = false;
						updateNativeWidget();
					}, 100);
				}
			}

			emit("blur");
			updateNativeWidgetStyle();
		}
	}

	private function onInput(e : Dynamic) {
		var newValue : String = nativeWidget.value;

		if (maxChars > 0) {
			newValue = newValue.substr(0, maxChars);
		}

		for (f in TextInputFilters) {
			newValue = f(newValue);
		}

		if (newValue != nativeWidget.value) {
			if (e != null && e.data != null && e.data.length != null) {
				var newCursorPosition : Int = untyped cursorPosition + newValue.length - nativeWidget.value.length + e.data.length;

				nativeWidget.value = newValue;
				setSelection(newCursorPosition, newCursorPosition);
			} else {
				nativeWidget.value = newValue;
			}
		} else {
			var selectionStart = getSelectionStart();
			var selectionEnd = getSelectionEnd();

			setSelection(selectionStart, selectionEnd);
		}

		this.text = newValue;
		emit("input", newValue);
	}

	private function onScroll(e : Dynamic) {
		emit("scroll", e);
	}

	public function setMultiline(multiline : Bool) : Void {
		if (this.multiline != multiline) {
			this.multiline = multiline;
			setTextInput();
		}
	}

	private function onKeyDown(e : Dynamic) {
		if (TextInputKeyDownFilters.length > 0) {
			var ke : Dynamic = RenderSupportJSPixi.parseKeyEvent(e);

			for (f in TextInputKeyDownFilters) {
				if (!f(ke.key, ke.ctrl, ke.shift, ke.alt, ke.meta, ke.keyCode)) {
					ke.preventDefault();
					RenderSupportJSPixi.PixiStage.emit("keydown", ke);
					break;
				}
			}
		}

		if (isNativeWidgetShown()) {
			checkPositionSelection();
		}
	}

	private function onKeyUp(e : Dynamic) {
		var ke : Dynamic = RenderSupportJSPixi.parseKeyEvent(e);
		if (TextInputKeyUpFilters.length > 0) {

			for (f in TextInputKeyUpFilters) {
				if (!f(ke.key, ke.ctrl, ke.shift, ke.alt, ke.meta, ke.keyCode)) {
					ke.preventDefault();
					RenderSupportJSPixi.PixiStage.emit("keyup", ke);
					break;
				}
			}
		}

		if (ke.keyCode == 13 && Platform.isMobile && !this.multiline) // Hide mobile keyboard on enter key press
			nativeWidget.blur();

		if (isNativeWidgetShown()) {
			checkPositionSelection();
		}
	}

	public function getDescription() : String {
		if (isInput()) {
			return 'TextField (text = "${nativeWidget.value}")';
		} else {
			return 'TextField (text = "${text}")';
		}
	}

	public function isInput() : Bool {
		return nativeWidget != null;
	}

	public override function setFocus(focus : Bool) : Void {
		shouldPreventFromFocus = false;

		if (nativeWidget != null && nativeWidget.parentNode != null) {
			// Workaround for IE not updating readonly after textfield is focused
			if (focus) {
				if (Platform.isIE || Platform.isEdge) {
					preOnFocus();
				}
				nativeWidget.focus();
			} else {
				nativeWidget.blur();
			}
		}
	}

	private function isNativeWidgetShown() {
		return isInput() && (Browser.document.activeElement == nativeWidget || (!readOnly && nativeWidget.autocomplete != ""));
	}

	public override function getWidth() : Float {
		return getBounds(true).width;
	}

	public override function getHeight() : Float {
		return getBounds(true).height;
	}

	public function getContent() : String {
		return text;
	}

	public function getCursorPosition() : Int {
		try {
			// Chrome doesn't support this method for "number" inputs
			if (nativeWidget.selectionStart != null) {
				return nativeWidget.selectionStart;
			}
		} catch (e : Dynamic) {}
		if (untyped Browser.document.selection != null) {
			nativeWidget.focus();
			var r : Dynamic = untyped Browser.document.selection.createRange();
			if (r == null) return 0;

			var re = nativeWidget.createTextRange();
			var rc = re.duplicate();
			re.moveToBookmark(r.getBookmark());
			untyped rc.setEndPoint('EndToStart', re);
			return rc.text.length;
		}
		return 0;
	}

	public function getSelectionStart() : Int {
		try {
			// Chrome doesn't support this method for "number" inputs
			if (nativeWidget.selectionStart == null) {
				return nativeWidget.value.length;
			} else {
				return nativeWidget.selectionStart;
			}
		} catch(e : Dynamic) {
			return 0;
		}
	}

	public function getSelectionEnd() : Int {
		try {
			// Chrome doesn't support this method for "number" inputs
			if (nativeWidget.selectionEnd == null) {
				return nativeWidget.value.length;
			} else {
				return nativeWidget.selectionEnd;
			}
		} catch(e : Dynamic) {
			return 0;
		}
	}

	public function setSelection(start : Int, end : Int) : Void {
		// Chrome doesn't support this method for "number" inputs
		try {
			nativeWidget.setSelectionRange(start, end);
		} catch(e : Dynamic) {}
	}

	public function addTextInputFilter(filter : String -> String) : Void -> Void {
		TextInputFilters.push(filter);
		return function() { TextInputFilters.remove(filter); }
	}

	public function addTextInputKeyDownEventFilter(filter : String -> Bool -> Bool -> Bool -> Bool -> Int -> Bool) : Void -> Void {
		TextInputKeyDownFilters.push(filter);
		return function() { TextInputKeyDownFilters.remove(filter); }
	}

	public function addTextInputKeyUpEventFilter(filter : String -> Bool -> Bool -> Bool -> Bool -> Int -> Bool) : Void -> Void {
		TextInputKeyUpFilters.push(filter);
		return function() { TextInputKeyUpFilters.remove(filter); }
	}

	public function getTextMetrics() : Array<Float> {
		var ascent = 0.9 * fontSize;
		var descent = 0.1 * fontSize;
		var leading = 0.15 * fontSize;
		return [ascent, descent, leading];
	}

	private static function getBulletsString(l : Int) : String {
		var bullet = String.fromCharCode(8226);
		var i = 0; var ret = "";
		for (i in 0...l) ret += bullet;
		return ret;
	}

	#if (pixijs < "4.7.0")
		public override function getLocalBounds() : Rectangle {
			if (isInput() && fieldHeight > 0.0 && fieldWidth > 0.0)
				return new Rectangle(0.0, 0.0, fieldWidth, fieldHeight);
			else
				return super.getLocalBounds();
		}
	#else
		public override function getLocalBounds(?rect:Rectangle) : Rectangle {
			if (isInput() && fieldHeight > 0.0 && fieldWidth > 0.0) {
				if (rect != null) {
					rect = new Rectangle(0.0, 0.0, fieldWidth, fieldHeight);
					return rect;
				} else {
					return new Rectangle(0.0, 0.0, fieldWidth, fieldHeight);
				}
			}
			else
				return super.getLocalBounds(rect);
		}
	#end

	public override function getBounds(?skipUpdate: Bool, ?rect: Rectangle) : Rectangle {
		if (rect == null && isInput() && fieldHeight > 0.0 && fieldWidth > 0.0) {
			var lt = toGlobal(new Point(0.0, 0.0));
			var rb = toGlobal(new Point(fieldWidth, fieldHeight));
			return new Rectangle(lt.x, lt.y, rb.x - lt.x, rb.y - lt.y);
		} else {
			return super.getBounds(skipUpdate, rect);
		}
	}

	public function calculateBounds() : Void {
		untyped super.calculateBounds();
		if (isInput() && fieldHeight > 0.0 && fieldWidth > 0.0) {
			untyped this._bounds.addFrame(this.transform, 0.0, 0.0, fieldWidth, fieldHeight);
		}
	}
}

private class PixiText extends TextField {
	private var textClip : Text = null;

	// Signalizes where we have changed any properties
	// influencing text width or height
	private var metricsChanged : Bool = false;

	// Use the property to set up custom antialias factor
	// Implemented by enlarging font size and decreasing scale of text clip
	private var textScaleFactor : Int = Platform.isMacintosh ? 2 : 1;

	public function new() {
		super();

		on("removed", function () {
			if (textClip != null) {
				destroyTextClipChildren();

				if (textClip.canvas != null && Browser.document.body.contains(textClip.canvas)) {
					Browser.document.body.removeChild(textClip.canvas);
				}

				removeChild(textClip);
				textClip.destroy({ children: true, texture: true, baseTexture: true });
				textClip = null;
			}
		});
	}

	private inline function destroyTextClipChildren() {
		var clip = textClip.children.length > 0 ? textClip.children[0] : null;

		while (clip != null) {
			if (untyped clip.canvas != null && Browser.document.body.contains(untyped clip.canvas)) {
				Browser.document.body.removeChild(untyped clip.canvas);
			}

			textClip.removeChild(clip);
			clip.destroy({ children: true, texture: true, baseTexture: true });

			clip = textClip.children.length > 0 ? textClip.children[0] : null;
		}
	}

	private inline function invalidateMetrics() {
		this.metricsChanged = true;
	}

	private function bidiDecorate(text : String) : String {
		var mark : String = "";
		if (textDirection == "ltr") mark = String.fromCharCode(0x202A) else if (textDirection == "rtl") mark = String.fromCharCode(0x202B);
		if (mark != "") return mark + text + String.fromCharCode(0x202C);
		return text;
	}

	public override function setTextAndStyle(
		text : String, fontfamily : String,
		fontsize : Float, fontweight : Int, fontslope : String,
		fillcolor : Int, fillopacity : Float, letterspacing : Float,
		backgroundcolour : Int, backgroundopacity : Float
	) : Void {

		if (this.text != text || this.fontFamily != fontfamily ||
			this.fontSize != fontsize || this.fontWeight != fontweight ||
			this.fontSlope != fontslope || this.letterSpacing != letterspacing) {

			this.invalidateMetrics();
		}

		var from_flow_style : FontStyle = FlowFontStyle.fromFlowFont(fontfamily);
		var fontStyle = fontslope != "" ? fontslope : from_flow_style.style;

		style =
			{
				fontSize : textScaleFactor * (fontsize < 0.6 ? 0.6 : fontsize), // pixi crashes when size < 0.6
				fill : "#" + StringTools.hex(RenderSupportJSPixi.removeAlphaChannel(fillcolor), 6),
				letterSpacing : letterspacing,
				fontFamily : from_flow_style.family,
				fontWeight : fontweight != 400 ? "" + fontweight : from_flow_style.weight,
				fontStyle : fontStyle
			};

		metrics = untyped pixi.core.text.TextMetrics.measureFont(new pixi.core.text.TextStyle(style).toFontString());

		if (interlineSpacing != 0) {
			style.lineHeight = style.fontSize * 1.1 + interlineSpacing;
		}

		super.setTextAndStyle(text, fontfamily, fontsize, fontweight, fontslope, fillcolor, fillopacity, letterspacing, backgroundcolour, backgroundopacity);
	}

	private override function layoutText() : Void {
		if (isInput())
			removeScrollRect();
		var widthDelta = 0.0;

		makeTextClip(text, style);

		textClip.x = -letterSpacing;

		if ((style.align == "center" || style.align == "right") && fieldWidth > 0) {
			if (clipWidth < fieldWidth) {
				widthDelta = fieldWidth - clipWidth;

				if (style.align == "center") {
					widthDelta = widthDelta / 2;
				}

				textClip.x += widthDelta;
			}

			clipWidth = Math.max(clipWidth, fieldWidth);
		}

		setTextBackground();
		if (isInput())
			setScrollRect(0, 0, getWidth() + widthDelta, getHeight());
	}

	private override function onInput(e : Dynamic) {
		super.onInput(e);
		invalidateMetrics();
	}

	public override function getWidth() : Float {
		return fieldWidth > 0.0 && isInput() ? fieldWidth : clipWidth;
	}

	public override function getHeight() : Float {
		return fieldHeight > 0.0 && isInput() ? fieldHeight : clipHeight;
	}

	public override function setCropWords(cropWords : Bool) : Void {
		if (this.cropWords != cropWords)
			this.invalidateMetrics();

		this.cropWords = cropWords;
		style.breakWords = cropWords;
		updateNativeWidgetStyle();
	}

	public override function setWordWrap(wordWrap : Bool) : Void {
		if (this.wordWrap != wordWrap)
			this.invalidateMetrics();

		this.wordWrap = wordWrap;
		style.wordWrap = wordWrap;
		updateNativeWidgetStyle();
	}

	public override function setTextInputType(type : String) : Void {
		super.setTextInputType(type);
		invalidateMetrics();
	}

	public override function setWidth(fieldWidth : Float) : Void {
		if (this.fieldWidth != fieldWidth)
			this.invalidateMetrics();

		this.fieldWidth = fieldWidth;
		style.wordWrapWidth = textScaleFactor * (fieldWidth > 0 ? fieldWidth : 2048);
		updateNativeWidgetStyle();
	}

	public override function setInterlineSpacing(interlineSpacing : Float) : Void {
		if (this.interlineSpacing != interlineSpacing)
			this.invalidateMetrics();

		this.interlineSpacing = interlineSpacing;
		style.lineHeight = style.fontSize * 1.15 + interlineSpacing;
		updateNativeWidgetStyle();
	}

	public override function setTextDirection(direction : String) : Void {
		this.textDirection = direction;
		if (direction == "RTL" || direction == "rtl")
			style.direction = "rtl";
		else
			style.direction = "ltr";
		updateNativeWidgetStyle();
	}

	public override function setAutoAlign(autoAlign : String) : Void {
		this.autoAlign = autoAlign;
		if (autoAlign == "AutoAlignRight")
			style.align = "right";
		else if (autoAlign == "AutoAlignCenter")
			style.align = "center";
		else
			style.align = "left";
		updateNativeWidgetStyle();
	}

	private function updateClipMetrics() {
		var metrics = textClip.children.length > 0 ? textClip.getLocalBounds() : getTextClipMetrics(textClip);

		clipWidth = Math.max(metrics.width - letterSpacing * 2, 0) / textScaleFactor;
		clipHeight = metrics.height / textScaleFactor;

		hitArea = new Rectangle(letterSpacing, 0, clipWidth + letterSpacing, clipHeight);
	}

	private static function checkTextLength(text : String) : Array<Array<String>> {
		var textSplit = text.split('\n');

		if (textSplit.filter(function (t) { return t.length > 1000; }).length > 0) {
			return textSplit.map(function (t) { return t.length > 1000 ? splitString(t) : [t]; });
		} else {
			return [[text]];
		}
	}

	private static function splitString(text : String) : Array<String> {
		return text.length > 1000 ? [text.substr(0, 1000)].concat(splitString(text.substr(1000))) :
			text.length > 0 ? [text] : [];
	}

	private override function makeTextClip(text : String, style : Dynamic) : Dynamic {
		if (isInput() && type == "password")
			text = TextField.getBulletsString(text.length);
		var texts = wordWrap ? [[text]] : checkTextLength(text);

		if (textClip == null) {
			textClip = createTextClip(texts[0][0], style);
		}

		if (metricsChanged) {
			textClip.text = bidiDecorate(texts[0][0]);
			textClip.style = style;

			if (text == "") {
				removeChild(textClip);
			} else {
				addChild(textClip);
			}

			destroyTextClipChildren();

			if (texts.length > 1 || texts[0].length > 1) {
				var currentHeight = 0.0;

				for (line in texts) {
					var currentWidth = 0.0;
					var lineHeight = 0.0;

					for (txt in line) {
						if (txt == texts[0][0]) {
							currentWidth = textClip.getLocalBounds().width;
							lineHeight = textClip.getLocalBounds().height;
						} else {
							var newTextClip = createTextClip(txt, style);

							newTextClip.x = currentWidth;
							newTextClip.y = currentHeight;

							textClip.addChild(newTextClip);

							currentWidth += newTextClip.getLocalBounds().width;
							lineHeight = Math.max(lineHeight, newTextClip.getLocalBounds().height);
						}
					}

					currentHeight += lineHeight;
				}
			}

			updateClipMetrics();
		}

		var anchorX = switch (autoAlign) {
			case "AutoAlignLeft" : 0;
			case "AutoAlignRight" : 1;
			case "AutoAlignCenter" : 0.5;
			default : textDirection == "rtl"? 1 : 0;
		};
		textClip.x = anchorX * (getWidth() - this.clipWidth);

		textClip.alpha = fillOpacity;

		metricsChanged = false;

		if (TextField.cacheTextsAsBitmap) {
			textClip.cacheAsBitmap = true;
		}

		return textClip;
	}

	private function createTextClip(text : String, style : Dynamic) : Text {
		var textClip = new Text(text, style);
		untyped textClip._visible = true;

		textClip.scale.x = 1 / textScaleFactor;
		textClip.scale.y = 1 / textScaleFactor;

		// The default font smoothing on webkit (-webkit-font-smoothing = subpixel-antialiased),
		// makes the text bolder when light text is placed on a dark background.
		// "antialised" produces a lighter text, which is what we want.
		// Moreover, the css style only has any effect when the canvas element
		// is part of the DOM, so we attach the underlying PIXI canvas backend
		// and make it invisible.
		// On Firefox, the equivalent css property (-moz-osx-font-smoothing = grayscale) seems to
		// have no effect on the canvas element.
		if (RenderSupportJSPixi.AntialiasFont && (Platform.isChrome || Platform.isSafari)) {
			untyped textClip.canvas.style.webkitFontSmoothing = "antialiased";
			textClip.canvas.style.display = "none";
			Browser.document.body.appendChild(textClip.canvas);
		}

		return textClip;
	}

	private override function getTextClipMetrics(clip : Dynamic) : Dynamic {
		return pixi.core.text.TextMetrics.measureText(clip.text, clip.style);
	}

	public override function getTextMetrics() : Array<Float> {
		if (metrics == null) {
			return super.getTextMetrics();
		} else {
			return [metrics.ascent / textScaleFactor, metrics.descent / textScaleFactor, metrics.descent / textScaleFactor];
		}
	}
}

private class DFontText extends TextField {
	private static inline var FireFoxMaxTextWidth : Float = 32765.0;

	public override function setTextAndStyle(
		text : String, fontfamily : String,
		fontsize : Float, fontweight : Int, fontslope : String,
		fillcolor : Int, fillopacity : Float, letterspacing : Float,
		backgroundcolour : Int, backgroundopacity : Float
	) {
		if (Platform.isFirefox && text.length * fontsize > FireFoxMaxTextWidth /* raw estimate */) {
			text = text.substr(0, Math.floor(FireFoxMaxTextWidth / fontsize));
		}

		if (getDFontInfo(fontfamily) == null) {
			var defaultFontFamily = getFirstDFontFamily();
			var met = getDFontInfo(defaultFontFamily);
			if (met != null) {
				Errors.print("Trying to render DFont " + fontfamily + " which is not loaded. Will use default font");
				untyped __js__ ("DFontText.dfont_table[fontfamily] = met");
				fontfamily = defaultFontFamily;
			} else {
				Errors.print("Trying to render DFont " + fontfamily + " which is not loaded yet. Default font is not loaded yet too");
				return;
			}
		}

		metrics = getDFontInfo(fontfamily);

		style.font = fontsize + "px " + fontfamily;
		style.tint = fillcolor != 0 ? fillcolor : 0x010101;
		style.letterSpacing = letterspacing;

		super.setTextAndStyle(
			text, fontfamily, fontsize, fontweight, fontslope,
			fillcolor, fillopacity,
			letterspacing, backgroundcolour, backgroundopacity);
	}

	private override function makeTextClip(text : String, style : Dynamic) : Dynamic {
		var clip : Dynamic = new DFontTextNative(text, style);

		clip.resolution = RenderSupportJSPixi.PixiRenderer.resolution; // calculateBounds needs that
		clip.on("resize", function (ratio : Float) {
			clip.resolution = ratio;
		});

		clip.alpha = fillOpacity;

		if (TextField.cacheTextsAsBitmap) {
			clip.cacheAsBitmap = true;
		}

		return clip;
	}

	private override function getTextClipMetrics(clip : Dynamic) : Dynamic {
		return clip.getTextDimensions();
	}

	public override function getTextMetrics() : Array<Float> {
		if (metrics == null) {
			return super.getTextMetrics();
		} else {
			// First value is baseline. See pixi-dfont.js for more details.
			return [(metrics.line_height + metrics.descender) * fontSize, metrics.descender * fontSize, 0.15 * fontSize];
		}
	}

	public override function getWidth() : Float {
		return (fieldWidth > 0.0 && isInput()) ? fieldWidth : clipWidth;
	}

	public override function getHeight() : Float {
		return (fieldHeight > 0.0 && isInput()) ? fieldHeight : clipHeight;
	}

	// Returns the object from DFontText.dfont_table
	public static function getDFontInfo(fontfamily : String) : Dynamic {
		return untyped __js__ ('DFontText.dfont_table[{0}]', fontfamily);
	}

	// Returns the object from DFontText.dfont_table
	public static function getFirstDFontFamily() : String {
		return untyped __js__ ("Object.keys(DFontText.dfont_table)[0]");
	}
}

//
// Shaders sources container
//
private class Shaders {
	public static var GlowFragmentSrc = [
		"precision lowp float;",
		"varying vec2 vTextureCoord;",
		"varying vec4 vColor;",
		'uniform sampler2D uSampler;',

		'void main() {',
			'vec4 sum = vec4(0);',
			'vec2 texcoord = vTextureCoord;',
			'for(int xx = -4; xx <= 4; xx++) {',
				'for(int yy = -3; yy <= 3; yy++) {',
					'float dist = sqrt(float(xx*xx) + float(yy*yy));',
					'float factor = 0.0;',
					'if (dist == 0.0) {',
						'factor = 2.0;',
					'} else {',
						'factor = 2.0/abs(float(dist));',
					'}',
					'sum += texture2D(uSampler, texcoord + vec2(xx, yy) * 0.002) * factor;',
				'}',
			'}',
			'gl_FragColor = sum * 0.025 + texture2D(uSampler, texcoord);',
		'}'
	];

	public static var VertexSrc = [
		"attribute vec2 aVertexPosition;",
		"attribute vec2 aTextureCoord;",
		"attribute vec4 aColor;",
		"uniform mat3 projectionMatrix;",
		"varying vec2 vTextureCoord;",
		"varying vec4 vColor;",
		"void main(void)",
		"{",
			"gl_Position = vec4((projectionMatrix * vec3(aVertexPosition, 1.0)).xy, 0.0, 1.0);",
			"vTextureCoord = aTextureCoord;",
			"vColor = vec4(aColor.rgb * aColor.a, aColor.a);",
		"}"
	];
}

private class DebugClipsTree {
	var TreeDiv : Element = null;
	var DebugWin : js.html.Window = null;
	var ClipBoundsRect : Element = null;

	private function new () {
		DebugWin = Browser.window.open("","clipstree","width=800,height=500");

		var description = DebugWin.document.getElementById("DebugWinDescription");
		if (description == null) {
			description = DebugWin.document.createElement("p");
			description.id = "DebugWinDescription";
			description.innerHTML = "Clips tree for: " + Browser.document.location.href;
			DebugWin.document.body.insertBefore(description, DebugWin.document.body.firstChild);
		}

		var expandall_button = DebugWin.document.getElementById("expandall_button");
		if (expandall_button == null) {
			expandall_button = Browser.document.createElement("button");
			expandall_button.id = "expandall_button";
			expandall_button.innerHTML = "Expand All";
			expandall_button.onclick = function(e : Dynamic) { expandAll(TreeDiv.firstChild); };
			DebugWin.document.body.appendChild(expandall_button);
		}

		var collapseall_button = DebugWin.document.getElementById("collapseall_button");
		if (collapseall_button == null) {
			collapseall_button = Browser.document.createElement("button");
			collapseall_button.id = "collapseall_button";
			collapseall_button.innerHTML = "Collapse All";
			collapseall_button.onclick = function(e : Dynamic) { collapseAll(TreeDiv.firstChild); };
			DebugWin.document.body.appendChild(collapseall_button);
		}

		TreeDiv = DebugWin.document.getElementById("TreeDiv");
		if (TreeDiv == null) {
			TreeDiv = Browser.document.createElement("div");
			TreeDiv.id = "TreeDiv";
			DebugWin.document.body.appendChild(TreeDiv);
		}

		ClipBoundsRect = DebugWin.document.getElementById("ClipBoundsRect");
		if (ClipBoundsRect == null) {
			ClipBoundsRect = Browser.document.createElement("div");
			ClipBoundsRect.id = "ClipBoundsRect";
			ClipBoundsRect.style.position = "fixed";
			ClipBoundsRect.style.backgroundColor = "rgba(255, 0, 0, 0.5)";
			Browser.document.body.appendChild(ClipBoundsRect);
		}

		while (TreeDiv.firstChild != null) {
			TreeDiv.removeChild(TreeDiv.firstChild);
		}

	}

	private static var instance : DebugClipsTree = null;

	public static function getInstance() : DebugClipsTree {
		if (instance == null) instance = new DebugClipsTree();
		return instance;
	}

	private function setClipBoundsRect(bounds : Dynamic) : Void {
		ClipBoundsRect.style.left = bounds.x;
		ClipBoundsRect.style.top = bounds.y;
		ClipBoundsRect.style.width = bounds.width;
		ClipBoundsRect.style.height = bounds.height;
	}

	private function clearTree() : Void {
		TreeDiv.innerHTML = "";
	}

	var UpdateTimer : haxe.Timer = null;
	public function updateTree(stage : FlowContainer) : Void {
		if (UpdateTimer != null) UpdateTimer.stop();
		UpdateTimer = haxe.Timer.delay(function() { doUpdateTree(stage); }, 1000);
	}

	private function doUpdateTree(stage : FlowContainer) : Void {
		clearTree();
		addItem(TreeDiv, stage);
	}

	private function expandNode(node : Dynamic) : Void {
		if (node.list != null) node.list.style.display = "block";
		node.arrow.innerHTML = StringTools.replace(node.arrow.innerHTML, "▶", "▼");
	}

	private function collapseNode(node : Dynamic) : Void {
		if (node.list != null) node.list.style.display = "none";
		node.arrow.innerHTML = StringTools.replace(node.arrow.innerHTML, "▼", "▶");
	}

	private function expandAll(node : Dynamic) : Void {
		expandNode(node);
		if (node.list != null && node.list.children != null) {
			var childs : Array<Dynamic> = node.list.children;
			for (c in childs) expandAll(c);
		}
	}

	private function collapseAll(node : Dynamic) : Void {
		collapseNode(node);
		if (node.list != null && node.list.children != null) {
			var childs : Array<Dynamic> = node.list.children;
			for (c in childs) collapseAll(c);
		}
	}

	private function getClipDescription(clip : Dynamic) : String {
		if (clip.getDescription)
			return clip.getDescription();

		if (clip.graphicsData) {
			return clip.graphicsData.length > 0 ? ("Graphics ( fill = " + clip.graphicsData[0].fill + " fillAlpha = " + clip.graphicsData[0].fillAlpha + ")") : "Graphics";
		}

		if (clip.texture) {
			var baseTexture = clip.texture.baseTexture;
			if (baseTexture.imageUrl)
				return 'Image (${baseTexture.imageUrl})';

			return "Text Sprite";
		}

		return "Clip";
	}

	private function addItem(root : Dynamic, item : Dynamic) : Void {
		var li = Browser.document.createElement("li");
		li.style.color = "rgba(0,0,0,0)"; // Hide item mark
		root.appendChild(li);

		var arrow = Browser.document.createElement("div");
		li.appendChild(arrow);
		//arrow.style.float = "left";
		arrow.style.color = "black";
		arrow.style.fontSize = "10px";
		arrow.style.display = "inline";
		untyped li.arrow = arrow;

		var description = Browser.document.createElement("div");
		description.style.display = "inline";

		description.innerHTML = getClipDescription(item);
		if (cast(item, DisplayObject).getClipVisible()) {
			description.style.color = "#303030";
		} else {
			description.style.color = "#DDDDDD";
			description.innerHTML += " invisible";
		}

		description.style.fontSize = "10px";

		if (item.isMask) description.innerHTML += " mask";

		description.addEventListener("mouseover", function(e : Dynamic) { description.style.backgroundColor = "#DDDDDD"; } );
		description.addEventListener("mouseout", function(e : Dynamic) { description.style.backgroundColor = ""; } );
		description.addEventListener("mousedown", function(e : Dynamic) { setClipBoundsRect(item.getBounds()); });

		li.appendChild(description);
		untyped li.description = description;

		if (item.children != null && item.children.length > 0) {
			arrow.innerHTML = "▶";
			var ul = Browser.document.createElement("ul");
			li.appendChild(ul);
			untyped li.list = ul;

			var childs : Array<Dynamic> = item.children;
			for (c in childs) { addItem(ul, c); }

			arrow.addEventListener("click", function(e : Dynamic) {
				if (ul.style.display == "none" ) {
					expandNode(li);
				} else {
					collapseNode(li);
				}
			} );
			ul.style.display = "none";
		}
	}
}