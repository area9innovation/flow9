#version 300 es
precision mediump float;

in vec2 FragPos;
out vec4 fragColor;

uniform vec2 screenSize;
uniform vec3 rayOrigin;
uniform mat4 view;

const int numTextures = 10;
uniform sampler2D textures[numTextures];

#define MAX_STEPS 1000
#define MAX_DIST 1000.
#define SURF_DIST .001

const vec3 backgroundColor = vec3(0.5, 0.5, 0.7);

struct Material {
	vec3 color;
	float reflectiveness;
};

struct ObjectInfo {
	float d;
	int id;
	int textureId;
	Material material;
};

mat2 makeRotate2(float angle) {
	float s = sin(angle);
    float c = cos(angle);
	return mat2(c, s, -s, c);
}

ObjectInfo minOI(ObjectInfo obj1, ObjectInfo obj2) {
	if (obj1.d < obj2.d)
		return obj1;
	else
		return obj2;
}

float sdBox( vec3 p, vec3 b ) {
	vec3 q = abs(p) - b;
	return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdRoundBox( vec3 p, vec3 b, float r )
{
	vec3 q = abs(p) - b;
	return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - r;
}

float sdBoxFrame( vec3 p, vec3 b, float e )
{
	p = abs(p  )-b;
	vec3 q = abs(p+e)-e;
	return min(min(
		length(max(vec3(p.x,q.y,q.z),0.0))+min(max(p.x,max(q.y,q.z)),0.0),
		length(max(vec3(q.x,p.y,q.z),0.0))+min(max(q.x,max(p.y,q.z)),0.0)),
		length(max(vec3(q.x,q.y,p.z),0.0))+min(max(q.x,max(q.y,p.z)),0.0)
	);
}

float sdTorus( vec3 p, vec2 t ) {
	vec2 q = vec2(length(p.xz) - t.x ,p.y);
	return length(q) - t.y;
}

float sdCappedTorus(in vec3 p, in vec2 sc, in float ra, in float rb)
{
	p.x = abs(p.x);
	float k = (sc.y*p.x>sc.x*p.y) ? dot(p.xy,sc) : length(p.xy);
	return sqrt( dot(p,p) + ra*ra - 2.0*ra*k ) - rb;
}

float sdCappedCylinder( vec3 p, float h, float r )
{
	vec2 d = abs(vec2(length(p.xz),p.y)) - vec2(r,h);
	return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

float sdRoundedCylinder( vec3 p, float ra, float rb, float h )
{
	vec2 d = vec2( length(p.xz)-2.0*ra+rb, abs(p.y) - h );
	return min(max(d.x,d.y),0.0) + length(max(d,0.0)) - rb;
}

float opSmoothUnion( float d1, float d2, float k ) {
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h); 
}

vec3 getObjectNormal(vec3 p);

vec3 getBaseMaterial(int id, vec3 p) {
	vec3 materialColor = vec3(0);

	%baseMaterial%

	return materialColor;
}

ObjectInfo minOIS(ObjectInfo obj1, ObjectInfo obj2, float k, vec3 p) {
	float interpolation = clamp(0.5 + 0.5 * (obj2.d - obj1.d) / k, 0.0, 1.0);
	float d = opSmoothUnion(obj1.d, obj2.d, k);
	vec3 color1 = obj1.textureId >= 0 ? getBaseMaterial(obj1.id, p) : obj1.material.color;
	vec3 color2 = obj2.textureId >= 0 ? getBaseMaterial(obj2.id, p) : obj2.material.color;
	return ObjectInfo(d, -1, -1, Material(mix(color2, color1, interpolation), mix(obj2.material.reflectiveness, obj1.material.reflectiveness, interpolation)));
}

ObjectInfo getObjectInfo(vec3 p) {
	ObjectInfo d = ObjectInfo(MAX_DIST, -1, -1, Material(vec3(0), 0.0));

	d = %distanceFunction%;

	return d;
}

float getObjectInfoSimple(vec3 p) {
	float d = MAX_DIST;

	d = %simpleDistance%;

	return d;
}

ObjectInfo RayMarch(vec3 ro, vec3 rd) {
	float dO = 0.;
	vec3 p;
	for (int i=0; i< MAX_STEPS; i++){
		p = ro + rd * dO;
		float d = getObjectInfoSimple(p);
		dO += d;
		if (dO > MAX_DIST || d < SURF_DIST) break;
	}
	ObjectInfo oi = getObjectInfo(p);
	oi.d = dO;
	return oi; 
}

vec3 getObjectNormal(vec3 p) {
	float d = getObjectInfoSimple(p);
	vec2 e = vec2(.01,0);
	vec3 n = d - vec3(
		getObjectInfoSimple(p - e.xyy),
		getObjectInfoSimple(p - e.yxy),
		getObjectInfoSimple(p - e.yyx)
	);
	return normalize(n);
}

float getShadow(vec3 p, vec3 lightPos, float maxDist, float lightSize) {
	float result = 1.0;
	float dist = 0.001;
	for (int i = 0; i < MAX_STEPS; i++) {
		float hit = getObjectInfoSimple(p + lightPos * dist);
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

	vec3 materialColor = backgroundColor;
	if (d.textureId >=0) {
		materialColor = getBaseMaterial(d.id, p);
	} else {
		materialColor = d.material.color;
	}

	vec3 ambientColor = 0.1 * materialColor;
	vec3 col = vec3(ambientColor);
	if (d.d < MAX_DIST) {
		col = col + (%light%) * materialColor;
	} else {
		col = backgroundColor;
	}
	return col;
}

vec3 getColor(vec2 uv) {
	vec3 rayDirection = normalize(vec3 (uv.x, uv.y, 1));
	rayDirection = (view*vec4(rayDirection, 1)).xyz;

	ObjectInfo d = RayMarch(rayOrigin, rayDirection);
	vec3 p = rayOrigin + rayDirection * d.d;
	vec3 materialColor = backgroundColor;
	if (d.textureId >=0) {
		materialColor = getBaseMaterial(d.id, p);
	} else {
		materialColor = d.material.color;
	}
	if (d.material.reflectiveness > 0.) {
		materialColor = mix(materialColor, getColorReflect(p, reflect(rayDirection, getObjectNormal(p))), d.material.reflectiveness);
	}

	vec3 ambientColor = 0.1 * materialColor;
	vec3 col = vec3(ambientColor);
	if (d.d < MAX_DIST) {
		col = col + (%light%) * materialColor;
	} else {
		col = backgroundColor;
	}
	col = pow(col, vec3(0.4545));
	return col;
}

void main() {
	vec2 uv = (FragPos - 0.5 * screenSize)/screenSize.y;
	vec3 col = getColor(uv);
	fragColor = vec4(col, 1.0);
}