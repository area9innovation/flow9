function getCameraVector(state) {
	return state.cameraDirection['-'](state.cameraPosition);
}

function getCameraRotationMatrix(defaultCameraDirection, state) {
	let cameraDirectionFromOrigin = glm.normalize(getCameraVector(state));
	let rotationDirectionY  = cameraDirectionFromOrigin.x > 0. ? 1 : -1;
	state.yRotationAngle = rotationDirectionY * Math.acos(glm.dot(defaultCameraDirection.xz, glm.normalize(cameraDirectionFromOrigin.xz)));
	let updatedCameraDirection = glm.rotate(glm.mat4(1), state.yRotationAngle, glm.vec3(0, 1, 0))['*'](defaultCameraDirection).xyz;
	let rotationDirectionX = cameraDirectionFromOrigin.y > 0. ? -1 : 1;
	state.xRotationAngle = rotationDirectionX * Math.acos(glm.dot(updatedCameraDirection, cameraDirectionFromOrigin));

	state.view = glm.mat4(1);
	state.view = glm.rotate(state.view, state.yRotationAngle, glm.vec3(0, 1, 0));
	state.view = glm.rotate(state.view, state.xRotationAngle, glm.vec3(1, 0, 0));
}

function drawFrame(glContext, defaultCameraDirection, state) {
	glContext.clearColor(1.0, 0.0, 0.0, 1.0);
	glContext.clear(glContext.COLOR_BUFFER_BIT | glContext.DEPTH_BUFFER_BIT);

	getCameraRotationMatrix(defaultCameraDirection, state);
	glContext.useProgram(state.shaderProgram);
	glContext.uniform3fv(glContext.getUniformLocation(state.shaderProgram, "rayOrigin"), state.cameraPosition.elements);
	glContext.uniformMatrix4fv(glContext.getUniformLocation(state.shaderProgram, "view"), false, state.view.elements);

	glContext.drawArrays(glContext.TRIANGLE_FAN, 0, 4);
	state.frameDrawn = true;
}

function drawLoop(glContext, defaultCameraDirection, state) {
	drawFrame(glContext, defaultCameraDirection, state);

	window.requestAnimationFrame(() => drawLoop(glContext, defaultCameraDirection, state));
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

				let pd = state.cameraDirection['-'](state.cameraPosition);
				let po = objIntersection['-'](state.cameraPosition);
				//M is projection of O on PD
				let m = state.cameraPosition['+'](pd['*'](glm.dot(pd, po)/glm.dot(pd, pd)));
				let md = state.cameraDirection['-'](m);
				let mp = state.cameraPosition['-'](m);
				let om = m['-'](objIntersection);
				let mdNew = rotateCamera['*'](glm.vec4(glm.normalize(md), 1)).xyz['*'](glm.length(md));
				let mpNew = rotateCamera['*'](glm.vec4(glm.normalize(mp), 1)).xyz['*'](glm.length(mp));
				let omNew = rotateCamera['*'](glm.vec4(glm.normalize(om), 1)).xyz['*'](glm.length(om));

				state.cameraDirection = omNew['+'](mdNew)['+'](objIntersection);
				state.cameraPosition = omNew['+'](mpNew)['+'](objIntersection);
			} else if (mouseMiddleDown) {
				let dX = (deltaX * Math.cos(state.yRotationAngle + Math.PI) + deltaY * Math.sin(state.yRotationAngle)) / 100;
				let dZ = (deltaY * Math.cos(state.yRotationAngle) + deltaX * Math.sin(state.yRotationAngle)) / 100;
				state.cameraPosition.x += dX;
				state.cameraPosition.z += dZ;
				state.cameraDirection.x += dX;
				state.cameraDirection.z += dZ;
			} else if (mouseRightDown) {
				let dX = (deltaX * Math.cos(state.yRotationAngle + Math.PI)) / 100;
				let dY = deltaY / 100;
				let dZ = (deltaX * Math.sin(state.yRotationAngle)) / 100;

				state.cameraPosition.x += dX;
				state.cameraPosition.y += dY;
				state.cameraPosition.z += dZ;
				state.cameraDirection.x += dX;
				state.cameraDirection.y += dY;
				state.cameraDirection.z += dZ;
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
		let direction = getCameraVector(state);
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
		cameraDirection: glm.vec3( %cameraDirection% ),
		cameraPosition: glm.vec3( %cameraPosition% ),
		fragShader: undefined,
		canvas: document.getElementById('rayCanvas' + id),
		invokeDistance: (p) => {return %distanceFunction%;}
	};

	let glContext = state.canvas.getContext('webgl');
	defaultCameraDirection = glm.vec4(0, 0, 1, 1);

	createShader(id, glContext, state);

	let vertex_buffer = glContext.createBuffer();
	glContext.bindBuffer(glContext.ARRAY_BUFFER, vertex_buffer);

	let coord = glContext.getAttribLocation(state.shaderProgram, "coordinates");
	glContext.vertexAttribPointer(coord, 2, glContext.FLOAT, false, 0, 0); 
	glContext.enableVertexAttribArray(coord);

	doResizeCanvas(glContext, state);

	rayCanvasManager.set(id, {
		setCameraPosition: (x, y, z) => state.cameraPosition = glm.vec3(x, y, z),
		setCameraDirection: (x, y, z) => state.cameraDirection = glm.vec3(x, y, z),
		recompileShader: (shader) => doRecompileShader(glContext, state, shader),
		setDistanceFunction: (fn) => state.invokeDistance = eval(fn),
		resizeCanvas: () => doResizeCanvas(glContext, state)
	});
	
	initializeMouseEvents(state);

	window.requestAnimationFrame(() => drawLoop(glContext, defaultCameraDirection, state));
}