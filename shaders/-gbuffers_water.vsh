#version 460

in vec3 vaPosition;
in vec3 vaNormal;
in vec2 vaUV0;
in ivec2 vaUV2;

uniform mat4 modelViewMatrix;
uniform mat4 modelViewMatrixInverse;
uniform mat4 projectionMatrix;
uniform mat3 normalMatrix;

uniform vec3 chunkOffset;
uniform vec3 cameraPosition;

uniform int worldTime;

out vec2 texCoord;
out vec2 lightMapCoord;
out vec3 viewSpacePosition;
out vec3 normal;

#define DETAILS 5

void main()
{
    texCoord = vaUV0;
    lightMapCoord = vaUV2 * (1.0 / 256.0) + (1.0 / 32.0);
    normal = vaNormal + cameraPosition;

    vec3 position = vaPosition + chunkOffset;
    
    vec3 worldSpacePos = position + cameraPosition;
    float randomOffset = worldSpacePos.x * 0.01 + worldSpacePos.y * 0.01 + worldSpacePos.z * 0.01;
    for (int i = 0; i < DETAILS; i++)
    {
        position.y += sin(worldTime * randomOffset * (i * 0.01)) * (i * 0.01) + cos(worldTime * randomOffset * (i * 0.005)) * (i * 0.015);
        position.z += sin(worldTime * randomOffset * (i * 0.01)) * (i * 0.01) + cos(worldTime * randomOffset * (i * 0.01)) * (i * 0.015);
    }
    worldSpacePos.y = position.y;

    vec4 viewSpacePositionVec4 = modelViewMatrix * vec4(position, 1.0);
    viewSpacePosition = viewSpacePositionVec4.xyz;

    gl_Position = projectionMatrix * viewSpacePositionVec4;
}