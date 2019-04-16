import js.Browser;
import pixi.core.display.Container;
import pixi.core.display.DisplayObject;
import pixi.core.math.shapes.Rectangle;
import pixi.core.math.Point;

import js.three.Camera;
import js.three.PerspectiveCamera;
import js.three.Scene;
import js.three.WebGLRenderer;

using DisplayObjectHelper;

class ThreeJSStage extends DisplayObject {
	public var camera : Camera;
	public var scene : Scene;
	public var renderer : WebGLRenderer;

	private var _visible : Bool = true;
	private var clipVisible : Bool = false;

	public function new(width : Float, height : Float) {
		super();

		this.camera = new PerspectiveCamera(45.0, 1.0, 0.1, 1000.0);
		this.scene = new Scene();
		this.renderer = new WebGLRenderer({antialias: true});

		renderer.setSize(width, height);

		// Chrome Inspect Three.js extension support
		untyped __js__("window.THREE = THREE;");
	}

	public function renderCanvas(renderer : pixi.core.renderers.canvas.CanvasRenderer) {
		if (!this.visible || this.worldAlpha <= 0 || !this.renderable)
		{
			return;
		}

		this.renderer.render(scene, camera);

		var ctx : Dynamic = untyped renderer.context;

		ctx.save();
		ctx.globalAlpha = this.worldAlpha;
		ctx.setTransform(worldTransform.a, worldTransform.b, worldTransform.c, worldTransform.d, worldTransform.tx, worldTransform.ty);
		ctx.drawImage(this.renderer.domElement, 0, 0, getWidth(), getHeight(), 0, 0, getWidth(), getHeight());
		ctx.restore();
	}

	private function getWidth() : Float { return renderer.getSize().width; }
	private function getHeight() : Float { return renderer.getSize().height; }

	private function setWidth(width : Float) : Void { renderer.setSize(width, getHeight()); }
	private function setHeight(height : Float) : Void { renderer.setSize(getWidth(), height); }

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
			}

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
		}

		var lt = toGlobal(new Point(0.0, 0.0));
		var rb = toGlobal(new Point(getWidth(), getHeight()));

		rect.x = lt.x;
		rect.y = lt.y;
		rect.width = rb.x - lt.x;
		rect.height = rb.y - lt.y;

		return rect;
	}
}