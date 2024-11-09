#version 460

/* DRAWBUFFERS:0 */
layout(location = 0) out vec4 outColor0;

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;
uniform vec3 fogColor;

uniform float rainStrength;
uniform float alphaTestRef;

in vec2 texCoord;
in vec2 lightMapCoord;
in vec3 foliageColor;
in vec3 viewSpacePosition;
in vec3 geoNormal;
in vec4 tangent;
in vec2 mcEntity;

#define FOG_DENSITY 2.0
#define FOG_END 500.0
#define RAIN_FOG_STRENGTH 1.0

#include "functions.glsl"

void main()
{
    vec4 textureColor = texture(gtexture, texCoord);
    if (textureColor.a < alphaTestRef) discard;
    
    vec3 albedo = textureColor.rgb * foliageColor;
    vec3 finalColor = lightningCalc(albedo);

    outColor0 = vec4(finalColor, textureColor.a);
}