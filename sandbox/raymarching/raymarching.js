var cameraPosition;
var cameraDirection;
var shaderProgram;
var yRotationAngle;
var xRotationAngle;

function getCameraRotationMatrix(cameraPosition, cameraDirection) {
	var defaultCameraDirection = glm.vec3(0, 0, 1);
	var cameraDirectionFromOrigin = glm.normalize(cameraDirection['-'](cameraPosition));
	var rotationDirectionY  = cameraDirectionFromOrigin.x > 0. ? 1 : -1;
	yRotationAngle = rotationDirectionY * Math.acos(glm.dot(defaultCameraDirection.xz, glm.normalize(cameraDirectionFromOrigin.xz)));
	var updatedCameraDirection = glm.rotate(glm.mat4(1), yRotationAngle, glm.vec3(0, 1, 0))['*'](glm.vec4(defaultCameraDirection, 1.)).xyz;
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

	var view = getCameraRotationMatrix(cameraPosition, cameraDirection);
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

	var mouseLeftDown = false,
		mouseMiddleDown = false,
		mouseRightDown = false,
        mouseX = 0,
        mouseY = 0;

	canvas.addEventListener('mousemove', function (evt) {
		evt.preventDefault();
		if (mouseLeftDown) {
			var deltaX = evt.clientX - mouseX,
				deltaY = evt.clientY - mouseY;
			mouseX = evt.clientX;
			mouseY = evt.clientY;
			cameraPosition = glm.vec3(
				cameraPosition.x - deltaX * Math.cos(yRotationAngle)/ 100,
				cameraPosition.y,
				cameraPosition.z + deltaX * Math.sin(yRotationAngle)/ 100
			);
			drawFrame();
		}
		else if (mouseMiddleDown) {
			var deltaX = evt.clientX - mouseX,
			deltaY = evt.clientY - mouseY;
			mouseX = evt.clientX;
			mouseY = evt.clientY;
			cameraPosition = glm.vec3(
				cameraPosition.x + (deltaY * Math.sin(yRotationAngle) + deltaX * Math.cos(yRotationAngle + Math.PI/2))/ 100,
				cameraPosition.y,
				cameraPosition.z + (deltaX * Math.sin(yRotationAngle + Math.PI/2) + deltaY * Math.cos(yRotationAngle))/ 100
			);
			cameraDirection = glm.vec3(
				cameraDirection.x + (deltaY * Math.sin(yRotationAngle) + deltaX * Math.cos(yRotationAngle + Math.PI/2))/ 100,
				cameraDirection.y,
				cameraDirection.z + (deltaX * Math.sin(yRotationAngle + Math.PI/2) + deltaY * Math.cos(yRotationAngle))/ 100
			);
			drawFrame();
		} else if (mouseRightDown) {
			var deltaX = evt.clientX - mouseX,
			deltaY = evt.clientY - mouseY;
			mouseX = evt.clientX;
			mouseY = evt.clientY;
			cameraPosition = glm.vec3(
				cameraPosition.x,
				cameraPosition.y + deltaY / 100,
				cameraPosition.z
			);
			cameraDirection = glm.vec3(
				cameraDirection.x,
				cameraDirection.y + deltaY / 100,
				cameraDirection.z
			);
			drawFrame();
		}
	}, false);
        
    canvas.addEventListener('mousedown', function (evt) {
        evt.preventDefault();
        if (evt.button == 0) mouseLeftDown = true;
		if (evt.button == 1) mouseMiddleDown = true;
		if (evt.button == 2) mouseRightDown = true;
        mouseX = evt.clientX;
        mouseY = evt.clientY;
    }, false);
    
    canvas.addEventListener('mouseup', function (evt) {
        evt.preventDefault();
        mouseLeftDown = false;
		mouseMiddleDown = false;
		mouseRightDown = false;
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