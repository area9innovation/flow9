import js.Browser;
import pixi.core.display.Container;
import pixi.core.display.DisplayObject;

import js.three.PerspectiveCamera;
import js.three.Scene;
import js.three.WebGLRenderer;

import js.three.BoxGeometry;
import js.three.Mesh;
import js.three.MeshNormalMaterial;

using DisplayObjectHelper;

class ThreeJSStage extends DisplayObject {
	public var camera : PerspectiveCamera;
	public var scene : Scene;
	public var renderer : WebGLRenderer;

	public function new() {
		super();

		camera = new PerspectiveCamera(70, Browser.window.innerWidth / Browser.window.innerHeight, 0.01, 10);
		camera.position.z = 1;

		scene = new Scene();
		renderer = new WebGLRenderer({antialias: true});

		renderer.setSize(Browser.window.innerWidth, Browser.window.innerHeight);

		var geometry = new BoxGeometry(0.2, 0.2, 0.2);
		var material = new MeshNormalMaterial();

		var mesh = new Mesh(geometry, material);
		scene.add(mesh);
	}

	public function renderCanvas(renderer : pixi.core.renderers.canvas.CanvasRenderer) {
		// if (!this.visible || this.worldAlpha <= 0 || !this.renderable)
		// {
		// 	return;
		// }

		this.renderer.render(scene, camera);
		untyped renderer.context.drawImage(this.renderer.domElement, 0, 0);
	}

	private function getWidth() : Float { return renderer.getSize().width; }
	private function getHeight() : Float { return renderer.getSize().height; }

	private function setWidth(width : Float) : Void { renderer.setSize(width, getHeight()); }
	private function setHeight(height : Float) : Void { renderer.setSize(getWidth(), height); }
}