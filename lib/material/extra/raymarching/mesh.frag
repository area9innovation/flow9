#version 300 es
precision mediump float;

in vec4 ndc;
in vec3 pos;
in vec3 norm;

uniform vec3 color;

out vec4 fragColor;

void main()
{
	vec4 u_diffuse = vec4(color, 1);
	vec3 u_lightDirection = normalize(vec3(100, 100, 100) - pos);
	vec3 normal = normalize(norm);
    float fakeLight = dot(u_lightDirection, normal) * .5 + .5;
    fragColor = vec4(u_diffuse.rgb * fakeLight, u_diffuse.a);
	gl_FragDepth = (ndc.z / ndc.w) * .5f + .5f;
}