var canvas = document.getElementById('rayCanvas');
gl = canvas.getContext('webgl');

var vertices = [
	0.0,canvas.height,0.0,
	0.0,0.0,0.0,
	canvas.width,0.0,0.0,
	canvas.width,canvas.height,0.0, 
];
indices = [0,1,2,3];

var vertex_buffer = gl.createBuffer();
gl.bindBuffer(gl.ARRAY_BUFFER, vertex_buffer);
gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(vertices), gl.STATIC_DRAW);
gl.bindBuffer(gl.ARRAY_BUFFER, null);

var index_buffer = gl.createBuffer();
gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, index_buffer);
gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(indices), gl.STATIC_DRAW);
gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, null);


var vertCode = document.getElementById("vertex-shader").text;
var vertShader = gl.createShader(gl.VERTEX_SHADER);
gl.shaderSource(vertShader, vertCode);
gl.compileShader(vertShader);

var fragCode = document.getElementById("fragment-shader").text;
var fragShader = gl.createShader(gl.FRAGMENT_SHADER);
gl.shaderSource(fragShader, fragCode); 
gl.compileShader(fragShader);
var shaderProgram = gl.createProgram();

var compilationLogV = gl.getShaderInfoLog(vertShader);
if (compilationLogV.length != 0) console.log('Vertex shader compiler log: ' + compilationLogV);
var compilationLogF = gl.getShaderInfoLog(fragShader);
if (compilationLogF.length != 0) console.log('Fragment shader compiler log: ' + compilationLogF);

gl.attachShader(shaderProgram, vertShader);
gl.attachShader(shaderProgram, fragShader);
gl.linkProgram(shaderProgram);
gl.useProgram(shaderProgram);


gl.bindBuffer(gl.ARRAY_BUFFER, vertex_buffer);
gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, index_buffer);

var coord = gl.getAttribLocation(shaderProgram, "coordinates");
gl.vertexAttribPointer(coord, 3, gl.FLOAT, false, 0, 0); 
gl.enableVertexAttribArray(coord);


var projection = glm.ortho(0, canvas.width, 0, canvas.height);
var locP = gl.getUniformLocation(shaderProgram, "projection");
gl.uniformMatrix4fv(locP, false, projection.elements);
gl.uniform2f(gl.getUniformLocation(shaderProgram, "screenSize"), canvas.width, canvas.height);

function getCameraRotationMatrix(cameraPosition, cameraDirection) {
	var defaultCameraDirection = glm.vec3(0, 0, 1);
	var cameraDirectionFromOrigin = glm.normalize(cameraDirection['-'](cameraPosition));
	var rotationDirectionY  = cameraDirectionFromOrigin.x > 0. ? 1 : -1;
	var yRotationAngle = rotationDirectionY * Math.acos(glm.dot(defaultCameraDirection.xz, glm.normalize(cameraDirectionFromOrigin.xz)));
	var updatedCameraDirection = glm.rotate(glm.mat4(1), yRotationAngle, glm.vec3(0, 1, 0))['*'](glm.vec4(defaultCameraDirection, 1.)).xyz;
	var rotationDirectionX = cameraDirectionFromOrigin.y > 0. ? -1 : 1;
	var xRotationAngle = rotationDirectionX * Math.acos(glm.dot(updatedCameraDirection, cameraDirectionFromOrigin));

	var view = glm.mat4(1);
	view = glm.rotate(view, yRotationAngle, glm.vec3(0, 1, 0));
	view = glm.rotate(view, xRotationAngle, glm.vec3(1, 0, 0));
	return view;
}

var cameraPosition = glm.vec3(6, 8, 12);
var cameraDirection = glm.vec3(0, 1, 6);
var view = getCameraRotationMatrix(cameraPosition, cameraDirection);

gl.uniform3fv(gl.getUniformLocation(shaderProgram, "rayOrigin"), cameraPosition.elements);
gl.uniformMatrix4fv(gl.getUniformLocation(shaderProgram, "view"), false, view.elements);

gl.enable(gl.DEPTH_TEST);
gl.viewport(0,0,canvas.width,canvas.height);

function draw(timestamp)
{
	gl.clearColor(1.0, 0.0, 0.0, 1.0);
	gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

	cameraPosition = glm.vec3(12*Math.sin(timestamp/150), 8, 12*Math.cos(timestamp/150));
	view = getCameraRotationMatrix(cameraPosition, cameraDirection);
	gl.uniform3fv(gl.getUniformLocation(shaderProgram, "rayOrigin"), cameraPosition.elements);
	gl.uniformMatrix4fv(gl.getUniformLocation(shaderProgram, "view"), false, view.elements);

	gl.drawElements(gl.TRIANGLE_FAN, indices.length, gl.UNSIGNED_SHORT,0);

	window.requestAnimationFrame(draw);
}

window.requestAnimationFrame(draw);
