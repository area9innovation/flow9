attribute vec3 coordinates;

varying vec3 FragPos;

uniform mat4 projection;

void main() {
	FragPos = coordinates;
	gl_Position = projection * vec4(coordinates, 1.0);
}