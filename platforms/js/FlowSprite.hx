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

	private static inline var MAX_CHACHED_IMAGES : Int = 50;
	private static var cachedImagesUrls : Map<String, Int> = new Map<String, Int>();

	public function getWidth() : Float {
		return texture != null ? texture.width : 0;
	}

	public function getHeight() : Float {
		return texture != null ? texture.height : 0;
	}

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

		once("removed", onSpriteRemoved);
		once("added", onSpriteAdded);

		if (RenderSupportJSPixi.DomRenderer) {
			createNativeWidget();
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
		removeTextureFromCache(texture);
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
		removeTextureFromCache(texture);
		loaded = false;

		texture = Texture.EMPTY;

		if (parent == null) {
			return;
		}

		errorFn("Can not load " + url);
	}

	private function onLoaded() : Void {
		try {
			metricsFn(texture.width, texture.height);

			localBounds.minX = 0;
			localBounds.minY = 0;
			localBounds.maxX = texture.width;
			localBounds.maxY = texture.height;

			invalidateStage();

			renderable = true;
			loaded = true;
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

	private function createNativeWidget(?node_name : String = "img") : Void {
		deleteNativeWidget();

		nativeWidget = Browser.document.createElement(node_name);
		nativeWidget.setAttribute('id', getClipUUID());
		nativeWidget.style.transformOrigin = 'top left';
		nativeWidget.style.position = 'fixed';
		// nativeWidget.style.willChange = 'transform, display, opacity';
		nativeWidget.style.pointerEvents = 'none';
		nativeWidget.src = url;

		updateNativeWidgetDisplay();

		onAdded(function() { addNativeWidget(); return removeNativeWidget; });
	}

	private function deleteNativeWidget() : Void {
		removeNativeWidget();

		if (accessWidget != null) {
			AccessWidget.removeAccessWidget(accessWidget);
		}

		nativeWidget = null;
	}

	private function updateNativeWidget() : Void {
		if (nativeWidget != null) {
			var transform = untyped this.transform.localTransform;

			var tx = Math.floor(transform.tx);
			var ty = Math.floor(transform.ty);

			if (tx != 0 || ty != 0 || transform.a != 1 || transform.b != 0 || transform.c != 0 || transform.d != 1) {
				if (Platform.isIE) {
					nativeWidget.style.transform = 'matrix(${transform.a}, ${transform.b}, ${transform.c}, ${transform.d}, 0, 0)';

					nativeWidget.style.left = '${tx}px';
					nativeWidget.style.top = '${ty}px';
				} else {
					nativeWidget.style.transform = 'matrix(${transform.a}, ${transform.b}, ${transform.c}, ${transform.d}, ${tx}, ${ty})';
				}
			} else {
				nativeWidget.style.transform = null;

				if (Platform.isIE) {
					nativeWidget.style.left = null;
					nativeWidget.style.top = null;
				}
			}

			if (alpha != 1) {
				nativeWidget.style.opacity = alpha;
			} else {
				nativeWidget.style.opacity = null;
			}

			if (scrollRect != null) {
				if (Platform.isIE || Platform.isEdge) {
					nativeWidget.style.clip = 'rect(
						${scrollRect.y}px,
						${scrollRect.x + scrollRect.width}px,
						${scrollRect.y + scrollRect.height}px,
						${scrollRect.x}px
					)';
				} else {
					nativeWidget.style.clipPath = 'polygon(
						${scrollRect.x}px ${scrollRect.y}px,
						${scrollRect.x}px ${scrollRect.y + scrollRect.height}px,
						${scrollRect.x + scrollRect.width}px ${scrollRect.y + scrollRect.height}px,
						${scrollRect.x + scrollRect.width}px ${scrollRect.y}px
					)';
				}
			} else if (mask != null) {
				if (Platform.isIE || Platform.isEdge) {
					nativeWidget.style.clip = 'rect(
						${mask.y}px,
						${mask.x + mask.getWidth()}px,
						${mask.y + mask.getHeight()}px,
						${mask.x}px
					)';
				} else {
					nativeWidget.style.clipPath = cast(mask, DisplayObject).getClipPath();
				}
			} else {
				nativeWidget.style.clipPath = null;
			}
		}
	}

	private function addNativeWidget() : Void {
		if (nativeWidget != null && parent != null && untyped parent.nativeWidget != null) {
			untyped parent.nativeWidget.appendChild(nativeWidget);
		}
	}

	private function removeNativeWidget() : Void {
		if (nativeWidget != null && nativeWidget.parentNode != null) {
			nativeWidget.parentNode.removeChild(nativeWidget);
		}
	}

	public function updateNativeWidgetDisplay() : Void {
		if (nativeWidget != null) {
			if (visible) {
				nativeWidget.style.display = "block";
			} else if (parent == null || (untyped parent.nativeWidget != null && untyped parent.nativeWidget.style.display == "block")) {
				nativeWidget.style.display = "none";
			}
		}
	}
}