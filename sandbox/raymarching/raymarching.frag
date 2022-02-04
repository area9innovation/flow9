precision mediump float;
varying vec3 FragPos;

uniform vec2 screenSize;

#define MAX_STEPS 100
#define MAX_DIST 100.
#define SURF_DIST .01

float GetDist(vec3 p){
	float minSphereDist = MAX_DIST;

	%spheres%

	float planeDist = p.y;
	float d = min(minSphereDist, planeDist);
	return d;
}

float RayMarch(vec3 ro, vec3 rd){
	float dO = 0.;
	for (int i=0; i< MAX_STEPS; i++){
		vec3 p = ro +rd*dO;
		float ds = GetDist(p);
		dO += ds;
		if (dO>MAX_DIST || ds<SURF_DIST) break;
	}
	return dO; 
}

vec3 GetNormal(vec3 p){
	float d = GetDist(p);
	vec2 e = vec2(.01,0);
	vec3 n = d - vec3(
		GetDist(p - e.xyy),
		GetDist(p - e.yxy),
		GetDist(p - e.yyx)
	);
	return normalize(n);
}

float GetLight(vec3 p){
	vec3 lightPos = vec3 (0, 5, 6);
	//lightPos.xz += vec2(sin(iTime),cos(iTime))*2.;
	vec3 l = normalize (lightPos-p);
	vec3 n = GetNormal(p);
	float dif = clamp(dot(n,l),0.,1.);
	float d = RayMarch(p+n*SURF_DIST*2.,l);
	if (d<length(lightPos-p)) dif *= .1;
	return dif;
}

mat2 makeRotationMatrix2(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(
		c, -s,
		s, c
	);
}

void main() {
	vec2 uv = (FragPos.xy - 0.5 * screenSize.xy)/screenSize.y;
	//vec3 rayOrigin = vec3(0, 8, 0);
	//vec3 rayOrigin = vec3(-6, 4, 6);
	//vec3 rayOrigin = vec3(-6, 4, 0);
	//vec3 rayOrigin = vec3(6, 4, 0);
	//vec3 rayOrigin = vec3(0, 4, 12);
	//vec3 rayOrigin = vec3(6, 8, 12);
	vec3 rayOrigin = vec3(10, 10, 10);
	vec3 rayDirection = normalize(vec3 (uv.x, uv.y, 1));

	vec3 defaultCameraDirection = vec3(0, 0, 1);
	vec3 cameraDirection = vec3(0, 1, 6);
	vec3 cameraDirectionFromOrigin = normalize(cameraDirection - rayOrigin);

	float mult = cameraDirectionFromOrigin.x > 0. ? 1. : -1.;
	mat2 yRotation = makeRotationMatrix2(mult*acos(dot(defaultCameraDirection.xz, normalize(cameraDirectionFromOrigin.xz))));
	vec3 updatedCameraDirection = defaultCameraDirection;
	updatedCameraDirection.xz = normalize(yRotation*defaultCameraDirection.xz);
	mat2 xRotation = makeRotationMatrix2(acos(dot(updatedCameraDirection, cameraDirectionFromOrigin)));
	rayDirection.yz *= xRotation;
	rayDirection.xz = yRotation * rayDirection.xz;
	

	float d = RayMarch(rayOrigin, rayDirection);
	vec3 col = vec3(0);
	vec3 p = rayOrigin + rayDirection * d;
	float dif = GetLight(p);
		
	//d/=6.;
	//col = vec3(d);
	col = vec3(dif);
	col = pow(col, vec3(.4545));
	//col *= vec3(FragPos.xy, d*100.)/200.;

	gl_FragColor = vec4(col, 1.0);
}