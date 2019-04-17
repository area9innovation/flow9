import js.three.Object3D;

class Object3DHelper {
	public static inline function invalidateStage(object : Object3D) : Void {
		if (getClipWorldVisible(object)) {
			RenderSupportJSPixi.InvalidateStage();
		}
	}

	public static inline function getClipWorldVisible(object : Object3D) : Bool {
		return object.visible;
	}
}