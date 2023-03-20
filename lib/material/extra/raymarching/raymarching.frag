#version 300 es
precision mediump float;

out vec4 fragColor;

uniform vec2 screenSize;
uniform vec3 rayOrigin;
uniform mat4 view;
uniform mat4 projection;
uniform mat4 inverseView;
uniform mat4 inverseProjection;

const int numTextures = %numTextures%; //max 16
uniform sampler2D textures[numTextures];

struct TextureTilingParameter {
	vec2 zx;
	vec2 xy;
	vec2 zy;
}; //4 * 2 * 3 = 24 => 32
			
struct TextureParamerters {
	TextureTilingParameter scale;
	TextureTilingParameter translate;
	TextureTilingParameter rotate;
	TextureTilingParameter step;
	TextureTilingParameter offset;
};// 32 * 5 => 160

uniform TextureParamertersBlock {
	TextureParamerters textureParameters[numTextures];
};

uniform int MAX_STEPS;
uniform float MAX_DIST;
uniform float SURF_DIST;

uniform vec4 backgroundColor;
uniform float shown[%numColors% + numTextures];

struct Material {
	vec3 color;
	float reflectiveness;
};

uniform MaterialsBlock {
	vec3 color[%numColors%];
	float reflectiveness[%numColors% + numTextures];
};

uniform PositionsBlock {
	mat4 positions[%numColors% + numTextures];
};

uniform ObjectParametersBlock {
	vec4 objectParameters[%numParameters%];
	float smoothCoefficients[%numSmooth%];
	vec3 spaces[%numRepetitions%];
	vec3 repetitions[%numRepetitions%];
}; //256 objects

struct ObjectInfo {
	float d;
	int id;
	int textureId;
	bool topLevel;
	Material material;
};

mat2 makeRotate2vec2(vec2 angle) {
	vec2 s = sin(angle);
    vec2 c = cos(angle);
	return mat2(c.x, s.x, -s.y, c.y);
}

ObjectInfo opUnion(ObjectInfo obj1, ObjectInfo obj2) {
	if (obj1.d < obj2.d)
		return obj1;
	else
		return obj2;
}

ObjectInfo opIntersection(ObjectInfo obj1, ObjectInfo obj2) {
	if (obj1.d > obj2.d)
		return obj1;
	else
		return obj2;
}

ObjectInfo opSubtraction(ObjectInfo obj1, ObjectInfo obj2) {
	ObjectInfo newObj;
	if (obj1.d > -obj2.d)
		newObj = obj1;
	else
		newObj = obj2;
	return ObjectInfo(
		max(obj1.d, -obj2.d),
		newObj.id,
		newObj.textureId,
		newObj.topLevel,
		newObj.material
	);
}

ObjectInfo opRound(ObjectInfo obj, float radius) {
	return ObjectInfo(
		obj.d - radius,
		obj.id,
		obj.textureId,
		obj.topLevel,
		obj.material
	);
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

float sdOctahedron(vec3 p, float s)
{
	p = abs(p);
	float m = p.x + p.y + p.z - s;
	vec3 q;
	if(3.0 * p.x < m) q = p.xyz;
		else if(3.0 * p.y < m) q = p.yzx;
		else if(3.0 * p.z < m) q = p.zxy;
		else return m * 0.57735027;

	float k = clamp(0.5 * (q.z - q.y + s), 0.0, s); 
	return length(vec3(q.x, q.y - s + k, q.z - k)); 
}

float sdHexagon(in vec2 p, in float r)
{
    const vec3 k = vec3(-0.866025404,0.5,0.577350269);
    p = abs(p);
    p -= 2.0*min(dot(k.xy,p),0.0)*k.xy;
    p -= vec2(clamp(p.x, -k.z*r, k.z*r), r);
    return length(p)*sign(p.y);
}

float sdTriangle(in vec2 p, in vec2 p0, in vec2 p1, in vec2 p2)
{
    vec2 e0 = p1-p0, e1 = p2-p1, e2 = p0-p2;
    vec2 v0 = p -p0, v1 = p -p1, v2 = p -p2;
    vec2 pq0 = v0 - e0*clamp( dot(v0,e0)/dot(e0,e0), 0.0, 1.0 );
    vec2 pq1 = v1 - e1*clamp( dot(v1,e1)/dot(e1,e1), 0.0, 1.0 );
    vec2 pq2 = v2 - e2*clamp( dot(v2,e2)/dot(e2,e2), 0.0, 1.0 );
    float s = sign( e0.x*e2.y - e0.y*e2.x );
    vec2 d = min(min(vec2(dot(pq0,pq0), s*(v0.x*e0.y-v0.y*e0.x)),
                     vec2(dot(pq1,pq1), s*(v1.x*e1.y-v1.y*e1.x))),
                     vec2(dot(pq2,pq2), s*(v2.x*e2.y-v2.y*e2.x)));
    return -sqrt(d.x)*sign(d.y);
}

float dot2( in vec2 v ) { return dot(v,v); }
float dot2( in vec3 v ) { return dot(v,v); }

float sdBezier( in vec2 pos, in vec2 A, in vec2 B, in vec2 C )
{    
    vec2 a = B - A;
    vec2 b = A - 2.0*B + C;
    vec2 c = a * 2.0;
    vec2 d = A - pos;
    float kk = 1.0/dot(b,b);
    float kx = kk * dot(a,b);
    float ky = kk * (2.0*dot(a,a)+dot(d,b)) / 3.0;
    float kz = kk * dot(d,a);      
    float res = 0.0;
    float p = ky - kx*kx;
    float p3 = p*p*p;
    float q = kx*(2.0*kx*kx-3.0*ky) + kz;
    float h = q*q + 4.0*p3;
    if( h >= 0.0) 
    { 
        h = sqrt(h);
        vec2 x = (vec2(h,-h)-q)/2.0;
        vec2 uv = sign(x)*pow(abs(x), vec2(1.0/3.0));
        float t = clamp( uv.x+uv.y-kx, 0.0, 1.0 );
        res = dot2(d + (c + b*t)*t);
    }
    else
    {
        float z = sqrt(-p);
        float v = acos( q/(p*z*2.0) ) / 3.0;
        float m = cos(v);
        float n = sin(v)*1.732050808;
        vec3  t = clamp(vec3(m+m,-n-m,n-m)*z-kx,0.0,1.0);
        res = min( dot2(d+(c+b*t.x)*t.x),
                   dot2(d+(c+b*t.y)*t.y) );
        // the third root cannot be the closest
        // res = min(res,dot2(d+(c+b*t.z)*t.z));
    }
    return sqrt( res );
}

float sdSegmentSq( in vec2 p, in vec2 a, in vec2 b )
{
	vec2 pa = p-a, ba = b-a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
	return dot2( pa - ba*h );
}

float sdCubicBezier(vec2 pos, vec2 p0, vec2 p1, vec2 p2, vec2 p3, const int kNum)
{   
    vec2 res = vec2(1e10,0.0);
    vec2 a = p0;
    for( int i=1; i<kNum; i++ )
    {
        float t = float(i)/float(kNum-1);
        float s = 1.0-t;
        vec2 b = p0*s*s*s + p1*3.0*s*s*t + p2*3.0*s*t*t + p3*t*t*t;
        float d = sdSegmentSq( pos, a, b );
        if( d<res.x ) res = vec2(d,t);
        a = b;
    }
    
	return sqrt(res.x);
}

float sd3DQuadraticBezier(vec3 pos, vec3 A, vec3 B, vec3 C) {
	vec3 a = B - A;
    vec3 b = A - 2.0*B + C;
    vec3 c = a * 2.0;
    vec3 d = A - pos;

    float kk = 1.0 / dot(b,b);
    float kx = kk * dot(a,b);
    float ky = kk * (2.0*dot(a,a)+dot(d,b)) / 3.0;
    float kz = kk * dot(d,a);      

    vec2 res;

    float p = ky - kx*kx;
    float p3 = p*p*p;
    float q = kx*(2.0*kx*kx - 3.0*ky) + kz;
    float h = q*q + 4.0*p3;

    if(h >= 0.0) 
    { 
        h = sqrt(h);
        vec2 x = (vec2(h, -h) - q) / 2.0;
        vec2 uv = sign(x)*pow(abs(x), vec2(1.0/3.0));
        float t = clamp(uv.x+uv.y-kx, 0.0, 1.0);

        // 1 root
        res = vec2(dot2(d+(c+b*t)*t),t);
        
        //res = vec2( dot2( pos-bezier(A,B,C,t)), t );
    }
    else
    {
        float z = sqrt(-p);
        float v = acos( q/(p*z*2.0) ) / 3.0;
        float m = cos(v);
        float n = sin(v)*1.732050808;
        vec3 t = clamp( vec3(m+m,-n-m,n-m)*z-kx, 0.0, 1.0);
        
        // 3 roots, but only need two
        float dis = dot2(d+(c+b*t.x)*t.x);
        res = vec2(dis,t.x);

        dis = dot2(d+(c+b*t.y)*t.y);
        if( dis<res.x ) res = vec2(dis,t.y );
    }
    
    res.x = sqrt(res.x);
    return res.x;
}

%generatedFunctions%

float opSmoothUnion( float d1, float d2, float k ) {
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h); 
}

float opSmoothIntersection( float d1, float d2, float k ) {
    float h = clamp( 0.5 - 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) + k*h*(1.0-h);
}

float opSmoothSubtraction( float d2, float d1, float k ) {
    float h = clamp( 0.5 - 0.5*(d2+d1)/k, 0.0, 1.0 );
    return mix( d2, -d1, h ) + k*h*(1.0-h);
}

float opSmoothUnion2( float d1, float d2, float k, float h ) {
    return mix( d2, d1, h ) - k*h*(1.0-h); 
}

float opSmoothIntersection2( float d1, float d2, float k, float h  ) {
    return mix( d2, d1, h ) + k*h*(1.0-h);
}

float opSmoothSubtraction2( float d2, float d1, float k, float h  ) {
    return mix( d2, -d1, h ) + k*h*(1.0-h);
}

float opExtrussion( in vec3 p, in float sdf, in float h )
{
    vec2 w = vec2( sdf, abs(p.z) - h );
  	return min(max(w.x,w.y),0.0) + length(max(w,0.0));
}

vec2 opRevolution( in vec3 p, float w )
{
    return vec2( length(p.xz) - w, p.y );
}

vec3 getTextureColor(vec3 p, vec3 normal, TextureParamerters textureParameter, sampler2D txtr) {
	vec2 texSize = vec2(textureSize(txtr, 0));
	vec2 sizeNormalized = texSize / max(texSize.x, texSize.y);

	vec2 py = p.zx;
	py.x *= sign(normal.y);
	vec2 pz = p.xy;
	pz.x *= -1. * sign(normal.z);
	vec2 px = p.zy;
	px.x *= -1. * sign(normal.x);

	py = (py - 0.5) * makeRotate2vec2(textureParameter.rotate.zx) + 0.5 - textureParameter.translate.zx;
	pz = (pz - 0.5) * makeRotate2vec2(textureParameter.rotate.xy) + 0.5 - textureParameter.translate.xy;
	px = (px - 0.5) * makeRotate2vec2(textureParameter.rotate.zy) + 0.5 - textureParameter.translate.zy;

	py = mod(mod(py / (textureParameter.scale.zx * sizeNormalized), textureParameter.step.zx) + textureParameter.offset.zx, 1.0);
	pz = mod(mod(pz / (textureParameter.scale.xy * sizeNormalized), textureParameter.step.xy) + textureParameter.offset.xy, 1.0);
	px = mod(mod(px / (textureParameter.scale.zy * sizeNormalized), textureParameter.step.zy) + textureParameter.offset.zy, 1.0); 

	normal = pow(normal, vec3(10.0));
	normal /= normal.x + normal.y + normal.z;

	return (texture(txtr, py) * normal.y + texture(txtr, pz) * normal.z + texture(txtr, px) * normal.x).rgb;
}

ObjectInfo absoluteDistance(ObjectInfo obj) {
	return ObjectInfo(
		abs(obj.d),
		obj.id,
		obj.textureId,
		obj.topLevel,
		obj.material
	);
}

vec3 getBaseMaterial(int id, vec3 p, vec3 normal) {
	vec3 materialColor = vec3(0);

	%baseMaterial%

	return materialColor;
}

ObjectInfo opSmoothUnionMaterial(ObjectInfo obj1, ObjectInfo obj2, float k, vec3 p, vec3 normal) {
	float interpolation = clamp(0.5 + 0.5 * (obj2.d - obj1.d) / k, 0.0, 1.0);
	float d = opSmoothUnion2(obj1.d, obj2.d, k, interpolation);
	return ObjectInfo(
		d, -1, -1, false,
		Material(
			mix(obj2.material.color, obj1.material.color, interpolation),
			mix(obj2.material.reflectiveness, obj1.material.reflectiveness, interpolation)
		)
	);
}

ObjectInfo opSmoothUnionTopLevel(ObjectInfo obj1, ObjectInfo obj2, float k) {
	float d = opSmoothUnion(obj1.d, obj2.d, k);
	return ObjectInfo(d, obj1.id, -1, false, Material(vec3(0.), 0.));
}

ObjectInfo opSmoothIntersectionMaterial(ObjectInfo obj1, ObjectInfo obj2, float k, vec3 p, vec3 normal) {
	float interpolation = clamp(0.5 - 0.5 * (obj2.d - obj1.d) / k, 0.0, 1.0);
	float d = opSmoothIntersection2(obj1.d, obj2.d, k, interpolation);
	return ObjectInfo(
		d, -1, -1, false,
		Material(
			mix(obj2.material.color, obj1.material.color, interpolation),
			mix(obj2.material.reflectiveness, obj1.material.reflectiveness, interpolation)
		)
	);
}

ObjectInfo opSmoothIntersectionTopLevel(ObjectInfo obj1, ObjectInfo obj2, float k) {
	float d = opSmoothIntersection(obj1.d, obj2.d, k);
	return ObjectInfo(d, obj1.id, -1, false, Material(vec3(0.), 0.));
}

ObjectInfo opSmoothSubtractionMaterial(ObjectInfo obj1, ObjectInfo obj2, float k, vec3 p, vec3 normal) {
	float interpolation = clamp(0.5 + 0.5 * (obj2.d + obj1.d) / k, 0.0, 1.0);
	float d = opSmoothSubtraction2(obj1.d, obj2.d, k, interpolation);
	return ObjectInfo(
		d, -1, -1, false,
		Material(
			mix(obj2.material.color, obj1.material.color, interpolation),
			mix(obj2.material.reflectiveness, obj1.material.reflectiveness, interpolation)
		)
	);
}

ObjectInfo opSmoothSubtractionTopLevel(ObjectInfo obj1, ObjectInfo obj2, float k) {
	float d = opSmoothSubtraction(obj1.d, obj2.d, k);
	return ObjectInfo(d, obj1.id, -1, false, Material(vec3(0.), 0.));
}

ObjectInfo getObjectInfoTopLevel(vec3 p) {
	return %distanceFunction%;
}

ObjectInfo getObjectInfo(int id, vec3 p, vec3 normal) {
	ObjectInfo result = ObjectInfo(MAX_DIST, -1, -1, true, Material(vec3(0.), 0.));

	%topLevelDistanceFunction%

	return result;
}

float getObjectInfoSimple(vec3 p) {
	return %simpleDistance%;
}

ObjectInfo rayMarch(vec3 ro, vec3 rd) {
	float dO = 0.;
	vec3 p;
	ObjectInfo oi;
	for (int i=0; i< MAX_STEPS; i++){
		p = ro + rd * dO;
		oi = getObjectInfoTopLevel(p);
		dO += oi.d;
		if (dO > MAX_DIST || oi.d < SURF_DIST) break;
	}
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

vec3 getLight(vec3 p, vec3 rayDirection, vec3 lightPos, vec3 lightColor, vec3 normal, float lightSize) {
	vec3 lightDir = normalize(lightPos - p);
	vec3 viewDir = -rayDirection;
	vec3 reflectDir = reflect(-lightDir, normal);

	float specularStrength = 0.25;
	float specularShininess = 8.0;
	vec3 specular = specularStrength * lightColor * pow(clamp(dot(reflectDir, viewDir), 0.0, 1.0), specularShininess);  

	float diffuseStrength = 0.9;
	vec3 diffuse = diffuseStrength * lightColor * clamp(dot(lightDir, normal), 0.0, 1.0);

	float shadow = getShadow(p + normal * SURF_DIST, lightDir, length(lightPos - p), lightSize);

	return (specular + diffuse) * shadow;
}


vec3 getColorReflect(vec3 newRayOrigin, vec3 rayDirection, vec3 normalOrigin) {
	ObjectInfo oiSimple = rayMarch(newRayOrigin + normalOrigin * SURF_DIST * 2., rayDirection);;
	vec3 col = backgroundColor.rgb;

	if (oiSimple.d < MAX_DIST) {
		vec3 p = newRayOrigin + rayDirection * oiSimple.d;
		vec3 normal = getObjectNormal(p);
		ObjectInfo oi = oiSimple;
		if (!oi.topLevel) {
			oi = getObjectInfo(oi.id, p, normal);
		}
		vec3 materialColor = oi.material.color;
		if (oi.textureId >= 0) {
			materialColor = getBaseMaterial(oi.id, p, normal);
		}

		vec3 ambientColor = 0.1 * materialColor;
		col = ambientColor + (%light%) * materialColor;
	}

	return col;
}

vec4 getColor(vec2 uv) {
	vec4 rd = inverseProjection * vec4(uv, -1., 1.);
	rd /= rd.w;
	rd = inverseView * rd;
	vec3 rayDirection = normalize(rd.xyz - rayOrigin);

	ObjectInfo oiSimple = rayMarch(rayOrigin, rayDirection);
	vec4 col = backgroundColor;

	vec3 p = rayOrigin + rayDirection * oiSimple.d;
	vec4 ndc = projection * view * vec4(p, 1);
	gl_FragDepth = (ndc.z / ndc.w) * .5f + .5f;

	if (oiSimple.d < MAX_DIST) {
		vec3 normal = getObjectNormal(p);
		ObjectInfo oi = oiSimple;
		if (!oi.topLevel) {
			oi = getObjectInfo(oi.id, p, normal);
		}
		vec3 materialColor = oi.material.color;
		if (oi.textureId >= 0) {
			materialColor = getBaseMaterial(oi.id, p, normal);
		}
		if (oi.material.reflectiveness > 0.001) {
			materialColor = mix(materialColor, getColorReflect(p, reflect(rayDirection, normal), normal), oi.material.reflectiveness);
		}

		vec3 ambientColor = 0.1 * materialColor;
		col = vec4(ambientColor + (%light%) * materialColor, 1.0);
	}

	col = pow(col, vec4(0.4545));
	return col;
}

void main() {
	vec2 uv = vec2(
		(gl_FragCoord.x / screenSize.x - 0.5) * 2.0,
		(gl_FragCoord.y / screenSize.y - 0.5) * 2.0
	);
	fragColor = getColor(uv);
}