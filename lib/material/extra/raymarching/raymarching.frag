precision mediump float;
varying vec3 FragPos;

uniform vec2 screenSize;
uniform vec3 rayOrigin;
uniform mat4 view;

#define MAX_STEPS 1000
#define MAX_DIST 1000.
#define SURF_DIST .001

struct MixColor {
	int id1;
	int id2;
	vec3 color;
	/*
		0 - id1 * id2
		1 - id1 * color
		2 - color * id2
	*/
	int conf;
	float coef;
};

struct HalfMixColor {
	int id;
	vec3 color;
	float coef;
	bool order;
};

struct ObjectInfo {
	float d;
	int id;
	bool plainColor;
	vec3 color;
	bool isMixColor;
	MixColor mixColor;
};

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

ObjectInfo minOIS(ObjectInfo obj1, ObjectInfo obj2, float k) {
	float interpolation = clamp(0.5 + 0.5 * (obj2.d - obj1.d) / k, 0.0, 1.0);
	int id1 = obj1.isMixColor ? (obj1.mixColor.coef < 0.5 ? obj1.mixColor.id1 : obj1.mixColor.id2) : obj1.id;
	int id2 = obj2.isMixColor ? (obj2.mixColor.coef < 0.5 ? obj2.mixColor.id1 : obj2.mixColor.id2) : obj2.id;
	float d = opSmoothUnion(obj1.d, obj2.d, k);
	int id = interpolation < 0.5 ? id2 : id1;
	if (obj1.plainColor && obj2.plainColor) {
		return ObjectInfo(d, id, true, mix(obj2.color, obj1.color, interpolation), false, MixColor(id2, id1, vec3(0), 0, interpolation));
	} else if (obj1.plainColor || obj2.plainColor) {
		bool isFirst = obj1.plainColor;
		vec3 color = isFirst ? obj1.color : obj2.color;
		int conf = isFirst ? 2 : 1;
		
		if (isFirst && obj2.isMixColor && obj2.mixColor.conf > 0) {
			color = mix(obj2.mixColor.color, color, interpolation);
		} else if (!isFirst && obj1.isMixColor && obj1.mixColor.conf > 0) {
			color = mix(color, obj1.mixColor.color, interpolation);
		}
		return ObjectInfo(d, id, false, vec3(0), true, MixColor(id2, id1, color, conf, interpolation));
	} else {
		vec3 color = vec3(0);
		int conf = 0;
		if (obj1.mixColor.conf > 0 || obj2.mixColor.conf > 0) {
			if (obj1.mixColor.conf > 0 && obj2.mixColor.conf > 0) {
				color = mix(obj2.mixColor.color, obj1.mixColor.color, interpolation);
				conf = interpolation < 0.5 ? obj2.mixColor.conf : obj1.mixColor.conf;
			} else if(obj1.mixColor.conf > 0) {
				color = mix(obj2.color, obj1.mixColor.color, interpolation);
				conf = obj1.mixColor.conf;
			} else if(obj2.mixColor.conf > 0) {
				color = mix(obj2.mixColor.color, obj1.color, interpolation);
				conf = obj2.mixColor.conf;
			} else {
				color = mix(obj2.mixColor.color, obj1.mixColor.color, interpolation);
				conf = obj2.mixColor.conf;
			}
		}
		return ObjectInfo(d, id, false, vec3(0), true, MixColor(id2, id1, color, conf, interpolation));
	}
}

ObjectInfo getObjectInfo(vec3 p) {
	ObjectInfo d = ObjectInfo(MAX_DIST, -1, true, vec3(0), false, MixColor(-1, -1, vec3(0), 0, 0.0));

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

vec3 backgroundColor = vec3(0.5, 0.5, 0.7);

vec3 getMaterialReflect(int id) {
	vec3 materialColor = backgroundColor;
	%materialFunction2%
	return materialColor;
}

vec3 getColorReflect(vec3 newRayOrigin, vec3 rayDirection) {
	ObjectInfo d = RayMarch(newRayOrigin + getObjectNormal(newRayOrigin) * SURF_DIST * 2., rayDirection);
	vec3 p = newRayOrigin + rayDirection * d.d;

	vec3 materialColor = backgroundColor;
	if (d.plainColor) {
		materialColor = d.color;
	} else if (d.isMixColor) {
		if (d.mixColor.conf == 0) {
			materialColor = mix(getMaterialReflect(d.mixColor.id1), getMaterialReflect(d.mixColor.id2), d.mixColor.coef);
		} else if (d.mixColor.conf == 1) {
			materialColor = mix(d.mixColor.color, getMaterialReflect(d.mixColor.id2), d.mixColor.coef);
		} else {
			materialColor = mix(getMaterialReflect(d.mixColor.id1), d.mixColor.color, d.mixColor.coef);
		}
	} else {
		materialColor = getMaterialReflect(d.id);
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

vec3 getMaterial(int id, vec3 p, vec3 rayDirection) {
	vec3 materialColor = backgroundColor;
	%materialFunction1%
	return materialColor;
}

vec3 getColor(vec2 uv) {
	vec3 rayDirection = normalize(vec3 (uv.x, uv.y, 1));
	rayDirection = (view*vec4(rayDirection, 1)).xyz;

	ObjectInfo d = RayMarch(rayOrigin, rayDirection);
	vec3 p = rayOrigin + rayDirection * d.d;
	vec3 materialColor = backgroundColor;
	if (d.plainColor) {
		materialColor = d.color;
	} else if (d.isMixColor) {
		if (d.mixColor.conf == 0) {
			materialColor = mix(getMaterial(d.mixColor.id1, p, rayDirection), getMaterial(d.mixColor.id2, p, rayDirection), d.mixColor.coef);
		} else if (d.mixColor.conf == 1) {
			materialColor = mix(d.mixColor.color, getMaterial(d.mixColor.id2, p, rayDirection), d.mixColor.coef);
		} else {
			materialColor = mix(getMaterial(d.mixColor.id1, p, rayDirection), d.mixColor.color, d.mixColor.coef);
		}
	} else {
		materialColor = getMaterial(d.id, p, rayDirection);
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
	vec2 uv = (FragPos.xy - 0.5 * screenSize.xy)/screenSize.y;
	vec3 col = getColor(uv);
	gl_FragColor = vec4(col, 1.0);
}