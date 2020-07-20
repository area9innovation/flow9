package com.area9innovation.flow;

public class RenderSupport3D extends NativeHost {
	private Func0<Object> no_op = new Func0<Object>() {
		public Object invoke() { return null; }
	};

	public Object load3DLibraries(Func0<Object> cb) {
		return null;
	}

	public Object[] get3DSupportedExtensions(Object stage) {
		return new Object[0];
	}

	public Object add3DChild(Object parent, Object child) {
		return null;
	}
	public Object add3DChildAt(Object parent, Object child, Integer index) {
		return null;
	}
	public Object remove3DChild(Object parent, Object child) {
		return null;
	}

	public Object[] get3DObjectChildren(Object object) {
		return new Object[0];
	}
	public String get3DObjectJSON(Object object, boolean includeCamera) {
		return "";
	}

	public String get3DObjectState(Object object) {
		return "";
	}
	public Object apply3DObjectState(Object object, String state) {
		return null;
	}

	public Object make3DObjectFromJSON(Object stage, String json) {
		return null;
	}
	public Object make3DObjectFromObj(Object stage, String obj, String mtl) {
		return null;
	}
	public Object make3DGeometryFromJSON(String json) {
		return null;
	}
	public Object make3DMaterialsFromJSON(String json) {
		return null;
	}

	public Object make3DStage(Double width, Double height) {
		return null;
	}
	public Object dispose3DStage(Object stage) {
		return null;
	}
	public Object make3DScene() {
		return null;
	}
	public Object make3DColor(String color) {
		return null;
	}

	public Object set3DSceneBackground(Object scene, Object background) {
		return null;
	}
	public Object set3DSceneFog(Object scene, Object fog) {
		return null;
	}

	public Object load3DObject(Object stage, String objUrl, String mtlUrl, Func1<Object,Object> onLoad) {
		return null;
	}
	public Func0<Object> load3DGLTFObject(Object stage, String url, Func5<Object,Object[],Object,Object[],Object[],Object> onLoad, Func1<Object,String> onError) {
		return no_op;
	}
	public Object load3DScene(Object stage, String url, Func1<Object,Object> onLoad) {
		return null;
	}
	public Object make3DTextureLoader(Object stage, String url, Func1<Object,Object> onLoad, Object[] parameters) {
		return null;
	}
	public Func0<Object> load3DTexture(Object texture) {
		return no_op;
	}
	public Object load3DCubeTexture(Object stage, String px, String nx, String py, String ny, String pz, String nz, Func1<Object,Object> onLoad, Object[] parameters) {
		return null;
	}
	public Object make3DDataTexture(Object[] data, Integer width, Integer height, Object[] parameters) {
		return null;
	}
	public Object make3DCanvasTexture(Object clip, Object[] parameters) {
		return null;
	}


	public Object set3DMaterialMap(Object object, Object map) {
		return null;
	}

	public Object set3DMaterialAlphaMap(Object object, Object alphaMap) {
		return null;
	}

	public Object set3DMaterialDisplacementMap(Object object, Object displacementMap, Double displacementScale, Double displacementBias) {
		return null;
	}

	public Object set3DMaterialBumpMap(Object object, Object bumpMap, Double bumpScale) {
		return null;
	}

	public Object set3DMaterialOpacity(Object object, Double opacity) {
		return null;
	}

	public Object set3DMaterialColor(Object object, Integer color) {
		return null;
	}


	public Object set3DTextureRotation(Object object, Double rotation) {
		return null;
	}

	public Object set3DTextureOffsetX(Object object, Double x) {
		return null;
	}

	public Object set3DTextureOffsetY(Object object, Double y) {
		return null;
	}


	public Object make3DAxesHelper(Double size) {
		return null;
	}
	public Object make3DGridHelper(Double size, Integer divisions, Integer colorCenterLine, Integer colorGrid) {
		return null;
	}

	public Object make3DVertexNormalsHelper(Object object, Double size, Integer color, Double lineWidth) {
		return null;
	}


	public Object set3DCamera(Object stage, Object camera, Object[] parameters) {
		return null;
	}
	public Object set3DScene(Object stage, Object scene) {
		return null;
	}

	public Func0<Object> add3DEventListener(Object stage, String event, Func0<Object> cb) {
		return no_op;
	}
	public Object emit3DMouseEvent(Object stage, String event, Double x, Double y) {
		return null;
	}
	public Object emit3DTouchEvent(Object stage, String event, Object[] points) {
		return null;
	}
	public Object emit3DKeyEvent(Object stage, String event, String utf, Boolean ctrl, Boolean shift, Boolean alt, Boolean meta, Integer keycode) {
		return null;
	}

	public Object attach3DTransformControls(Object stage, Object object) {
		return null;
	}
	public Object detach3DTransformControls(Object stage, Object object) {
		return null;
	}
	public Object clear3DTransformControls(Object object) {
		return null;
	}
	public Object set3DOrbitControlsEnabled(Object object, Boolean enabled) {
		return null;
	}
	public Boolean is3DTransformControlsAttached(Object stage, Object object) {
		return false;
	}


	public Object set3DTransformControlsMode(Object stage, String mode) {
		return null;
	}
	public String get3DTransformControlsMode(Object stage) {
		return "";
	}

	public Object set3DTransformControlsTranslationSnap(Object stage, Double snap) {
		return null;
	}
	public Double get3DTransformControlsTranslationSnap(Object stage) {
		return 0.0;
	}

	public Object set3DTransformControlsRotationSnap(Object stage, Double snap) {
		return null;
	}
	public Double get3DTransformControlsRotationSnap(Object stage) {
		return 0.0;
	}

	public Object set3DTransformControlsSize(Object stage, Double size) {
		return null;
	}
	public Double get3DTransformControlsSize(Object stage) {
		return 0.0;
	}

	public Object set3DTransformControlsShowX(Object stage, Boolean show) {
		return null;
	}
	public Boolean get3DTransformControlsShowX(Object stage) {
		return false;
	}

	public Object set3DTransformControlsShowY(Object stage, Boolean show) {
		return null;
	}
	public Boolean get3DTransformControlsShowY(Object stage) {
		return false;
	}

	public Object set3DTransformControlsShowZ(Object stage, Boolean show) {
		return null;
	}
	public Boolean get3DTransformControlsShowZ(Object stage) {
		return false;
	}

	public Object set3DTransformControlsEnabled(Object stage, Boolean enabled) {
		return null;
	}
	public Boolean get3DTransformControlsEnabled(Object stage) {
		return false;
	}

	public Object attach3DBoxHelper(Object stage, Object object) {
		return null;
	}
	public Object detach3DBoxHelper(Object stage, Object object) {
		return null;
	}
	public Object clear3DBoxHelpers(Object object) {
		return null;
	}

	public String get3DObjectId(Object object) {
		return "";
	}
	public Object[] get3DObjectById(Object stage, String id) {
		return new Object[0];
	}
	public String get3DObjectType(Object object) {
		return "";
	}
	public String get3DObjectName(Object object) {
		return "";
	}
	public Object set3DObjectName(Object object, String name) {
		return null;
	}

	public Boolean get3DObjectVisible(Object object) {
		return false;
	}
	public Object set3DObjectVisible(Object object, Boolean visible) {
		return null;
	}

	public Double get3DObjectAlpha(Object object) {
		return 0.0;
	}
	public Object set3DObjectAlpha(Object object, Double alpha) {
		return null;
	}

	public Boolean get3DObjectCastShadow(Object object) {
		return false;
	}
	public Object set3DObjectCastShadow(Object object, Boolean castShadow) {
		return null;
	}

	public Boolean get3DObjectReceiveShadow(Object object) {
		return false;
	}
	public Object set3DObjectReceiveShadow(Object object, Boolean receiveShadow) {
		return null;
	}

	public Boolean get3DObjectFrustumCulled(Object object) {
		return false;
	}
	public Object set3DObjectFrustumCulled(Object object, Boolean frustumCulled) {
		return null;
	}

	public Double get3DObjectLocalPositionX(Object object) {
		return 0.0;
	}
	public Double get3DObjectLocalPositionY(Object object) {
		return 0.0;
	}
	public Double get3DObjectLocalPositionZ(Object object) {
		return 0.0;
	}

	public Object set3DObjectLocalPositionX(Object object, Double x) {
		return null;
	}
	public Object set3DObjectLocalPositionY(Object object, Double y) {
		return null;
	}
	public Object set3DObjectLocalPositionZ(Object object, Double z) {
		return null;
	}

	public Double get3DObjectLocalRotationX(Object object) {
		return 0.0;
	}
	public Double get3DObjectLocalRotationY(Object object) {
		return 0.0;
	}
	public Double get3DObjectLocalRotationZ(Object object) {
		return 0.0;
	}

	public Object set3DObjectLocalRotationX(Object object, Double x) {
		return null;
	}
	public Object set3DObjectLocalRotationY(Object object, Double y) {
		return null;
	}
	public Object set3DObjectLocalRotationZ(Object object, Double z) {
		return null;
	}

	public Double get3DObjectLocalScaleX(Object object) {
		return 0.0;
	}
	public Double get3DObjectLocalScaleY(Object object) {
		return 0.0;
	}
	public Double get3DObjectLocalScaleZ(Object object) {
		return 0.0;
	}

	public Object set3DObjectLocalScaleX(Object object, Double x) {
		return null;
	}
	public Object set3DObjectLocalScaleY(Object object, Double y) {
		return null;
	}
	public Object set3DObjectLocalScaleZ(Object object, Double z) {
		return null;
	}

	public Double get3DObjectWorldX(Object object) {
		return 0.0;
	}
	public Double get3DObjectWorldY(Object object) {
		return 0.0;
	}
	public Double get3DObjectWorldZ(Object object) {
		return 0.0;
	}

	public Object set3DObjectWorldX(Object object, Double x) {
		return null;
	}
	public Object set3DObjectWorldY(Object object, Double y) {
		return null;
	}
	public Object set3DObjectWorldZ(Object object, Double z) {
		return null;
	}

	public Double get3DObjectWorldRotationX(Object object) {
		return 0.0;
	}
	public Double get3DObjectWorldRotationY(Object object) {
		return 0.0;
	}
	public Double get3DObjectWorldRotationZ(Object object) {
		return 0.0;
	}

	public Object set3DObjectWorldRotationX(Object object, Double x) {
		return null;
	}
	public Object set3DObjectWorldRotationY(Object object, Double y) {
		return null;
	}
	public Object set3DObjectWorldRotationZ(Object object, Double z) {
		return null;
	}

	public Double get3DObjectWorldScaleX(Object object) {
		return 0.0;
	}
	public Double get3DObjectWorldScaleY(Object object) {
		return 0.0;
	}
	public Double get3DObjectWorldScaleZ(Object object) {
		return 0.0;
	}

	public Object set3DObjectWorldScaleX(Object object, Double x) {
		return null;
	}
	public Object set3DObjectWorldScaleY(Object object, Double y) {
		return null;
	}
	public Object set3DObjectWorldScaleZ(Object object, Double z) {
		return null;
	}

	public Object set3DObjectLookAt(Object object, Double x, Double y, Double z) {
		return null;
	}

	public Object set3DObjectLocalMatrix(Object object, Object[] matrix) {
		return null;
	}

	public Object set3DObjectWorldMatrix(Object object, Object[] matrix) {
		return null;
	}

	public Object set3DObjectInteractive(Object object, Boolean interactive) {
		return null;
	}
	public Boolean get3DObjectInteractive(Object object) {
		return false;
	}

	public Object[] get3DObjectBoundingBox(Object object) {
		return new Object[0];
	}

	public Func0<Object> add3DObjectLocalPositionListener(Object object, Func3<Object,Double,Double,Double> cb) {
		return no_op;
	}
	public Func0<Object> add3DObjectWorldPositionListener(Object object, Func3<Object,Double,Double,Double> cb) {
		return no_op;
	}
	public Func0<Object> add3DObjectStagePositionListener(Object stage, Object object, Func2<Object,Double,Double> cb) {
		return no_op;
	}
	public Func0<Object> add3DObjectLocalRotationListener(Object object, Func3<Object,Double,Double,Double> cb) {
		return no_op;
	}
	public Func0<Object> add3DObjectLocalScaleListener(Object object, Func3<Object,Double,Double,Double> cb) {
		return no_op;
	}
	public Func0<Object> add3DObjectBoundingBoxListener(Object object, Func1<Object,Object[]> cb) {
		return no_op;
	}
	public Func0<Object> add3DObjectLocalMatrixListener(Object object, Func1<Object,Object[]> cb) {
		return no_op;
	}
	public Func0<Object> add3DObjectWorldMatrixListener(Object object, Func1<Object,Object[]> cb) {
		return no_op;
	}


	public Object make3DPerspectiveCamera(Double fov, Double aspect, Double near, Double far) {
		return null;
	}

	public Object make3DOrthographicCamera(Double width, Double height, Double near, Double far) {
		return null;
	}

	public Object set3DCameraFov(Object object, Double fov) {
		return null;
	}
	public Object set3DCameraAspect(Object object, Double aspect) {
		return null;
	}
	public Object set3DCameraNear(Object object, Double near) {
		return null;
	}
	public Object set3DCameraFar(Object object, Double far) {
		return null;
	}
	public Object set3DCameraWidth(Object object, Double width) {
		return null;
	}
	public Object set3DCameraHeight(Object object, Double height) {
		return null;
	}
	public Object set3DCameraZoom(Object object, Double zoom) {
		return null;
	}

	public Object get3DCameraFov(Object object) {
		return 0.0;
	}
	public Object get3DCameraAspect(Object object) {
		return 0.0;
	}
	public Object get3DCameraNear(Object object) {
		return 0.0;
	}
	public Object get3DCameraFar(Object object) {
		return 0.0;
	}
	public Object get3DCameraZoom(Object object) {
		return 0.0;
	}

	public Object make3DPointLight(Integer color, Double intensity, Double distance, Double decayAmount) {
		return null;
	}

	public Object make3DSpotLight(Integer color, Double intensity, Double distance, Double angle, Double penumbra, Double decayAmount) {
		return null;
	}

	public Object make3DAmbientLight(Integer color, Double intensity) {
		return null;
	}

	public Object set3DObjectColor(Object object, Integer color) {
		return null;
	}
	public Object set3DObjectEmissive(Object object, Integer color) {
		return null;
	}
	public Object set3DLightIntensity(Object object, Double intensity) {
		return null;
	}
	public Object set3DLightDistance(Object object, Double distance) {
		return null;
	}
	public Object set3DLightAngle(Object object, Double angle) {
		return null;
	}
	public Object set3DLightPenumbra(Object object, Double penumbra) {
		return null;
	}
	public Object set3DLightDecay(Object object, Double decayAmount) {
		return null;
	}

	public Integer get3DObjectColor(Object object) {
		return 0;
	}
	public Integer get3DObjectEmissive(Object object) {
		return 0;
	}
	public Double get3DLightIntensity(Object object) {
		return 0.0;
	}
	public Double get3DLightDistance(Object object) {
		return 0.0;
	}
	public Double get3DLightAngle(Object object) {
		return 0.0;
	}
	public Double get3DLightPenumbra(Object object) {
		return 0.0;
	}
	public Double get3DLightDecay(Object object) {
		return 0.0;
	}


	public Object make3DPlaneGeometry(Double width, Double height,
		Integer widthSegments, Integer heightSegments) {
		return null;
	}

	public Object make3DBoxGeometry(Double width, Double height, Double depth,
		Integer widthSegments, Integer heightSegments, Integer depthSegments) {
		return null;
	}

	public Object make3DCircleGeometry(Double radius, Integer segments,
		Double thetaStart, Double thetaLength) {
		return null;
	}

	public Object make3DRingGeometry(Double innerRadius, Double outerRadius, Integer segments,
		Double thetaStart, Double thetaLength) {
		return null;
	}

	public Object make3DConeGeometry(Double radius, Double height, Integer radialSegments, Integer heightSegments,
		Boolean openEnded, Double thetaStart, Double thetaLength) {
		return null;
	}

	public Object make3DCylinderGeometry(Double radiusTop, Double radiusBottom, Double height, Integer radialSegments,
		Integer heightSegments, Boolean openEnded, Double thetaStart, Double thetaLength) {
		return null;
	}

	public Object make3DSphereGeometry(Double radius, Integer widthSegments, Integer heightSegments,
		Double phiStart, Double phiLength, Double thetaStart, Double thetaLength) {
		return null;
	}

	public Object set3DGeometryMatrix(Object geometry, Object[] matrix) {
		return null;
	}


	public Object make3DSphereBufferGeometry(Double radius, Integer widthSegments, Integer heightSegments,
		Double phiStart, Double phiLength, Double thetaStart, Double thetaLength, Func2<Object[], Integer, Integer> addGroups) {
		return null;
	}

	public Object make3DCylinderBufferGeometry(Double radiusTop, Double radiusBottom, Double height, Integer radialSegments,
		Integer heightSegments, Boolean openEnded, Double thetaStart, Double thetaLength, Func2<Object[], Integer, Integer> addGroups) {
		return null;
	}

	public Object make3DBoxBufferGeometry(Double width, Double height, Double depth, Integer widthSegments, Integer heightSegments,
		Integer depthSegments, Func2<Object[], Integer, Integer> addGroups) {
		return null;
	}

	public Object make3DShapeBufferGeometry(Object[] pathes, Func2<Object[], Integer, Integer> addGroups) {
		return null;
	}

	public Object make3DBufferFromGeometry(Object geometry, Object[] parameters) {
		return null;
	}


	public Object add3DBufferGeometryAttribute(Object geometry, String name, Object[] data) {
		return null;
	}
	public Object[] get3DBufferGeometryAttribute(Object geometry, String name) {
		return new Object[0];
	}


	public Object make3DShapeGeometry(Object[] pathes) {
		return null;
	}

	public Object make3DVertexGeometry(Object[] vertices) {
		return null;
	}

	public Object make3DShapeGeometry3D(Object[] path) {
		return null;
	}

	public Object make3DVertexGeometry3D(Object[] vertices) {
		return null;
	}

	public Object make3DWireframeGeometry(Object geometry) {
		return null;
	}

	public Object modify3DGeometryVertices(Object geometry, Func1<Object[], Object[]> modifyFn) {
		return null;
	}

	public Object make3DEdgesGeometry(Object geometry) {
		return null;
	}

	public Object tesselate3DGeometry(Object geometry, Double distance, Integer iterations) {
		return null;
	}

	public Object simplify3DGeometry(Object geometry, Func1<Integer, Integer> countFn) {
		return null;
	}


	public Object make3DMeshBasicMaterial(Integer color, Object[] parameters) {
		return null;
	}

	public Object make3DLineBasicMaterial(Integer color, Object[] parameters) {
		return null;
	}

	public Object make3DPointsMaterial(Integer color, Double size, Object[] parameters) {
		return null;
	}

	public Object make3DMeshStandardMaterial(Integer color, Object[] parameters) {
		return null;
	}

	public Object make3DMeshNormalMaterial(Integer color, Object[] parameters) {
		return null;
	}

	public Object make3DShaderMaterial(Object stage, String uniforms, String vertexShader, String fragmentShader, Object[] parameters) {
		return null;
	}


	public Object set3DShaderMaterialUniformValue(Object material, String uniform, String value) {
		return null;
	}

	public String get3DShaderMaterialUniformValue(Object material, String uniform) {
		return "";
	}


	public Object make3DMesh(Object geometry, Object[] materials, Object[] parameters) {
		return null;
	}

	public Object make3DInstancedMesh(Object geometry, Object[] materials, Object[] parameters, Integer count, Func2<Object,Integer,Object> fn) {
		return null;
	}

	public Object make3DLine(Object geometry, Object[] materials, Object[] parameters) {
		return null;
	}

	public Object make3DLineSegments(Object geometry, Object[] materials, Object[] parameters) {
		return null;
	}

	public Object make3DPoints(Object geometry, Object[] materials, Object[] parameters) {
		return null;
	}


	public Object set3DAnimationDuration(Object animation, Double duration) {
		return null;
	}
	public Double get3DAnimationDuration(Object animation) {
		return 0.0;
	}
	public Object create3DAnimationMixer(Object object) {
		return null;
	}
	public Func0<Object> start3DAnimationMixer(Object mixer, Object animation) {
		return no_op;
	}

	public Object enable3DStageObjectCache(Object stage) {
		return null;
	}
	public Object clear3DStageObjectCache(Object stage) {
		return null;
	}
	public Object[] convert3DVectorToStageCoordinates(Object stage, Double x, Double y, Double z) {
		return new Object[0];
	}

	public Object make3DLOD() {
		return null;
	}

	public Object add3DLODLevel(Object lod, Double level, Object object) {
		return null;
	}

	public Object export3DGLTFObject(Object object, Func1<Object, String> exportFn, Object[] parameters) {
		return null;
	}

	public Object set3DObjectParameters(Object object, Object[] parameters) {
		return null;
	}

	public Object set3DObjectMaterialParameters(Object object, Object[] parameters) {
		return null;
	}

	public String get3DObjectParameter(Object object, String name, String def) {
		return "";
	}

	public String get3DGeometryParameter(Object geometry, String name, String def) {
		return "";
	}

	public Object[] get3DObjectMaterials(Object object) {
		return new Object[0];
	}

	public Object[] get3DObjectGeometries(Object object) {
		return new Object[0];
	}
}