#version 300 es
in vec3 aPos;
in vec3 aNorm;
in vec2 aUV;

out vec4 ndc;
out vec3 pos;
out vec3 norm;
out vec2 uv;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main()
{
	pos = aPos;
	ndc = projection * view * model * vec4(aPos, 1.0);
	gl_Position = ndc;
	norm = mat3(model) * aNorm;
	uv = aUV;
} 