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


using DisplayObjectHelper;
using Object3DHelper;

class ThreeJSStage extends Container {
	public var camera : Camera;
	public var scene : Scene;
	public var renderer : WebGLRenderer;
	public var orbitControls : OrbitControls;
	public var transformControls : Dynamic;
	public var boxHelpers : Array<Object3D> = new Array<Object3D>();
	public var objectCache : Array<Object3D> = new Array<Object3D>();

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

		widgetWidth = width;
		widgetHeight = height;

		if (RenderSupportJSPixi.RendererType == "html") {
			initNativeWidget('canvas');
			this.renderer = new WebGLRenderer({antialias: true, alpha : true, canvas : nativeWidget});
		} else {
			this.renderer = new WebGLRenderer({antialias: true, alpha : true});
		}

		renderer.setSize(width, height);

		// Chrome Inspect Three.js extension support
		untyped __js__("window.THREE = THREE;");
	}

	public function invalidateStage() {
		if (RenderSupportJSPixi.RendererType == "html") {
			invalidateTransform('ThreeJSStage');
		} else {
			DisplayObjectHelper.invalidateStage(this);
		}
	}

	private function addEventListeners() {
		renderer.domElement.removeEventListener("mousedown", onMouseEvent);
		renderer.domElement.addEventListener("mousedown", onMouseEvent);

		renderer.domElement.removeEventListener("mouseup", onMouseEvent);
		renderer.domElement.addEventListener("mouseup", onMouseEvent);

		renderer.domElement.removeEventListener("mousemove", onMouseEvent);
		renderer.domElement.addEventListener("mousemove", onMouseEvent);
	}

	public function onMouseEvent(event : Dynamic, ?object : Object3D) : Void {
		if (orbitControls != null && !orbitControls.enabled) {
			return;
		}

		var interactiveChildren = scene.get3DObjectAllInteractiveChildren();

		if (interactiveChildren.length == 0) {
			return;
		}

		var handledObjects = new Array<Dynamic>();

		var raycaster = new Raycaster();
		raycaster.setFromCamera(new Vector2((event.pageX / getWidth()) * 2.0 - 1.0, -(event.pageY / getHeight()) * 2.0 + 1.0), camera);

		for (ob in raycaster.intersectObjects(interactiveChildren)) {
			var object = ob.object;

			if (handledObjects.indexOf(object) == -1) {
				handledObjects.push(object);
				object.emitEvent(event.type);
			}
		};
	}

	private function createTransformControls() {
		if (scene != null && transformControls != null) {
			untyped scene.transformControls = null;
		}

		if (camera != null) {
			transformControls = new TransformControls(camera, renderer.domElement);
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

		invalidateStage();
	}

	private function createOrbitControls() {
		if (camera != null) {
			orbitControls = new OrbitControls(camera, renderer.domElement);
		}

		invalidateStage();
	}

	public function setCamera(camera : Camera, minDistance : Float, maxDistance : Float) {
		this.camera = camera;

		createOrbitControls();
		createTransformControls();
		addEventListeners();

		orbitControls.minDistance = minDistance;
		orbitControls.maxDistance = maxDistance;

		invalidateStage();
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

		if (orbitControls != null) {
			orbitControls.update();
		}

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
		ctx.drawImage(this.renderer.domElement, 0, 0, getWidth(), getHeight(), 0, 0, getWidth() * resolution, getHeight() * resolution);
	}

	private function getWidth() : Float {
		return widgetWidth;
	}

	private function getHeight() : Float {
		return widgetHeight;
	}

	private function setWidth(width : Float) : Void {
		if (widgetWidth != width) {
			widgetWidth = width;
			renderer.setSize(width, getHeight());
			invalidateStage();
		}
	}

	private function setHeight(height : Float) : Void {
		if (widgetHeight != height) {
			widgetHeight = height;
			renderer.setSize(getWidth(), height);
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

		deleteNativeWidget();

		nativeWidget = Browser.document.createElement(tagName);
		updateClipID();
		nativeWidget.className = 'nativeWidget';

		isNativeWidget = true;
	}

	public function calculateWidgetBounds() : Void {
		widgetBounds.minX = 0.0;
		widgetBounds.minY = 0.0;
		widgetBounds.maxX = DisplayObjectHelper.ceil(getWidth());
		widgetBounds.maxY = DisplayObjectHelper.ceil(getHeight());
	}

	public function updateNativeWidget() : Void {
		if (RenderSupportJSPixi.RendererType == "html") {
			if (isNativeWidget) {
				if (visible) {
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

					updateNativeWidgetTransformMatrix();
					updateNativeWidgetOpacity();

					if (orbitControls != null) {
						orbitControls.update();
					}

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

				updateNativeWidgetDisplay();
			}
		}
	}
}