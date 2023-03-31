// This script is inserted just once, so we can allow global variables here.
let rayCanvasManager = new Map();

// These are the functions are used in hostCall in flow. 
function setCameraPosition(id, x, y, z) {
	rayCanvasManager.get(id.toString()).setCameraPosition(x, y, z)
}

function setCameraLookAt(id, x, y, z) {
	rayCanvasManager.get(id.toString()).setCameraLookAt(x, y, z)
}

function setCameraFov(id, fov) {
	rayCanvasManager.get(id.toString()).setCameraFov(fov)
}

function recompileShader(id, shader) {
	rayCanvasManager.get(id.toString()).recompileShader(shader)
}

function recompileMeshShader(id, shader) {
	rayCanvasManager.get(id.toString()).recompileMeshShader(shader)
}

function setDistanceFunction(id, fn) {
	rayCanvasManager.get(id.toString()).setDistanceFunction(fn)
}

function resizeCanvas(id) {
	rayCanvasManager.get(id.toString()).resizeCanvas()
}

function loadNewTexture(id, txtr) {
	rayCanvasManager.get(id.toString()).loadTexture(txtr)
}

function resetTextures(id) {
	rayCanvasManager.get(id.toString()).resetTextures()
}

function loadNewTextureParameters(id, params) {
	rayCanvasManager.get(id.toString()).loadTextureParameters(params)
}

function updateMaterialsColorParameters(id, params) {
	rayCanvasManager.get(id.toString()).updateMaterialsColor(params)
}

function updateMaterialsReflectivnessParameters(id, params) {
	rayCanvasManager.get(id.toString()).updateMaterialsReflectivness(params)
}

function updateObjectPositions(id, transformations) {
	rayCanvasManager.get(id.toString()).updateObjectPositions(transformations)
}

function updateObjectParameters(id, params) {
	rayCanvasManager.get(id.toString()).updateObjectParameters(params)
}

function updateSmoothCoefficients(id, params) {
	rayCanvasManager.get(id.toString()).updateSmoothCoefficients(params)
}

function toggleFirstPersonCamera(id, toggle) {
	rayCanvasManager.get(id.toString()).toggleFirstPersonCamera(toggle)
}

function changeThirdPersonCameraLimits(id, lowerLimit, upperLimit) {
	rayCanvasManager.get(id.toString()).changeThirdPersonCameraLimits({lower: lowerLimit, upper : upperLimit})
}

function changeFirstPersonCameraLimits(id, lowerLimit, upperLimit) {
	rayCanvasManager.get(id.toString()).changeFirstPersonCameraLimits({lower: lowerLimit, upper : upperLimit})
}

function changeFirstPersonCameraSpeed(id, speed) {
	rayCanvasManager.get(id.toString()).changeFirstPersonCameraSpeed(speed)
}

function changeFirstPersonCameraLeftMouseButtonUnlock(id, toggle) {
	rayCanvasManager.get(id.toString()).toggleFirstPersonCameraLeftMouseButtonUnlock(toggle)
}

function changeBackgroundColor(id, r, g, b, a) {
	rayCanvasManager.get(id.toString()).changeBackgroundColor(r, g, b, a)
}

function updateRepetitionCoefficients(id, spaces, repetitions) {
	rayCanvasManager.get(id.toString()).updateRepetitionCoefficients(spaces, repetitions)
}

function doOnDemandRender(id) {
	rayCanvasManager.get(id.toString()).doOnDemandRender()
}

function setOnDemandRender(id, toggle) {
	rayCanvasManager.get(id.toString()).setOnDemandRender(toggle)
}

function updateVisibility(id, params) {
	rayCanvasManager.get(id.toString()).updateVisibility(params)
}

function updateTextPoints(id, params) {
	rayCanvasManager.get(id.toString()).updateTextPoints(params)
}

function getTextCoords(id) {
	return rayCanvasManager.get(id.toString()).getTextCoords()
}

function setMaxRenderSteps(id, value) {
	rayCanvasManager.get(id.toString()).setMaxRenderSteps(value)
}

function setMaxRenderDistance(id, value) {
	rayCanvasManager.get(id.toString()).setMaxRenderDistance(value)
}

function setSurfaceDistance(id, value) {
	rayCanvasManager.get(id.toString()).setSurfaceDistance(value)
}

function deleteMeshes(id) {
	rayCanvasManager.get(id.toString()).deleteMeshes()
}

function addMesh(id, vertices, uvs, normals) {
	rayCanvasManager.get(id.toString()).addMesh(new Float32Array(vertices), new Float32Array(uvs), new Float32Array(normals))
}

function updateMeshParameters(id, models, colors, textures) {
	rayCanvasManager.get(id.toString()).updateMeshParameters(models, colors, textures)
}