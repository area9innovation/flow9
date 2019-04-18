import js.three.Object3D;
import js.three.Box3;

class Object3DHelper {
	public static inline function invalidateStage(object : Object3D) : Void {
		if (getClipWorldVisible(object)) {
			RenderSupportJSPixi.InvalidateStage();
		}
	}

	public static inline function getClipWorldVisible(object : Object3D) : Bool {
		return object.visible;
	}

	public static inline function getBoundingBox(object : Object3D) : Box3 {
		var completeBoundingBox = new Box3(); // create a new box which will contain the entire values

		for (child in object.children) { // iterate through the children
			if (untyped child.geometry != null) {
				untyped child.geometry.computeBoundingBox(); // compute the bounding box of the the meshes geometry
				var box = untyped child.geometry.boundingBox.clone(); // clone the calculated bounding box, because we have to translate it
				box.translate(child.position); // translate the geometries bounding box by the meshes position
				completeBoundingBox.expandByPoint(box.max).expandByPoint(box.min); // add the max and min values to your completeBoundingBox
			}
		}

		return completeBoundingBox;
	}
}