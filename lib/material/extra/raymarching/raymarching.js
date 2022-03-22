var cameraPosition;
var cameraDirection;
var shaderProgram;
var yRotationAngle;
var xRotationAngle;
var defaultCameraDirection;
var frameDrawn = false;
var vertices;
var view;
var canvas;

function getCameraVector() {
	return cameraDirection['-'](cameraPosition);
}

function getCameraRotationMatrix() {
	var cameraDirectionFromOrigin = glm.normalize(getCameraVector());
	var rotationDirectionY  = cameraDirectionFromOrigin.x > 0. ? 1 : -1;
	yRotationAngle = rotationDirectionY * Math.acos(glm.dot(defaultCameraDirection.xz, glm.normalize(cameraDirectionFromOrigin.xz)));
	var updatedCameraDirection = glm.rotate(glm.mat4(1), yRotationAngle, glm.vec3(0, 1, 0))['*'](defaultCameraDirection).xyz;
	var rotationDirectionX = cameraDirectionFromOrigin.y > 0. ? -1 : 1;
	xRotationAngle = rotationDirectionX * Math.acos(glm.dot(updatedCameraDirection, cameraDirectionFromOrigin));

	view = glm.mat4(1);
	view = glm.rotate(view, yRotationAngle, glm.vec3(0, 1, 0));
	view = glm.rotate(view, xRotationAngle, glm.vec3(1, 0, 0));
}

function setCameraPosition(x, y, z) {
	cameraPosition = glm.vec3(x, y, z);
}

function setCameraDirection(x, y, z) {
	cameraDirection = glm.vec3(x, y, z);
}

function drawFrame() {
	gl.clearColor(1.0, 0.0, 0.0, 1.0);
	gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

	getCameraRotationMatrix();
	gl.uniform3fv(gl.getUniformLocation(shaderProgram, "rayOrigin"), cameraPosition.elements);
	gl.uniformMatrix4fv(gl.getUniformLocation(shaderProgram, "view"), false, view.elements);

	gl.drawArrays(gl.TRIANGLE_FAN, 0, 4);
	frameDrawn = true;
}

function drawLoop(timestamp)
{
	drawFrame();

	window.requestAnimationFrame(drawLoop);
}

function resizeCanvas(canvas) {
	vertices = new Float32Array([
		0.0, canvas.height,
		0.0, 0.0,
		canvas.width, 0.0,
		canvas.width, canvas.height,
	]);

	gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW);

	var projection = glm.ortho(0, canvas.width, 0, canvas.height);
	gl.uniformMatrix4fv(gl.getUniformLocation(shaderProgram, "projection"), false, projection.elements);
	gl.uniform2f(gl.getUniformLocation(shaderProgram, "screenSize"), canvas.width, canvas.height);

	gl.viewport(0, 0, canvas.width, canvas.height);
}

var MAX_STEPS = 100;
var MAX_DIST = 100;
var SURF_DIST = 0.001;
var objIntersection;
var invokeDistance = (p) => {return %distanceFunction%;};

function setDistanceFunction(fn) {
	invokeDistance = eval(fn);
}

function getDistance(p) {
	var d = MAX_DIST;

	d = invokeDistance(p);

	return d;
}

function rayMarch(ro, rd) {
	var dO = 0.;
	var d;
	for (var i=0; i< MAX_STEPS; i++){
		var p = ro['+'](rd['*'](dO));
		d = getDistance(p);
		dO += d;
		if (dO>MAX_DIST || d<SURF_DIST) break;
	}
	return dO; 
}

function initializeMouseEvents(canvas) {
	var mouseLeftDown = false,
		mouseMiddleDown = false,
		mouseRightDown = false,
		mouseX = 0,
		mouseY = 0;

	canvas.addEventListener('mousedown', function (evt) {
		if (evt.button == 0) mouseLeftDown = true;
		if (evt.button == 1) mouseMiddleDown = true;
		if (evt.button == 2) mouseRightDown = true;
		mouseX = evt.clientX;
		mouseY = evt.clientY;

		var uv = glm.vec2(
			(mouseX - canvas.getBoundingClientRect().x - 0.5 * canvas.width) / canvas.height,
			(0.5 * canvas.height - mouseY + canvas.getBoundingClientRect().y) / canvas.height
		);
		var rd = glm.normalize(glm.vec3 (uv.x, uv.y, 1));
		rd = (view['*'](glm.vec4(rd, 1))).xyz;
		//TODO: check d for max distance to prevent weird rotations
		var d = rayMarch(cameraPosition, rd);
		objIntersection = cameraPosition['+'](rd['*'](d));
	}, false);
	canvas.addEventListener('mousemove', function (evt) {
		if (frameDrawn && (mouseLeftDown || mouseMiddleDown || mouseRightDown)) {
			var deltaX = evt.clientX - mouseX,
				deltaY = evt.clientY - mouseY;
			mouseX = evt.clientX;
			mouseY = evt.clientY;
			if (mouseLeftDown) {
				var angleX = xRotationAngle + deltaY / 100.;
				angleX = angleX > - Math.PI / 2 && angleX < Math.PI / 2 ? deltaY / 100 : 0;
				var angleY = deltaX / 100;
				var xRotatationAxis = glm.rotate(glm.mat4(1), yRotationAngle, glm.vec3(0, 1, 0))['*'](glm.vec4(1, 0, 0, 1)).xyz;

				var rotateCamera = glm.mat4(1);
				rotateCamera = glm.rotate(rotateCamera, angleY, glm.vec3(0, 1, 0));
				rotateCamera = glm.rotate(rotateCamera, angleX, xRotatationAxis);

				var pd = cameraDirection['-'](cameraPosition);
				var po = objIntersection['-'](cameraPosition);
				//M is projection of O on PD
				var m = cameraPosition['+'](pd['*'](glm.dot(pd, po)/glm.dot(pd, pd)));
				var md = cameraDirection['-'](m);
				var mp = cameraPosition['-'](m);
				var om = m['-'](objIntersection);
				var mdNew = rotateCamera['*'](glm.vec4(glm.normalize(md), 1)).xyz['*'](glm.length(md));
				var mpNew = rotateCamera['*'](glm.vec4(glm.normalize(mp), 1)).xyz['*'](glm.length(mp));
				var omNew = rotateCamera['*'](glm.vec4(glm.normalize(om), 1)).xyz['*'](glm.length(om));

				cameraDirection = omNew['+'](mdNew)['+'](objIntersection);
				cameraPosition = omNew['+'](mpNew)['+'](objIntersection);
			} else if (mouseMiddleDown) {
				var dX = (deltaX * Math.cos(yRotationAngle + Math.PI) + deltaY * Math.sin(yRotationAngle)) / 100;
				var dZ = (deltaY * Math.cos(yRotationAngle) + deltaX * Math.sin(yRotationAngle)) / 100;
				cameraPosition.x += dX;
				cameraPosition.z += dZ;
				cameraDirection.x += dX;
				cameraDirection.z += dZ;
			} else if (mouseRightDown) {
				var dX = (deltaX * Math.cos(yRotationAngle + Math.PI)) / 100;
				var dY = deltaY / 100;
				var dZ = (deltaX * Math.sin(yRotationAngle)) / 100;

				cameraPosition.x += dX;
				cameraPosition.y += dY;
				cameraPosition.z += dZ;
				cameraDirection.x += dX;
				cameraDirection.y += dY;
				cameraDirection.z += dZ;
			}
			frameDrawn = false;
		}
	}, false);
		
	canvas.addEventListener('mouseup', function (evt) {
		mouseLeftDown = false;
		mouseMiddleDown = false;
		mouseRightDown = false;
	}, false);

	canvas.addEventListener('wheel', function (evt) {
		var direction = getCameraVector();
		var step = evt.deltaY / 100;
		var zoomLimitCheck = glm.length(direction) + step;
		if (zoomLimitCheck > 2 && (zoomLimitCheck < 20 || step < 0)) {
			cameraPosition['-='](glm.normalize(direction)['*'](step));
		}
	}, {passive: true});
}

var fragShader;
function createShader() {
	var vertCode = document.getElementById("vertex-shader").text;
	var vertShader = gl.createShader(gl.VERTEX_SHADER);
	gl.shaderSource(vertShader, vertCode);
	gl.compileShader(vertShader);
	
	var fragCode = document.getElementById("fragment-shader").text;
	fragShader = gl.createShader(gl.FRAGMENT_SHADER);
	gl.shaderSource(fragShader, fragCode); 
	gl.compileShader(fragShader);
	shaderProgram = gl.createProgram();
	
	var compilationLogV = gl.getShaderInfoLog(vertShader);
	if (compilationLogV.length != 0) console.log('Vertex shader compiler log: ' + compilationLogV);
	var compilationLogF = gl.getShaderInfoLog(fragShader);
	if (compilationLogF.length != 0) console.log('Fragment shader compiler log: ' + compilationLogF);
	
	gl.attachShader(shaderProgram, vertShader);
	gl.attachShader(shaderProgram, fragShader);
	gl.linkProgram(shaderProgram);
	gl.useProgram(shaderProgram);
}

function recompileShader(fragCode) {
	gl.detachShader(shaderProgram, fragShader);

	fragShader = gl.createShader(gl.FRAGMENT_SHADER);
	gl.shaderSource(fragShader, fragCode); 
	gl.compileShader(fragShader);

	var compilationLogF = gl.getShaderInfoLog(fragShader);
	if (compilationLogF.length != 0) console.log('Fragment shader compiler log: ' + compilationLogF);
	
	gl.attachShader(shaderProgram, fragShader);
	gl.linkProgram(shaderProgram);
	gl.useProgram(shaderProgram);

	var projection = glm.ortho(0, canvas.width, 0, canvas.height);
	gl.uniformMatrix4fv(gl.getUniformLocation(shaderProgram, "projection"), false, projection.elements);
	gl.uniform2f(gl.getUniformLocation(shaderProgram, "screenSize"), canvas.width, canvas.height);
}

function rayMain() {
	canvas = document.getElementById('rayCanvas');
	gl = canvas.getContext('webgl');
	defaultCameraDirection = glm.vec4(0, 0, 1, 1);

	createShader();

	var vertex_buffer = gl.createBuffer();
	gl.bindBuffer(gl.ARRAY_BUFFER, vertex_buffer);

	var coord = gl.getAttribLocation(shaderProgram, "coordinates");
	gl.vertexAttribPointer(coord, 2, gl.FLOAT, false, 0, 0); 
	gl.enableVertexAttribArray(coord);

	resizeCanvas(canvas);
	
	%setCamera%;

	initializeMouseEvents(canvas);

	window.requestAnimationFrame(drawLoop);
}