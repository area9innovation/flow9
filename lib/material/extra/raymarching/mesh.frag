#version 300 es
precision mediump float;

in vec4 ndc;
in vec3 col;

out vec4 fragColor;

void main()
{
	fragColor = vec4(col, 1);
	gl_FragDepth = (ndc.z / ndc.w) * .5f + .5f;
}