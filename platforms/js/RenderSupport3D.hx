import js.Browser;

import js.three.Scene;
import js.three.Fog;

import js.three.Color;
import js.three.Vector3;
import js.three.Euler;
import js.three.Quaternion;

import js.three.Object3D;
import js.three.Mesh;

import js.three.Camera;
import js.three.PerspectiveCamera;
import js.three.OrbitControls;
import js.three.TransformControls;
import js.three.BoxHelper;

import js.three.Geometry;
import js.three.PlaneGeometry;
import js.three.BoxGeometry;
import js.three.CircleGeometry;
import js.three.RingGeometry;
import js.three.ConeGeometry;
import js.three.CylinderGeometry;
import js.three.SphereGeometry;

import js.three.BufferGeometry;
import js.three.SphereBufferGeometry;

import js.three.Material;
import js.three.MeshBasicMaterial;
import js.three.MeshStandardMaterial;

import js.three.Texture;

import js.three.Light;
import js.three.PointLight;
import js.three.SpotLight;
import js.three.AmbientLight;

import js.three.GridHelper;
import js.three.PointLightHelper;
import js.three.SpotLightHelper;

import js.three.TextureLoader;
import js.three.ObjectLoader;

import js.three.AnimationClip;
import js.three.AnimationMixer;
import js.three.Clock;

using DisplayObjectHelper;
using Object3DHelper;

class RenderSupport3D {
	public static function load3DLibraries(cb : Void -> Void) : Void {
		if (untyped __js__("typeof THREE === 'undefined'")) {
			var head = Browser.document.getElementsByTagName('head')[0];
			var jscounter = 0;
			var onloadFn = function() {
				jscounter++;

				if (jscounter > 4) {
					cb();
				}
			}

			var node = Browser.document.createElement('script');
			node.setAttribute("type","text/javascript");
			node.setAttribute("src", 'js/threejs/three.min.js');
			node.onload = function() {
				var node = Browser.document.createElement('script');
				node.setAttribute("type","text/javascript");
				node.setAttribute("src", 'js/threejs/MTLLoader.js');
				node.onload = onloadFn;
				head.appendChild(node);

				node = Browser.document.createElement('script');
				node.setAttribute("type","text/javascript");
				node.setAttribute("src", 'js/threejs/OBJLoader.js');
				node.onload = onloadFn;
				head.appendChild(node);

				node = Browser.document.createElement('script');
				node.setAttribute("type","text/javascript");
				node.setAttribute("src", 'js/threejs/GLTFLoader.js');
				node.onload = onloadFn;
				head.appendChild(node);

				node = Browser.document.createElement('script');
				node.setAttribute("type","text/javascript");
				node.setAttribute("src", 'js/threejs/OrbitControls.js');
				node.onload = onloadFn;
				head.appendChild(node);

				node = Browser.document.createElement('script');
				node.setAttribute("type","text/javascript");
				node.setAttribute("src", 'js/threejs/TransformControls.js');
				node.onload = onloadFn;
				head.appendChild(node);
			};
			head.appendChild(node);
		} else {
			cb();
		}
	}

	public static function add3DChild(parent : Object3D, child : Object3D) : Void {
		parent.add3DChild(child);
	}

	public static function add3DChildAt(parent : Object3D, child : Object3D, index : Int) : Void {
		parent.add3DChildAt(child, index);
	}

	public static function remove3DChild(parent : Object3D, child : Object3D) : Void {
		parent.remove3DChild(child);
	}

	public static function remove3DChildren(parent : Object3D) : Void {
		parent.remove3DChildren();
	}

	public static function get3DObjectChildren(object : Object3D) : Array<Object3D> {
		return object.children.copy();
	}

	public static function get3DObjectJSON(object : Object3D, includeCamera : Bool) : String {
		if (includeCamera) {
			var stage = get3DObjectStage(object);

			if (stage.length > 0) {
				var camera = stage[0].camera;

				if (camera != null) {
					object.add3DChild(camera, false);
				}

				var json = haxe.Json.stringify(object.toJSON());

				if (camera != null) {
					object.remove3DChild(camera, false);
				}

				return json;
			}
		}

		return haxe.Json.stringify(object.toJSON());
	}

	public static function get3DObjectState(object : Object3D) : String {
		var obj : Dynamic = {};

		copyObjectProperties(object, obj);

		obj.childrenMap = new Array<Array<Dynamic>>();

		var objectChildren : Map<Int, Object3D> = object.get3DChildrenMap();
		var objChildren : Array<Array<Dynamic>> = obj.childrenMap;

		for (key in objectChildren.keys()) {
			objChildren.push([key, get3DObjectState(objectChildren.get(key))]);
		}

		return haxe.Json.stringify(obj);
	}

	public static function apply3DObjectState(object : Object3D, state : String) : Void {
		var obj = haxe.Json.parse(state);

		apply3DObjectStateFromObject(object, obj);
		object.invalidateStage();
	}

	private static function apply3DObjectStateFromObject(object : Object3D, obj : Dynamic, ?stage : Dynamic) : Void {
		if (stage == null) {
			stage = object.getStage();
		}

		if (stage.length == 0) {
			return;
		}

		copyObjectProperties(obj, object);

		var objectChildren : Map<Int, Object3D> = object.get3DChildrenMap();
		var objChildren : Array<Array<Dynamic>> = obj.childrenMap.map(function(child) {
			var childObj = haxe.Json.parse(child[1]);

			return untyped [child[0], childObj, get3DObjectById(stage[0], get3DObjectId(childObj))[0]];
		});

		for (child in objChildren) {
			if (child[1] != null) {
				RenderSupport3D.apply3DObjectStateFromObject(child[2], child[1], stage);
				object.add3DChildAt(child[2], child[0]);
			}
		}
	}

	private static function copyObjectProperties(object1 : Dynamic, object2 : Dynamic) : Void {
		untyped __js__("
			for (var property in object1) {
				if (typeof object1[property] != 'undefined' && typeof object1[property] != 'function'
					&& property != 'children' && property != 'geometry' && property != 'childrenMap'
					&& property != 'stage' && property != 'transformControls' && property != 'parent' && property != '_listeners'
					&& property != 'material') {

					if (Array.isArray(object1[property]) || object1[property] instanceof String) {
						object2[property] = object1[property];
					} else if (typeof object1[property] != 'object' && typeof object2[property] != 'object') {
						object2[property] = object1[property];
					} else {
						if (typeof object2[property] == 'undefined') {
							object2[property] = new Object();
						}

						RenderSupport3D.copyObjectProperties(object1[property], object2[property]);
					}
				}
			}
		");
	}

	public static function make3DObjectFromJSON(json : String) : Object3D {
		json = haxe.Json.parse(json);
		return new ObjectLoader().parse(json);
	}

	public static function make3DObjectFromObj(obj : String, mtl : String) : Object3D {
		return untyped __js__("new THREE.OBJLoader().setMaterials(new THREE.MTLLoader().parse(mtl)).parse(obj)");
	}

	public static function make3DGeometryFromJSON(json : String) : Object3D {
		json = haxe.Json.parse(json);
		var geometry : Object3D = untyped __js__("new THREE.ObjectLoader().parseGeometries(json)");

		if (haxe.Json.stringify(geometry) == "{}") {
			return untyped __js__("new THREE.ObjectLoader().parse(json).geometry");
		} else {
			return geometry;
		}
	}

	public static function make3DMaterialsFromJSON(json : String) : Object3D {
		json = haxe.Json.parse(json);
		var materials : Object3D = untyped __js__("new THREE.ObjectLoader().parseMaterials(json)");

		if (haxe.Json.stringify(materials) == "{}") {
			return untyped __js__("new THREE.ObjectLoader().parse(json).material");
		} else {
			return materials;
		}
	}

	public static function make3DStage(width : Float, height : Float) : ThreeJSStage {
		return new ThreeJSStage(width, height);
	}

	public static function make3DScene() : Scene {
		return new Scene();
	}

	public static function make3DColor(color : String) : Color {
		return new Color(color);
	}

	public static function set3DSceneBackground(scene : Scene, background : Dynamic) : Void {
		scene.background = background;
		scene.invalidateStage();
	}

	public static function set3DSceneFog(scene : Scene, fog : Fog) : Void {
		scene.fog = fog;
		scene.invalidateStage();
	}


	public static function load3DObject(objUrl : String, mtlUrl : String, onLoad : Dynamic -> Void) : Void {
		if (Platform.isIE || Platform.isEdge) {
			untyped __js__("
				new THREE.MTLLoader()
					.load(mtlUrl, function (materials) {
						materials.preload();

						new THREE.OBJLoader()
							.setMaterials(materials)
							.load(objUrl, onLoad);
					})
			");
		} else {
			untyped __js__("
				eval(\"import('./js/threejs/MTLLoader2.js')\".concat(
					\".then((module) => {\",
					\"import('./js/threejs/OBJLoader2.js')\",
					\".then((module2) => {\",
					\"import('./js/threejs/obj2/bridge/MtlObjBridge.js')\",
					\".then((module3) => {\",
					\"new module.MTLLoader()\",
					\".load(mtlUrl, function(materials) {\",
					\"new module2.OBJLoader2()\",
					\".addMaterials(module3.MtlObjBridge.addMaterialsFromMtlLoader(materials))\",
					\".load(objUrl, onLoad);\",
					\"});\",
					\"});\",
					\"});\",
					\"})\"
				))
			");
		}
	}

	public static function load3DGLTFObject(url : String, onLoad : Array<Dynamic> -> Dynamic -> Array<Dynamic> -> Array<Dynamic> -> Dynamic -> Void) : Void {
		untyped __js__("
			new THREE.GLTFLoader()
				.load(url, function (gltf) {
					onLoad(
						gltf.animations, // Array<THREE.AnimationClip>
						gltf.scene, // THREE.Scene
						gltf.scenes, // Array<THREE.Scene>
						gltf.cameras, // Array<THREE.Camera>
						gltf.asset // Object
					);
				});
		");
	}

	public static function load3DScene(url : String, onLoad : Dynamic -> Void) : Void {
		new ObjectLoader().load(url, onLoad);
	}

	public static function load3DTexture(object : Material, url : String, parameters : Array<Array<String>>) : Material {
		untyped object.map = new TextureLoader().load(url, function(e) {
			for (child in RenderSupportJSPixi.PixiStage.children) {
				child.invalidateTransform('InvalidateLocalStages');
			}
		});

		for (par in parameters) {
			untyped object.map[par[0]] = untyped __js__("eval(par[1])");
		}

		return object;
	}

	public static function make3DDataTexture(object : Material, data : Array<Int>, width : Int, height : Int, parameters : Array<Array<String>>) : Material {
		untyped __js__("
			var size = width * height;
			var udata = new Uint8Array(3 * size);

			for (var i = 0; i < size; i++) {
				var stride = i * 3;

				udata[stride] = data[stride];
				udata[stride + 1] = data[stride + 1];
				udata[stride + 2] = data[stride + 2];
			}

			object.map = new THREE.DataTexture(udata, width, height, THREE.RGBFormat);
		");

		for (par in parameters) {
			untyped object.map[par[0]] = untyped __js__("eval(par[1])");
		}

		return object;
	}

	public static function make3DCanvasTexture(object : Material, clip : FlowContainer) : Material {
		var container = new FlowCanvas();

		container.addChild(clip);
		RenderSupportJSPixi.mainRenderClip().addChild(container);
		RenderSupportJSPixi.render();

		var texture = new Texture(untyped container.nativeWidget);
		texture.needsUpdate = true;
		untyped object.map = texture;

		RenderSupportJSPixi.mainRenderClip().removeChild(container);
		RenderSupportJSPixi.render();

		return object;
	}


	public static function set3DMaterialRotation(object : Material, rotation : Float) : Void {
		if (untyped object.map != null && object.map.rotation != rotation) {
			untyped object.map.rotation = rotation;
		}
	}

	public static function get3DMaterialRotation(object : Material) : Float {
		return untyped object.map != null && object.map.rotation != null ? object.map.rotation : 0.0;
	}

	public static function set3DMaterialOffsetX(object : Material, x : Float) : Void {
		if (untyped object.map != null && object.map.offset.x != x) {
			untyped object.map.offset.x = x;
		}
	}

	public static function get3DMaterialOffsetX(object : Material) : Float {
		return untyped object.map != null && object.map.offset != null ? object.map.offset.x : 0.0;
	}

	public static function set3DMaterialOffsetY(object : Material, y : Float) : Void {
		if (untyped object.map != null && object.map.offset.y != y) {
			untyped object.map.offset.y = y;
		}
	}

	public static function get3DMaterialOffsetY(object : Material) : Float {
		return untyped object.map != null && object.map.offset != null ? object.map.offset.y : 0.0;
	}


	public static function make3DAxesHelper(size : Float) : Object3D {
		return untyped __js__("new THREE.AxesHelper(size)");
	}

	public static function make3DGridHelper(size : Float, divisions : Int, colorCenterLine : Int, colorGrid : Int) : Object3D {
		return new GridHelper(size, divisions, new Color(colorCenterLine), new Color(colorGrid));
	}


	public static function set3DCamera(stage : ThreeJSStage, camera : Camera) : Void {
		stage.setCamera(camera);
	}

	public static function set3DScene(stage : ThreeJSStage, scene : Scene) : Void {
		stage.setScene(scene);
	}


	static function add3DEventListener(object : Object3D, event : String, cb : Void -> Void) : Void -> Void {
		object.addEventListener(event, untyped cb);

		return function() {
			object.removeEventListener(event, untyped cb);
		};
	}

	static function emit3DMouseEvent(stage : ThreeJSStage, event : String, x : Float, y : Float) : Void {
		if (stage.scene == null) {
			return;
		}

		var ev : Dynamic = null;

		if (event == "mousemiddledown" || event == "mousemiddleup") {
			ev = Platform.isIE || Platform.isSafari
				? untyped __js__("new CustomEvent(event == 'mousemiddledown' ? 'mousedown' : 'mouseup')")
				: new js.html.Event(event == "mousemiddledown" ? "mousedown" : "mouseup");

			untyped ev.button = 1;
		} else if (event == "mouserightdown" || event == "mouserightup") {
			ev = Platform.isIE || Platform.isSafari
				? untyped __js__("new CustomEvent(event == 'mouserightdown' ? 'mousedown' : 'mouseup')")
				: new js.html.Event(event == "mouserightdown" ? "mousedown" : "mouseup");

			untyped ev.button = 2;
		} else {
			ev = Platform.isIE || Platform.isSafari
				? untyped __js__("new CustomEvent(event)")
				: new js.html.Event(event);

			if (event == "mousedown" || event == "mouseup") {
				untyped ev.button = 0;
			}
		}

		if (stage.ctrlKey) {
			ev.ctrlKey == true;
		}

		if (stage.metaKey) {
			ev.metaKey == true;
		}

		if (stage.shiftKey) {
			ev.shiftKey == true;
		}

		if (event == "wheel") {
			untyped ev.deltaX = x;
			untyped ev.deltaY = y;
		} else {
			untyped ev.pageX = x;
			untyped ev.pageY = y;
		}

		stage.renderer.domElement.dispatchEvent(ev);
		stage.scene.invalidateStage();
	}

	static function emit3DKeyEvent(stage : ThreeJSStage, event : String, key : String, ctrl : Bool, shift : Bool, alt : Bool, meta : Bool, keyCode : Int) : Void {
		var ke = {key : key, ctrlKey : ctrl, shiftKey : shift, altKey : alt, metaKey : meta, keyCode : keyCode};

		stage.ctrlKey = ctrl;
		stage.shiftKey = shift;
		stage.metaKey = meta;

		stage.renderer.domElement.dispatchEvent(new js.html.KeyboardEvent(event, ke));
		stage.scene.invalidateStage();
	}

	public static function attach3DTransformControls(stage : ThreeJSStage, object : Object3D) : Void {
		if (stage.transformControls != null) {
		 	if (untyped object.transformControls != null) {
		 		if (untyped object.transformControls.object != null) {
		 			detach3DTransformControls(stage, untyped object.transformControls.object);
		 		}
			} else {
				if (stage.transformControls.object != null) {
					if (stage.transformControls.object == object) {
						return;
					} else {
						stage.transformControls.object.dispatchEvent({ type : "detached" });
					}
				}

				stage.transformControls.attach(object);

				if (stage.transformControls.object != null) {
					stage.transformControls.object.dispatchEvent({ type : "attached" });
				}
			}
		}
	}

	public static function detach3DTransformControls(stage : ThreeJSStage, object : Object3D) : Void {
		if (stage.transformControls != null) {
			if (stage.transformControls.object == object) {
				stage.transformControls.object.dispatchEvent({ type : "detached" });
				stage.transformControls.detach();
			} else for (child in object.children) {
				detach3DTransformControls(stage, child);
			}
		}
	}

	public static function clear3DTransformControls(stage : ThreeJSStage) : Void {
		if (stage.transformControls != null && stage.transformControls.object != null && (stage.orbitControls == null || stage.orbitControls.enabled)) {
			stage.transformControls.object.dispatchEvent({ type : "detached" });
			stage.transformControls.detach();
		}
	}

	public static function is3DTransformControlsAttached(stage : ThreeJSStage, object : Object3D) : Bool {
		if (stage.transformControls != null) {
			return stage.transformControls.object == object;
		}

		return false;
	}


	public static function set3DTransformControlsSpace(stage : ThreeJSStage, local : Bool) : Void {
		if (stage.transformControls != null) {
			stage.transformControls.setSpace(local ? "local" : "world");
		}
	}

	public static function is3DTransformControlsSpaceLocal(stage : ThreeJSStage) : Bool {
		return stage.transformControls != null ? stage.transformControls.space == "local" : false;
	}

	public static function set3DTransformControlsMode(stage : ThreeJSStage, mode : String) : Void {
		if (stage.transformControls != null) {
			stage.transformControls.setMode(mode);
		}
	}

	public static function get3DTransformControlsMode(stage : ThreeJSStage) : String {
		return stage.transformControls != null ? stage.transformControls.mode : "";
	}

	public static function set3DTransformControlsTranslationSnap(stage : ThreeJSStage, snap : Float) : Void {
		if (stage.transformControls != null) {
			stage.transformControls.setTranslationSnap(snap);
		}
	}

	public static function get3DTransformControlsTranslationSnap(stage : ThreeJSStage) : Float {
		return stage.transformControls != null ? stage.transformControls.translationSnap : -1.0;
	}

	public static function set3DTransformControlsRotationSnap(stage : ThreeJSStage, snap : Float) : Void {
		if (stage.transformControls != null) {
			stage.transformControls.setRotationSnap(js.three.Math.degToRad(snap));
		}
	}

	public static function get3DTransformControlsRotationSnap(stage : ThreeJSStage) : Float {
		return stage.transformControls != null ? stage.transformControls.rotationSnap : -1.0;
	}

	public static function set3DTransformControlsSize(stage : ThreeJSStage, size : Float) : Void {
		if (stage.transformControls != null) {
			stage.transformControls.setSize(size);
		}
	}

	public static function get3DTransformControlsSize(stage : ThreeJSStage) : Float {
		return stage.transformControls != null ? stage.transformControls.size : -1.0;
	}

	public static function set3DTransformControlsShowX(stage : ThreeJSStage, show : Bool) : Void {
		if (stage.transformControls != null) {
			stage.transformControls.showX = show;
		}
	}

	public static function get3DTransformControlsShowX(stage : ThreeJSStage) : Bool {
		return stage.transformControls != null ? stage.transformControls.showX : false;
	}

	public static function set3DTransformControlsShowY(stage : ThreeJSStage, show : Bool) : Void {
		if (stage.transformControls != null) {
			stage.transformControls.showY = show;
		}
	}

	public static function get3DTransformControlsShowY(stage : ThreeJSStage) : Bool {
		return stage.transformControls != null ? stage.transformControls.showY : false;
	}

	public static function set3DTransformControlsShowZ(stage : ThreeJSStage, show : Bool) : Void {
		if (stage.transformControls != null) {
			stage.transformControls.showZ = show;
		}
	}

	public static function get3DTransformControlsShowZ(stage : ThreeJSStage) : Bool {
		return stage.transformControls != null ? stage.transformControls.showZ : false;
	}

	public static function set3DTransformControlsEnabled(stage : ThreeJSStage, enabled : Bool) : Void {
		if (stage.transformControls != null) {
			stage.transformControls.enabled = enabled;
		}
	}

	public static function get3DTransformControlsEnabled(stage : ThreeJSStage) : Bool {
		return stage.transformControls != null ? stage.transformControls.enabled : false;
	}


	public static function attach3DBoxHelper(stage : ThreeJSStage, object : Object3D) : Void {
		if (untyped object.boxHelper == null) {
			if (untyped __instanceof__(object, PointLight)) {
				var boxHelper = new PointLightHelper(untyped object, untyped object.distance);
				untyped boxHelper.disposers = [];

				stage.boxHelpers.push(boxHelper);
				untyped object.boxHelper = boxHelper;
			} else if (untyped __instanceof__(object, SpotLight)) {
				var boxHelper = new SpotLightHelper(untyped object);
				untyped boxHelper.disposers = [];

				stage.boxHelpers.push(boxHelper);
				untyped object.boxHelper = boxHelper;
			} else {
				var boxHelper = new BoxHelper();
				var fn = function(a, b, c) {
					untyped boxHelper.setFromObject(object);
				};
				untyped boxHelper.disposers =
					[
						add3DObjectPositionListener(object, fn),
						add3DObjectScaleListener(object, fn),
						add3DObjectRotationListener(object, fn)
					];

				stage.boxHelpers.push(boxHelper);
				untyped object.boxHelper = boxHelper;
			}
		}
	}

	public static function detach3DBoxHelper(stage : ThreeJSStage, object : Object3D) : Void {
		if (untyped object.boxHelper != null) {
			var disposers : Array<Void -> Void> = untyped object.boxHelper.disposers;

			for (d in disposers) {
				d();
			}

			stage.boxHelpers.remove(untyped object.boxHelper);
			untyped object.boxHelper = null;
		}
	}

	public static function clear3DBoxHelpers(stage : ThreeJSStage) : Void {
		for (bh in stage.boxHelpers) {
			var disposers : Array<Void -> Void> = untyped bh.disposers;

			for (d in disposers) {
				d();
			}
		}

		stage.boxHelpers = new Array<Object3D>();
	}

	public static function get3DObjectId(object : Object3D) : String {
		return object.uuid;
	}

	public static function get3DObjectById(stage : ThreeJSStage, id : String) : Array<Object3D> {
		if (stage.scene != null) {
			return stage.scene.get3DObjectByUUID(id);
		} else {
			return [];
		}
	}

	public static function get3DObjectType(object : Object3D) : String {
		return object.type;
	}

	public static function get3DObjectStage(object : Object3D) : Array<ThreeJSStage> {
		return object.getStage();
	}

	public static function get3DStageScene(stage : ThreeJSStage) : Array<Scene> {
		return stage.scene != null ? [stage.scene] : [];
	}

	public static function get3DObjectName(object : Object3D) : String {
		return object.name;
	}

	public static function set3DObjectName(object : Object3D, name : String) : Void {
		if (object.name != name) {
			object.name = name;

			object.emitEvent("namechange");
		}
	}

	public static function get3DObjectVisible(object : Object3D) : Bool {
		return object.visible;
	}

	public static function set3DObjectVisible(object : Object3D, visible : Bool) : Void {
		if (object.visible != visible) {
			object.visible = visible;

			object.broadcastEvent("visiblechanged");
			object.emitEvent("change");

			object.invalidateStage();
		}
	}

	public static function get3DObjectAlpha(object : Object3D) : Float {
		return untyped object.material != null ? object.material.opacity : 0.0;
	}

	public static function set3DObjectAlpha(object : Object3D, alpha : Float) : Void {
		if (untyped object.material != null && object.material.opacity != alpha) {
			untyped object.material.transparent = true;
			untyped object.material.opacity = alpha;

			object.broadcastEvent("visiblechanged");
			object.emitEvent("change");

			object.invalidateStage();
		}
	}

	public static function get3DObjectCastShadow(object : Object3D) : Bool {
		return object.castShadow;
	}

	public static function set3DObjectCastShadow(object : Object3D, castShadow : Bool) : Void {
		if (object.castShadow != castShadow) {
			object.castShadow = castShadow;

			object.broadcastEvent("shadowchanged");
			object.emitEvent("change");

			object.invalidateStage();
		}
	}

	public static function get3DObjectReceiveShadow(object : Object3D) : Bool {
		return object.receiveShadow;
	}

	public static function set3DObjectReceiveShadow(object : Object3D, receiveShadow : Bool) : Void {
		if (object.receiveShadow != receiveShadow) {
			object.receiveShadow = receiveShadow;

			object.broadcastEvent("shadowchanged");
			object.emitEvent("change");

			object.invalidateStage();
		}
	}

	public static function get3DObjectFrustumCulled(object : Object3D) : Bool {
		return object.frustumCulled;
	}

	public static function set3DObjectFrustumCulled(object : Object3D, frustumCulled : Bool) : Void {
		if (object.frustumCulled != frustumCulled) {
			object.frustumCulled = frustumCulled;

			object.broadcastEvent("frustumchanged");
			object.emitEvent("change");

			object.invalidateStage();
		}
	}

	public static function get3DObjectX(object : Object3D) : Float {
		return object.position.x;
	}

	public static function get3DObjectY(object : Object3D) : Float {
		return object.position.y;
	}

	public static function get3DObjectZ(object : Object3D) : Float {
		return object.position.z;
	}

	public static function set3DObjectX(object : Object3D, x : Float) : Void {
		if (object.position.x != x) {
			object.position.x = x;

			object.broadcastEvent("position");
			object.emitEvent("change");

			object.invalidateStage();
		}
	}

	public static function set3DObjectY(object : Object3D, y : Float) : Void {
		if (object.position.y != y) {
			object.position.y = y;

			object.broadcastEvent("position");
			object.emitEvent("change");

			object.invalidateStage();
		}
	}

	public static function set3DObjectZ(object : Object3D, z : Float) : Void {
		if (object.position.z != z) {
			object.position.z = z;

			object.broadcastEvent("position");
			object.emitEvent("change");

			object.invalidateStage();
		}
	}



	public static function get3DObjectRotationX(object : Object3D) : Float {
		return object.rotation.x / 0.0174532925 /*degrees*/;
	}

	public static function get3DObjectRotationY(object : Object3D) : Float {
		return object.rotation.y / 0.0174532925 /*degrees*/;
	}

	public static function get3DObjectRotationZ(object : Object3D) : Float {
		return object.rotation.z / 0.0174532925 /*degrees*/;
	}

	public static function set3DObjectRotationX(object : Object3D, x : Float) : Void {
		x = x * 0.0174532925 /*radians*/;

		if (object.rotation.x != x) {
			object.rotation.x = x;

			object.broadcastEvent("position");
			object.broadcastEvent("rotation");
			object.emitEvent("change");

			object.invalidateStage();
		}
	}

	public static function set3DObjectRotationY(object : Object3D, y : Float) : Void {
		y = y * 0.0174532925 /*radians*/;

		if (object.rotation.y != y) {
			object.rotation.y = y;

			object.broadcastEvent("position");
			object.broadcastEvent("rotation");
			object.emitEvent("change");

			object.invalidateStage();
		}
	}

	public static function set3DObjectRotationZ(object : Object3D, z : Float) : Void {
		z = z * 0.0174532925 /*radians*/;

		if (object.rotation.z != z) {
			object.rotation.z = z;

			object.broadcastEvent("position");
			object.broadcastEvent("rotation");
			object.emitEvent("change");

			object.invalidateStage();
		}
	}



	public static function get3DObjectScaleX(object : Object3D) : Float {
		return object.scale.x;
	}

	public static function get3DObjectScaleY(object : Object3D) : Float {
		return object.scale.y;
	}

	public static function get3DObjectScaleZ(object : Object3D) : Float {
		return object.scale.z;
	}

	public static function set3DObjectScaleX(object : Object3D, x : Float) : Void {
		if (object.scale.x != x) {
			object.scale.x = x;

			object.broadcastEvent("position");
			object.broadcastEvent("scale");
			object.emitEvent("change");

			object.invalidateStage();
		}
	}

	public static function set3DObjectScaleY(object : Object3D, y : Float) : Void {
		if (object.scale.y != y) {
			object.scale.y = y;

			object.broadcastEvent("position");
			object.broadcastEvent("scale");
			object.emitEvent("change");

			object.invalidateStage();
		}
	}

	public static function set3DObjectScaleZ(object : Object3D, z : Float) : Void {
		if (object.scale.z != z) {
			object.scale.z = z;

			object.broadcastEvent("position");
			object.broadcastEvent("scale");
			object.emitEvent("change");

			object.invalidateStage();
		}
	}



	public static function get3DObjectWorldX(object : Object3D) : Float {
		return object.getWorldPosition(new Vector3()).x;
	}

	public static function get3DObjectWorldY(object : Object3D) : Float {
		return object.getWorldPosition(new Vector3()).y;
	}

	public static function get3DObjectWorldZ(object : Object3D) : Float {
		return object.getWorldPosition(new Vector3()).z;
	}

	public static function set3DObjectWorldX(object : Object3D, x : Float) : Void {
		set3DObjectX(object, object.parent != null ? x - get3DObjectWorldX(object.parent) : x);
	}

	public static function set3DObjectWorldY(object : Object3D, y : Float) : Void {
		set3DObjectY(object, object.parent != null ? y - get3DObjectWorldY(object.parent) : y);
	}

	public static function set3DObjectWorldZ(object : Object3D, z : Float) : Void {
		set3DObjectZ(object, object.parent != null ? z - get3DObjectWorldZ(object.parent) : z);
	}



	public static function get3DObjectWorldRotationX(object : Object3D) : Float {
		var euler = new Euler();
		euler.setFromQuaternion(object.getWorldQuaternion(new Quaternion()));

		return euler.x / 0.0174532925 /*degrees*/;
	}

	public static function get3DObjectWorldRotationY(object : Object3D) : Float {
		var euler = new Euler();
		euler.setFromQuaternion(object.getWorldQuaternion(new Quaternion()));

		return euler.y / 0.0174532925 /*degrees*/;
	}

	public static function get3DObjectWorldRotationZ(object : Object3D) : Float {
		var euler = new Euler();
		euler.setFromQuaternion(object.getWorldQuaternion(new Quaternion()));

		return euler.z / 0.0174532925 /*degrees*/;
	}

	public static function set3DObjectWorldRotationX(object : Object3D, x : Float) : Void {
		set3DObjectRotationX(object, object.parent != null ? x - get3DObjectWorldRotationX(object.parent) : x);
	}

	public static function set3DObjectWorldRotationY(object : Object3D, y : Float) : Void {
		set3DObjectRotationY(object, object.parent != null ? y - get3DObjectWorldRotationY(object.parent) : y);
	}

	public static function set3DObjectWorldRotationZ(object : Object3D, z : Float) : Void {
		set3DObjectRotationZ(object, object.parent != null ? z - get3DObjectWorldRotationZ(object.parent) : z);
	}



	public static function get3DObjectWorldScaleX(object : Object3D) : Float {
		return object.getWorldScale(new Vector3()).x;
	}

	public static function get3DObjectWorldScaleY(object : Object3D) : Float {
		return object.getWorldScale(new Vector3()).y;
	}

	public static function get3DObjectWorldScaleZ(object : Object3D) : Float {
		return object.getWorldScale(new Vector3()).z;
	}

	public static function set3DObjectWorldScaleX(object : Object3D, x : Float) : Void {
		set3DObjectScaleX(object, object.parent != null ? x / get3DObjectWorldScaleX(object.parent) : x);
	}

	public static function set3DObjectWorldScaleY(object : Object3D, y : Float) : Void {
		set3DObjectScaleY(object, object.parent != null ? y / get3DObjectWorldScaleY(object.parent) : y);
	}

	public static function set3DObjectWorldScaleZ(object : Object3D, z : Float) : Void {
		set3DObjectScaleZ(object, object.parent != null ? z / get3DObjectWorldScaleZ(object.parent) : z);
	}



	public static function set3DObjectLookAt(object : Object3D, x : Float, y : Float, z : Float) : Void {
		object.lookAt(new Vector3(x, y, z));
		object.invalidateStage();
	}


	public static function get3DObjectBoundingBox(object : Object3D) : Array<Array<Float>> {
		var box = object.getBoundingBox();
		return [[box.min.x, box.min.y, box.min.z], [box.max.x, box.max.y, box.max.z]];
	}

	public static function add3DObjectPositionListener(object : Object3D, cb : Float -> Float -> Float -> Void) : Void -> Void {
		var fn = function(e : Dynamic) {
			cb(get3DObjectX(object), get3DObjectY(object), get3DObjectZ(object));
		};

		fn(0);

		object.addEventListener("position", fn);
		return function() { object.removeEventListener("position", fn); };
	}

	public static function add3DObjectRotationListener(object : Object3D, cb : Float -> Float -> Float -> Void) : Void -> Void {
		var fn = function(e : Dynamic) {
			cb(get3DObjectRotationX(object), get3DObjectRotationY(object), get3DObjectRotationZ(object));
		};

		fn(0);

		object.addEventListener("rotation", fn);
		return function() { object.removeEventListener("rotation", fn); };
	}

	public static function add3DObjectScaleListener(object : Object3D, cb : Float -> Float -> Float -> Void) : Void -> Void {
		var fn = function(e : Dynamic) {
			cb(get3DObjectScaleX(object), get3DObjectScaleY(object), get3DObjectScaleZ(object));
		};

		fn(0);

		object.addEventListener("scale", fn);
		return function() { object.removeEventListener("scale", fn); };
	}

	public static function add3DObjectBoundingBoxListener(object : Object3D, cb : (Array<Array<Float>>) -> Void) : Void -> Void {
		var fn = function(e : Dynamic) {
			cb(get3DObjectBoundingBox(object));
		};

		fn(0);

		object.addEventListener("box", fn);
		return function() { object.removeEventListener("box", fn); };
	}



	public static function make3DPerspectiveCamera(fov : Float, aspect : Float, near : Float, far : Float) : PerspectiveCamera {
		return new PerspectiveCamera(fov, aspect, near, far);
	}

	public static function set3DCameraFov(camera : PerspectiveCamera, fov : Float) : Void {
		camera.fov = fov;
		camera.invalidateStage();
	}

	public static function set3DCameraAspect(camera : PerspectiveCamera, aspect : Float) : Void {
		camera.aspect = aspect;
		camera.invalidateStage();
	}

	public static function set3DCameraNear(camera : PerspectiveCamera, near : Float) : Void {
		camera.near = near;
		camera.invalidateStage();
	}

	public static function set3DCameraFar(camera : PerspectiveCamera, far : Float) : Void {
		camera.far = far;
		camera.invalidateStage();
	}

	public static function get3DCameraFov(camera : PerspectiveCamera) : Float {
		return camera.fov;
	}

	public static function get3DCameraAspect(camera : PerspectiveCamera) : Float {
		return camera.aspect;
	}

	public static function get3DCameraNear(camera : PerspectiveCamera) : Float {
		return camera.near;
	}

	public static function get3DCameraFar(camera : PerspectiveCamera) : Float {
		return camera.far;
	}



	public static function make3DPointLight(color : Int, intensity : Float, distance : Float, decay : Float) : Light {
		return new PointLight(color, intensity, distance, decay);
	}

	public static function make3DSpotLight(color : Int, intensity : Float, distance : Float, angle : Float, penumbra : Float, decay : Float) : Light {
		return new SpotLight(color, intensity, distance, angle, penumbra, decay);
	}

	public static function make3DAmbientLight(color : Int, intensity : Float) : Light {
		return new AmbientLight(color, intensity);
	}


	public static function set3DLightColor(object : Light, color : Int) : Void {
		object.color = new Color(color);

		object.broadcastEvent("change"); // TODO:

		object.invalidateStage();
	}

	public static function set3DLightIntensity(object : Light, intensity : Float) : Void {
		object.intensity = intensity;

		object.broadcastEvent("change"); // TODO:

		object.invalidateStage();
	}

	public static function set3DLightDistance(object : PointLight, distance : Float) : Void {
		object.distance = distance;

		object.broadcastEvent("change"); // TODO:

		object.invalidateStage();
	}

	public static function set3DLightAngle(object : SpotLight, angle : Float) : Void {
		object.angle = angle * 0.0174532925 /*radians*/;

		object.broadcastEvent("change"); // TODO:

		object.invalidateStage();
	}

	public static function set3DLightPenumbra(object : SpotLight, penumbra : Float) : Void {
		object.penumbra = penumbra;

		object.broadcastEvent("change"); // TODO:

		object.invalidateStage();
	}

	public static function set3DLightDecay(object : PointLight, decay : Float) : Void {
		object.decay = decay;

		object.broadcastEvent("change"); // TODO:

		object.invalidateStage();
	}

	public static function get3DLightColor(object : Light) : Int {
		return object.color.getHex();
	}

	public static function get3DLightIntensity(object : Light) : Float {
		return object.intensity;
	}

	public static function get3DLightDistance(object : PointLight) : Float {
		return object.distance;
	}

	public static function get3DLightAngle(object : SpotLight) : Float {
		return object.angle / 0.0174532925 /*degrees*/;
	}

	public static function get3DLightPenumbra(object : SpotLight) : Float {
		return object.penumbra;
	}

	public static function get3DLightDecay(object : PointLight) : Float {
		return object.decay;
	}

	public static function make3DPlaneGeometry(width : Float, height : Float, widthSegments : Int, heightSegments : Int) : Geometry {
		return new PlaneGeometry(width, height, widthSegments, heightSegments);
	}

	public static function make3DBoxGeometry(width : Float, height : Float, depth : Float, widthSegments : Int, heightSegments : Int, depthSegments : Int) : Geometry {
		return new BoxGeometry(width, height, depth, widthSegments, heightSegments, depthSegments);
	}

	public static function make3DCircleGeometry(radius : Float, segments : Int, thetaStart : Float, thetaLength : Float) : Geometry {
		return new CircleGeometry(radius, segments, thetaStart, thetaLength);
	}

	public static function make3DRingGeometry(innerRadius : Float, outerRadius : Float, segments : Int, thetaStart : Float, thetaLength : Float) : Geometry {
		return new RingGeometry(innerRadius, outerRadius, segments, thetaStart, thetaLength);
	}

	public static function make3DConeGeometry(radius : Float, height : Float, radialSegments : Int, heightSegments : Int, openEnded : Bool, thetaStart : Float, thetaLength : Float) : Geometry {
		return new ConeGeometry(radius, height, radialSegments, heightSegments, openEnded, thetaStart, thetaLength);
	}

	public static function make3DCylinderGeometry(radiusTop : Float, radiusBottom : Float, height : Float, radialSegments : Int, heightSegments : Int, openEnded : Bool, thetaStart : Float, thetaLength : Float) : Geometry {
		return new CylinderGeometry(radiusTop, radiusBottom, height, radialSegments, heightSegments, openEnded, thetaStart, thetaLength);
	}

	public static function make3DSphereGeometry(radius : Float, widthSegments : Int, heightSegments : Int, phiStart : Float, phiLength : Float, thetaStart : Float, thetaLength : Float) : Geometry {
		return new SphereGeometry(radius, widthSegments, heightSegments, phiStart, phiLength, thetaStart, thetaLength);
	}

	public static function make3DSphereBufferGeometry(radius : Float, widthSegments : Int, heightSegments : Int, phiStart : Float, phiLength : Float, thetaStart : Float, thetaLength : Float) : BufferGeometry {
		return new SphereBufferGeometry(radius, widthSegments, heightSegments, phiStart, phiLength, thetaStart, thetaLength);
	}

	public static function make3DMeshBasicMaterial(color : Int, parameters : Array<Array<String>>) : Material {
		var material = new MeshBasicMaterial(untyped {color : new Color(color)});

		for (par in parameters) {
			untyped material[par[0]] = untyped __js__("eval(par[1])");
		}

		return material;
	}

	public static function make3DMeshStandardMaterial(color : Int, parameters : Array<Array<String>>) : Material {
		var material = new MeshStandardMaterial(untyped {color : new Color(color)});

		for (par in parameters) {
			untyped material[par[0]] = untyped __js__("eval(par[1])");
		}

		return material;
	}


	public static function make3DMesh(geometry : Geometry, materials : Array<Material>, parameters : Array<Array<String>>) : Mesh {
		if (untyped geometry.clearGroups != null) {
			untyped geometry.clearGroups();

			for (i in 0...materials.length) {
				untyped geometry.addGroup(0, Math.POSITIVE_INFINITY, i);
			}
		}

		var mesh = new Mesh(geometry, untyped materials.length == 1 ? materials[0] : materials);

		for (par in parameters) {
			untyped mesh[par[0]] = untyped __js__("eval(par[1])");
		}

		return mesh;
	}

	public static function set3DObjectAlphaMap(object : Object3D, alphaMap : Material) : Void {
		if (untyped object.material != null && object.material.alphaMap != alphaMap.map) {
			untyped object.material.alphaMap = alphaMap.map;
			untyped object.material.transparent = true;
			object.invalidateStage();
		}
	}


	public static function set3DAnimationDuration(animation : AnimationClip, duration : Float) : Void {
		animation.duration = duration;
	}

	public static function get3DAnimationDuration(animation : AnimationClip) : Float {
		return animation.duration;
	}

	public static function create3DAnimationMixer(object : Object3D) : AnimationMixer {
		var mixer : Dynamic = untyped __js__("new THREE.AnimationMixer(object)");
		mixer.clock = new Clock();
		return mixer;
	}

	public static function start3DAnimationMixer(mixer : AnimationMixer, animation : AnimationClip) : Void -> Void {
		var action = mixer.clipAction(animation);
		var drawFrameFn = function() {
			mixer.update(untyped mixer.clock.getDelta());
			RenderSupportJSPixi.PixiStageChanged = true;
		};

		action.play();
		RenderSupportJSPixi.on('drawframe', drawFrameFn);

		return function() {
			action.stop();
			RenderSupportJSPixi.off('drawframe', drawFrameFn);
		}
	}

	public static function clear3DStageObjectCache(stage : ThreeJSStage) : Void {
		if (stage.objectCache != null) {
			stage.objectCache = new Array<Object3D>();
		}
	}
}