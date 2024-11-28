#version 460 compatibility

out vec2 texCoord;
out vec3 foliageColor;

vec3 distortShadowClipPos(vec3 shadowClipPos)
{
    float distortionFactor = length(shadowClipPos.xy);  
    distortionFactor += 0.1;

    shadowClipPos.xy /= distortionFactor;
    shadowClipPos.z *= 0.5;
    return shadowClipPos;
}

void main()
{
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    foliageColor = gl_Color.rgb;
    gl_Position = ftransform();
    gl_Position.xyz = distortShadowClipPos(gl_Position.xyz);
}