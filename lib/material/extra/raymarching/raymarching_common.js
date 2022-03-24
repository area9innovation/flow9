// This script is inserted just once, so we can allow global variables here.
let rayCanvasManager = new Map();

// These are the functions are used in hostCall in flow. 
function setCameraPosition(id, x, y, z) {
	rayCanvasManager.get(id.toString()).setCameraPosition(x, y, z)
}

function setCameraDirection(id, x, y, z) {
	rayCanvasManager.get(id.toString()).setCameraDirection(x, y, z)
}

function recompileShader(id, shader) {
	rayCanvasManager.get(id.toString()).recompileShader(shader)
}

function setDistanceFunction(id, fn) {
	rayCanvasManager.get(id.toString()).setDistanceFunction(fn)
}