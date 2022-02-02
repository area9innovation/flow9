precision mediump float;
varying vec3 FragPos;

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

void main() {
	vec2 res = vec2(1080, 600);
	vec2 uv = (FragPos.xy - 0.5 * res.xy)/res.y;
	vec3 ro = vec3(0, 1, 0);
	vec3 rd = normalize(vec3 (uv.x, uv.y, 1));

	float d = RayMarch(ro,rd);
	vec3 col = vec3(0);
	vec3 p = ro + rd * d;
	float dif = GetLight(p);
		
	d/=6.;
	//col = vec3(d);
	col = vec3(dif);
	col *= vec3(FragPos.xy, d*100.)/100.;
	gl_FragColor = vec4(col, 1.0);
}