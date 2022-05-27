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

	window.postMessage(JSON.stringify({
		"cameraPosition" : state.cameraPosition,
		"cameraLookAt" : state.cameraLookAt,
	}));
}

function drawFrame(state, time) {
	let dif = time - state.timeStart;
	state.frameCount++;
	if (dif >= 1000) {
		fps = state.frameCount;
		window.postMessage(JSON.stringify({"fps" : fps}));
		state.frameCount = 0;
		state.timeStart = time;
	}

	let gl = state.gl;
	gl.clearColor(1.0, 0.0, 0.0, 1.0);
	gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

	getCameraRotationMatrix(state);
	gl.uniform3fv(gl.getUniformLocation(state.shaderProgram, "rayOrigin"), state.cameraPosition.elements);
	gl.uniformMatrix4fv(gl.getUniformLocation(state.shaderProgram, "view"), false, state.view.elements);

	if (state.textures.length > 0) {
		gl.uniform1iv(gl.getUniformLocation(state.shaderProgram, "textures"), state.textures.keys());
	}

	gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
	state.frameDrawn = true;
}

function drawLoop(state, time) {
	drawFrame(state, time);

	if (document.body.contains(state.canvas))
		window.requestAnimationFrame((time) => drawLoop(state, time));
}

function doResizeCanvas(state) {
	let canvas = state.canvas;
	let gl = state.gl;

	gl.uniform2f(gl.getUniformLocation(state.shaderProgram, "screenSize"), canvas.width, canvas.height);
	gl.viewport(0, 0, canvas.width, canvas.height);
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

function minOI(obj1, obj2) {
	if (obj1.distance < obj2.distance)
		return obj1;
	else
		return obj2;
}

function minOIS(obj1, obj2, k) {
	let d = opSmoothUnion(obj1.distance, obj2.distance, k);
	return {distance : d, id : obj1.id}
}

function getDistance(p, invokeDistanceFn, positions, objectParameters) {
	const MAX_DIST = 1000;
	let d = {distance : MAX_DIST, id : -1};

	d = invokeDistanceFn(p, positions, objectParameters);

	return d;
}

function rayMarch(ro, rd, invokeDistanceFn, positions, objectParameters) {
	const MAX_STEPS = 1000;
	const MAX_DIST = 1000;
	const SURF_DIST = 0.001;
	let dO = 0.;
	let d;

	for (let i=0; i< MAX_STEPS; i++){
		let p = ro['+'](rd['*'](dO));
		d = getDistance(p, invokeDistanceFn, positions, objectParameters);
		dO += d.distance;
		if (dO>MAX_DIST || d.distance<SURF_DIST) break;
	}
	return {distance : dO, id : d.id}; 
}

function initializeMouseEvents(state) {
	let canvas = state.canvas;
	let mouseLeftDown = false,
		mouseMiddleDown = false,
		mouseRightDown = false,
		mouseX = 0,
		mouseY = 0;
	let objIntersection;
	let lastHoveredObject = -1;

	getGLMPositions = (positions) => {
		var buf = [];
		for(var i = 0; i < positions.length; i += 4) {
			buf.push(glm.vec3(positions[i], positions[i + 1], positions[i + 2]))
		}
		return buf;
	};

	getObjectParameters = (params) => {
		var buf = [];
		for(var i = 0; i < params.length; i += 4) {
			buf.push(glm.vec4(params[i], params[i + 1], params[i + 2], params[i + 3]))
		}
		return buf;
	}

	canvas.addEventListener('mousemove', function (evt) {
		const MAX_DIST = 1000;

		let uv = glm.vec2(
			(evt.clientX - canvas.getBoundingClientRect().x - 0.5 * canvas.width) / canvas.height,
			(0.5 * canvas.height - evt.clientY + canvas.getBoundingClientRect().y) / canvas.height
		);
		let rd = glm.normalize(glm.vec3 (uv.x, uv.y, 1));
		if (state.view !== undefined && state.positions !== undefined && state.objectParameters !== undefined) {
			rd = (state.view['*'](glm.vec4(rd, 1))).xyz;
			let d = rayMarch(state.cameraPosition, rd, state.invokeDistance, getGLMPositions(state.positions), getObjectParameters(state.objectParameters));

			if (d.distance < MAX_DIST) {
				window.postMessage(JSON.stringify({
					"mouseHoverObjectId" : d.id,
					...(lastHoveredObject != d.id) && {"mouseHoverInObjectId" : d.id, "mouseHoverOutObjectId" : lastHoveredObject}
				}));
				lastHoveredObject = d.id;
			} else {
				window.postMessage(JSON.stringify({"mouseHoverOutObjectId" : lastHoveredObject}));
				lastHoveredObject = -1;
			}
		}
	}, false);
	canvas.addEventListener('mousedown', function (evt) {
		const MAX_DIST = 1000;

		mouseX = evt.clientX;
		mouseY = evt.clientY;

		if (evt.button == 1) mouseMiddleDown = true;
		if (evt.button == 2) mouseRightDown = true;

		let uv = glm.vec2(
			(mouseX - canvas.getBoundingClientRect().x - 0.5 * canvas.width) / canvas.height,
			(0.5 * canvas.height - mouseY + canvas.getBoundingClientRect().y) / canvas.height
		);
		let rd = glm.normalize(glm.vec3 (uv.x, uv.y, 1));
		rd = (state.view['*'](glm.vec4(rd, 1))).xyz;
		let d = rayMarch(state.cameraPosition, rd, state.invokeDistance, getGLMPositions(state.positions), getObjectParameters(state.objectParameters));

		if (d.distance < MAX_DIST) {
			if (evt.button == 0) mouseLeftDown = true;

			objIntersection = state.cameraPosition['+'](rd['*'](d.distance));
			if (mouseLeftDown) window.postMessage(JSON.stringify({"mouseDownLeftObjectId" : d.id}));
		}
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

function createShader(id, state) {
	let gl = state.gl;
	let vertCode = document.getElementById("vertex-shader" + id).text;
	let vertShader = gl.createShader(gl.VERTEX_SHADER);
	gl.shaderSource(vertShader, vertCode);
	gl.compileShader(vertShader);
	
	let fragCode = document.getElementById("fragment-shader" + id).text;
	state.fragShader = gl.createShader(gl.FRAGMENT_SHADER);
	gl.shaderSource(state.fragShader, fragCode); 
	gl.compileShader(state.fragShader);
	state.shaderProgram = gl.createProgram();
	
	let compilationLogV = gl.getShaderInfoLog(vertShader);
	if (compilationLogV.length != 0) console.log('Vertex shader compiler log: ' + compilationLogV);
	let compilationLogF = gl.getShaderInfoLog(state.fragShader);
	if (compilationLogF.length != 0) console.log('Fragment shader compiler log: ' + compilationLogF);
	
	gl.attachShader(state.shaderProgram, vertShader);
	gl.attachShader(state.shaderProgram, state.fragShader);
	gl.linkProgram(state.shaderProgram);
	gl.useProgram(state.shaderProgram);
}

function doRecompileShader(state, fragCode) {
	let gl = state.gl;
	let newFrag = gl.createShader(gl.FRAGMENT_SHADER);
	gl.shaderSource(newFrag, fragCode); 
	gl.compileShader(newFrag);

	let compilationLogF = gl.getShaderInfoLog(newFrag);
	if (compilationLogF.length != 0) console.log('Fragment shader compiler log: ' + compilationLogF);

	gl.deleteBuffer(state.uboBufferTextureParameters);
	gl.deleteBuffer(state.uboBufferMaterials);
	
	gl.detachShader(state.shaderProgram, state.fragShader);
	state.fragShader = newFrag;
	gl.attachShader(state.shaderProgram, state.fragShader);
	gl.linkProgram(state.shaderProgram);
	gl.useProgram(state.shaderProgram);

	state.uboBufferTextureParameters = bindUBO(state, "TextureParamertersBlock", 0);
	state.uboBufferMaterials = bindUBO(state, "MaterialsBlock", 1);
	state.uboMaterialsInfo = calculateMaterialsUBOInfo(state);

	gl.bindBuffer(gl.UNIFORM_BUFFER, state.uboBufferTextureParameters);
	gl.bufferSubData(gl.UNIFORM_BUFFER, 0, new Float32Array(state.textureParameters), 0);

	gl.bindBuffer(gl.UNIFORM_BUFFER, state.uboBufferMaterials);
	gl.bufferSubData(gl.UNIFORM_BUFFER, state.uboMaterialsInfo["color[0]"].offset, new Float32Array(state.colors), 0);
	gl.bufferSubData(gl.UNIFORM_BUFFER, state.uboMaterialsInfo["reflectiveness[0]"].offset, new Float32Array(state.reflectiveness), 0);

	gl.bindBuffer(gl.UNIFORM_BUFFER, state.uboBufferPositions);
	gl.bufferSubData(gl.UNIFORM_BUFFER, 0, new Float32Array(state.positions), 0);

	gl.bindBuffer(gl.UNIFORM_BUFFER, state.uboBufferObjectParameters);
	gl.bufferSubData(gl.UNIFORM_BUFFER, 0, new Float32Array(state.objectParameters), 0);

	let projection = glm.ortho(0, state.canvas.width, 0, state.canvas.height);
	gl.uniformMatrix4fv(gl.getUniformLocation(state.shaderProgram, "projection"), false, projection.elements);
	gl.uniform2f(gl.getUniformLocation(state.shaderProgram, "screenSize"), state.canvas.width, state.canvas.height);
}

function rayMain(id) {
	let state = {
		gl : undefined,
		frameDrawn: false,
		view: undefined,
		shaderProgram: undefined,
		yRotationAngle: undefined,
		xRotationAngle: undefined,
		cameraLookAt: glm.vec3( %cameraLookAt% ),
		cameraPosition: glm.vec3( %cameraPosition% ),
		fragShader: undefined,
		textures: [],
		canvas: document.getElementById('rayCanvas' + id),
		invokeDistance: (p, positions, objectParameters) => {return %distanceFunction%;},
		timeStart: 0,
		frameCount: 0,
	};

	state.gl = state.canvas.getContext('webgl2');
	let gl = state.gl;

	let textureCounter = 0;
	let textureBuffer = new Map();
	let saveTexture = (t, tid) => {
		textureBuffer.set(tid, t);
		state.textures = [];

		for (let i = 0; i < textureBuffer.size; i++) {
			state.textures.push(textureBuffer.get(i));
			gl.activeTexture(gl.TEXTURE0 + i);
			gl.bindTexture(gl.TEXTURE_2D, state.textures[i]);
		}
	};

	createShader(id, state);

	state.uboBufferTextureParameters = bindUBO(state, "TextureParamertersBlock", 0);
	state.uboBufferMaterials = bindUBO(state, "MaterialsBlock", 1);
	state.uboBufferPositions = bindUBO(state, "PositionsBlock", 2);
	state.uboBufferObjectParameters = bindUBO(state, "ObjectParametersBlock", 3);
	
	state.uboMaterialsInfo = calculateMaterialsUBOInfo(state);

	doResizeCanvas(state);

	rayCanvasManager.set(id, {
		setCameraPosition: (x, y, z) => state.cameraPosition = glm.vec3(x, y, z),
		setCameraLookAt: (x, y, z) => state.cameraLookAt = glm.vec3(x, y, z),
		recompileShader: (shader) => doRecompileShader(state, shader),
		setDistanceFunction: (fn) => state.invokeDistance = eval(fn),
		resizeCanvas: () => doResizeCanvas(state),
		loadTexture: (txtr) => {
			loadTexture(gl, textureCounter++, txtr, saveTexture);
		},
		resetTextures: () => {
			state.textures.forEach((texture) => gl.deleteTexture(texture));
			state.textures = [];
			textureBuffer.clear();
			textureCounter = 0;
		},
		loadTextureParameters: (params) => {
			state.textureParameters = params;
			gl.bindBuffer(gl.UNIFORM_BUFFER, state.uboBufferTextureParameters);
			gl.bufferSubData(gl.UNIFORM_BUFFER, 0, new Float32Array(state.textureParameters), 0);
		},
		updateMaterialsColor: (params) => {
			state.colors = params;
			gl.bindBuffer(gl.UNIFORM_BUFFER, state.uboBufferMaterials);
			gl.bufferSubData(gl.UNIFORM_BUFFER, state.uboMaterialsInfo["color[0]"].offset, new Float32Array(state.colors), 0);
		},
		updateMaterialsReflectivness: (params) => {
			state.reflectiveness = params;
			gl.bindBuffer(gl.UNIFORM_BUFFER, state.uboBufferMaterials);
			gl.bufferSubData(gl.UNIFORM_BUFFER, state.uboMaterialsInfo["reflectiveness[0]"].offset, new Float32Array(state.reflectiveness), 0);
		},
		updateObjectPositions: (params) => {
			state.positions = params;
			gl.bindBuffer(gl.UNIFORM_BUFFER, state.uboBufferPositions);
			gl.bufferSubData(gl.UNIFORM_BUFFER, 0, new Float32Array(state.positions), 0);
		},
		updateObjectParameters: (params) => {
			state.objectParameters = params;
			gl.bindBuffer(gl.UNIFORM_BUFFER, state.uboBufferObjectParameters);
			gl.bufferSubData(gl.UNIFORM_BUFFER, 0, new Float32Array(state.objectParameters), 0);
		}
	});
	
	initializeMouseEvents(state);

	window.postMessage(JSON.stringify({"webglContextLoaded" : id}));

	window.requestAnimationFrame((time) => drawLoop(state, time));
}

function loadTexture(gl, tid, url, saveTexture) {
	const texture = gl.createTexture();
	const image = new Image();

	image.onload = function() {
		gl.bindTexture(gl.TEXTURE_2D, texture);
		gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image);

		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);

		saveTexture(texture, tid);
	};

	image.src = url;
}

function bindUBO(state, name, blockBinding) {
	let gl = state.gl;
	const blockIndex = gl.getUniformBlockIndex(state.shaderProgram, name);

	const blockSize = gl.getActiveUniformBlockParameter(
		state.shaderProgram,
		blockIndex,
		gl.UNIFORM_BLOCK_DATA_SIZE
	);

	const uboBuffer = gl.createBuffer();
	gl.bindBuffer(gl.UNIFORM_BUFFER, uboBuffer);
	gl.bufferData(gl.UNIFORM_BUFFER, blockSize, gl.DYNAMIC_DRAW);
	gl.bindBuffer(gl.UNIFORM_BUFFER, null);

	gl.bindBufferBase(gl.UNIFORM_BUFFER, blockBinding, uboBuffer);
	gl.uniformBlockBinding(state.shaderProgram, blockIndex, blockBinding);

	return uboBuffer;
}

function calculateMaterialsUBOInfo(state) {
	let gl = state.gl;
	const uboVariableNames = ["color[0]", "reflectiveness[0]"];
	const uboVariableIndices = gl.getUniformIndices(
		state.shaderProgram,
		uboVariableNames
	);
	const uboVariableOffsets = gl.getActiveUniforms(
		state.shaderProgram,
		uboVariableIndices,
		gl.UNIFORM_OFFSET
	);
	uboVariableInfo = {};
	uboVariableNames.forEach((name, index) => {
		uboVariableInfo[name] = {
			index: uboVariableIndices[index],
			offset: uboVariableOffsets[index],
		};
	});

	return uboVariableInfo;
}