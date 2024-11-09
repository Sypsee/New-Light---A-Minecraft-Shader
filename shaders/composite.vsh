#version 140

in vec3 vaPosition;

out vec2 texcoord;

void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vec4 fragPosVec4 = gl_ModelViewMatrix * vec4(vaPosition, 1.0);
	
    gl_Position = gl_ProjectionMatrix * fragPosVec4;
}