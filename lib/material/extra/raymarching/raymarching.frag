precision mediump float;
varying vec3 FragPos;

uniform vec2 screenSize;
uniform vec3 rayOrigin;
uniform mat4 view;

#define MAX_STEPS 100
#define MAX_DIST 100.
#define SURF_DIST .001

struct ObjectInfo {
	float d;
	int id;
};

ObjectInfo minOI(ObjectInfo obj1, ObjectInfo obj2) {
	if (obj1.d < obj2.d)
		return obj1;
	else
		return obj2;
}

ObjectInfo getObjectInfo(vec3 p) {
	ObjectInfo d = ObjectInfo(MAX_DIST, -1);

	d = %distanceFunction%;

	return d;
}

ObjectInfo RayMarch(vec3 ro, vec3 rd) {
	float dO = 0.;
	ObjectInfo oi;
	for (int i=0; i< MAX_STEPS; i++){
		vec3 p = ro +rd*dO;
		oi = getObjectInfo(p);
		dO += oi.d;
		if (dO>MAX_DIST || oi.d<SURF_DIST) break;
	}
	oi.d = dO;
	return oi; 
}

vec3 getObjectNormal(vec3 p) {
	float d = getObjectInfo(p).d;
	vec2 e = vec2(.01,0);
	vec3 n = d - vec3(
		getObjectInfo(p - e.xyy).d,
		getObjectInfo(p - e.yxy).d,
		getObjectInfo(p - e.yyx).d
	);
	return normalize(n);
}

float getShadow(vec3 p, vec3 lightPos, float maxDist, float lightSize) {
	float result = 1.0;
	float dist = 0.001;
	for (int i = 0; i < MAX_STEPS; i++) {
		float hit = getObjectInfo(p + lightPos * dist).d;
		result = min(result, hit / (dist * lightSize));
		dist += hit;
		if (hit < SURF_DIST/100. || dist > maxDist) break;
	}
	return clamp(result, 0.0, 1.0);
}

vec3 getLight(vec3 p, vec3 rayDirection, vec3 lightPos, vec3 lightColor, float lightSize) {
	vec3 lightDir = normalize(lightPos - p);
	vec3 norm = getObjectNormal(p);
	vec3 viewDir = -rayDirection;
	vec3 reflectDir = reflect(-lightDir, norm);

	float specularStrength = 0.25;
	float specularShininess = 8.0;
	vec3 specular = specularStrength * lightColor * pow(clamp(dot(reflectDir, viewDir), 0.0, 1.0), specularShininess);  

	float diffuseStrength = 0.9;
	vec3 diffuse = diffuseStrength * lightColor * clamp(dot(lightDir, norm), 0.0, 1.0);

	float shadow = getShadow(p + norm * SURF_DIST, lightDir, length(lightPos - p), lightSize);

	return (specular + diffuse) * shadow;
}

vec3 getColorReflect(vec3 newRayOrigin, vec3 rayDirection) {
	ObjectInfo d = RayMarch(newRayOrigin + getObjectNormal(newRayOrigin) * SURF_DIST * 2., rayDirection);
	vec3 p = newRayOrigin + rayDirection * d.d;

	int id = d.id;
	vec3 materialColor = vec3(0.5, 0.5, 0.7);
	%materialFunction2%

	vec3 ambientColor = 0.1 * materialColor;
	vec3 col = vec3(ambientColor);
	if (d.d < MAX_DIST) {
		col = col + (%light%) * materialColor;
	} else {
		col = vec3(0.5, 0.5, 0.7);
	}
	return col;
}

vec3 getColor(vec2 uv) {
	vec3 rayDirection = normalize(vec3 (uv.x, uv.y, 1));
	rayDirection = (view*vec4(rayDirection, 1)).xyz;

	ObjectInfo d = RayMarch(rayOrigin, rayDirection);
	vec3 p = rayOrigin + rayDirection * d.d;
	int id = d.id;
	vec3 materialColor;
	%materialFunction1%

	vec3 ambientColor = 0.1 * materialColor;
	vec3 col = vec3(ambientColor);
	if (d.id >= 0) {
		col = col + (%light%) * materialColor;
	} else {
		col = vec3(0.5, 0.5, 0.7);
	}
	col = pow(col, vec3(0.4545));
	return col;
}

void main() {
	vec2 uv = (FragPos.xy - 0.5 * screenSize.xy)/screenSize.y;
	vec3 col = getColor(uv);
	gl_FragColor = vec4(col, 1.0);
}