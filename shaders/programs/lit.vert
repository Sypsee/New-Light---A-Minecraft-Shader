#version 460

in vec2 mc_Entity;

in vec3 vaPosition;
in vec3 vaNormal;
in vec4 vaColor;
in vec2 vaUV0;
in ivec2 vaUV2;
in vec4 at_tangent;
in vec2 mc_midTexCoord;

uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;
uniform mat3 normalMatrix;

uniform vec3 chunkOffset;
uniform int worldTime;

out vec2 texCoord;
out vec2 lightMapCoord;
out vec3 foliageColor;
out vec3 viewSpacePosition;
out vec3 geoNormal;
out vec4 tangent;
out vec2 mcEntity;


void main()
{
    texCoord = vaUV0;
    lightMapCoord = vaUV2 * (1.0 / 256.0) + (1.0 / 32.0);
    foliageColor = vaColor.rgb;
    mcEntity = mc_Entity;

    vec3 position = vaPosition;
    if (mc_Entity.x == 69.0 && texCoord.y < mc_midTexCoord.y)
    {
        position += sin(worldTime * (position.x * 0.01) * 0.03) * (position.x * 0.005 + position.y * 0.005 + position.z * 0.005) * 0.04 + sin(worldTime * 0.05) * 0.02 + cos(worldTime * 0.05) * 0.035;
    }

    if (mc_Entity.x == 70.0)
    {
        position += sin(worldTime * (position.x * 0.01) * 0.025) * (position.x * 0.01 + position.y * 0.01) * 0.03 + sin(worldTime * 0.05) * (position.z * 0.02) * 0.025 + cos(worldTime * 0.1) * 0.03;
    }

    if (mc_Entity.x == 71.0)
    {
        position += (normalize(vaNormal) * 0.03) + sin(worldTime * (position.x * 0.01) * 0.025) * (position.x * 0.01 + position.y * 0.01) * 0.03 + sin(worldTime * 0.05) * (position.z * 0.02) * 0.025 + cos(worldTime * 0.1) * 0.03;
    }

    vec4 viewSpacePositionVec4 = modelViewMatrix * vec4(position+chunkOffset, 1.0);
    viewSpacePosition = viewSpacePositionVec4.xyz;
    geoNormal = normalMatrix * vaNormal;
    tangent = vec4(normalize(normalMatrix * at_tangent.rgb), at_tangent.a);

    gl_Position = projectionMatrix * viewSpacePositionVec4;
}