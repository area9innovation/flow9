#version 300 es
in vec3 aPos;

out vec4 ndc;
out vec3 col;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main()
{
	col = aPos;
	ndc = projection * view * model * vec4(aPos, 1.0);
    gl_Position = ndc;
} 