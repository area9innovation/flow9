precision mediump float;
varying vec3 FragPos;

uniform vec2 screenSize;
uniform vec3 rayOrigin;
uniform mat4 view;

#define MAX_STEPS 100
#define MAX_DIST 100.
#define SURF_DIST .01

struct ObjectInfo {
	vec3 col;
	float d;
};

ObjectInfo minOI(ObjectInfo obj1, ObjectInfo obj2) {
	if (obj1.d < obj2.d)
		return obj1;
	else
		return obj2;
}

ObjectInfo getObjectInfo(vec3 p) {
	ObjectInfo d = ObjectInfo(vec3(1, 1, 1), MAX_DIST);

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

float shadow( in vec3 ro, in vec3 rd/*, const float mint,  const float maxt */, float k)
{	
	float t=0.;
	float h;
	float res = 1.0;
   // for( float t=0.; t<10.;  t += h)
   for (int i=0; i< MAX_STEPS; i++)
    {
        float h = getObjectInfo(ro + rd*t).d;
        if( h<0.001 )
            return 0.0;
		res = min( res, k*h/t );
        t += h;
		if (/*t < 10. ||*/ t>MAX_DIST || h<SURF_DIST) break;
    }
    //return 1.0;
	return res;
}

float getLight(vec3 p, vec3 lightPos) {
	vec3 l = normalize(lightPos - p);
	vec3 n = getObjectNormal(p);
	float dif = clamp(dot(n, l) + 0.2, 0., 1.);
	float d = RayMarch(p+n*SURF_DIST*2., l).d;
	//float d = shadow(p+n*SURF_DIST*2., l/*, 0., 10.*/, 2.);
	if (d < length(lightPos - p)) dif *= .1;
	//if (d < 1.0) dif *= .1;
	//dif *= d;
	return dif;
}

vec3 getColor(vec2 uv) {
	vec3 rayDirection = normalize(vec3 (uv.x, uv.y, 1));
	rayDirection = (view*vec4(rayDirection, 1)).xyz;

	ObjectInfo d = RayMarch(rayOrigin, rayDirection);
	vec3 p = rayOrigin + rayDirection * d.d;

	vec3 col = vec3(0.3);
	col += %light%;
	if (d.d < MAX_DIST -1.) col *= d.col; else col = vec3(0.5, 0.5, 0.7);
	return col;
}

void main() {
	vec2 uv = (FragPos.xy - 0.5 * screenSize.xy)/screenSize.y;
	vec3 col = getColor(uv);
	gl_FragColor = vec4(col, 1.0);
}