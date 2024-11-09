#version 460

/* DRAWBUFFERS:0 */
layout(location = 0) out vec4 outColor0;

uniform sampler2D gtexture;

uniform mat4 gbufferModelViewInverse;
uniform mat3 normalMatrix;

uniform vec3 cameraPosition;
uniform vec3 shadowLightPosition;
uniform vec3 skyColor;

uniform float alphaTestRef;

in vec2 texCoord;
in vec3 viewSpacePosition;
in vec3 normal;

void main()
{
    vec3 reflectedDir = reflect(-shadowLightPosition, normalMatrix * normal);
    vec3 fragFeetPlayerSpace = vec3(gbufferModelViewInverse * vec4(viewSpacePosition, 1.0));
    vec3 fragWorldSpace = fragFeetPlayerSpace + cameraPosition;
    vec3 viewDir = normalize(cameraPosition - fragWorldSpace);

    float specular = max(pow(dot(reflectedDir, viewDir), 100.0), 0.0);

    vec3 albedo = vec3(0, 0.41, 0.58);
    vec3 finalColor = albedo * skyColor;

    outColor0 = vec4(finalColor, 0.25);
}