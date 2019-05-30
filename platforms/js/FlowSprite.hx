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

		once("removed", onRemoved);
		once("added", onAdded);
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

	private function onAdded() : Void {
		if (!loaded) {
			if (StringTools.endsWith(url, ".svg")) {
				var svgXhr = new js.html.XMLHttpRequest();
				if (!Platform.isIE && !Platform.isEdge)
					svgXhr.overrideMimeType('image/svg+xml');

				svgXhr.onload = function () {
					url = "data:image/svg+xml;utf8," + svgXhr.response;
					loadTexture();
				};

				svgXhr.open('GET', url, true);
				svgXhr.send();
			} else {
				loadTexture();
			}
		}
	}

	private function onRemoved() : Void {
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
		errorFn("Can not load " + url);
	}

	private function onLoaded() : Void {
		try {
			metricsFn(texture.width, texture.height);

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
}