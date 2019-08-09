import js.three.Object3D;
import js.three.Box3;
import js.three.Camera;

using DisplayObjectHelper;

class Object3DHelper {
	public static inline function invalidateStage(object : Object3D) : Void {
		if (untyped object.updateProjectionMatrix != null) {
			untyped object.updateProjectionMatrix();
		}

		if (getClipWorldVisible(object)) {
			for (stage in getStage(object)) {
				stage.invalidateStage(false);
			}
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

	public static function update3DChildren(parent : Object3D) : Void {
		var childrenMap = get3DChildrenMap(parent);

		parent.children = [for (value in childrenMap.iterator()) value];
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
			remove3DChild(child.parent, child, false);
		}

		var childrenMap = get3DChildrenMap(parent);

		if (childrenMap.get(index) != child) {
			if (childrenMap.get(index) != null) {
				remove3DChild(parent, childrenMap.get(index), false);
			}

			childrenMap.set(index, child);
			child.parent = parent;

			// Apply object world transform while adding to new parent

			RenderSupport3D.set3DObjectWorldX(child, RenderSupport3D.get3DObjectX(child));
			RenderSupport3D.set3DObjectWorldY(child, RenderSupport3D.get3DObjectY(child));
			RenderSupport3D.set3DObjectWorldZ(child, RenderSupport3D.get3DObjectZ(child));

			RenderSupport3D.set3DObjectWorldScaleX(child, RenderSupport3D.get3DObjectScaleX(child));
			RenderSupport3D.set3DObjectWorldScaleY(child, RenderSupport3D.get3DObjectScaleY(child));
			RenderSupport3D.set3DObjectWorldScaleZ(child, RenderSupport3D.get3DObjectScaleZ(child));

			RenderSupport3D.set3DObjectWorldRotationX(child, RenderSupport3D.get3DObjectRotationX(child));
			RenderSupport3D.set3DObjectWorldRotationY(child, RenderSupport3D.get3DObjectRotationY(child));
			RenderSupport3D.set3DObjectWorldRotationZ(child, RenderSupport3D.get3DObjectRotationZ(child));

			update3DChildren(parent);

			var stage = getStage(parent);

			if (stage.length > 0) {
				for (subChild in child.children) {
					if (untyped __instanceof__(subChild, Camera)) {
						stage[0].setCamera(cast(subChild, Camera));
						child.remove(subChild);
						subChild.parent = null;
					}
				}
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
		if (child.parent != parent) {
			return;
		}

		var stage = getStage(parent);

		if (stage.length > 0) {
			untyped stage[0].objectCache.push(child);

			if (invalidate) { // Do no lose transform controls if it isn't the last operation
				RenderSupport3D.detach3DTransformControls(stage[0], child);
			}
		}

		var childrenMap = get3DChildrenMap(parent);

		for (k in childrenMap.keys()) {
			if (childrenMap.get(k) == child) {
				childrenMap.remove(k);
			}
		}

		// Save object world transform while removing from parent

		RenderSupport3D.set3DObjectX(child, RenderSupport3D.get3DObjectWorldX(child));
		RenderSupport3D.set3DObjectY(child, RenderSupport3D.get3DObjectWorldY(child));
		RenderSupport3D.set3DObjectZ(child, RenderSupport3D.get3DObjectWorldZ(child));

		RenderSupport3D.set3DObjectScaleX(child, RenderSupport3D.get3DObjectWorldScaleX(child));
		RenderSupport3D.set3DObjectScaleY(child, RenderSupport3D.get3DObjectWorldScaleY(child));
		RenderSupport3D.set3DObjectScaleZ(child, RenderSupport3D.get3DObjectWorldScaleZ(child));

		RenderSupport3D.set3DObjectRotationX(child, RenderSupport3D.get3DObjectWorldRotationX(child));
		RenderSupport3D.set3DObjectRotationY(child, RenderSupport3D.get3DObjectWorldRotationY(child));
		RenderSupport3D.set3DObjectRotationZ(child, RenderSupport3D.get3DObjectWorldRotationZ(child));

		parent.remove(child);
		child.parent = null;

		update3DChildren(parent);

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

	public static function get3DObjectByUUID(parent : Object3D, id : String, ?checkObjectCache : Bool = true) : Array<Object3D> {
		if (parent.uuid == id) {
			return [parent];
		}

		if (checkObjectCache) {
			var stage = getStage(parent);

			if (stage.length > 0) {
				var objectCache : Array<Object3D> = untyped stage[0].objectCache;

				for (child in objectCache) {
					var object = get3DObjectByUUID(child, id, false);

					if (object.length > 0) {
						return object;
					}
				}
			}
		}

		for (child in parent.children) {
			var object = get3DObjectByUUID(child, id, false);

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