import js.Browser;
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

class ThreeJSStage extends DisplayObject {
	public var camera : Camera;
	public var scene : Scene;
	public var renderer : WebGLRenderer;
	public var orbitControls : OrbitControls;
	public var transformControls : Dynamic;
	public var boxHelpers : Array<Object3D> = new Array<Object3D>();

	private var _visible : Bool = true;
	private var clipVisible : Bool = false;

	public var ctrlKey : Bool = false;
	public var shiftKey : Bool = false;
	public var metaKey : Bool = false;

	private var widgetWidth : Float = 0.0;
	private var widgetHeight : Float = 0.0;

	public function new(width : Float, height : Float) {
		super();

		widgetWidth = width;
		widgetHeight = height;

		this.renderer = new WebGLRenderer({antialias: true, alpha : true});
		renderer.setSize(width, height);

		// Chrome Inspect Three.js extension support
		untyped __js__("window.THREE = THREE;");
	}

	private function addEventListeners() {
		renderer.domElement.removeEventListener("mousedown", onMouseEvent);
		renderer.domElement.addEventListener("mousedown", onMouseEvent);

		renderer.domElement.removeEventListener("mouseup", onMouseEvent);
		renderer.domElement.addEventListener("mouseup", onMouseEvent);

		renderer.domElement.removeEventListener("mousemove", onMouseEvent);
		renderer.domElement.addEventListener("mousemove", onMouseEvent);
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

	public function setCamera(camera : Camera) {
		this.camera = camera;

		createOrbitControls();
		createTransformControls();
		addEventListeners();

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
		if (!this.visible || this.worldAlpha <= 0 || !this.renderable || camera == null || scene == null)
		{
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

	#if (pixijs < "4.7.0")
		public override function getLocalBounds() : Rectangle {
			var rect = new Rectangle();

			rect.x = 0;
			rect.y = 0;
			rect.width = getWidth();
			rect.height = getHeight();

			return rect;
		}
	#else
		public override function getLocalBounds(?rect:Rectangle) : Rectangle {
			if (rect == null) {
				rect = new Rectangle();
			};

			rect.x = 0;
			rect.y = 0;
			rect.width = getWidth();
			rect.height = getHeight();

			return rect;
		}
	#end

	public override function getBounds(?skipUpdate: Bool, ?rect: Rectangle) : Rectangle {
		if (rect == null) {
			rect = new Rectangle();
		};

		var lt = toGlobal(new Point(0.0, 0.0));
		var rb = toGlobal(new Point(getWidth(), getHeight()));

		rect.x = lt.x;
		rect.y = lt.y;
		rect.width = rb.x - lt.x;
		rect.height = rb.y - lt.y;

		return rect;
	}

	public function onMouseEvent(event : Dynamic, ?object : Object3D, ?handledObjects : Array<Dynamic>) : Void {
		if (orbitControls != null && !orbitControls.enabled) {
			return;
		}

		if (object == null) {
			if (scene == null) {
				return;
			}

			object = scene;
		};

		if (handledObjects == null) {
			handledObjects = new Array<Dynamic>();
		};

		var raycaster = new Raycaster();
		raycaster.setFromCamera(new Vector2((event.pageX / getWidth()) * 2.0 - 1.0, -(event.pageY / getHeight()) * 2.0 + 1.0), camera);

		for (ob in raycaster.intersectObjects(object.children)) {
			var object = ob.object;

			if (handledObjects.indexOf(object) == -1) {
				handledObjects.push(object);
				object.emitEvent(event.type);
			}
		};

		for (child in object.children) {
			onMouseEvent(event, child, handledObjects);
		};
	}
}