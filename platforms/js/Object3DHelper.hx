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

	public static function get3DChildrenMap(parent : Object3D) : Map<Int, Object3D> {
		if (untyped parent.childrenMap == null) {
			untyped parent.childrenMap = new Map<Int, Object3D>();
		}

		return untyped parent.childrenMap;
	}

	public static function add3DChild(parent : Object3D, child : Object3D, ?invalidate : Bool = true) : Void {
		var childrenMap = get3DChildrenMap(parent);

		if (child.parent != null) {
			if (child.parent == parent) {
				return;
			}

			remove3DChild(child.parent, child, false);
		}

		var index = 0;

		for (k in childrenMap.keys()) {
			if (k >= index) {
				index = k + 1;
			}
		}

		add3DChildAt(parent, child, index, invalidate);
	}

	public static function add3DChildAt(parent : Object3D, child : Object3D, index : Int, ?invalidate : Bool = true) : Void {
		if (child.parent != null) {
			if (child.parent == parent) {
				invalidate = false;
			}

			remove3DChild(child.parent, child, false);
		}

		var childrenMap = get3DChildrenMap(parent);

		if (childrenMap.get(index) != child) {
			if (childrenMap.get(index) != null) {
				remove3DChild(parent, childrenMap.get(index), false);
			}

			childrenMap.set(index, child);
			child.parent = parent;

			for (k in childrenMap.keys()) {
				parent.children[k] = childrenMap.get(k);
			}

			if (invalidate) {
				emitEvent(parent, "box");
				emitEvent(parent, "childrenchanged");

				broadcastEvent(child, "position");
				broadcastEvent(child, "scale");
				broadcastEvent(child, "rotation");

				emitEvent(parent, "change");

				invalidateStage(parent);
			}
		}
	}

	public static function remove3DChild(parent : Object3D, child : Object3D, ?invalidate : Bool = true) : Void {
		var childrenMap = get3DChildrenMap(parent);

		for (k in childrenMap.keys()) {
			if (childrenMap.get(k) == child) {
				childrenMap.remove(k);
			}
		}

		var stage = getStage(child);

		if (stage.length > 0) {
			untyped stage[0].objectCache.push(child);
		}

		parent.remove(child);
		child.parent = null;

		if (invalidate) {
			emitEvent(parent, "box");
			emitEvent(parent, "childrenchanged");

			emitEvent(parent, "change");

			invalidateStage(parent);
		}
	}

	public static function remove3DChildren(parent : Object3D, ?invalidate : Bool = true) : Void {
		for (child in parent.children) {
			remove3DChild(parent, child, false);
		}

		if (invalidate) {
			emitEvent(parent, "box");
			emitEvent(parent, "childrenchanged");

			emitEvent(parent, "change");

			invalidateStage(parent);
		}
	}

	public static function get3DObjectByUUID(parent : Object3D, id : String) : Array<Object3D> {
		if (parent.uuid == id) {
			return [parent];
		}

		if (untyped parent.stage != null) {
			var objectCache : Array<Object3D> = untyped parent.stage.objectCache;

			for (child in objectCache) {
				var object = get3DObjectByUUID(child, id);

				if (object.length > 0) {
					return object;
				}
			}
		}

		for (child in parent.children) {
			var object = get3DObjectByUUID(child, id);

			if (object.length > 0) {
				return object;
			}
		}

		return [];
	}

	public static function get3DObjectAllChildren(parent : Object3D) : Array<Object3D> {
		var children = parent.children.copy();

		for (child in parent.children) {
			children = children.concat(get3DObjectAllChildren(child));
		}

		return children;
	}
}