function getCameraDirection(state) {
	return state.cameraLookAt['-'](state.cameraPosition);
}

function getCameraRotationMatrix(state) {
	let cameraLookAt = state.cameraLookAt;
	let cameraPosition = state.cameraPosition;
	let previousView = state.cameraState != undefined ? state.cameraState.view : glm.mat4(1);
	let defaultCameraDirection = glm.vec4(0, 0, 1, 1);
	let cameraDirection = glm.normalize(cameraLookAt['-'](cameraPosition));
	let rotationDirectionY = cameraDirection.x > 0. ? 1 : -1;
	let yRotationAngle = rotationDirectionY * Math.acos(glm.dot(defaultCameraDirection.xz, glm.normalize(cameraDirection.xz)));
	let updatedCameraDirection = glm.rotate(glm.mat4(1), yRotationAngle, glm.vec3(0, 1, 0))['*'](defaultCameraDirection).xyz;
	let rotationDirectionX = cameraDirection.y > 0. ? -1 : 1;
	let xRotationAngle = rotationDirectionX * Math.acos(glm.dot(updatedCameraDirection, cameraDirection));
	let projection = glm.perspective(glm.radians(45), state.canvas.width/state.canvas.height, 0.1, 2 * state.MAX_DIST);
	let view = glm.lookAt(cameraPosition, cameraLookAt, glm.vec3(0, 1, 0));
	state.cameraState = {
		x : xRotationAngle,
		y : yRotationAngle,
		view : view,
		inverseView : glm.inverse(view),
		projection : projection,
		inverseProjection : glm.inverse(projection),
		cameraPosition : cameraPosition,
		cameraLookAt : cameraLookAt
	};

	window.postMessage(JSON.stringify({
		"cameraPosition" : state.cameraPosition,
		"cameraLookAt" : state.cameraLookAt,
	}));

	if (previousView != view && state.textPoints.length > 0) {
		const boundingRect = state.canvas.getBoundingClientRect();
		var buffer = new Array(state.textPoints.length);
		for(var i = 0; i < state.textPoints.length; i++) {
			var pointToCamera = glm.vec3(state.textPoints[i][0], state.textPoints[i][1], state.textPoints[i][2])['-'](cameraPosition);
			var rayDirectionRotated = (view)['*'](glm.vec4(pointToCamera, 1));
			rayDirectionRotated = glm.normalize(rayDirectionRotated);
			var screenSpaceCoord = {
				x: boundingRect.width / 2 + rayDirectionRotated.x * boundingRect.height,
				y: boundingRect.height / 2 - rayDirectionRotated.y * boundingRect.height,
				distance: glm.length(pointToCamera),
			};
			screenSpaceCoord.inBounds = screenSpaceCoord.x > 0 && screenSpaceCoord.y > 0 && screenSpaceCoord.x < boundingRect.width && screenSpaceCoord.y < boundingRect.height;
			buffer[i] = screenSpaceCoord;
		}
		state.textPositions = buffer.map(JSON.stringify);
	}

}

function getFirstPersonCameraMoveVector(state, frameTime) {
	let getMoveVector = (doMove, sideMove, oppositeMove) => {
		if (doMove) {
			let direction = getCameraDirection(state);
			if (sideMove)
				direction = glm.rotate(glm.mat4(1), Math.PI / 2, glm.vec3(0, 1, 0))['*'](glm.vec4(direction, 1));
			let directionCoefficient = oppositeMove ? -1 : 1;
			let move = glm.normalize(direction.xz)['*'](directionCoefficient * state.firstPersonCameraSpeed * frameTime / 20);
			return glm.vec3(move.x, 0, move.y);
		} else {
			return glm.vec3(0, 0, 0);
		}
	};

	return getMoveVector(state.firstPersonCameraMove.up, false, false)['+']
		(getMoveVector(state.firstPersonCameraMove.down, false, true))['+']
		(getMoveVector(state.firstPersonCameraMove.right, true, false))['+']
		(getMoveVector(state.firstPersonCameraMove.left, true, true));
};

function drawFrame(state, time) {
	let dif = time - state.timeStart;
	state.frameCount++;
	if (dif >= 1000) {
		let fps = state.frameCount;
		window.postMessage(JSON.stringify({"fps" : fps}));
		state.frameCount = 0;
		state.timeStart = time;
	}
	let newFrameTime = time - state.lastFrameTime;
	state.lastFrameTime = time;

	let gl = state.gl;
	gl.clearColor(1.0, 0.0, 0.0, 1.0);
	gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

	if (state.firstPersonCameraMove.up || state.firstPersonCameraMove.down || state.firstPersonCameraMove.right || state.firstPersonCameraMove.left) {
		let moveVector = getFirstPersonCameraMoveVector(state, newFrameTime);
		state.cameraPosition['+='](moveVector);
		state.cameraLookAt['+='](moveVector);
	}
	let currentView = state.cameraState.view;
	let currentProjeciton = state.cameraState.projection;
	let currentInverseView = state.cameraState.inverseView;
	let currentInverseProjeciton = state.cameraState.inverseProjection;
	let cameraPosition = state.cameraState.cameraPosition;

	for (let i = 0; i < state.textures.length; i++) {
		gl.activeTexture(gl.TEXTURE0 + i);
		gl.bindTexture(gl.TEXTURE_2D, state.textures[i]);
	}
	gl.useProgram(state.shaderProgram);
	gl.uniformMatrix4fv(gl.getUniformLocation(state.shaderProgram, "view"), false, currentView.elements);
	gl.uniformMatrix4fv(gl.getUniformLocation(state.shaderProgram, "projection"), false, currentProjeciton.elements);
	gl.uniformMatrix4fv(gl.getUniformLocation(state.shaderProgram, "inverseView"), false, currentInverseView.elements);
	gl.uniformMatrix4fv(gl.getUniformLocation(state.shaderProgram, "inverseProjection"), false, currentInverseProjeciton.elements);
	gl.uniform3fv(gl.getUniformLocation(state.shaderProgram, "rayOrigin"), cameraPosition.elements);
	gl.uniform4fv(gl.getUniformLocation(state.shaderProgram, "backgroundColor"), state.backgroundColor.elements);
	gl.uniform1fv(gl.getUniformLocation(state.shaderProgram, "shown"), state.shown);
	gl.uniform1i(gl.getUniformLocation(state.shaderProgram, "MAX_STEPS"), state.MAX_STEPS);
	gl.uniform1f(gl.getUniformLocation(state.shaderProgram, "MAX_DIST"), state.MAX_DIST);
	gl.uniform1f(gl.getUniformLocation(state.shaderProgram, "SURF_DIST"), state.SURF_DIST);
	if (state.textures.length > 0) {
		gl.uniform1iv(gl.getUniformLocation(state.shaderProgram, "textures"), state.textures.keys());
	}
	gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);

	gl.useProgram(state.shaderProgramMesh);
	
	gl.uniformMatrix4fv(gl.getUniformLocation(state.shaderProgramMesh, "view"), false, currentView.elements);
	gl.uniformMatrix4fv(gl.getUniformLocation(state.shaderProgramMesh, "projection"), false, currentProjeciton.elements);
	gl.uniformMatrix4fv(gl.getUniformLocation(state.shaderProgramMesh, "inverseView"), false, currentInverseView.elements);
	gl.uniformMatrix4fv(gl.getUniformLocation(state.shaderProgramMesh, "inverseProjection"), false, currentInverseProjeciton.elements);
	gl.uniform3fv(gl.getUniformLocation(state.shaderProgramMesh, "rayOrigin"), cameraPosition.elements);

	state.VAOs.forEach((e, i) => {
		let model = glm.mat4(1);
		if (state.meshModels[i]) model = state.meshModels[i];
		let color = glm.vec3(1, 1, 1);
		if (state.meshColors[i]) color = state.meshColors[i];
		gl.uniform3fv(gl.getUniformLocation(state.shaderProgramMesh, "color"), color.elements);
		let texture = state.meshTextures.get(i);
		if (texture) {	
			gl.activeTexture(gl.TEXTURE0);
			gl.bindTexture(gl.TEXTURE_2D, texture);
			gl.uniform1i(gl.getUniformLocation(state.shaderProgramMesh, "uTexture"), 0);
			gl.uniform1i(gl.getUniformLocation(state.shaderProgramMesh, "useTexture"), 1);
		} else {
			gl.uniform1i(gl.getUniformLocation(state.shaderProgramMesh, "useTexture"), 0);
		}
		gl.uniformMatrix4fv(gl.getUniformLocation(state.shaderProgramMesh, "model"), false, model.elements);
		gl.bindVertexArray(e.vao);
		gl.drawArrays(gl.TRIANGLES, 0, e.size);
	});

	state.frameDrawn = true;
}

function drawLoop(state, time) {
	drawFrame(state, time);

	if (document.body.contains(state.canvas) && !state.onDemandRender)
		window.requestAnimationFrame((time) => drawLoop(state, time));
}

function doResizeCanvas(state) {
	let canvas = state.canvas;
	let gl = state.gl;

	gl.useProgram(state.shaderProgram);
	gl.uniform2f(gl.getUniformLocation(state.shaderProgram, "screenSize"), canvas.width, canvas.height);
	gl.viewport(0, 0, canvas.width, canvas.height);

	getCameraRotationMatrix(state);
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

function sdOctahedron(p, s)
{
	p = glm.abs(p);
	let m = p.x + p.y + p.z - s;
	let q;
	if(3.0 * p.x < m) q = glm.vec3(p.x, p.y, p.z);
		else if(3.0 * p.y < m) q = glm.vec3(p.y, p.z, p.x);
		else if(3.0 * p.z < m) q = glm.vec3(p.z, p.x, p.y);
		else return m * 0.57735027;

	let k = glm.clamp(0.5 * (q.z - q.y + s), 0.0, s); 
	return glm.length(glm.vec3(q.x, q.y - s + k, q.z - k)); 
}

function sdHexagon(p, r)
{
	let k = glm.vec3(-0.866025404,0.5,0.577350269);
	p = glm.abs(p);
	p['-='](k.xy['*'](2.0*Math.min(glm.dot(k.xy,p),0.0)));
	p['-='](glm.vec2(clampFloat(p.x, -k.z*r, k.z*r), r));
	return glm.length(p)*Math.sign(p.y);
}

function sdTriangle(p, p0, p1, p2)
{
	let e0 = p1['-'](p0), e1 = p2['-'](p1), e2 = p0['-'](p2);
	let v0 = p['-'](p0), v1 = p['-'](p1), v2 = p['-'](p2);
	let pq0 = v0['-'](e0['*'](clampFloat( glm.dot(v0,e0)/glm.dot(e0,e0), 0.0, 1.0)));
	let pq1 = v1['-'](e1['*'](clampFloat( glm.dot(v1,e1)/glm.dot(e1,e1), 0.0, 1.0)));
	let pq2 = v2['-'](e2['*'](clampFloat( glm.dot(v2,e2)/glm.dot(e2,e2), 0.0, 1.0)));
   	let s = Math.sign( e0.x*e2.y - e0.y*e2.x );
	let d = minVec2(
		minVec2(
			glm.vec2(glm.dot(pq0,pq0), s*(v0.x*e0.y-v0.y*e0.x)),
			glm.vec2(glm.dot(pq1,pq1), s*(v1.x*e1.y-v1.y*e1.x))
		),
		glm.vec2(glm.dot(pq2,pq2), s*(v2.x*e2.y-v2.y*e2.x))
	);
	return -Math.sqrt(d.x)*Math.sign(d.y);
}

function bboxBezierSimple(p0, p1, p2)
{
	let mi = minVec2(p0, minVec2(p1,p2));
	let ma = maxVec2(p0, maxVec2(p1,p2));
		
	return glm.vec4(mi.x, mi.y, ma.x, ma.y);
}

function sdBox2(p, b) 
{
	let q = glm.abs(p)['-'](b);
	let m = glm.vec2(Math.min(q.x,q.y), Math.max(q.x,q.y));
	return (m.x > 0.0) ? glm.length(q) : m.y; 
}

function sdBezier(pos, A, B, C)
{	
	let bs = bboxBezierSimple(A, B, C);
	let d = sdBox2(pos['-'](bs.xy['+'](bs.zw))['*'](0.5), (bs.zw['-'](bs.xy))['*'](0.5));
	return d;
}

function bboxCubicBezierSimple(p0, p1, p2, p3)
{
	let mi = minVec2(minVec2(p0, p1), minVec2(p2, p3));
	let ma = maxVec2(maxVec2(p0, p1), maxVec2(p2, p3));
		
	return glm.vec4(mi.x, mi.y, ma.x, ma.y);
}

function sdCubicBezier(pos, A, B, C, D, k)
{	
	let bs = bboxCubicBezierSimple(A, B, C, D);
	let d = sdBox2(pos['-'](bs.xy['+'](bs.zw))['*'](0.5), (bs.zw['-'](bs.xy))['*'](0.5));
	return d;
}

function sd3DQuadraticBezier(pos, A, B, C)
{	
	let mi = minVec3(A, minVec3(B, C));
	let ma = maxVec3(A, maxVec3(B, C));
	let d = sdBox(pos['-'](mi['+'](ma))['*'](0.5), (ma['-'](mi))['*'](0.5));
	return d;
}

function sdPolygon(v, p)
{
	let N = v.length;
	let d = glm.dot(p['-'](v[0]), p['-'](v[0]));
	let s = 1.0;
	for(let i = 0, j = N - 1; i < N; j = i, i++)
	{
	   	let e = v[j]['-'](v[i]);
		let w = p['-'](v[i]);
		let b = w['-'](e['*'](glm.clamp(glm.dot(w, e) / glm.dot(e, e), 0.0, 1.0)));
		d = Math.min(d, glm.dot(b, b));
		let c = glm.bvec3(p.y >= v[i].y, p.y < v[j].y, e.x * w.y > e.y * w.x);
		not = (vv) => glm.bvec3(!vv.x, !vv.y, !vv.z);
		if(glm.all(c) || glm.all(not(c))) s *= -1.0;  
	}
	return s * Math.sqrt(d);
}

function opRound(obj, radius) {
	return {distance: obj.distance - radius, id : obj.id};
}

function opUnion(obj1, obj2) {
	if (obj1.distance < obj2.distance)
		return obj1;
	else
		return obj2;
}

function opIntersection(obj1, obj2) {
	if (obj1.distance >= obj2.distance)
		return obj1;
	else
		return obj2;
}

function opSubtraction(obj1, obj2) {
	return {distance : Math.max(obj1.distance, -obj2.distance), id : obj1.distance > -obj2.distance ? obj1.id : obj2.id};
}

function opSmoothUnion(obj1, obj2, k) {
	let h = glm.clamp(0.5 + 0.5 * (obj2.distance - obj1.distance) / k, 0.0, 1.0);
	let d = glm.mix(obj2.distance, obj1.distance, h) - k * h * (1.0 - h); 
	return {distance : d, id : obj1.id};
}

function opSmoothIntersection(obj1, obj2, k) {
	let h = glm.clamp(0.5 - 0.5 * (obj2.distance - obj1.distance) / k, 0.0, 1.0);
	let d = glm.mix(obj2.distance, obj1.distance, h) + k * h * (1.0 - h); 
	return {distance : d, id : obj1.id};
}

function opSmoothSubtraction(obj2, obj1, k) {
	let h = glm.clamp(0.5 - 0.5 * (obj2.distance + obj1.distance) / k, 0.0, 1.0);
	let d = glm.mix(obj2.distance, -obj1.distance, h) + k * h * (1.0 - h); 
	return {distance : d, id : obj2.id};
}

function opExtrussion(p, sdf, h)
{
	let w = glm.vec2(sdf, Math.abs(p.z) - h);
  	return Math.min(Math.max(w.x,w.y),0.0) + glm.length(glm.max(w,0.0));
}

function opRevolution(p, w)
{
	return glm.vec2(glm.length(p.xz) - w, p.y);
}

function divVec3(vec1, vec2) {
	return glm.vec3(vec1.x / vec2.x, vec1.y / vec2.y, vec1.z / vec2.z);
}

function roundVec3(vec) {
	return glm.vec3(Math.round(vec.x), Math.round(vec.y), Math.round(vec.z));
}

function minVec3(vec1, vec2) {
	return glm.vec3(Math.min(vec1.x, vec2.x), Math.min(vec1.y, vec2.y), Math.min(vec1.z, vec2.z));
}

function maxVec3(vec1, vec2) {
	return glm.vec3(Math.max(vec1.x, vec2.x), Math.max(vec1.y, vec2.y), Math.max(vec1.z, vec2.z));
}

function minVec2(vec1, vec2) {
	return glm.vec2(Math.min(vec1.x, vec2.x), Math.min(vec1.y, vec2.y));
}

function maxVec2(vec1, vec2) {
	return glm.vec2(Math.max(vec1.x, vec2.x), Math.max(vec1.y, vec2.y));
}

function clampVec3(vec, minVal, maxVal) {
	return glm.vec3(
		Math.min(Math.max(vec.x, minVal.x), maxVal.x),
		Math.min(Math.max(vec.y, minVal.y), maxVal.y),
		Math.min(Math.max(vec.z, minVal.z), maxVal.z)
	);
}

function clampFloat(num, min, max) {
	return Math.min(Math.max(num, min), max);
}

function powVec2(vec1, vec2) {
	return glm.vec2(Math.pow(vec1.x, vec2.x), Math.pow(vec1.y, vec2.y));
}

function subVec3(vec, num) {
	return glm.vec3(vec.x - num, vec.y - num, vec.z - num);
}

function getDistance(p, MAX_DIST, invokeDistanceFn, positions, objectParameters, smoothCoefficients, spaces, repetitions, shown) {
	return invokeDistanceFn(p, MAX_DIST, positions, objectParameters, smoothCoefficients, spaces, repetitions, shown);
}

function rayMarch(state, rd, objectParameters, smoothCoefficients, spaces, repetitions) {
	const ro = state.cameraState.cameraPosition;
	const invokeDistanceFn = state.invokeDistance;
	const positions = state.matrices;
	const shown = state.shown;
	let dO = 0.;
	let d;

	for (let i=0; i< state.MAX_STEPS; i++){
		let p = ro['+'](rd['*'](dO));
		d = getDistance(p, state.MAX_DIST, invokeDistanceFn, positions, objectParameters, smoothCoefficients, spaces, repetitions, shown);
		dO += d.distance;
		if (dO > state.MAX_DIST || d.distance < state.SURF_DIST) break;
	}
	return {distance : dO, id : d.id}; 
}

function initializeMouseEvents(state) {
	let canvas = state.canvas;
	let mouseLeftDown = false,
		mouseMiddleDown = false,
		mouseRightDown = false,
		mouseX = 0,
		mouseY = 0,
		lockMouseMoveX = 0,
		lockMouseMoveY = 0,
		accLockMouseMoveX = 0,
		accLockMouseMoveY = 0;
	let objIntersection;
	let lastHoveredObject = -1;

	let allowFirstPersonMovement = false;

	let getMousePositionNormalized = (evt) => {
		let uv = glm.vec2(0, 0);
		const boundingRect = canvas.getBoundingClientRect();
		if (!allowFirstPersonMovement) uv = glm.vec2(
			((evt.clientX - boundingRect.x) / boundingRect.width - 0.5) * 2,
			-((evt.clientY - boundingRect.y) / boundingRect.height - 0.5) * 2
		);
		return glm.vec4(uv.x, uv.y, -1, 1);
	}

	let doRayMarch = (rd) => {
		let getObjectParameters = (params) => {
			var buf = [];
			for(var i = 0; i < params.length; i += 4) {
				buf.push(glm.vec4(params[i], params[i + 1], params[i + 2], params[i + 3]))
			}
			return buf;
		}
	
		let getSmoothCoefficients = (params) => {
			var buf = [];
			for(var i = 0; i < params.length; i += 4) {
				buf.push(params[i])
			}
			return buf;
		}

		let getRepetitionSpacesParameters = (params) => {
			var buf = [];
			for(var i = 0; i < params.length; i += 4) {
				buf.push(glm.vec3(params[i], params[i + 1], params[i + 2]))
			}
			return buf;
		}

		let getRepetitionParameters = (params) => {
			var buf = [];
			for(var i = 0; i < params.length; i += 4) {
				buf.push(glm.vec3(params[i], params[i + 1], params[i + 2]))
			}
			return buf;
		}

		
		return rayMarch(
			state,
			rd,
			getObjectParameters(state.objectParameters),
			getSmoothCoefficients(state.smoothCoefficients),
			getRepetitionSpacesParameters(state.spacesCoefficients),
			getRepetitionParameters(state.repetitionCoefficients),
		);
	}

	let getRayDestination = (evt) => {
		let rd = glm.inverse(state.cameraState.projection)['*'](getMousePositionNormalized(evt));
		rd['/='](rd.w);
		rd = glm.inverse(state.cameraState.view)['*'](rd);
		return glm.normalize(rd.xyz['-'](state.cameraState.cameraPosition));
	}

	canvas.addEventListener('mousemove', (evt) => {
		if (state.cameraState.view !== undefined && state.positions !== undefined && state.objectParameters !== undefined) {
			let rd = getRayDestination(evt);
			let d = doRayMarch(rd);

			if (d.distance < state.MAX_DIST) {
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
	canvas.addEventListener('mousedown', (evt) => {
		if (allowFirstPersonMovement && state.firstPersonCameraLeftMouseButtonUnlock && evt.button == 0) {
			document.exitPointerLock();
		} else if (state.firstPersonCamera && evt.button == 0 && !allowFirstPersonMovement && !state.onDemandRender) {
			canvas.requestPointerLock();
		} else {
			mouseX = evt.clientX;
			mouseY = evt.clientY;

			if (evt.button == 1) mouseMiddleDown = true;
			if (evt.button == 2) mouseRightDown = true;

			let rd = getRayDestination(evt);
			let d = doRayMarch(rd);

			if (d.distance < state.MAX_DIST) {
				if (evt.button == 0) mouseLeftDown = true;

				objIntersection = state.cameraPosition['+'](rd['*'](d.distance));
				if (mouseLeftDown) window.postMessage(JSON.stringify({"mouseDownLeftObjectId" : d.id}));
			}
		}
	}, false);
	canvas.addEventListener('mousemove', (evt) => {
		var blockMouse2 = false;
		if (state.frameDrawn && (mouseLeftDown || mouseMiddleDown || mouseRightDown) && !state.firstPersonCamera && !state.onDemandRender && !state.blockMouse) {
			state.blockMouse = true;
			let deltaX = -(evt.clientX - mouseX),
				deltaY = evt.clientY - mouseY;
			mouseX = evt.clientX;
			mouseY = evt.clientY;
			let cameraState = state.cameraState;
		
			if (mouseLeftDown) {	
				let angleX = cameraState.x + deltaY / 100.;
				angleX = angleX > state.thirdPersonCameraLimits.lower && angleX <state.thirdPersonCameraLimits.upper ? deltaY / 100 : 0;
				let angleY = deltaX / 100;
				let xRotatationAxis = glm.rotate(glm.mat4(1), cameraState.y, glm.vec3(0, 1, 0))['*'](glm.vec4(1, 0, 0, 1)).xyz;

				let rotateCamera = glm.mat4(1);
				rotateCamera = glm.rotate(rotateCamera, angleY, glm.vec3(0, 1, 0));
				rotateCamera = glm.rotate(rotateCamera, angleX, xRotatationAxis);

				let pd = cameraState.cameraLookAt['-'](cameraState.cameraPosition);
				let po = objIntersection['-'](cameraState.cameraPosition);
				//M is projection of O on PD
				let m = cameraState.cameraPosition['+'](pd['*'](glm.dot(pd, po)/glm.dot(pd, pd)));
				let md = cameraState.cameraLookAt['-'](m);
				let mp = cameraState.cameraPosition['-'](m);
				let om = m['-'](objIntersection);
				let mdNew = rotateCamera['*'](glm.vec4(glm.normalize(md), 1)).xyz['*'](glm.length(md));
				let mpNew = rotateCamera['*'](glm.vec4(glm.normalize(mp), 1)).xyz['*'](glm.length(mp));
				let omNew = rotateCamera['*'](glm.vec4(glm.normalize(om), 1)).xyz['*'](glm.length(om));

				state.cameraLookAt = omNew['+'](mdNew)['+'](objIntersection);
				state.cameraPosition = omNew['+'](mpNew)['+'](objIntersection);
			} else if (mouseMiddleDown) {
				let dX = (deltaX * Math.cos(cameraState.y + Math.PI) + deltaY * Math.sin(cameraState.y)) / 100;
				let dZ = (deltaY * Math.cos(cameraState.y) + deltaX * Math.sin(cameraState.y)) / 100;
				state.cameraPosition.x += dX;
				state.cameraPosition.z += dZ;
				state.cameraLookAt.x += dX;
				state.cameraLookAt.z += dZ;
			} else if (mouseRightDown) {
				let dX = (deltaX * Math.cos(cameraState.y + Math.PI)) / 100;
				let dY = deltaY / 100;
				let dZ = (deltaX * Math.sin(cameraState.y)) / 100;

				state.cameraPosition.x += dX;
				state.cameraPosition.y += dY;
				state.cameraPosition.z += dZ;
				state.cameraLookAt.x += dX;
				state.cameraLookAt.y += dY;
				state.cameraLookAt.z += dZ;
			}
			state.frameDrawn = false;
			blockMouse2 = true;
		}
		if (allowFirstPersonMovement) {
			accLockMouseMoveX -= evt.movementX;
			accLockMouseMoveY += evt.movementY;
		}
		if (state.frameDrawn && allowFirstPersonMovement) {
			state.blockMouse = true;
			var deltaX =  accLockMouseMoveX - lockMouseMoveX,
				deltaY =  accLockMouseMoveY - lockMouseMoveY;

			lockMouseMoveX = accLockMouseMoveX;
			lockMouseMoveY = accLockMouseMoveY;

			let cameraState = state.cameraState;
			let angle = cameraState.x + deltaY / 100.;
			angle = angle > state.firstPersonCameraLimits.lower && angle < state.firstPersonCameraLimits.upper ? deltaY / 100 : 0;

			let defaultCameraDirection = glm.vec4(0, 0, 1, 1);
			var rotateCamera = glm.mat4(1);
			rotateCamera = glm.rotate(rotateCamera, cameraState.y + deltaX / 100., glm.vec3(0, 1, 0));
			rotateCamera = glm.rotate(rotateCamera, cameraState.x + angle, glm.vec3(1, 0, 0));
			state.cameraLookAt = rotateCamera['*'](defaultCameraDirection).xyz['*'](glm.length(getCameraDirection(state)))['+'](cameraState.cameraPosition);
			state.frameDrawn = false;
			blockMouse2 = true;
		}
		if (state.blockMouse && blockMouse2) {
			getCameraRotationMatrix(state);
			state.blockMouse = false;
		}
	}, false);
		
	canvas.addEventListener('mouseup', (evt) => {
		mouseLeftDown = false;
		mouseMiddleDown = false;
		mouseRightDown = false;
	}, false);

	canvas.addEventListener('wheel', (evt) => {
		let direction = getCameraDirection(state);
		let step = evt.deltaY / 100;
		let zoomLimitCheck = glm.length(direction) + step;
		if (zoomLimitCheck > 2 && (zoomLimitCheck < 50 || step < 0) && !state.onDemandRender) {
			state.cameraPosition['-='](glm.normalize(direction)['*'](step));
			getCameraRotationMatrix(state);
		}
	}, {passive: true});

	canvas.addEventListener('keydown', (evt) => {
		if (state.firstPersonCamera && allowFirstPersonMovement) {
			if (evt.code == 'KeyW' || evt.code == 'ArrowUp') {
				state.firstPersonCameraMove.up = true;
			}
			if (evt.code == 'KeyS' || evt.code == 'ArrowDown') {
				state.firstPersonCameraMove.down = true;
			}
			if (evt.code == 'KeyD' || evt.code == 'ArrowRight') {
				state.firstPersonCameraMove.right = true;
			}
			if (evt.code == 'KeyA' || evt.code == 'ArrowLeft') {
				state.firstPersonCameraMove.left = true;
			}
		}
	});

	canvas.addEventListener('keyup', (evt) => {
		if (state.firstPersonCamera && allowFirstPersonMovement) {
			if (evt.code == 'KeyW' || evt.code == 'ArrowUp') {
				state.firstPersonCameraMove.up = false;
			}
			if (evt.code == 'KeyS' || evt.code == 'ArrowDown') {
				state.firstPersonCameraMove.down = false;
			}
			if (evt.code == 'KeyD' || evt.code == 'ArrowRight') {
				state.firstPersonCameraMove.right = false;
			}
			if (evt.code == 'KeyA' || evt.code == 'ArrowLeft') {
				state.firstPersonCameraMove.left = false;
			}
		}
	});

	document.addEventListener('pointerlockchange', (evt) => allowFirstPersonMovement = document.pointerLockElement === canvas, false);
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

function createMeshShader(id, state) {
	let gl = state.gl;
	let vertCode = document.getElementById("mesh-vertex-shader" + id).text;
	let vertShader = gl.createShader(gl.VERTEX_SHADER);
	gl.shaderSource(vertShader, vertCode);
	gl.compileShader(vertShader);
	
	let fragCode = document.getElementById("mesh-fragment-shader" + id).text;
	state.fragMeshShader = gl.createShader(gl.FRAGMENT_SHADER);
	gl.shaderSource(state.fragMeshShader, fragCode); 
	gl.compileShader(state.fragMeshShader);
	state.shaderProgramMesh = gl.createProgram();
	
	let compilationLogV = gl.getShaderInfoLog(vertShader);
	if (compilationLogV.length != 0) console.log('Vertex shader compiler log(Mesh): ' + compilationLogV);
	let compilationLogF = gl.getShaderInfoLog(state.fragMeshShader);
	if (compilationLogF.length != 0) console.log('Fragment shader compiler log(Mesh): ' + compilationLogF);
	
	gl.attachShader(state.shaderProgramMesh, vertShader);
	gl.attachShader(state.shaderProgramMesh, state.fragMeshShader);
	gl.linkProgram(state.shaderProgramMesh);
	gl.useProgram(state.shaderProgramMesh);
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
	state.uboBufferPositions = bindUBO(state, "PositionsBlock", 2);
	state.uboBufferObjectParameters = bindUBO(state, "ObjectParametersBlock", 3);
	state.uboMaterialsInfo = calculateMaterialsUBOInfo(state);

	gl.bindBuffer(gl.UNIFORM_BUFFER, state.uboBufferTextureParameters);
	gl.bufferSubData(gl.UNIFORM_BUFFER, 0, new Float32Array(state.textureParameters), 0);

	gl.bindBuffer(gl.UNIFORM_BUFFER, state.uboBufferMaterials);
	gl.bufferSubData(gl.UNIFORM_BUFFER, state.uboMaterialsInfo["color[0]"].offset, new Float32Array(state.colors), 0);
	gl.bufferSubData(gl.UNIFORM_BUFFER, state.uboMaterialsInfo["reflectiveness[0]"].offset, new Float32Array(state.reflectiveness), 0);

	gl.bindBuffer(gl.UNIFORM_BUFFER, state.uboBufferPositions);
	gl.bufferSubData(gl.UNIFORM_BUFFER, 0, new Float32Array(state.positions), 0);

	gl.bindBuffer(gl.UNIFORM_BUFFER, state.uboBufferObjectParameters);
	gl.bufferSubData(gl.UNIFORM_BUFFER, state.uboMaterialsInfo["objectParameters[0]"].offset, new Float32Array(state.objectParameters), 0);
	gl.bufferSubData(gl.UNIFORM_BUFFER, state.uboMaterialsInfo["smoothCoefficients[0]"].offset, new Float32Array(state.smoothCoefficients), 0);
	gl.bufferSubData(gl.UNIFORM_BUFFER, state.uboMaterialsInfo["spaces[0]"].offset, new Float32Array(state.spacesCoefficients), 0);
	gl.bufferSubData(gl.UNIFORM_BUFFER, state.uboMaterialsInfo["repetitions[0]"].offset, new Float32Array(state.repetitionCoefficients), 0);

	let projection = glm.ortho(0, state.canvas.width, 0, state.canvas.height);
	gl.uniformMatrix4fv(gl.getUniformLocation(state.shaderProgram, "projection"), false, projection.elements);
	gl.uniform2f(gl.getUniformLocation(state.shaderProgram, "screenSize"), state.canvas.width, state.canvas.height);
}

function doRecompileMeshShader(state, fragCode) {
	let gl = state.gl;
	let newFrag = gl.createShader(gl.FRAGMENT_SHADER);
	gl.shaderSource(newFrag, fragCode); 
	gl.compileShader(newFrag);

	let compilationLogF = gl.getShaderInfoLog(newFrag);
	if (compilationLogF.length != 0) console.log('Fragment shader compiler log: ' + compilationLogF);
	
	gl.detachShader(state.shaderProgramMesh, state.fragMeshShader);
	state.fragMeshShader = newFrag;
	gl.attachShader(state.shaderProgramMesh, state.fragMeshShader);
	gl.linkProgram(state.shaderProgramMesh);
	gl.useProgram(state.shaderProgramMesh);
}

function rayMain(id) {
	let state = {
		gl : undefined,
		frameDrawn: false,
		shaderProgram: undefined,
		cameraLookAt: glm.vec3( %cameraLookAt% ),
		cameraPosition: glm.vec3( %cameraPosition% ),
		fragShader: undefined,
		textures: [],
		canvas: document.getElementById('rayCanvas' + id),
		invokeDistance: (p, MAX_DIST, positions, objectParameters, smoothCoefficients, spaces, repetitions, shown) => {return %distanceFunction%;},
		timeStart: 0,
		frameCount: 0,
		uboVariableNames: ["color[0]", "reflectiveness[0]", "objectParameters[0]", "smoothCoefficients[0]", "spaces[0]", "repetitions[0]"],
		firstPersonCamera : %firstPersonCamera%,
		firstPersonCameraMove : {up : false, down : false, right : false, left : false},
		lastFrameTime: 1,
		backgroundColor: glm.vec4(0.5, 0.5, 0.7, 1.0),
		onDemandRender: false,
		shown: %shown%,
		textPoints: [],
		blockMouse: false,
		textPositions: [],
		MAX_STEPS: 1000,
		MAX_DIST: 1000,
		SURF_DIST: 0.001,
		enableDepthTest: true,
		VAOs: [],
		meshModels: [],
		meshColors: [],
		meshTextures: new Map(),
	};
	getCameraRotationMatrix(state);

	state.gl = state.canvas.getContext('webgl2', { premultipliedAlpha: false });
	let gl = state.gl;

	if (state.enableDepthTest) {
		gl.enable(gl.DEPTH_TEST);
		gl.depthFunc(gl.LESS);
		gl.enable(gl.CULL_FACE);
		gl.cullFace(gl.BACK);
	}
	gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);

	let textureCounter = 0;
	let textureBuffer = new Map();
	let saveTexture = (t, tid) => {
		textureBuffer.set(tid, t);
		state.textures = [];

		for (let i = 0; i < textureBuffer.size; i++) {
			state.textures.push(textureBuffer.get(i));
		}

		if (state.onDemandRender) window.requestAnimationFrame((time) => drawLoop(state, time));
	};
	createMeshShader(id, state);
	createShader(id, state);

	state.uboBufferTextureParameters = bindUBO(state, "TextureParamertersBlock", 0);
	state.uboBufferMaterials = bindUBO(state, "MaterialsBlock", 1);
	state.uboBufferPositions = bindUBO(state, "PositionsBlock", 2);
	state.uboBufferObjectParameters = bindUBO(state, "ObjectParametersBlock", 3);
	
	state.uboMaterialsInfo = calculateMaterialsUBOInfo(state);

	doResizeCanvas(state);

	rayCanvasManager.set(id, {
		setCameraPosition: (x, y, z) => {
			state.cameraPosition = glm.vec3(x, y, z);
			getCameraRotationMatrix(state);
		},
		setCameraLookAt: (x, y, z) => {
			state.cameraLookAt = glm.vec3(x, y, z);
			getCameraRotationMatrix(state);
		},
		recompileShader: (shader) => doRecompileShader(state, shader),
		recompileMeshShader: (shader) => doRecompileMeshShader(state, shader),
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
		updateObjectPositions: (transformations) => {
			let buf1 = [];
			let buf2 = [];

			for(let i = 0; i < transformations.length; i++) {
				let m = glm.mat4(1);
				for(let j = 0; j < transformations[i].length; j += 4) {
					switch(transformations[i][j]) {
						case 0: {
							m = glm.translate(m, glm.vec3(transformations[i][j + 1], transformations[i][j + 2], transformations[i][j + 3]));
							break;
						}
						case 1: {
							m = glm.rotate(m, transformations[i][j + 1], glm.vec3(1, 0, 0));
							m = glm.rotate(m, transformations[i][j + 2], glm.vec3(0, 1, 0));
							m = glm.rotate(m, transformations[i][j + 3], glm.vec3(0, 0, 1));
							break;
						}
						case 2: {
							m = glm.scale(m, glm.vec3(transformations[i][j + 1], transformations[i][j + 2], transformations[i][j + 3]));
							break;
						}
						default: {
							break;
						}
					}
				}
				m = glm.inverse(m);

				buf1.push(m);
				buf2.push(Array.from(m.elements));
			}

			state.matrices = buf1;
			state.positions = buf2.flat();
			gl.bindBuffer(gl.UNIFORM_BUFFER, state.uboBufferPositions);
			gl.bufferSubData(gl.UNIFORM_BUFFER, 0, new Float32Array(state.positions), 0);
		},
		updateObjectParameters: (params) => {
			state.objectParameters = params;
			gl.bindBuffer(gl.UNIFORM_BUFFER, state.uboBufferObjectParameters);
			gl.bufferSubData(gl.UNIFORM_BUFFER, state.uboMaterialsInfo["objectParameters[0]"].offset, new Float32Array(state.objectParameters), 0);
		},
		updateSmoothCoefficients: (params) => {
			state.smoothCoefficients = params;
			gl.bindBuffer(gl.UNIFORM_BUFFER, state.uboBufferObjectParameters);
			gl.bufferSubData(gl.UNIFORM_BUFFER, state.uboMaterialsInfo["smoothCoefficients[0]"].offset, new Float32Array(state.smoothCoefficients), 0);
		},
		toggleFirstPersonCamera: (firstPerson) => state.firstPersonCamera = firstPerson,
		changeThirdPersonCameraLimits: (limits) => state.thirdPersonCameraLimits = limits,
		changeFirstPersonCameraLimits: (limits) => state.firstPersonCameraLimits = limits,
		changeFirstPersonCameraSpeed: (speed) => state.firstPersonCameraSpeed = speed,
		toggleFirstPersonCameraLeftMouseButtonUnlock: (toggle) => state.firstPersonCameraLeftMouseButtonUnlock = toggle,
		changeBackgroundColor: (r, g, b, a) => state.backgroundColor = glm.vec4(r, g, b, a),
		updateRepetitionCoefficients: (spaces, repetitions) => {
			state.spacesCoefficients = spaces;
			state.repetitionCoefficients = repetitions;
			gl.bindBuffer(gl.UNIFORM_BUFFER, state.uboBufferObjectParameters);
			gl.bufferSubData(gl.UNIFORM_BUFFER, state.uboMaterialsInfo["spaces[0]"].offset, new Float32Array(state.spacesCoefficients), 0);
			gl.bufferSubData(gl.UNIFORM_BUFFER, state.uboMaterialsInfo["repetitions[0]"].offset, new Float32Array(state.repetitionCoefficients), 0);
		},
		doOnDemandRender: () => {if (state.onDemandRender) {
			getCameraRotationMatrix(state);
			window.requestAnimationFrame((time) => drawLoop(state, time));
		}},
		setOnDemandRender: (toggle) => state.onDemandRender = toggle,
		updateVisibility: (params) => state.shown = params,
		updateTextPoints: (textPoints) => {
			state.textPoints = textPoints;
			getCameraRotationMatrix(state)
		},
		getTextCoords: () => {
			return state.textPositions;
		},
		setMaxRenderSteps: (value) => state.MAX_STEPS = value,
		setMaxRenderDistance: (value) => state.MAX_DIST = value,
		setSurfaceDistance: (value) => state.SURF_DIST = value,
		addMesh: (vertices, uvs, normals) => {
			var VAO = gl.createVertexArray();
			var vboVertex = gl.createBuffer();
			var vboNormal = gl.createBuffer();
			var vboUV = gl.createBuffer();

			gl.bindVertexArray(VAO);

			gl.enableVertexAttribArray(gl.getAttribLocation(state.shaderProgramMesh, "aPos"));
			gl.bindBuffer(gl.ARRAY_BUFFER, vboVertex);
			gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW);
			gl.vertexAttribPointer(gl.getAttribLocation(state.shaderProgramMesh, "aPos"), 3, gl.FLOAT, false, 12, 0);

			gl.enableVertexAttribArray(gl.getAttribLocation(state.shaderProgramMesh, "aNorm"));
			gl.bindBuffer(gl.ARRAY_BUFFER, vboNormal);
			gl.bufferData(gl.ARRAY_BUFFER, normals, gl.STATIC_DRAW);
			gl.vertexAttribPointer(gl.getAttribLocation(state.shaderProgramMesh, "aNorm"), 3, gl.FLOAT, false, 12, 0);

			gl.enableVertexAttribArray(gl.getAttribLocation(state.shaderProgramMesh, "aUV"));
			gl.bindBuffer(gl.ARRAY_BUFFER, vboUV);
			gl.bufferData(gl.ARRAY_BUFFER, uvs, gl.STATIC_DRAW);
			gl.vertexAttribPointer(gl.getAttribLocation(state.shaderProgramMesh, "aUV"), 2, gl.FLOAT, false, 8, 0);

			state.VAOs.push({vao: VAO, size: vertices.length/3});
		},
		updateMeshParameters: (rawModels, colors, textures) => {
			state.meshModels = rawModels.map(m => {
				let position = glm.vec3(m[0], m[1], m[2]);
				let rotation = glm.vec3(m[3], m[4], m[5]);
				let scale = glm.vec3(m[6], m[7], m[8]);

				let model = glm.mat4(1)
				model = glm.rotate(model, rotation.x, glm.vec3(1, 0, 0));
				model = glm.rotate(model, rotation.y, glm.vec3(0, 1, 0));
				model = glm.rotate(model, rotation.z, glm.vec3(0, 0, 1));
				model = glm.translate(model, position);	
				model = glm.scale(model, scale);

				return model;
			});

			state.meshColors = colors.map(p => glm.vec3(p[0], p[1], p[2]));
			state.meshTextures.clear();
			for(let i = 0; i < textures.length; i++) {
				if (textures[i] != "") {
					loadTexture(gl, i, textures[i], (t, tid) => state.meshTextures.set(tid, t))
				}
			}
		},
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

	const uboVariableIndices = gl.getUniformIndices(
		state.shaderProgram,
		state.uboVariableNames
	);
	const uboVariableOffsets = gl.getActiveUniforms(
		state.shaderProgram,
		uboVariableIndices,
		gl.UNIFORM_OFFSET
	);
	uboVariableInfo = {};
	state.uboVariableNames.forEach((name, index) => {
		uboVariableInfo[name] = {
			index: uboVariableIndices[index],
			offset: uboVariableOffsets[index],
		};
	});

	return uboVariableInfo;
}