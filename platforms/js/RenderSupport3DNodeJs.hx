class RenderSupport3D {
	public static var LOADING_CACHE_ENABLED = true;

	public static function load3DLibraries(cb : Void -> Void) : Void {
	}

	public static function get3DSupportedExtensions(stage : Dynamic) : Array<String> {
		return [];
	}

	public static function add3DChild(parent : Dynamic, child : Dynamic) : Void {
	}

	public static function add3DChildAt(parent : Dynamic, child : Dynamic, index : Int) : Void {
	}

	public static function remove3DChild(parent : Dynamic, child : Dynamic) : Void {
	}

	public static function remove3DChildren(parent : Dynamic) : Void {
	}

	public static function get3DObjectChildren(object : Dynamic) : Array<Dynamic> {
		return [];
	}

	public static function get3DObjectJSON(object : Dynamic, includeCamera : Bool) : String {
		return "";
	}

	public static function get3DObjectState(object : Dynamic) : String {
		return "";
	}

	public static function apply3DObjectState(object : Dynamic, state : String) : Void {
	}

	public static function make3DObjectFromJSON(stage : Dynamic, json : String) : Dynamic {
		return null;
	}

	public static function make3DObjectFromObj(stage : Dynamic, obj : String, mtl : String) : Dynamic {
		return null;
	}

	public static function make3DGeometryFromJSON(json : String) : Dynamic {
		return null;
	}

	public static function make3DMaterialsFromJSON(json : String) : Dynamic {
		return null;
	}

	public static function make3DStage(width : Float, height : Float) : Dynamic {
		return null;
	}

	public static function dispose3DStage(stage : Dynamic) : Void {
	}

	public static function make3DScene() : Dynamic {
		return null;
	}

	public static function make3DColor(color : String) : Dynamic {
		return null;
	}

	public static function set3DStageOnStart(stage : Dynamic, onStart : Void -> Void) : Void  {
	}

	public static function set3DStageOnError(stage : Dynamic, onError : Void -> Void) : Void  {
	}

	public static function set3DStageOnLoad(stage : Dynamic, onLoad : Void -> Void) : Void  {
	}

	public static function set3DStageOnProgress(stage : Dynamic, onProgress : String -> Int -> Int -> Void) : Void {
	}

	public static function set3DSceneBackground(scene : Dynamic, background : Dynamic) : Void {
	}

	public static function set3DSceneFog(scene : Dynamic, fog : Dynamic) : Void {
	}


	public static function load3DObject(stage : Dynamic, objUrl : String, mtlUrl : String, onLoad : Dynamic -> Void) : Void {
	}

	public static function load3DGLTFObject(stage : Dynamic, url : String, onLoad : Array<Dynamic> -> Dynamic -> Array<Dynamic> -> Array<Dynamic> -> Dynamic -> Void, onError : String -> Void) : Void -> Void {
		return function() {};
	}

	public static function load3DScene(stage : Dynamic, url : String, onLoad : Dynamic -> Void) : Void {
	}

	public static function make3DTextureLoader(stage : Dynamic, url : String, onLoad : Dynamic -> Void, parameters : Array<Array<String>>) : Dynamic {
		return null;
	}

	public static function load3DTexture(texture : Dynamic) : Void -> Void {
		return function() {};
	}

	public static function load3DCubeTexture(stage : Dynamic, px : String, nx : String, py : String, ny : String, pz : String, nz : String,
		onLoad : Dynamic -> Void, parameters : Array<Array<String>>) : Dynamic {
		return null;
	}

	public static function make3DDataTexture(data : Array<Int>, width : Int, height : Int, parameters : Array<Array<String>>) : Dynamic {
		return null;
	}

	public static function make3DCanvasTexture(clip : Dynamic, parameters : Array<Array<String>>) : Dynamic {
		return null;
	}


	public static function set3DMaterialMap(material : Dynamic, map : Dynamic) : Void {
	}

	public static function set3DMaterialAlphaMap(material : Dynamic, alphaMap : Dynamic) : Void {
	}

	public static function set3DMaterialDisplacementMap(material : Dynamic, displacementMap : Dynamic, displacementScale : Float, displacementBias : Float) : Void {
	}

	public static function set3DMaterialBumpMap(material : Dynamic, bumpMap : Dynamic, bumpScale : Float) : Void {
	}

	public static function set3DMaterialOpacity(material : Dynamic, opacity : Float) : Void {
	}

	public static function set3DMaterialVisible(material : Dynamic, visible : Bool) : Void {
	}

	public static function set3DMaterialColor(material : Dynamic, color : Int) : Void {
	}


	public static function set3DTextureRotation(object : Dynamic, rotation : Float) : Void {
	}

	public static function get3DTextureRotation(object : Dynamic) : Float {
		return 0.0;
	}

	public static function set3DTextureOffsetX(object : Dynamic, x : Float) : Void {
	}

	public static function get3DTextureOffsetX(object : Dynamic) : Float {
		return 0.0;
	}

	public static function set3DTextureOffsetY(object : Dynamic, y : Float) : Void {
	}

	public static function get3DTextureOffsetY(object : Dynamic) : Float {
		return 0.0;
	}


	public static function make3DAxesHelper(size : Float) : Dynamic {
		return null;
	}

	public static function make3DGridHelper(size : Float, divisions : Int, colorCenterLine : Int, colorGrid : Int) : Dynamic {
		return null;
	}

	public static function make3DVertexNormalsHelper(object : Dynamic, size : Float, color : Int, lineWidth : Float) : Dynamic {
		return null;
	}

	public static function set3DCamera(stage : Dynamic, camera : Dynamic, parameters : Array<Array<String>>) : Void {
	}

	public static function set3DScene(stage : Dynamic, scene : Dynamic) : Void {
	}


	static function add3DEventListener(object : Dynamic, event : String, cb : Void -> Void) : Void -> Void {
		return function() { };
	}

	static function emit3DMouseEvent(stage : Dynamic, event : String, x : Float, y : Float) : Void {
	}

	static function emit3DTouchEvent(stage : Dynamic, event : String, points : Array<Array<Float>>) : Void {
	}

	static function emit3DKeyEvent(stage : Dynamic, event : String, key : String, ctrl : Bool, shift : Bool, alt : Bool, meta : Bool, keyCode : Int) : Void {
	}

	public static function attach3DTransformControls(stage : Dynamic, object : Dynamic) : Void {
	}

	public static function detach3DTransformControls(stage : Dynamic, object : Dynamic) : Void {
	}

	public static function clear3DTransformControls(stage : Dynamic) : Void {
	}

	public static function set3DOrbitControlsEnabled(stage : Dynamic, enabled : Bool) : Void {
	}

	public static function is3DTransformControlsAttached(stage : Dynamic, object : Dynamic) : Bool {
		return false;
	}


	public static function set3DTransformControlsSpace(stage : Dynamic, local : Bool) : Void {
	}

	public static function is3DTransformControlsSpaceLocal(stage : Dynamic) : Bool {
		return false;
	}

	public static function set3DTransformControlsMode(stage : Dynamic, mode : String) : Void {
	}

	public static function get3DTransformControlsMode(stage : Dynamic) : String {
		return "";
	}

	public static function set3DTransformControlsTranslationSnap(stage : Dynamic, snap : Float) : Void {
	}

	public static function get3DTransformControlsTranslationSnap(stage : Dynamic) : Float {
		return 0.0;
	}

	public static function set3DTransformControlsRotationSnap(stage : Dynamic, snap : Float) : Void {
	}

	public static function get3DTransformControlsRotationSnap(stage : Dynamic) : Float {
		return 0.0;
	}

	public static function set3DTransformControlsSize(stage : Dynamic, size : Float) : Void {
	}

	public static function get3DTransformControlsSize(stage : Dynamic) : Float {
		return 0.0;
	}

	public static function set3DTransformControlsShowX(stage : Dynamic, show : Bool) : Void {
	}

	public static function get3DTransformControlsShowX(stage : Dynamic) : Bool {
		return false;
	}

	public static function set3DTransformControlsShowY(stage : Dynamic, show : Bool) : Void {
	}

	public static function get3DTransformControlsShowY(stage : Dynamic) : Bool {
		return false;
	}

	public static function set3DTransformControlsShowZ(stage : Dynamic, show : Bool) : Void {
	}

	public static function get3DTransformControlsShowZ(stage : Dynamic) : Bool {
		return false;
	}

	public static function set3DTransformControlsEnabled(stage : Dynamic, enabled : Bool) : Void {
	}

	public static function get3DTransformControlsEnabled(stage : Dynamic) : Bool {
		return false;
	}


	public static function attach3DBoxHelper(stage : Dynamic, object : Dynamic) : Void {
	}

	public static function detach3DBoxHelper(stage : Dynamic, object : Dynamic) : Void {
	}

	public static function clear3DBoxHelpers(stage : Dynamic) : Void {
	}

	public static function get3DObjectId(object : Dynamic) : String {
		return "";
	}

	public static function get3DObjectById(stage : Dynamic, id : String) : Array<Dynamic> {
		return [];
	}

	public static function get3DObjectType(object : Dynamic) : String {
		return "";
	}

	public static function get3DObjectStage(object : Dynamic) : Array<Dynamic> {
		return null;
	}

	public static function get3DStageScene(stage : Dynamic) : Array<Dynamic> {
		return [];
	}

	public static function get3DObjectName(object : Dynamic) : String {
		return "";
	}

	public static function set3DObjectName(object : Dynamic, name : String) : Void {
	}

	public static function get3DObjectVisible(object : Dynamic) : Bool {
		return false;
	}

	public static function set3DObjectVisible(object : Dynamic, visible : Bool) : Void {
	}

	public static function get3DObjectAlpha(object : Dynamic) : Float {
		return 0.0;
	}

	public static function set3DObjectAlpha(object : Dynamic, alpha : Float) : Void {
	}

	public static function get3DObjectCastShadow(object : Dynamic) : Bool {
		return false;
	}

	public static function set3DObjectCastShadow(object : Dynamic, castShadow : Bool) : Void {
	}

	public static function get3DObjectReceiveShadow(object : Dynamic) : Bool {
		return false;
	}

	public static function set3DObjectReceiveShadow(object : Dynamic, receiveShadow : Bool) : Void {
	}

	public static function get3DObjectFrustumCulled(object : Dynamic) : Bool {
		return false;
	}

	public static function set3DObjectFrustumCulled(object : Dynamic, frustumCulled : Bool) : Void {
	}

	public static function get3DObjectLocalPositionX(object : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DObjectWorldPositionX(object : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DObjectLocalPositionY(object : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DObjectWorldPositionY(object : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DObjectLocalPositionZ(object : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DObjectWorldPositionZ(object : Dynamic) : Float {
		return 0.0;
	}

	public static function set3DObjectLocalPositionX(object : Dynamic, x : Float) : Void {
	}

	public static function set3DObjectLocalPositionY(object : Dynamic, y : Float) : Void {
	}

	public static function set3DObjectLocalPositionZ(object : Dynamic, z : Float) : Void {
	}

	public static function get3DObjectLocalRotationX(object : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DObjectLocalRotationY(object : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DObjectLocalRotationZ(object : Dynamic) : Float {
		return 0.0;
	}

	public static function set3DObjectLocalRotationX(object : Dynamic, x : Float) : Void {
	}

	public static function set3DObjectLocalRotationY(object : Dynamic, y : Float) : Void {
	}

	public static function set3DObjectLocalRotationZ(object : Dynamic, z : Float) : Void {
	}

	public static function get3DObjectLocalScaleX(object : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DObjectLocalScaleY(object : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DObjectLocalScaleZ(object : Dynamic) : Float {
		return 0.0;
	}

	public static function set3DObjectLocalScaleX(object : Dynamic, x : Float) : Void {
	}

	public static function set3DObjectLocalScaleY(object : Dynamic, y : Float) : Void {
	}

	public static function set3DObjectLocalScaleZ(object : Dynamic, z : Float) : Void {
	}

	public static function get3DObjectWorldX(object : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DObjectWorldY(object : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DObjectWorldZ(object : Dynamic) : Float {
		return 0.0;
	}

	public static function set3DObjectWorldX(object : Dynamic, x : Float) : Void {
	}

	public static function set3DObjectWorldY(object : Dynamic, y : Float) : Void {
	}

	public static function set3DObjectWorldZ(object : Dynamic, z : Float) : Void {
	}

	public static function get3DObjectWorldRotationX(object : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DObjectWorldRotationY(object : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DObjectWorldRotationZ(object : Dynamic) : Float {
		return 0.0;
	}

	public static function set3DObjectWorldRotationX(object : Dynamic, x : Float) : Void {
	}

	public static function set3DObjectWorldRotationY(object : Dynamic, y : Float) : Void {
	}

	public static function set3DObjectWorldRotationZ(object : Dynamic, z : Float) : Void {
	}

	public static function get3DObjectWorldScaleX(object : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DObjectWorldScaleY(object : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DObjectWorldScaleZ(object : Dynamic) : Float {
		return 0.0;
	}

	public static function set3DObjectWorldScaleX(object : Dynamic, x : Float) : Void {
	}

	public static function set3DObjectWorldScaleY(object : Dynamic, y : Float) : Void {
	}

	public static function set3DObjectWorldScaleZ(object : Dynamic, z : Float) : Void {
	}

	public static function set3DObjectLookAt(object : Dynamic, x : Float, y : Float, z : Float) : Void {
	}

	public static function set3DObjectLocalMatrix(object : Dynamic, matrix : Array<Float>) : Void {
	}

	// TODO: TEST
	public static function set3DObjectWorldMatrix(object : Dynamic, matrix : Array<Float>) : Void {
	}

	public static function set3DObjectInteractive(object : Dynamic, interactive : Bool) : Void {
	}

	public static function get3DObjectInteractive(object : Dynamic) : Bool {
		return false;
	}

	public static function get3DObjectBoundingBox(object : Dynamic) : Array<Array<Float>> {
		return [];
	}

	public static function get3DObjectLocalMatrix(object : Dynamic) : Array<Float> {
		return [];
	}

	public static function get3DObjectWorldMatrix(object : Dynamic) : Array<Float> {
		return [];
	}

	public static function add3DObjectLocalPositionListener(object : Dynamic, cb : Float -> Float -> Float -> Void) : Void -> Void {
		return function() { };
	}

	public static function add3DObjectWorldPositionListener(object : Dynamic, cb : Float -> Float -> Float -> Void) : Void -> Void {
		return function() { };
	}

	public static function add3DObjectStagePositionListener(stage : Dynamic, object : Dynamic, cb : Float -> Float -> Void) : Void -> Void {
		return function() { };
	}

	public static function add3DObjectLocalRotationListener(object : Dynamic, cb : Float -> Float -> Float -> Void) : Void -> Void {
		return function() { };
	}

	public static function add3DObjectLocalScaleListener(object : Dynamic, cb : Float -> Float -> Float -> Void) : Void -> Void {
		return function() { };
	}

	public static function add3DObjectBoundingBoxListener(object : Dynamic, cb : (Array<Array<Float>>) -> Void) : Void -> Void {
		return function() { };
	}

	public static function add3DObjectLocalMatrixListener(object : Dynamic, cb : (Array<Float>) -> Void) : Void -> Void {
		return function() { };
	}

	public static function add3DObjectWorldMatrixListener(object : Dynamic, cb : (Array<Float>) -> Void) : Void -> Void {
		return function() { };
	}

	public static function make3DPerspectiveCamera(fov : Float, aspect : Float, near : Float, far : Float) : Dynamic {
		return null;
	}

	public static function make3DOrthographicCamera(width : Float, height : Float, near : Float, far : Float) : Dynamic {
		return null;
	}

	public static function set3DCameraFov(camera : Dynamic, fov : Float) : Void {
	}

	public static function set3DCameraAspect(camera : Dynamic, aspect : Float) : Void {
	}

	public static function set3DCameraNear(camera : Dynamic, near : Float) : Void {
	}

	public static function set3DCameraFar(camera : Dynamic, far : Float) : Void {
	}

	public static function set3DCameraWidth(camera : Dynamic, width : Float) : Void {
	}

	public static function set3DCameraHeight(camera : Dynamic, height : Float) : Void {
	}

	public static function set3DCameraZoom(camera : Dynamic, zoom : Float) : Void {
	}

	public static function get3DCameraFov(camera : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DCameraAspect(camera : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DCameraNear(camera : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DCameraFar(camera : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DCameraZoom(camera : Dynamic) : Float {
		return 0.0;
	}

	public static function make3DPointLight(color : Int, intensity : Float, distance : Float, decay : Float) : Dynamic {
		return null;
	}

	public static function make3DSpotLight(color : Int, intensity : Float, distance : Float, angle : Float, penumbra : Float, decay : Float) : Dynamic {
		return null;
	}

	public static function make3DAmbientLight(color : Int, intensity : Float) : Dynamic {
		return null;
	}

	public static function set3DObjectColor(object : Dynamic, color : Int) : Void {
	}

	public static function set3DObjectEmissive(object : Dynamic, color : Int) : Void {
	}

	public static function set3DLightIntensity(object : Dynamic, intensity : Float) : Void {
	}

	public static function set3DLightDistance(object : Dynamic, distance : Float) : Void {
	}

	public static function set3DLightAngle(object : Dynamic, angle : Float) : Void {
	}

	public static function set3DLightPenumbra(object : Dynamic, penumbra : Float) : Void {
	}

	public static function set3DLightDecay(object : Dynamic, decay : Float) : Void {
	}

	public static function get3DObjectColor(object : Dynamic) : Int {
		return 0;
	}

	public static function get3DObjectEmissive(object : Dynamic) : Int {
		return 0;
	}

	public static function get3DLightIntensity(object : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DLightDistance(object : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DLightAngle(object : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DLightPenumbra(object : Dynamic) : Float {
		return 0.0;
	}

	public static function get3DLightDecay(object : Dynamic) : Float {
		return 0.0;
	}

	public static function make3DPlaneGeometry(width : Float, height : Float, widthSegments : Int, heightSegments : Int) : Dynamic {
		return null;
	}

	public static function make3DBoxGeometry(width : Float, height : Float, depth : Float, widthSegments : Int, heightSegments : Int, depthSegments : Int) : Dynamic {
		return null;
	}

	public static function make3DCircleGeometry(radius : Float, segments : Int, thetaStart : Float, thetaLength : Float) : Dynamic {
		return null;
	}

	public static function make3DRingGeometry(innerRadius : Float, outerRadius : Float, segments : Int, thetaStart : Float, thetaLength : Float) : Dynamic {
		return null;
	}

	public static function make3DConeGeometry(radius : Float, height : Float, radialSegments : Int, heightSegments : Int, openEnded : Bool, thetaStart : Float, thetaLength : Float) : Dynamic {
		return null;
	}

	public static function make3DCylinderGeometry(radiusTop : Float, radiusBottom : Float, height : Float, radialSegments : Int, heightSegments : Int, openEnded : Bool, thetaStart : Float, thetaLength : Float) : Dynamic {
		return null;
	}

	public static function make3DSphereGeometry(radius : Float, widthSegments : Int, heightSegments : Int, phiStart : Float, phiLength : Float, thetaStart : Float, thetaLength : Float) : Dynamic {
		return null;
	}

	public static function set3DGeometryMatrix(geometry : Dynamic, matrix : Array<Float>) : Void {
	}

	public static function make3DSphereBufferGeometry(radius : Float, widthSegments : Int, heightSegments : Int, phiStart : Float, phiLength : Float, thetaStart : Float, thetaLength : Float, addGroups : Int -> Int -> Array<Array<Int>>) : Dynamic {
		return null;
	}

	public static function make3DCylinderBufferGeometry(radiusTop : Float, radiusBottom : Float, height : Float, radialSegments : Int, heightSegments : Int, openEnded : Bool, thetaStart : Float, thetaLength : Float, addGroups : Int -> Int -> Array<Array<Int>>) : Dynamic {
		return null;
	}

	public static function make3DBoxBufferGeometry(width : Float, height : Float, depth : Float, widthSegments : Int, heightSegments : Int, depthSegments : Int, addGroups : Int -> Int -> Array<Array<Int>>) : Dynamic {
		return null;
	}

	public static function make3DShapeBufferGeometry(pathes : Array<Array<Float>>, addGroups : Int -> Int -> Array<Array<Int>>) : Dynamic {
		return null;
	}

	public static function make3DBufferFromGeometry(geometry : Dynamic, ?parameters : Array<Array<String>>, ?addGroups : Int -> Int -> Array<Array<Int>>) : Dynamic {
		return null;
	}

	public static function add3DBufferGeometryAttribute(geometry : Dynamic, name : String, data : Array<Array<Float>>) : Void {
	}

	public static function get3DBufferGeometryAttribute(geometry : Dynamic, name : String) : Array<Array<Float>> {
		return [];
	}

	public static function make3DShapeGeometry(pathes : Array<Array<Float>>) : Dynamic {
		return null;
	}

	public static function make3DShapeGeometry3D(path : Array<Float>) : Dynamic {
		return null;
	}

	public static function make3DVertexGeometry(vertices : Array<Float>) : Dynamic {
		return null;
	}

	public static function make3DVertexGeometry3D(vertices : Array<Float>) : Dynamic {
		return null;
	}

	public static function make3DEdgesGeometry(geometry : Dynamic) : Dynamic {
		return null;
	}

	public static function make3DWireframeGeometry(geometry : Dynamic) : Dynamic {
		return null;
	}


	public static function modify3DGeometryVertices(geometry : Dynamic, modifyFn : (Array<Float>) -> Array<Float>) : Dynamic {
		return null;
	}

	public static function tesselate3DGeometry(geometry : Dynamic, distance : Float, iterations : Int) : Dynamic {
		return null;
	}

	public static function simplify3DGeometry(geometry : Dynamic, countFn : Int -> Int) : Dynamic {
		return null;
	}

	public static function make3DMeshBasicMaterial(color : Int, parameters : Array<Array<String>>) : Dynamic {
		return null;
	}

	public static function make3DLineBasicMaterial(color : Int, parameters : Array<Array<String>>) : Dynamic {
		return null;
	}

	public static function make3DPointsMaterial(color : Int, size : Float, parameters : Array<Array<String>>) : Dynamic {
		return null;
	}

	public static function make3DMeshStandardMaterial(color : Int, parameters : Array<Array<String>>) : Dynamic {
		return null;
	}

	public static function make3DMeshNormalMaterial(color : Int, parameters : Array<Array<String>>) : Dynamic {
		return null;
	}

	public static function make3DShaderMaterial(stage : Dynamic, uniforms : String, vertexShader : String, fragmentShader : String, parameters : Array<Array<String>>) : Dynamic {
		return null;
	}


	public static function set3DShaderMaterialUniformValue(material : Dynamic, uniform : String, value : String) : Void {
	}

	public static function get3DShaderMaterialUniformValue(material : Dynamic, uniform : String) : String {
		return "";
	}


	public static function make3DMesh(geometry : Dynamic, materials : Array<Dynamic>, parameters : Array<Array<String>>) : Dynamic {
		return null;
	}

	public static function make3DInstancedMesh(geometry : Dynamic, materials : Array<Dynamic>, parameters : Array<Array<String>>, count : Int, fn : Int -> Dynamic -> Void) : Dynamic {
		return null;
	}

	public static function make3DLineSegments(geometry : Dynamic, materials : Array<Dynamic>, parameters : Array<Array<String>>) : Dynamic {
		return null;
	}

	public static function make3DLine(geometry : Dynamic, materials : Array<Dynamic>, parameters : Array<Array<String>>) : Dynamic {
		return null;
	}

	public static function make3DPoints(geometry : Dynamic, materials : Array<Dynamic>, parameters : Array<Array<String>>) : Dynamic {
		return null;
	}


	public static function set3DAnimationDuration(animation : Dynamic, duration : Float) : Void {
	}

	public static function get3DAnimationDuration(animation : Dynamic) : Float {
		return 0.0;
	}

	public static function create3DAnimationMixer(object : Dynamic) : Dynamic {
		return null;
	}

	public static function start3DAnimationMixer(mixer : Dynamic, animation : Dynamic) : Void -> Void {
		return function() {};
	}

	public static function enable3DStageObjectCache(stage : Dynamic) : Void {
	}

	public static function clear3DStageObjectCache(stage : Dynamic) : Void {
	}

	public static function convert3DVectorToStageCoordinates(stage : Dynamic, x : Float, y : Float, z : Float) : Array<Float> {
		return [];
	}

	public static function make3DLOD() : Dynamic {
		return null;
	}

	public static function add3DLODLevel(lod : Dynamic, level : Float, object : Dynamic) : Void {
	}

	public static function export3DGLTFObject(object : Dynamic, exportFn : String -> Void, parameters : Array<Array<String>>) : Void {
	}

	public static function set3DObjectParameters(object : Dynamic, parameters : Array<Array<String>>) : Dynamic {
		return null;
	}

	public static function set3DObjectMaterialParameters(object : Dynamic, parameters : Array<Array<String>>) : Dynamic {
		return null;
	}

	public static function get3DObjectParameter(object : Dynamic, name : String, def : String) : String {
		return "";
	}

	public static function get3DGeometryParameter(object : Dynamic, name : String, def : String) : String {
		return "";
	}

	public static function get3DObjectMaterials(object : Dynamic) : Array<Dynamic> {
		return [];
	}

	public static function get3DObjectGeometries(object : Dynamic) : Array<Dynamic> {
		return [];
	}

	public static function set3DObjectMaterials(object : Dynamic, materials : Array<Dynamic>) : Void {
	}
}
