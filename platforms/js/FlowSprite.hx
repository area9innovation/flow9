import js.Browser;

import pixi.core.display.Bounds;
import pixi.core.math.shapes.Rectangle;
import pixi.core.sprites.Sprite;
import pixi.core.textures.Texture;
import pixi.core.textures.BaseTexture;

import StringTools;
import js.html.Uint8Array;
import js.html.URL;

using DisplayObjectHelper;
using RequestQueue;

class FlowSprite extends Sprite {
	private var scrollRect : FlowGraphics;
	private var _visible : Bool = true;
	private var clipVisible : Bool = false;
	private var transformChanged : Bool = true;

	private var url : String = "";
	private var headers : Array<Array<String>> = [];
	public var loaded : Bool = false;
	public var failed : Bool = false;
	private var visibilityChanged : Bool = true;
	private var widgetBoundsChanged : Bool = false;
	private var updateParent : Bool = false;
	private var cache : Bool = false;
	private var metricsFn : Float -> Float -> Void;
	private var errorFn : String -> Void;
	private var onlyDownload : Bool = false;
	private var altText : String = "";
	private var retries : Int = 0;

	private var localBounds = new Bounds();
	private var widgetBounds = new Bounds();
	private var _bounds = new Bounds();
	public var filterPadding = 0.0;

	public var nativeWidget : Dynamic;
	public var accessWidget : AccessWidget;
	public var tagName : String;
	public var className : String;

	public var isEmpty : Bool = true;
	public var isCanvas : Bool = false;
	public var isSvg : Bool = false;
	public var forceSvg : Bool = false;
	public var isNativeWidget : Bool = false;
	public var keepNativeWidget : Bool = false;
	public var keepNativeWidgetChildren : Bool = false;
	public var useCrossOrigin : Bool = false;
	private var disposed : Bool = false;

	private static inline var MAX_CHACHED_IMAGES : Int = 50;
	private static var cachedImagesUrls : Map<String, Int> = new Map<String, Int>();
	private static var requestQueue = new RequestQueue();

	public function new(url : String, cache : Bool, metricsFn : Float -> Float -> Void, errorFn : String -> Void, onlyDownload : Bool, altText : String, headers : Array<Array<String>>) {
		super();

		visible = false;
		interactiveChildren = false;

		this.url = url;
		this.headers = headers;
		this.cache = cache;
		this.metricsFn = metricsFn;
		this.errorFn = errorFn;
		this.onlyDownload = onlyDownload;
		this.altText = altText;

		if (StringTools.endsWith(url, ".swf")) {
			url = StringTools.replace(url, ".swf", ".png");
		};

		if (this.isHTMLRenderer()) {
			// Chrome can't render svgs with <img> element if file contains "data:img" type instead of "data:image"
			// As workaround we insert svg content directly to innerHTML
			forceSvg = Platform.isChrome && url.indexOf(".svg") > 0;
			this.initNativeWidget("img");
		} else {
			once("removed", onSpriteRemoved);
			once("added", onSpriteAdded);
		}
	}

	private static function clearUrlTextureCache(url : String) : Void {
		cachedImagesUrls.remove(url);
		var texture = Texture.removeFromCache(url);
		var baseTexture = untyped BaseTexture.removeFromCache(url);

		untyped __js__("delete this.baseTexture");
		untyped __js__("delete this.texture");
	}

	private static function pushTextureToCache(texture : Texture) : Void {
		if (texture != null && texture.baseTexture != null && texture.baseTexture.imageUrl != null) {
			var url = texture.baseTexture.imageUrl;

			if (url != null) {
				if (cachedImagesUrls.exists(url)) {
					cachedImagesUrls.set(url, cachedImagesUrls[url] + 1);
				} else {
					cachedImagesUrls.set(url, 1);

					var cachedImagesKeys = cachedImagesUrls.keys();
					var cachedImagesCount = Lambda.count(cachedImagesUrls);
					while (cachedImagesCount > MAX_CHACHED_IMAGES) {
						clearUrlTextureCache(cachedImagesKeys.next());
						cachedImagesCount--;
					}
				}
			}
		}
	}

	private static function removeTextureFromCache(texture : Texture) : Bool {
		if (texture != null && texture.baseTexture != null && texture.baseTexture.imageUrl != null) {
			var url = texture.baseTexture.imageUrl;

			if (url != null) {
				if (cachedImagesUrls.exists(url) && cachedImagesUrls.get(url) > 1) {
					cachedImagesUrls.set(url, cachedImagesUrls[url] - 1);

					return cachedImagesUrls.get(url) == 0;
				} else {
					clearUrlTextureCache(url);

					return true;
				}
			}
		}

		return false;
	}

	private function onSpriteAdded() : Void {
		if (!loaded) {
			if (url.indexOf(".svg") > 0) {
				var svgXhr = new js.html.XMLHttpRequest();
				if (!Platform.isIE && !Platform.isEdge)
					svgXhr.overrideMimeType('image/svg+xml');

				svgXhr.onload = function () {
					url = "data:image/svg+xml;utf8," + untyped encodeURIComponent(svgXhr.response);
					loadTexture();
				};

				svgXhr.open('GET', url, true);
				svgXhr.send();
			} else {
				loadTexture();
			}
		}
	}

	private function onSpriteRemoved() : Void {
		if (removeTextureFromCache(texture) && !loaded) {
			var nativeWidget = texture.baseTexture.source;
			nativeWidget.removeAttribute('src');

			if (nativeWidget != null) {
				var parentNode : Dynamic = nativeWidget.parentNode;

				if (parentNode != null) {
					parentNode.removeChild(nativeWidget);
				}

				nativeWidget = null;
			}

			texture.baseTexture.destroy();
		}

		texture = Texture.EMPTY;
	}

	private function onDispose() : Void {
		disposed = true;

		if (texture != null) {
			removeTextureFromCache(texture);
		}

		loaded = false;
		visibilityChanged = true;

		if (parent != null) {
			loadTexture();
		} else {
			texture = Texture.EMPTY;
		}

		this.invalidateStage();
		this.deleteNativeWidget();
	}

	private function onError() : Void {
		if (texture != null) {
			removeTextureFromCache(texture);
		}

		loaded = false;
		failed = true;
		visibilityChanged = true;

		texture = Texture.EMPTY;

		if (parent == null) {
			return;
		}

		errorFn("Can not load " + url);
		this.deleteNativeWidget();
	}

	private function enableSprites() : Void {
		if (untyped this.destroyed || parent == null || nativeWidget == null || (RenderSupport.printMode && Util.determineCrossOrigin(url) == "anonymous")) {
			return;
		}
		if (nativeWidget.baseTexture == null) {
			if (texture != null) {
				nativeWidget.baseTexture = texture.baseTexture;
				if (Util.getParameter("has_loaded_fix") != "0") {
					nativeWidget.baseTexture.hasLoaded = true;
				}
			} else {
				return;
			}
		}

		texture = Texture.from(nativeWidget);
		RenderSupport.on("disable_sprites", disableSprites);
	}

	private function disableSprites() : Void {
		removeTextureFromCache(texture);
		texture = Texture.EMPTY;
		RenderSupport.off("disable_sprites", disableSprites);
	}

	private function onLoaded() : Void {
		RenderSupport.once("drawframe", function() {
			if (disposed) {
				return;
			}

			try {
				this.invalidateTransform('onLoaded');
				widgetBoundsChanged = true;
				calculateWidgetBounds();

				if (widgetBounds.maxX == 0.0) {
					if (parent != null && retries < 10) {
						retries++;
						nativeWidget.style.width = null;
						nativeWidget.style.height = null;

						Native.timer(retries * 1000, onLoaded);
					} else {
						if (forceSvg) {
							forceImageElement();
						} else {
							onError();
						}
					}
				} else {
					if (this.isHTMLRenderer()) {
						if (nativeWidget == null) {
							return;
						}

						this.onAdded(function() {
							RenderSupport.on("enable_sprites", enableSprites);

							return function() {
								RenderSupport.off("enable_sprites", enableSprites);
								disableSprites();
							}
						});

						// With Chrome svg data:img images are not scaled correctly for devicePixelRatio > 1.
						// For instance, with Retina display, which has a factor from 2 to 3.
						var width = Math.isFinite(widgetBounds.maxX) ? {
							if (
								forceSvg
								&& Browser.window.devicePixelRatio > 1
								&& Platform.isChrome
							) {
								widgetBounds.maxX / Browser.window.devicePixelRatio;
							 } else {
								widgetBounds.maxX;
							}
						} : 0;
						var height = Math.isFinite(widgetBounds.maxY) ? {
							if (
								forceSvg
								&& Browser.window.devicePixelRatio > 1
								&& Platform.isChrome
							) {
								widgetBounds.maxY / Browser.window.devicePixelRatio;
							 } else {
								widgetBounds.maxY;
							}
						} : 0;

						metricsFn(width, height);
					} else {
						metricsFn(texture.width, texture.height);
					}

					visibilityChanged = true;
					loaded = true;
					failed = false;
				}
			} catch (e : Dynamic) {
				if (parent != null && retries < 2) {
					loadTexture();
				} else {
					onError();
				}
			};
		});
	}

	private function loadTexture() : Void {
		retries++;
		texture = Texture.fromImage(url, Util.determineCrossOrigin(url) != '');
		pushTextureToCache(texture);

		if (texture.baseTexture == null || texture.baseTexture == untyped __js__("undefined")) {
			onError();
		} else {
			if (texture.baseTexture.hasLoaded) {
				onLoaded();
			}

			texture.baseTexture.on("loaded", onLoaded);
			texture.baseTexture.on("error", onError);
			texture.baseTexture.on("dispose", onDispose);
		}
	}

	public override function getLocalBounds(?rect : Rectangle) : Rectangle {
		rect = localBounds.getRectangle(rect);

		if (this.filterPadding != 0.0) {
			rect.x -= this.filterPadding;
			rect.y -= this.filterPadding;
			rect.width += this.filterPadding * 2.0;
			rect.height += this.filterPadding * 2.0;
		}

		return rect;
	}

	public override function getBounds(?skipUpdate : Bool, ?rect : Rectangle) : Rectangle {
		if (!skipUpdate) {
			updateTransform();
		}

		if (untyped this._boundsID != untyped this._lastBoundsID)
		{
			calculateBounds();
		}

		return _bounds.getRectangle(rect);
	}

	public function calculateBounds() : Void {
		_bounds.minX = localBounds.minX * worldTransform.a + localBounds.minY * worldTransform.c + worldTransform.tx;
		_bounds.minY = localBounds.minX * worldTransform.b + localBounds.minY * worldTransform.d + worldTransform.ty;
		_bounds.maxX = localBounds.maxX * worldTransform.a + localBounds.maxY * worldTransform.c + worldTransform.tx;
		_bounds.maxY = localBounds.maxX * worldTransform.b + localBounds.maxY * worldTransform.d + worldTransform.ty;
	}

	private function forceImageElement(?tagName : String = "img") : Void {
		if (untyped this.destroyed || parent == null || nativeWidget == null || disposed) {
			return;
		}

		forceSvg = false;
		createNativeWidget(tagName);
	}

	private function createNativeWidget(?tagName : String = "img") : Void {
		if (!isNativeWidget) {
			return;
		}

		this.deleteNativeWidget();

		if (forceSvg) {
			tagName = "div";
		}

		nativeWidget = Browser.document.createElement(tagName);
		this.updateClipID();

		// SVG specific download. Does not use cache strategy
		if (forceSvg) {
			var svgXhr = new js.html.XMLHttpRequest();
			if (!Platform.isIE && !Platform.isEdge)
				svgXhr.overrideMimeType('image/svg+xml');

			svgXhr.onload = function () {
				if (untyped this.destroyed || parent == null || nativeWidget == null || disposed) {
					return;
				}

				try {
					var isContentTypeSvg = svgXhr.getResponseHeader("content-type").indexOf("svg") > 0;
					if (isContentTypeSvg && svgXhr.response.indexOf("data:img") > 0) {
						nativeWidget.style.width = null;
						nativeWidget.style.height = null;
						nativeWidget.innerHTML = svgXhr.response;

						onLoaded();
					} else if (isContentTypeSvg && svgXhr.response.indexOf('foreignObject') > 0) {
						var warnMessage = 'Warning! SVG (' + url + ') has a <foreignObject> inside, which could effect file size and ability to take a screenshot';
						untyped console.warn(warnMessage);
						errorFn(warnMessage);
						// SVG with foreignObject taints canvas, so we have to trick it
						url = "data:image/svg+xml;utf8," + untyped encodeURIComponent(svgXhr.response);
						forceImageElement();
					} else {
						forceImageElement();
					}
				} catch (e : Dynamic) {
					forceImageElement();
				}
			};
			svgXhr.onerror = function() {
				forceImageElement();
			};

			svgXhr.open('GET', url, true);
			for (header in this.headers) {
				svgXhr.setRequestHeader(header[0], header[1]);
			}

			svgXhr.send();
		} else if (this.headers.length == 0) {
			if (useCrossOrigin) {
				nativeWidget.crossOrigin = Util.determineCrossOrigin(url);
			}

			// Loads image natively, with browser functions
			nativeWidget.onload = onLoaded;
			nativeWidget.onerror = onError;
			nativeWidget.src = url;
		} else {
			if (useCrossOrigin) {
				nativeWidget.crossOrigin = Util.determineCrossOrigin(url);
			}

			nativeWidget.onerror = onError;

			var keepInRequestCache = false;
			var headers = this.headers.filter(function(header) {
				if (header.length < 2) return false;
				if (header[0] == 'keepInRequestCache' && header[1] == 'true') {
					keepInRequestCache = true;
					return false;
				}
				return true;
			});

			// Downloads a file from/with a queue
			var promise = requestQueue.request(url, headers);

			// Handle the response
			promise.then(function(blob) {
				if (nativeWidget != null) {
					// Everything is fine, let's show image
					nativeWidget.src = blob;

					Native.defer(function() {
						requestQueue.removeBlobUsage(url, keepInRequestCache);
					});

					onLoaded();
				}
			}).catchError(function(error) {
				onError();
			});
		}

		nativeWidget.className = 'nativeWidget';
		if (this.className != null && this.className != '') {
			nativeWidget.classList.add(this.className);
		}
		nativeWidget.style.visibility = 'hidden';
		nativeWidget.alt = altText;

		isNativeWidget = true;
	}

	public function switchUseCrossOrigin(useCrossOrigin) : Void {
		if (this.useCrossOrigin != useCrossOrigin) {
			this.useCrossOrigin = useCrossOrigin;

			if (useCrossOrigin) nativeWidget.crossOrigin = Util.determineCrossOrigin(url)
			else nativeWidget.crossOrigin = null;
		}
	}

	public function setPictureReferrerPolicy(referrerpolicy) : Void {
		if (nativeWidget != null) {
			nativeWidget.referrerPolicy = referrerpolicy;
		}
	}

	public function calculateWidgetBounds() : Void {
		if (!widgetBoundsChanged) {
			return;
		}

		if (this.isHTMLRenderer()) {
			if (nativeWidget == null) {
				widgetBounds.clear();
			} else {
				nativeWidget.style.width = null;
				nativeWidget.style.height = null;

				widgetBounds.minX = 0;
				widgetBounds.minY = 0;

				if (nativeWidget.naturalWidth != null && nativeWidget.naturalHeight != null && (nativeWidget.naturalWidth > 0 || nativeWidget.naturalHeight > 0)) {
					widgetBounds.maxX = nativeWidget.naturalWidth;
					widgetBounds.maxY = nativeWidget.naturalHeight;
				} else if (isSvg) {
					var svgElement = nativeWidget.children[0];
					if (svgElement != null) {
						var viewBox = svgElement.viewBox.baseVal;
						var IMG_STANDARD_WIDTH = 300;
						var IMG_STANDARD_HEIGHT = 150;
						var svgWidth = viewBox.width;
						var svgHeight = viewBox.height;
						var scale = Math.min(1, Math.min(IMG_STANDARD_WIDTH / svgWidth, IMG_STANDARD_HEIGHT / svgHeight));
						widgetBounds.maxX = svgWidth * scale;
						widgetBounds.maxY = svgHeight * scale;
					}
				} else {
					Browser.document.body.appendChild(nativeWidget);

					widgetBounds.maxX = nativeWidget.clientWidth * RenderSupport.backingStoreRatio;
					widgetBounds.maxY = nativeWidget.clientHeight * RenderSupport.backingStoreRatio;

					this.addNativeWidget();
				}
			}
		} else {
			widgetBounds.minX = 0;
			widgetBounds.minY = 0;
			widgetBounds.maxX = texture.width;
			widgetBounds.maxY = texture.height;
		}

		widgetBoundsChanged = false;
	}

	public static function clearPictureRequestCache() {
		requestQueue.clearCache();
	}
}
