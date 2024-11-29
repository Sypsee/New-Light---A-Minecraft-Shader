#version 120

#define DRAW_SHADOW_MAP gcolor //Configures which buffer to draw to the screen [gcolor shadowcolor0 shadowtex0 shadowtex1]

/* const int colortex0Format = RGBA16F; */

uniform sampler2D gcolor;
varying vec2 texcoord;

#define CONTRAST 1.1
#define BRIGHTNESS 0.05
#define SATURATION 1.1

vec3 acesApprox(vec3 v)
{
    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
    return (v*(a*v+b))/(v*(c*v+d)+e);
}

void main() {
	vec3 color = texture2D(DRAW_SHADOW_MAP, texcoord).rgb;
	color = CONTRAST * (color - 0.5) + 0.5 + BRIGHTNESS;
	float luminance = color.r * 0.2125 + color.g * 0.7153 + color.b * 0.07121;
	color = mix(vec3(luminance), color, SATURATION);
	color = acesApprox(color);

	/* DRAWBUFFERS:0 */
	gl_FragData[0] = vec4(color, 1.0); //gcolor
}