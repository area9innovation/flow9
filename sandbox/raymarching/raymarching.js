var cameraPosition;
var cameraDirection;
var shaderProgram;
var yRotationAngle;
var xRotationAngle;
var defaultCameraDirection;

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

	var view = glm.mat4(1);
	view = glm.rotate(view, yRotationAngle, glm.vec3(0, 1, 0));
	view = glm.rotate(view, xRotationAngle, glm.vec3(1, 0, 0));
	return view;
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

	var view = getCameraRotationMatrix();
	gl.uniform3fv(gl.getUniformLocation(shaderProgram, "rayOrigin"), cameraPosition.elements);
	gl.uniformMatrix4fv(gl.getUniformLocation(shaderProgram, "view"), false, view.elements);

	gl.drawArrays(gl.TRIANGLE_FAN, 0, 4);
}

function drawAnimate(timestamp)
{
	cameraPosition = glm.vec3(12*Math.sin(timestamp/150), 8, 12*Math.cos(timestamp/150));
	drawFrame();

	window.requestAnimationFrame(drawAnimate);
}

function rayMain() {
	var canvas = document.getElementById('rayCanvas');
	gl = canvas.getContext('webgl');
	
	var vertices = [
		0.0,canvas.height,0.0,
		0.0,0.0,0.0,
		canvas.width,0.0,0.0,
		canvas.width,canvas.height,0.0, 
	];

	defaultCameraDirection = glm.vec4(0, 0, 1, 1);

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
	}, false);

	canvas.addEventListener('mousemove', function (evt) {
		if (mouseLeftDown || mouseMiddleDown || mouseRightDown) {
			var deltaX = evt.clientX - mouseX,
				deltaY = evt.clientY - mouseY;
			mouseX = evt.clientX;
			mouseY = evt.clientY;
			if (mouseLeftDown) {
				var rotateCamera= glm.mat4(1);
				rotateCamera = glm.rotate(rotateCamera, yRotationAngle + deltaX / 100., glm.vec3(0, 1, 0));
				rotateCamera = glm.rotate(rotateCamera, xRotationAngle + deltaY / 100., glm.vec3(1, 0, 0));
				cameraDirection = rotateCamera['*'](defaultCameraDirection).xyz['*'](glm.length(getCameraVector()))['+'](cameraPosition);
			} else if (mouseMiddleDown) {
				var dX = (deltaX * Math.cos(yRotationAngle + Math.PI) + deltaY * Math.sin(yRotationAngle)) / 100;
				var dZ = (deltaY * Math.cos(yRotationAngle) + deltaX * Math.sin(yRotationAngle)) / 100;
				cameraPosition.x += dX;
				cameraPosition.z += dZ;
				cameraDirection.x += dX;
				cameraDirection.z += dZ;
			} else if (mouseRightDown) {
				var dY = deltaY / 100;
				cameraPosition.y += dY;
				cameraDirection.y += dY;
				cameraPosition.x -= deltaX * Math.cos(yRotationAngle) / 100;
				cameraPosition.z += deltaX * Math.sin(yRotationAngle) / 100;
			}
			drawFrame();
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
		if (zoomLimitCheck > 2 && zoomLimitCheck < 20) {
			cameraPosition['-='](glm.normalize(direction)['*'](step));
			drawFrame();
		}
	}, false);

	var vertex_buffer = gl.createBuffer();
	gl.bindBuffer(gl.ARRAY_BUFFER, vertex_buffer);
	gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(vertices), gl.STATIC_DRAW);
	gl.bindBuffer(gl.ARRAY_BUFFER, null);
	
	var vertCode = document.getElementById("vertex-shader").text;
	var vertShader = gl.createShader(gl.VERTEX_SHADER);
	gl.shaderSource(vertShader, vertCode);
	gl.compileShader(vertShader);
	
	var fragCode = document.getElementById("fragment-shader").text;
	var fragShader = gl.createShader(gl.FRAGMENT_SHADER);
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
	
	gl.bindBuffer(gl.ARRAY_BUFFER, vertex_buffer);

	var coord = gl.getAttribLocation(shaderProgram, "coordinates");
	gl.vertexAttribPointer(coord, 3, gl.FLOAT, false, 0, 0); 
	gl.enableVertexAttribArray(coord);
	
	var projection = glm.ortho(0, canvas.width, 0, canvas.height);
	gl.uniformMatrix4fv(gl.getUniformLocation(shaderProgram, "projection"), false, projection.elements);
	gl.uniform2f(gl.getUniformLocation(shaderProgram, "screenSize"), canvas.width, canvas.height);

	gl.enable(gl.DEPTH_TEST);
	gl.viewport(0,0,canvas.width,canvas.height);
	
	%setCamera%;

	//window.requestAnimationFrame(drawAnimate);
	drawFrame();
}