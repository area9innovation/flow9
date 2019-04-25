import js.Browser;

class ThreeJSLoader {
	public function new(objUrl : String, mtlUrl : String, onLoad : Dynamic -> Void) {
		untyped __js__("
			new MTLLoader()
				.load(mtlUrl, function (materials) {
					materials.preload();

					new OBJLoader()
						.setMaterials(materials)
						.load(objUrl, onLoad);
				});
		");
	}
}