#version 300 es
precision mediump float;

in vec4 ndc;
in vec3 pos;
in vec3 norm;
in vec2 uv;

uniform vec3 color;
uniform vec3 rayOrigin;

uniform sampler2D uTexture;
uniform bool useTexture;

out vec4 fragColor;

vec3 getLight(vec3 p, vec3 rayDirection, vec3 lightPos, vec3 lightColor, vec3 normal, float size) {
	vec3 lightDir = normalize(lightPos - p);
	vec3 viewDir = -rayDirection;
	vec3 reflectDir = reflect(-lightDir, normal);

	float specularStrength = 0.25;
	float specularShininess = 8.0;
	vec3 specular = specularStrength * lightColor * pow(clamp(dot(reflectDir, viewDir), 0.0, 1.0), specularShininess);  

	float diffuseStrength = 0.9;
	vec3 diffuse = diffuseStrength * lightColor * clamp(dot(lightDir, normal), 0.0, 1.0);

	return (specular + diffuse);
}

void main()
{
	vec3 normal = normalize(norm);
	vec3 p = pos;
	vec3 rayDirection = normalize(pos - rayOrigin);

	vec3 material = useTexture ? texture(uTexture, uv).rgb : color;

	vec3 ambientColor = 0.1 * material;
	fragColor = pow(vec4(ambientColor + (%light%) * material, 1.0), vec4(0.4545));	

	gl_FragDepth = (ndc.z / ndc.w) * .5f + .5f;
}