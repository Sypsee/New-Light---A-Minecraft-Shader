/* DRAWBUFFERS:0 */
layout(location = 0) out vec4 outColor0;

uniform sampler2D gtexture;

in vec2 texCoord;
in vec3 foliageColor;

void main()
{
    vec4 textureColor = texture(gtexture, texCoord);
    if (textureColor.a <= 0.1)
    {
        discard;
    }
    vec3 albedo = textureColor.rgb * foliageColor;

    outColor0 = vec4(albedo, textureColor.a);
}