attribute vec2 coordinates;

varying vec2 FragPos;

uniform mat4 projection;

void main() {
	FragPos = coordinates;
	gl_Position = projection * vec4(coordinates, 0.0, 1.0);
}