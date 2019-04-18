import js.Browser;

import js.three.Scene;
import js.three.Fog;

import js.three.Color;

import js.three.Object3D;
import js.three.Mesh;

import js.three.Camera;
import js.three.PerspectiveCamera;

import js.three.Geometry;
import js.three.BoxGeometry;
import js.three.CircleGeometry;
import js.three.ConeGeometry;
import js.three.CylinderGeometry;

import js.three.Material;
import js.three.MeshBasicMaterial;

import js.three.Light;
import js.three.PointLight;

import js.three.TextureLoader;

using DisplayObjectHelper;
using Object3DHelper;

class RenderSupport3D {
	public static function __init__() {
		var head = Browser.document.getElementsByTagName('head')[0];

		var node = Browser.document.createElement('script');
		node.setAttribute("type","text/javascript");
		node.setAttribute("src", 'js/three.min.js');
		head.appendChild(node);

		node = Browser.document.createElement('script');
		node.setAttribute("type","text/javascript");
		node.setAttribute("src", 'js/threejs/MTLLoader.js');
		head.appendChild(node);

		node = Browser.document.createElement('script');
		node.setAttribute("type","text/javascript");
		node.setAttribute("src", 'js/threejs/OBJLoader.js');
		head.appendChild(node);
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
		new ThreeJSLoader(objUrl, mtlUrl, onLoad);
	}

	public static function load3DTexture(object : Material, url : String) : Material {
		untyped object.map = new TextureLoader().load(url);
		return object;
	}


	public static function set3DCamera(stage : ThreeJSStage, camera : Camera) : Void {
		stage.camera = camera;
		stage.invalidateStage();
	}

	public static function set3DScene(stage : ThreeJSStage, scene : Scene) : Void {
		stage.scene = scene;

		// Chrome Inspect Three.js extension support
		untyped __js__("window.scene = scene;");

		stage.invalidateStage();
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
			object.invalidateStage();
		}
	}

	public static function set3DObjectY(object : Object3D, y : Float) : Void {
		if (object.position.y != y) {
			object.position.y = y;
			object.invalidateStage();
		}
	}

	public static function set3DObjectZ(object : Object3D, z : Float) : Void {
		if (object.position.z != z) {
			object.position.z = z;
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
			object.invalidateStage();
		}
	}

	public static function set3DObjectRotationY(object : Object3D, y : Float) : Void {
		y = y * 0.0174532925 /*radians*/;

		if (object.rotation.y != y) {
			object.rotation.y = y;
			object.invalidateStage();
		}
	}

	public static function set3DObjectRotationZ(object : Object3D, z : Float) : Void {
		z = z * 0.0174532925 /*radians*/;

		if (object.rotation.z != z) {
			object.rotation.z = z;
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
			object.invalidateStage();
		}
	}

	public static function set3DObjectScaleY(object : Object3D, y : Float) : Void {
		if (object.scale.y != y) {
			object.scale.y = y;
			object.invalidateStage();
		}
	}

	public static function set3DObjectScaleZ(object : Object3D, z : Float) : Void {
		if (object.scale.z != z) {
			object.scale.z = z;
			object.invalidateStage();
		}
	}

	public static function set3DObjectLookAt(object : Object3D, x : Float, y : Float, z : Float) : Void {
		object.lookAt(new js.three.Vector3(x, y, z));
		object.invalidateStage();
	}


	public static function getObject3DBoundingBox(object : Object3D) : Array<Array<Float>> {
		var box = object.getBoundingBox();
		return [[box.min.x, box.min.y, box.min.z], [box.max.x, box.max.y, box.max.z]];
	}



	public static function make3DPerspectiveCamera(fov : Float, aspect : Float, near : Float, far : Float) : PerspectiveCamera {
		return new PerspectiveCamera(fov, aspect, near, far);
	}

	public static function set3DCameraFov(camera : PerspectiveCamera, fov : Float) : Void {
		camera.fov = fov;
	}

	public static function set3DCameraAspect(camera : PerspectiveCamera, aspect : Float) : Void {
		camera.aspect = aspect;
	}

	public static function set3DCameraNear(camera : PerspectiveCamera, near : Float) : Void {
		camera.near = near;
	}

	public static function set3DCameraFar(camera : PerspectiveCamera, far : Float) : Void {
		camera.far = far;
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

	public static function set3DLightColor(object : Light, color : Int) : Void {
		object.color = new Color(color);
		object.invalidateStage();
	}

	public static function set3DLightIntensity(object : Light, intensity : Float) : Void {
		object.intensity = intensity;
		object.invalidateStage();
	}

	public static function set3DLightDistance(object : PointLight, distance : Float) : Void {
		object.distance = distance;
		object.invalidateStage();
	}

	public static function set3DLightDecay(object : PointLight, decay : Float) : Void {
		object.decay = decay;
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

	public static function get3DLightDecay(object : PointLight) : Float {
		return object.decay;
	}



	public static function make3DBoxGeometry(width : Float, height : Float, depth : Float, widthSegments : Int, heightSegments : Int, depthSegments : Int) : Geometry {
		return new BoxGeometry(width, height, depth, widthSegments, heightSegments, depthSegments);
	}

	public static function make3DCircleGeometry(radius : Float, segments : Int, thetaStart : Float, thetaLength : Float) : Geometry {
		return new CircleGeometry(radius, segments, thetaStart, thetaLength);
	}

	public static function make3DConeGeometry(radius : Float, height : Float, radialSegments : Int, heightSegments : Int, openEnded : Bool, thetaStart : Float, thetaLength : Float) : Geometry {
		return new ConeGeometry(radius, height, radialSegments, heightSegments, openEnded, thetaStart, thetaLength);
	}

	public static function make3DCylinderGeometry(radiusTop : Float, radiusBottom : Float, height : Float, radialSegments : Int, heightSegments : Int, openEnded : Bool, thetaStart : Float, thetaLength : Float) : Geometry {
		return new CylinderGeometry(radiusTop, radiusBottom, height, radialSegments, heightSegments, openEnded, thetaStart, thetaLength);
	}

	public static function make3DMeshBasicMaterial(color : Int, parameters : Array<Array<String>>) : Material {
		return new MeshBasicMaterial({color : color});
	}


	public static function make3DMesh(geometry : Geometry, material : Material) : Mesh {
		return new Mesh(geometry, material);
	}
}