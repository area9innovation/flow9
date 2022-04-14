function getCameraDirection(state) {
	return state.cameraLookAt['-'](state.cameraPosition);
}

function getCameraRotationMatrix(state) {
	let defaultCameraDirection = glm.vec4(0, 0, 1, 1);
	let cameraDirection = glm.normalize(getCameraDirection(state));
	let rotationDirectionY = cameraDirection.x > 0. ? 1 : -1;
	state.yRotationAngle = rotationDirectionY * Math.acos(glm.dot(defaultCameraDirection.xz, glm.normalize(cameraDirection.xz)));
	let updatedCameraDirection = glm.rotate(glm.mat4(1), state.yRotationAngle, glm.vec3(0, 1, 0))['*'](defaultCameraDirection).xyz;
	let rotationDirectionX = cameraDirection.y > 0. ? -1 : 1;
	state.xRotationAngle = rotationDirectionX * Math.acos(glm.dot(updatedCameraDirection, cameraDirection));

	state.view = glm.mat4(1);
	state.view = glm.rotate(state.view, state.yRotationAngle, glm.vec3(0, 1, 0));
	state.view = glm.rotate(state.view, state.xRotationAngle, glm.vec3(1, 0, 0));
}

function drawFrame(glContext, state) {
	glContext.clearColor(1.0, 0.0, 0.0, 1.0);
	glContext.clear(glContext.COLOR_BUFFER_BIT | glContext.DEPTH_BUFFER_BIT);

	getCameraRotationMatrix(state);
	glContext.useProgram(state.shaderProgram);
	glContext.uniform3fv(glContext.getUniformLocation(state.shaderProgram, "rayOrigin"), state.cameraPosition.elements);
	glContext.uniformMatrix4fv(glContext.getUniformLocation(state.shaderProgram, "view"), false, state.view.elements);

	if (state.textures.length > 0 && state.textureSizes.length > 1) {
		state.textures.forEach((texture, i) => {
			glContext.activeTexture(glContext.TEXTURE0 + i);
			glContext.bindTexture(glContext.TEXTURE_2D, texture);
		});
		glContext.uniform1iv(glContext.getUniformLocation(state.shaderProgram, "uSampler"), state.textures.keys());
		glContext.uniform2fv(glContext.getUniformLocation(state.shaderProgram, "textureSizes"), state.textureSizes);
	}

	glContext.drawArrays(glContext.TRIANGLE_FAN, 0, 4);
	state.frameDrawn = true;
}

function drawLoop(glContext, state) {
	drawFrame(glContext, state);

	window.requestAnimationFrame(() => drawLoop(glContext, state));
}

function doResizeCanvas(glContext, state) {
	let canvas = state.canvas;
	let vertices = new Float32Array([
		0.0, canvas.height,
		0.0, 0.0,
		canvas.width, 0.0,
		canvas.width, canvas.height,
	]);

	glContext.bufferData(glContext.ARRAY_BUFFER, vertices, glContext.STATIC_DRAW);

	let projection = glm.ortho(0, canvas.width, 0, canvas.height);
	glContext.useProgram(state.shaderProgram);
	glContext.uniformMatrix4fv(glContext.getUniformLocation(state.shaderProgram, "projection"), false, projection.elements);
	glContext.uniform2f(glContext.getUniformLocation(state.shaderProgram, "screenSize"), canvas.width, canvas.height);

	glContext.viewport(0, 0, canvas.width, canvas.height);
}

function sdBox( p, b ) {
	let q = glm.abs(p)['-'](b);
	return glm.length(glm.max(q, 0.0)) + Math.min(Math.max(q.x,Math.max(q.y,q.z)),0.0);
}

function sdRoundBox(p, b, r)
{
	let q = glm.abs(p)['-'](b);
	return glm.length(glm.max(q,0.0)) + Math.min(Math.max(q.x,Math.max(q.y,q.z)),0.0) - r;
}

function sdBoxFrame(p, b, e)
{
	p = glm.abs(p)['-'](b);
	let q = glm.abs(p['+'](e))['-'](glm.vec3(e));
	return Math.min(Math.min(
		glm.length(glm.max(glm.vec3(p.x,q.y,q.z),0.0))+Math.min(Math.max(p.x,Math.max(q.y,q.z)),0.0),
		glm.length(glm.max(glm.vec3(q.x,p.y,q.z),0.0))+Math.min(Math.max(q.x,Math.max(p.y,q.z)),0.0)),
		glm.length(glm.max(glm.vec3(q.x,q.y,p.z),0.0))+Math.min(Math.max(q.x,Math.max(q.y,p.z)),0.0)
	);
}

function sdTorus(p, t) {
	let q = glm.vec2(glm.length(p.xz) - t.x, p.y);
	return glm.length(q) - t.y;
}

function sdCappedTorus(p, sc, ra, rb)
{
	p.x = Math.abs(p.x);
	let k = (sc.y*p.x>sc.x*p.y) ? glm.dot(p.xy,sc) : glm.length(p.xy);
	return Math.sqrt( glm.dot(p,p) + ra*ra - 2.0*ra*k ) - rb;
}

function sdCappedCylinder(p, h, r)
{
	let d = glm.abs(glm.vec2(glm.length(p.xz),p.y))['-'](glm.vec2(r,h));
	return Math.min(Math.max(d.x,d.y),0.0) + glm.length(glm.max(d,0.0));
}

function sdRoundedCylinder(p, ra, rb, h)
{
	let d = glm.vec2( glm.length(p.xz)-2.0*ra+rb, Math.abs(p.y) - h );
	return Math.min(Math.max(d.x,d.y),0.0) + glm.length(glm.max(d,0.0)) - rb;
}

function opSmoothUnion(d1, d2, k) {
	let h = glm.clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
	return glm.mix( d2, d1, h ) - k*h*(1.0-h); 
}

function getDistance(p, invokeDistanceFn) {
	const MAX_DIST = 100;
	let d = MAX_DIST;

	d = invokeDistanceFn(p);

	return d;
}

function rayMarch(ro, rd, invokeDistanceFn) {
	const MAX_STEPS = 100;
	const MAX_DIST = 100;
	const SURF_DIST = 0.001;
	let dO = 0.;
	let d;

	for (let i=0; i< MAX_STEPS; i++){
		let p = ro['+'](rd['*'](dO));
		d = getDistance(p, invokeDistanceFn);
		dO += d;
		if (dO>MAX_DIST || d<SURF_DIST) break;
	}
	return dO; 
}

function initializeMouseEvents(state) {
	let canvas = state.canvas;
	let mouseLeftDown = false,
		mouseMiddleDown = false,
		mouseRightDown = false,
		mouseX = 0,
		mouseY = 0;
	let objIntersection;
	canvas.addEventListener('mousedown', function (evt) {
		if (evt.button == 0) mouseLeftDown = true;
		if (evt.button == 1) mouseMiddleDown = true;
		if (evt.button == 2) mouseRightDown = true;
		mouseX = evt.clientX;
		mouseY = evt.clientY;

		let uv = glm.vec2(
			(mouseX - canvas.getBoundingClientRect().x - 0.5 * canvas.width) / canvas.height,
			(0.5 * canvas.height - mouseY + canvas.getBoundingClientRect().y) / canvas.height
		);
		let rd = glm.normalize(glm.vec3 (uv.x, uv.y, 1));
		rd = (state.view['*'](glm.vec4(rd, 1))).xyz;
		//TODO: check d for max distance to prevent weird rotations
		let d = rayMarch(state.cameraPosition, rd, state.invokeDistance);
		objIntersection = state.cameraPosition['+'](rd['*'](d));
	}, false);
	canvas.addEventListener('mousemove', function (evt) {
		if (state.frameDrawn && (mouseLeftDown || mouseMiddleDown || mouseRightDown)) {
			let deltaX = evt.clientX - mouseX,
				deltaY = evt.clientY - mouseY;
			mouseX = evt.clientX;
			mouseY = evt.clientY;
			if (mouseLeftDown) {
				let angleX = state.xRotationAngle + deltaY / 100.;
				angleX = angleX > - Math.PI / 2 && angleX < Math.PI / 2 ? deltaY / 100 : 0;
				let angleY = deltaX / 100;
				let xRotatationAxis = glm.rotate(glm.mat4(1), state.yRotationAngle, glm.vec3(0, 1, 0))['*'](glm.vec4(1, 0, 0, 1)).xyz;

				let rotateCamera = glm.mat4(1);
				rotateCamera = glm.rotate(rotateCamera, angleY, glm.vec3(0, 1, 0));
				rotateCamera = glm.rotate(rotateCamera, angleX, xRotatationAxis);

				let pd = state.cameraLookAt['-'](state.cameraPosition);
				let po = objIntersection['-'](state.cameraPosition);
				//M is projection of O on PD
				let m = state.cameraPosition['+'](pd['*'](glm.dot(pd, po)/glm.dot(pd, pd)));
				let md = state.cameraLookAt['-'](m);
				let mp = state.cameraPosition['-'](m);
				let om = m['-'](objIntersection);
				let mdNew = rotateCamera['*'](glm.vec4(glm.normalize(md), 1)).xyz['*'](glm.length(md));
				let mpNew = rotateCamera['*'](glm.vec4(glm.normalize(mp), 1)).xyz['*'](glm.length(mp));
				let omNew = rotateCamera['*'](glm.vec4(glm.normalize(om), 1)).xyz['*'](glm.length(om));

				state.cameraLookAt = omNew['+'](mdNew)['+'](objIntersection);
				state.cameraPosition = omNew['+'](mpNew)['+'](objIntersection);
			} else if (mouseMiddleDown) {
				let dX = (deltaX * Math.cos(state.yRotationAngle + Math.PI) + deltaY * Math.sin(state.yRotationAngle)) / 100;
				let dZ = (deltaY * Math.cos(state.yRotationAngle) + deltaX * Math.sin(state.yRotationAngle)) / 100;
				state.cameraPosition.x += dX;
				state.cameraPosition.z += dZ;
				state.cameraLookAt.x += dX;
				state.cameraLookAt.z += dZ;
			} else if (mouseRightDown) {
				let dX = (deltaX * Math.cos(state.yRotationAngle + Math.PI)) / 100;
				let dY = deltaY / 100;
				let dZ = (deltaX * Math.sin(state.yRotationAngle)) / 100;

				state.cameraPosition.x += dX;
				state.cameraPosition.y += dY;
				state.cameraPosition.z += dZ;
				state.cameraLookAt.x += dX;
				state.cameraLookAt.y += dY;
				state.cameraLookAt.z += dZ;
			}
			state.frameDrawn = false;
		}
	}, false);
		
	canvas.addEventListener('mouseup', function (evt) {
		mouseLeftDown = false;
		mouseMiddleDown = false;
		mouseRightDown = false;
	}, false);

	canvas.addEventListener('wheel', function (evt) {
		let direction = getCameraDirection(state);
		let step = evt.deltaY / 100;
		let zoomLimitCheck = glm.length(direction) + step;
		if (zoomLimitCheck > 2 && (zoomLimitCheck < 20 || step < 0)) {
			state.cameraPosition['-='](glm.normalize(direction)['*'](step));
		}
	}, {passive: true});
}

function createShader(id, glContext, state) {
	let vertCode = document.getElementById("vertex-shader" + id).text;
	let vertShader = glContext.createShader(glContext.VERTEX_SHADER);
	glContext.shaderSource(vertShader, vertCode);
	glContext.compileShader(vertShader);
	
	let fragCode = document.getElementById("fragment-shader" + id).text;
	state.fragShader = glContext.createShader(glContext.FRAGMENT_SHADER);
	glContext.shaderSource(state.fragShader, fragCode); 
	glContext.compileShader(state.fragShader);
	state.shaderProgram = glContext.createProgram();
	
	let compilationLogV = glContext.getShaderInfoLog(vertShader);
	if (compilationLogV.length != 0) console.log('Vertex shader compiler log: ' + compilationLogV);
	let compilationLogF = glContext.getShaderInfoLog(state.fragShader);
	if (compilationLogF.length != 0) console.log('Fragment shader compiler log: ' + compilationLogF);
	
	glContext.attachShader(state.shaderProgram, vertShader);
	glContext.attachShader(state.shaderProgram, state.fragShader);
	glContext.linkProgram(state.shaderProgram);
	glContext.useProgram(state.shaderProgram);
}

function doRecompileShader(glContext, state, fragCode) {
	glContext.detachShader(state.shaderProgram, state.fragShader);

	state.fragShader = glContext.createShader(glContext.FRAGMENT_SHADER);
	glContext.shaderSource(state.fragShader, fragCode); 
	glContext.compileShader(state.fragShader);

	let compilationLogF = glContext.getShaderInfoLog(state.fragShader);
	if (compilationLogF.length != 0) console.log('Fragment shader compiler log: ' + compilationLogF);
	
	glContext.attachShader(state.shaderProgram, state.fragShader);
	glContext.linkProgram(state.shaderProgram);
	glContext.useProgram(state.shaderProgram);

	let projection = glm.ortho(0, state.canvas.width, 0, state.canvas.height);
	glContext.uniformMatrix4fv(glContext.getUniformLocation(state.shaderProgram, "projection"), false, projection.elements);
	glContext.uniform2f(glContext.getUniformLocation(state.shaderProgram, "screenSize"), state.canvas.width, state.canvas.height);
}

function rayMain(id) {
	let state = {
		frameDrawn: false,
		view: undefined,
		shaderProgram: undefined,
		yRotationAngle: undefined,
		xRotationAngle: undefined,
		cameraLookAt: glm.vec3( %cameraLookAt% ),
		cameraPosition: glm.vec3( %cameraPosition% ),
		fragShader: undefined,
		textures: [],
		textureSizes: [],
		canvas: document.getElementById('rayCanvas' + id),
		invokeDistance: (p) => {return %distanceFunction%;}
	};

	let glContext = state.canvas.getContext('webgl');

	let textureCounter = 0;
	let textureBuffer = new Map();
	let textureSizeBuffer = new Map();
	let saveSize = (t, tid, w, h) => {
		textureBuffer.set(tid, t);
		textureSizeBuffer.set(tid * 2, w);
		textureSizeBuffer.set(tid * 2 + 1, h);

		state.textures = [];
		state.textureSizes = [];
		for (let i = 0; i < textureBuffer.size; i++) {
			state.textures.push(textureBuffer.get(i));
			state.textureSizes.push(textureSizeBuffer.get(i * 2));
			state.textureSizes.push(textureSizeBuffer.get(i * 2 + 1));
		}
	};

	%initialTextures%

	createShader(id, glContext, state);

	let vertex_buffer = glContext.createBuffer();
	glContext.bindBuffer(glContext.ARRAY_BUFFER, vertex_buffer);

	let coord = glContext.getAttribLocation(state.shaderProgram, "coordinates");
	glContext.vertexAttribPointer(coord, 2, glContext.FLOAT, false, 0, 0); 
	glContext.enableVertexAttribArray(coord);

	doResizeCanvas(glContext, state);

	rayCanvasManager.set(id, {
		setCameraPosition: (x, y, z) => state.cameraPosition = glm.vec3(x, y, z),
		setCameraLookAt: (x, y, z) => state.cameraLookAt = glm.vec3(x, y, z),
		recompileShader: (shader) => doRecompileShader(glContext, state, shader),
		setDistanceFunction: (fn) => state.invokeDistance = eval(fn),
		resizeCanvas: () => doResizeCanvas(glContext, state),
		loadTexture: (txtr) => {
			loadTexture(glContext, textureCounter++, txtr, saveSize);
		},
		resetTextures: () => {
			state.textures = [];//also needs to free textures?
			state.textureSizes = [];
			textureBuffer.clear();
			textureSizeBuffer.clear();
			textureCounter = 0;
		}
	});
	
	initializeMouseEvents(state);

	window.requestAnimationFrame(() => drawLoop(glContext, state));
}

function loadTexture(gl, tid, url, saveSize) {
	const texture = gl.createTexture();
	gl.bindTexture(gl.TEXTURE_2D, texture);

	const level = 0;
	const internalFormat = gl.RGBA;
	const srcFormat = gl.RGBA;
	const srcType = gl.UNSIGNED_BYTE;

	const image = new Image();
	image.onload = function() {
		gl.bindTexture(gl.TEXTURE_2D, texture);
		gl.texImage2D(gl.TEXTURE_2D, level, internalFormat,
						srcFormat, srcType, image);

		if (isPowerOf2(image.width) && isPowerOf2(image.height)) {
			gl.generateMipmap(gl.TEXTURE_2D);
		} else {
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
		}

		saveSize(texture, tid, image.width, image.height);
	};
	image.src = url;
}

function isPowerOf2(value) {
	return (value & (value - 1)) == 0;
}