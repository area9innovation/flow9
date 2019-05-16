import js.three.Object3D;
import js.three.Box3;

class Object3DHelper {
	public static inline function invalidateStage(object : Object3D) : Void {
		if (untyped object.updateProjectionMatrix != null) {
			untyped object.updateProjectionMatrix();
		}

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

	public static inline function getStage(object : Object3D) : Array<ThreeJSStage> {
		if (object.parent == null) {
			if (untyped object.stage != null) {
				return [untyped object.stage];
			} else {
				return [];
			}
		} else {
			return getStage(object.parent);
		}
	}

	public static function broadcastEvent(parent : Object3D, event : String) : Void {
		parent.dispatchEvent({ type : event });

		var children : Array<Dynamic> = untyped parent.children;
		if (children != null) {
			for (c in children) {
				broadcastEvent(c, event);
			}
		}
	}

	public static function emitEvent(parent : Object3D, event : String) : Void {
		parent.dispatchEvent({ type : event });

		if (parent.parent != null) {
			emitEvent(parent.parent, event);
		}
	}

	public static function add3DChild(parent : Object3D, child : Object3D) : Void {
		if (child.parent != null) {
			child.parent.remove(child);
		}

		parent.add(child);

		emitEvent(parent, "box");
		emitEvent(parent, "childrenchanged");

		broadcastEvent(child, "position");
		broadcastEvent(child, "scale");
		broadcastEvent(child, "rotation");

		invalidateStage(parent);
	}

	public static function add3DChildAt(parent : Object3D, child : Object3D, index : Int) : Void {
		if (child.parent != null) {
			child.parent.remove(child);
		}

		parent.children.insert(index, child);
		child.parent = parent;

		emitEvent(parent, "box");
		emitEvent(parent, "childrenchanged");

		broadcastEvent(child, "position");
		broadcastEvent(child, "scale");
		broadcastEvent(child, "rotation");

		invalidateStage(parent);
	}

	public static function remove3DChild(parent : Object3D, child : Object3D) : Void {
		parent.remove(child);

		emitEvent(parent, "box");
		emitEvent(parent, "childrenchanged");

		invalidateStage(parent);
	}

	public static function remove3DChildren(parent : Object3D) : Void {
		for (child in parent.children) {
			parent.remove(child);
		}

		emitEvent(parent, "box");
		emitEvent(parent, "childrenchanged");

		invalidateStage(parent);
	}

	public static function get3DObjectByUUID(parent : Object3D, id : String) : Array<Object3D> {
		if (parent.uuid == id) {
			return [parent];
		} else for (child in parent.children) {
			var object = get3DObjectByUUID(child, id);

			if (object.length > 0) {
				return object;
			}
		}

		return [];
	}
}