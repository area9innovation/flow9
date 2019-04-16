import js.Browser;
// import pixi.core.display.Container;
// import pixi.core.display.DisplayObject;
// import pixi.core.math.shapes.Rectangle;
// import pixi.core.math.Point;

// import js.three.Camera;
// import js.three.Scene;
// import js.three.Object3D;
// import js.three.WebGLRenderer;

// using DisplayObjectHelper;

class ThreeJSLoader {
	public function new(objUrl : String, mtlUrl : String, onLoad : Dynamic -> Void) {
		// var ext = url.substr(url.length - 3);

		// trace(ext);

		// if (ext == "mtl") {
		// 	untyped __js__("new THREE.MTLLoader().load(url, function (materials) {
		// 		materials.preload();

		// 		onLoad(materials);
		// 	});");
		// } else if (ext == "obj") {
		// 	untyped __js__("new THREE.OBJLoader().setMaterial(materials).load(url, onLoad);");
		// }

		untyped __js__("
			new THREE.MTLLoader()
				.load(mtlUrl, function (materials) {
					materials.preload();

					new THREE.OBJLoader()
						.setMaterials(materials)
						.load(objUrl, onLoad);
				});
		");
	}
}