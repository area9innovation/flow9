import js.Browser;

import pixi.core.display.Bounds;
import pixi.core.math.shapes.Rectangle;
import pixi.core.display.DisplayObject;
import pixi.core.sprites.Sprite;
import pixi.core.textures.Texture;
import pixi.core.textures.BaseTexture;

using DisplayObjectHelper;

class FlowSprite extends Sprite {
	private var scrollRect : FlowGraphics;
	private var _visible : Bool = true;
	private var clipVisible : Bool = false;
	private var transformChanged : Bool = true;

	private var url : String = "";
	private var loaded : Bool = false;
	private var cache : Bool = false;
	private var metricsFn : Float -> Float -> Void;
	private var errorFn : String -> Void;
	private var onlyDownload : Bool = false;
	private var retries : Int = 0;

	private var localBounds = new Bounds();
	private var _bounds = new Bounds();

	private var nativeWidget : Dynamic;
	private var accessWidget : AccessWidget;

	public var isNativeWidget : Bool = false;

	private static inline var MAX_CHACHED_IMAGES : Int = 50;
	private static var cachedImagesUrls : Map<String, Int> = new Map<String, Int>();

	public function new(url : String, cache : Bool, metricsFn : Float -> Float -> Void, errorFn : String -> Void, onlyDownload : Bool) {
		super();

		visible = false;
		interactiveChildren = false;

		this.url = url;
		this.cache = cache;
		this.metricsFn = metricsFn;
		this.errorFn = errorFn;
		this.onlyDownload = onlyDownload;

		if (StringTools.endsWith(url, ".swf")) {
			url = StringTools.replace(url, ".swf", ".png");
		};

		if (RenderSupportJSPixi.DomRenderer) {
			initNativeWidget("img");
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
			if (StringTools.endsWith(url, ".svg")) {
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
		renderable = false;
		if (texture != null) {
			removeTextureFromCache(texture);
		}
		loaded = false;

		if (parent != null) {
			loadTexture();
		} else {
			texture = Texture.EMPTY;
		}

		invalidateStage();
	}

	private function onError() : Void {
		renderable = false;
		if (texture != null) {
			removeTextureFromCache(texture);
		}
		loaded = false;

		texture = Texture.EMPTY;

		if (parent == null) {
			return;
		}

		errorFn("Can not load " + url);
	}

	private function onLoaded() : Void {
		try {
			if (RenderSupportJSPixi.DomRenderer) {
				if (nativeWidget == null) {
					return;
				}

				nativeWidget.style.visibility = 'visible';
				metricsFn(nativeWidget.naturalWidth, nativeWidget.naturalHeight);
			} else {
				metricsFn(texture.width, texture.height);
			}

			invalidateTransform();

			renderable = true;
			loaded = true;

			calculateLocalBounds();
		} catch (e : Dynamic) {
			if (parent != null && retries < 2) {
				loadTexture();
			} else {
				onError();
			}
		};
	}

	private function loadTexture() : Void {
		retries++;
		texture = Texture.fromImage(url, Util.determineCrossOrigin(url) != '');
		pushTextureToCache(texture);

		if (texture.baseTexture == null) {
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
		return localBounds.getRectangle(rect);
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

	private function createNativeWidget(?tagName : String = "img") : Void {
		if (!isNativeWidget) {
			return;
		}

		deleteNativeWidget();

		nativeWidget = Browser.document.createElement(tagName);
		nativeWidget.setAttribute('id', getClipUUID());
		nativeWidget.className = 'nativeWidget';
		nativeWidget.onload = onLoaded;
		nativeWidget.onerror = onError;
		nativeWidget.src = url;
		nativeWidget.style.visibility = 'hidden';

		isNativeWidget = true;
	}

	public function calculateLocalBounds() : Void {
		var currentBounds = new Bounds();

		if (parent != null && localBounds.minX != Math.POSITIVE_INFINITY) {
			applyLocalBoundsTransform(currentBounds);
		}

		localBounds.clear();

		if (mask != null || untyped this.alphaMask != null || scrollRect != null) {
			var mask = mask != null ? mask : untyped this.alphaMask != null ? untyped this.alphaMask : scrollRect;

			if (untyped mask.localBounds != null && mask.localBounds.minX != Math.POSITIVE_INFINITY) {
				cast(mask, DisplayObject).applyLocalBoundsTransform(localBounds);
			}
		} else {
			localBounds.minX = 0;
			localBounds.minY = 0;

			if (RenderSupportJSPixi.DomRenderer) {
				localBounds.maxX = nativeWidget.naturalWidth;
				localBounds.maxY = nativeWidget.naturalHeight;
			} else {
				localBounds.maxX = texture.width;
				localBounds.maxY = texture.height;
			}
		}

		if (parent != null) {
			var newBounds = applyLocalBoundsTransform();
			if (!currentBounds.isEqualBounds(newBounds)) {
				parent.replaceLocalBounds(currentBounds, newBounds);
			}
		}
	}
}