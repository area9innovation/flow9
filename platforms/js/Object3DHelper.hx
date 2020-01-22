import js.three.Object3D;
import js.three.Material;
import js.three.Texture;
import js.three.Box3;
import js.three.Camera;
import js.three.Geometry;

using DisplayObjectHelper;

class Object3DHelper {
	public static inline function invalidateStage(object : Object3D) : Void {
		if (untyped object.updateProjectionMatrix != null) {
			untyped object.updateProjectionMatrix();
		}

		if (getClipWorldVisible(object)) {
			for (stage in getStage(object)) {
				stage.invalidateStage();
			}
		}
	}

	public static inline function invalidateMaterialStage(object : Material) : Void {
		if (untyped object.parent != null) {
			invalidateStage(untyped object.parent);
		}
	}

	public static inline function invalidateTextureStage(object : Texture) : Void {
		if (untyped object.parent != null) {
			invalidateMaterialStage(untyped object.parent);
		}
	}

	public static inline function getClipWorldVisible(object : Object3D) : Bool {
		return object.visible;
	}

	public static inline function getBoundingBox(object : Object3D) : Box3 {
		var completeBoundingBox = new Box3(); // create a new box which will contain the entire values

		if (untyped object.geometry != null) {
			untyped object.geometry.computeBoundingBox(); // compute the bounding box of the the meshes geometry
			var box = untyped object.geometry.boundingBox.clone(); // clone the calculated bounding box, because we have to translate it
			box.translate(object.position); // translate the geometries bounding box by the meshes position
			completeBoundingBox.expandByPoint(box.max).expandByPoint(box.min); // add the max and min values to your completeBoundingBox
		}

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

	public static function emit(parent : Object3D, event : String) : Void {
		parent.dispatchEvent({ type : event });
		parent.dispatchEvent({ type : "change" });
	}

	public static function on(parent : Object3D, event : String, fn : Void -> Void) : Void {
		parent.addEventListener(event, untyped fn);
	}

	public static function off(parent : Object3D, event : String, fn : Void -> Void) : Void {
		parent.removeEventListener(event, untyped fn);
	}

	public static function once(parent : Object3D, event : String, fn : Void -> Void) : Void {
		var disp : Void -> Void = null;
		disp = function() {
			off(parent, event, fn);
			off(parent, event, disp);
		};

		on(parent, event, fn);
		on(parent, event, disp);
	}


	public static function broadcastEvent(parent : Object3D, event : String) : Void {
		parent.dispatchEvent({ type : event });
		parent.dispatchEvent({ type : "change" });

		var children : Array<Dynamic> = untyped parent.children;
		if (children != null) {
			for (c in children) {
				broadcastEvent(c, event);
			}
		}
	}

	public static function emitEvent(parent : Object3D, event : String) : Void {
		parent.dispatchEvent({ type : event });
		parent.dispatchEvent({ type : "change" });

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
			if (untyped child.worldTransformSaved) {
				RenderSupport3D.set3DObjectWorldX(child, RenderSupport3D.get3DObjectLocalPositionX(child));
				RenderSupport3D.set3DObjectWorldY(child, RenderSupport3D.get3DObjectLocalPositionY(child));
				RenderSupport3D.set3DObjectWorldZ(child, RenderSupport3D.get3DObjectLocalPositionZ(child));

				RenderSupport3D.set3DObjectWorldScaleX(child, RenderSupport3D.get3DObjectLocalScaleX(child));
				RenderSupport3D.set3DObjectWorldScaleY(child, RenderSupport3D.get3DObjectLocalScaleY(child));
				RenderSupport3D.set3DObjectWorldScaleZ(child, RenderSupport3D.get3DObjectLocalScaleZ(child));

				RenderSupport3D.set3DObjectWorldRotationX(child, RenderSupport3D.get3DObjectRotationX(child));
				RenderSupport3D.set3DObjectWorldRotationY(child, RenderSupport3D.get3DObjectLocalRotationY(child));
				RenderSupport3D.set3DObjectWorldRotationZ(child, RenderSupport3D.get3DObjectLocalRotationZ(child));
			}

			update3DChildren(parent);

			for (stage in getStage(parent)) {
				for (subChild in child.children) {
					if (untyped HaxeRuntime.instanceof(subChild, Camera)) {
						stage.setCamera(cast(subChild, Camera), []);
						child.remove(subChild);
						subChild.parent = null;
					}
				}

				if (untyped child.interactive && stage.interactiveObjects.indexOf(child) < 0) {
					stage.interactiveObjects.push(child);
				}
			}

			if (invalidate) {
				emitEvent(child, "added");
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

		for (stage in getStage(parent)) {
			untyped stage.objectCache.push(child);

			if (invalidate) { // Do no lose transform controls if it isn't the last operation
				RenderSupport3D.detach3DTransformControls(stage, child);
			}

			if (untyped child.interactive && stage.interactiveObjects.indexOf(child) >= 0) {
				stage.interactiveObjects.remove(child);
			}
		}

		var childrenMap = get3DChildrenMap(parent);

		for (k in childrenMap.keys()) {
			if (childrenMap.get(k) == child) {
				childrenMap.remove(k);
			}
		}

		// Save object world transform while removing from parent

		if (untyped child.saveWorldTransform) {
			RenderSupport3D.set3DObjectLocalPositionX(child, RenderSupport3D.get3DObjectWorldX(child));
			RenderSupport3D.set3DObjectLocalPositionY(child, RenderSupport3D.get3DObjectWorldY(child));
			RenderSupport3D.set3DObjectLocalPositionZ(child, RenderSupport3D.get3DObjectWorldZ(child));

			RenderSupport3D.set3DObjectLocalScaleX(child, RenderSupport3D.get3DObjectWorldScaleX(child));
			RenderSupport3D.set3DObjectLocalScaleY(child, RenderSupport3D.get3DObjectWorldScaleY(child));
			RenderSupport3D.set3DObjectLocalScaleZ(child, RenderSupport3D.get3DObjectWorldScaleZ(child));

			RenderSupport3D.set3DObjectLocalRotationX(child, RenderSupport3D.get3DObjectWorldRotationX(child));
			RenderSupport3D.set3DObjectLocalRotationY(child, RenderSupport3D.get3DObjectWorldRotationY(child));
			RenderSupport3D.set3DObjectLocalRotationZ(child, RenderSupport3D.get3DObjectWorldRotationZ(child));

			untyped child.worldTransformSaved = true;
		}

		parent.remove(child);
		child.parent = null;

		update3DChildren(parent);

		if (invalidate) {
			emitEvent(parent, "box");
			emitEvent(parent, "childrenchanged");

			emitEvent(parent, "change");
			emitEvent(child, "removed");

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

	public static function get3DObjectAllInteractiveChildren(parent : Object3D) : Array<Object3D> {
		var children = Lambda.array(Lambda.filter(parent.children.copy(), function(v) { return untyped v.interactive; }));

		for (child in parent.children) {
			children = children.concat(get3DObjectAllInteractiveChildren(child));
		}

		return children;
	}

	public static function get3DObjectAllGeometries(parent : Object3D) : Array<Geometry> {
		var children : Array<Geometry> =
			Lambda.array(
				Lambda.map(
					Lambda.filter(
						get3DObjectAllChildren(parent),
						function(v) { return untyped v.geometry != null; }
					),
					function(v) { return untyped v.geometry; }
				)
			);

		if (untyped parent.geometry != null) {
			children.push(untyped parent.geometry);
		}

		return children;
	}
}