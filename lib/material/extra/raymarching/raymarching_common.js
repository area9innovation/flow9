// This script is inserted just once, so we can allow global variables here.
let rayCanvasManager = new Map();

// These are the functions are used in hostCall in flow. 
function setCameraPosition(id, x, y, z) {
	rayCanvasManager.get(id.toString()).setCameraPosition(x, y, z)
}

function setCameraLookAt(id, x, y, z) {
	rayCanvasManager.get(id.toString()).setCameraLookAt(x, y, z)
}

function recompileShader(id, shader) {
	rayCanvasManager.get(id.toString()).recompileShader(shader)
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

function updateObjectPositions(id, params) {
	rayCanvasManager.get(id.toString()).updateObjectPositions(params)
}

function updateObjectParameters(id, params) {
	rayCanvasManager.get(id.toString()).updateObjectParameters(params)
}

