import js.Browser;
import pixi.core.display.Bounds;
import pixi.core.display.Container;
import pixi.core.display.DisplayObject;
import pixi.core.math.shapes.Rectangle;
import pixi.core.math.Point;

import js.three.Object3D;
import js.three.Vector2;

import js.three.Camera;
import js.three.PerspectiveCamera;

import js.three.OrbitControls;
import js.three.TransformControls;
import js.three.BoxHelper;

import js.three.Scene;
import js.three.Raycaster;
import js.three.WebGLRenderer;
import js.three.LoadingManager;


using DisplayObjectHelper;
using Object3DHelper;

class ThreeJSStage extends Container {
	public var camera : Camera;
	public var scene : Scene;
	public var renderer : WebGLRenderer;
	private var raycaster : Raycaster;
	public var orbitControls : OrbitControls;
	public var transformControls : Dynamic;
	public var boxHelpers : Array<Object3D> = [];
	public var objectCache : Array<Object3D> = [];
	public var objectCacheEnabled : Bool = false;
	public static var loadingManager : LoadingManager = null;
	public var interactiveObjects : Array<Object3D> = [];
	private var interactiveObjectsMouseOver : Array<Object3D> = [];

	private var _visible : Bool = true;
	private var clipVisible : Bool = false;

	public var ctrlKey : Bool = false;
	public var shiftKey : Bool = false;
	public var metaKey : Bool = false;

	private var widgetWidth : Float = 0.0;
	private var widgetHeight : Float = 0.0;

	public var transformChanged : Bool = false;
	public var stageChanged : Bool = false;
	private var worldTransformChanged : Bool = false;
	private var localTransformChanged : Bool = true;

	private var localBounds = new Bounds();
	private var widgetBounds = new Bounds();
	private var _bounds = new Bounds();

	private var nativeWidget : Dynamic;
	private var accessWidget : AccessWidget;

	public var isNativeWidget : Bool = false;

	public function new(width : Float, height : Float) {
		super();

		if (ThreeJSStage.loadingManager == null) {
			ThreeJSStage.loadingManager = new LoadingManager();
			untyped ThreeJSStage.loadingManager.cache = new Map<String, Dynamic>();
		}

		widgetWidth = width;
		widgetHeight = height;
		raycaster = new Raycaster();

		initRenderer();
	}

	private function initRenderer() {
		if (this.renderer != null) {
			dispose();
		}

		if (RenderSupportJSPixi.RendererType == "html") {
			this.initNativeWidget('canvas');
			this.renderer = new WebGLRenderer({antialias: !Platform.isIOS && RenderSupportJSPixi.detectExternalVideoCard(), alpha : true, canvas : nativeWidget, logarithmicDepthBuffer : true});
		} else {
			this.renderer = new WebGLRenderer({antialias: !Platform.isIOS && RenderSupportJSPixi.detectExternalVideoCard(), alpha : true, logarithmicDepthBuffer : true});
		}

		updatePixelRatio();

		RenderSupportJSPixi.on("resize", updatePixelRatio);

		untyped this.renderer.eventElement = Browser.document.createElement('div');

		renderer.setSize(widgetWidth, widgetHeight);

		renderer.domElement.addEventListener("webglcontextlost", function(event) {
			event.preventDefault();
			initRenderer();
		}, false);

		// Chrome Inspect Three.js extension support
		untyped __js__("window.THREE = THREE;");

		if (camera != null && orbitControls != null) {
			setCamera(camera, untyped orbitControls.parameters);
		}

		if (scene != null) {
			setScene(scene);
		}
	}

	private function updatePixelRatio() : Void {
		this.renderer.setPixelRatio(RenderSupportJSPixi.backingStoreRatio);

		if (camera != null) {
			camera.broadcastEvent("matrix");
			camera.emit("change");
		}

		this.emit("resize");
	}

	public function dispose() : Void {
		boxHelpers = null;
		objectCache = null;
		objectCacheEnabled = false;
		interactiveObjects = null;
		interactiveObjectsMouseOver = null;
		raycaster = null;
		if (!RenderSupport3D.LOADING_CACHE_ENABLED) {
			ThreeJSStage.loadingManager = null;
		}

		RenderSupportJSPixi.off("resize", updatePixelRatio);

		if (orbitControls != null) {
			RenderSupportJSPixi.off("drawframe", orbitControls.update);
		}

		if (renderer != null) {
			renderer.dispose();
			renderer = null;
		}

		if (scene != null) {
			scene.dispose();
			scene = null;
		}

		if (camera != null) {
			camera.dispose();
		}

		if (orbitControls != null) {
			orbitControls.dispose();
			orbitControls = null;
		}

		if (transformControls != null) {
			transformControls.dispose();
			transformControls = null;
		}

		this.deleteNativeWidget();
	}

	public function invalidateStage() {
		if (RenderSupportJSPixi.RendererType == "html") {
			this.invalidateTransform('ThreeJSStage');
		} else {
			DisplayObjectHelper.invalidateStage(this);
		}
	}

	private function addEventListeners() {
		RenderSupport.removeNonPassiveEventListener(untyped renderer.domElement, "pointerover", onMouseEvent);
		RenderSupport.addNonPassiveEventListener(untyped renderer.domElement, "pointerout", onMouseEvent);

		if (Platform.isMobile) {
			RenderSupportJSPixi.removeNonPassiveEventListener(untyped renderer.eventElement, "touchstart", onMouseEvent);
			RenderSupportJSPixi.addNonPassiveEventListener(untyped renderer.eventElement, "touchstart", onMouseEvent);

			RenderSupportJSPixi.removeNonPassiveEventListener(untyped renderer.eventElement, "touchend", onMouseEvent);
			RenderSupportJSPixi.addNonPassiveEventListener(untyped renderer.eventElement, "touchend", onMouseEvent);

			RenderSupportJSPixi.removeNonPassiveEventListener(untyped renderer.eventElement, "touchmove", onMouseEvent);
			RenderSupportJSPixi.addNonPassiveEventListener(untyped renderer.eventElement, "touchmove", onMouseEvent);
		} else {
			RenderSupportJSPixi.removeNonPassiveEventListener(untyped renderer.eventElement, "mousedown", onMouseEvent);
			RenderSupportJSPixi.addNonPassiveEventListener(untyped renderer.eventElement, "mousedown", onMouseEvent);

			RenderSupportJSPixi.removeNonPassiveEventListener(untyped renderer.eventElement, "mouseup", onMouseEvent);
			RenderSupportJSPixi.addNonPassiveEventListener(untyped renderer.eventElement, "mouseup", onMouseEvent);

			RenderSupportJSPixi.removeNonPassiveEventListener(untyped renderer.eventElement, "mousemove", onMouseEvent);
			RenderSupportJSPixi.addNonPassiveEventListener(untyped renderer.eventElement, "mousemove", onMouseEvent);
		}
	}

	var prevMousePos = null;

	public function onMouseEvent(event : Dynamic) : Void {
		if ((orbitControls != null && !orbitControls.enabled) || interactiveObjects.length == 0) {
			return;
		}

		var newInteractiveObjectsMouseOver = [];
		var handledObjects = new Array<Dynamic>();
		var mousePos = new Vector2(
			((event.touches != null && event.touches.length >= 1 ? event.touches[0] : event).pageX / getWidth() / RenderSupportJSPixi.backingStoreRatio) * 2.0 - 1.0,
			-((event.touches != null && event.touches.length >= 1 ? event.touches[0] : event).pageY / getHeight() / RenderSupportJSPixi.backingStoreRatio) * 2.0 + 1.0
		);

		if ((prevMousePos != null && mousePos.equals(prevMousePos)) || (mousePos.x == 0 && mousePos.y == 0)) {
			for (object in interactiveObjectsMouseOver) {
				object.emit(event.type);
				object.invalidateStage();
			}

			return;
		} else {
			prevMousePos = mousePos;
		}

		raycaster.setFromCamera(
			mousePos,
			camera
		);

		for (ob in raycaster.intersectObjects(interactiveObjects)) {
			var object = untyped ob.instanceId != null && ob.object.instanceObjects != null ? ob.object.instanceObjects[ob.instanceId] : ob.object;

			if (handledObjects.indexOf(object) == -1) {
				handledObjects.push(object);

				if (boxHelpers.indexOf(object) >= 0) {
					return;
				}

				if (untyped object.inside != (event.name != "pointerout")) {
					untyped object.inside = event.name != "pointerout";
					object.emit(event.name != "pointerout" ? "mouseover" : "mouseout");
				}

				if (untyped object.inside) {
					newInteractiveObjectsMouseOver.push(object);
				}

				object.emit(event.type);
				object.invalidateStage();
			}
		};

		for (ob in interactiveObjectsMouseOver) {
			if (newInteractiveObjectsMouseOver.indexOf(ob) < 0) {
				untyped ob.inside = false;
				ob.emit("mouseout");
			}
		}

		interactiveObjectsMouseOver = newInteractiveObjectsMouseOver;
	}

	public function createTransformControls() {
		if (scene != null && transformControls != null) {
			untyped scene.transformControls = null;
		}

		if (camera != null) {
			transformControls = untyped __js__("new THREE.TransformControls(this.camera, this.renderer.domElement, this.renderer.eventElement)");
			untyped transformControls.transformControls = transformControls;
		}

		if (scene != null) {
			untyped scene.transformControls = transformControls;
		}

		transformControls.addEventListener('dragging-changed', function (event) {
			if (orbitControls != null) {
				untyped orbitControls.enabled = !event.value;
			}
		});

		addEventListeners();
		invalidateStage();
	}

	private function createOrbitControls() {
		if (orbitControls != null) {
			RenderSupportJSPixi.off("drawframe", orbitControls.update);
		}

		if (camera != null) {
			orbitControls = untyped __js__("new THREE.OrbitControls(this.camera, this.renderer.domElement, this.renderer.eventElement)");
			RenderSupportJSPixi.on("drawframe", orbitControls.update);
		}

		invalidateStage();
	}

	public function setCamera(camera : Camera, parameters : Array<Array<String>>) {
		this.camera = camera;

		addEventListeners();
		createOrbitControls();

		untyped orbitControls.parameters = parameters;

		for (par in parameters) {
			untyped orbitControls[par[0]] = untyped __js__("eval(par[1])");
		}

		if (this.camera != null) {
			untyped this.camera.stage = this;

			invalidateStage();
		}
	}

	public function setScene(scene : Scene) {
		if (scene != null) {
			if (transformControls != null) {
				untyped scene.transformControls = null;
			}

			untyped scene.stage = null;
		}

		this.scene = scene;

		if (this.scene != null) {
			untyped this.scene.stage = this;

			if (transformControls != null) {
				untyped scene.transformControls = transformControls;
			}

			// Chrome Inspect Three.js extension support
			untyped __js__("window.scene = scene;");

			invalidateStage();
		}
	}

	public function renderCanvas(renderer : pixi.core.renderers.canvas.CanvasRenderer) {
		if (!this.visible || this.worldAlpha <= 0 || !this.renderable || camera == null || scene == null ||
			getWidth() <= 0 || getHeight() <= 0) {
			return;
		}

		this.emit("drawframe");

		if (transformControls != null) {
			scene.add(transformControls);
		}

		for (b in boxHelpers) {
			scene.add(b);
		}

		this.renderer.render(scene, camera);

		for (b in boxHelpers) {
			scene.remove(b);
		}

		if (transformControls != null) {
			scene.remove(transformControls);
		}

		var ctx : Dynamic = untyped renderer.context;
		var resolution = renderer.resolution;

		ctx.globalAlpha = this.worldAlpha;
		ctx.setTransform(worldTransform.a, worldTransform.b, worldTransform.c, worldTransform.d, worldTransform.tx * resolution, worldTransform.ty * resolution);
		ctx.drawImage(this.renderer.domElement, 0, 0, getWidth() * RenderSupportJSPixi.backingStoreRatio, getHeight() * RenderSupportJSPixi.backingStoreRatio, 0, 0, getWidth() * resolution, getHeight() * resolution);
	}

	public function getWidth() : Float {
		return widgetWidth;
	}

	public function getHeight() : Float {
		return widgetHeight;
	}

	public function setWidth(width : Float) : Void {
		if (widgetWidth != width) {
			widgetWidth = width;
			renderer.setSize(width, getHeight());
			this.emit("resize");
			invalidateStage();
		}
	}

	public function setHeight(height : Float) : Void {
		if (widgetHeight != height) {
			widgetHeight = height;
			renderer.setSize(getWidth(), height);
			this.emit("resize");
			invalidateStage();
		}
	}

	public override function getLocalBounds(?rect : Rectangle) : Rectangle {
		rect = localBounds.getRectangle(rect);

		var filterPadding = untyped this.filterPadding;

		if (filterPadding != null) {
			rect.x -= filterPadding;
			rect.y -= filterPadding;
			rect.width += filterPadding * 2.0;
			rect.height += filterPadding * 2.0;
		}

		return rect;
	}

	public override function getBounds(?skipUpdate : Bool, ?rect : Rectangle) : Rectangle {
		if (!skipUpdate) {
			updateTransform();
		}

		getLocalBounds();
		calculateBounds();

		return _bounds.getRectangle(rect);
	}

	public function calculateBounds() : Void {
		_bounds.minX = localBounds.minX * worldTransform.a + localBounds.minY * worldTransform.c + worldTransform.tx;
		_bounds.minY = localBounds.minX * worldTransform.b + localBounds.minY * worldTransform.d + worldTransform.ty;
		_bounds.maxX = localBounds.maxX * worldTransform.a + localBounds.maxY * worldTransform.c + worldTransform.tx;
		_bounds.maxY = localBounds.maxX * worldTransform.b + localBounds.maxY * worldTransform.d + worldTransform.ty;
	}

	private function createNativeWidget(?tagName : String = "canvas") : Void {
		if (!isNativeWidget) {
			return;
		}

		this.deleteNativeWidget();

		nativeWidget = Browser.document.createElement(tagName);
		this.updateClipID();
		nativeWidget.className = 'nativeWidget';
		nativeWidget.style.pointerEvents = 'auto';

		isNativeWidget = true;
	}

	public function calculateWidgetBounds() : Void {
		widgetBounds.minX = 0.0;
		widgetBounds.minY = 0.0;
		widgetBounds.maxX = DisplayObjectHelper.ceil(getWidth());
		widgetBounds.maxY = DisplayObjectHelper.ceil(getHeight());
	}

	private function simulateContextLost() : Void { // Useful for debugging
		untyped __js__("console.log(this.nativeWidget.getContext(\"webgl\").getSupportedExtensions())");
		untyped __js__("this.nativeWidget.getContext(\"webgl\").getExtension(\"WEBGL_lose_context\").loseContext()");
	}

	public function updateNativeWidget() : Void {
		if (RenderSupportJSPixi.RendererType == "html") {
			if (isNativeWidget) {
				if (visible && camera != null && scene != null && getWidth() > 0 && getHeight() > 0) {
					this.emit("drawframe");

					if (DisplayObjectHelper.DebugUpdate) {
						untyped this.nativeWidget.setAttribute("update", Std.int(this.nativeWidget.getAttribute("update")) + 1);
						if (untyped this.from) {
							untyped this.nativeWidget.setAttribute("from", this.from);
							untyped this.from = null;
						}

						if (untyped this.info) {
							untyped this.nativeWidget.setAttribute("info", this.info);
						}
					}

					this.updateNativeWidgetTransformMatrix();
					this.updateNativeWidgetOpacity();

					if (transformControls != null) {
						scene.add(transformControls);
					}

					for (b in boxHelpers) {
						scene.add(b);
					}

					this.renderer.render(scene, camera);

					for (b in boxHelpers) {
						scene.remove(b);
					}

					if (transformControls != null) {
						scene.remove(transformControls);
					}
				}

				this.updateNativeWidgetDisplay();
			}
		}
	}
}