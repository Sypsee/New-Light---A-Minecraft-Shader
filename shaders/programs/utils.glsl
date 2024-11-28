vec4 phaseParams = vec4(0.83, 0.3, 0.8, 0.15);
const int shadowMapResolution = 1024;

float hg(float a, float g) {
	float g2 = g*g;
	return (1-g2) / (4*3.1415*pow(1+g2-2*g*(a), 1.5));
}

float phase(float a) {
	float blend = .5;
	float hgBlend = hg(a,phaseParams.x) * (1-blend) + hg(a,-phaseParams.y) * blend;
	return phaseParams.z + hgBlend*phaseParams.w;
}

vec4 getNoise(vec2 coord){
  ivec2 screenCoord = ivec2(coord * vec2(viewWidth, viewHeight)); // exact pixel coordinate onscreen
  ivec2 noiseCoord = screenCoord % 64; // wrap to range of noiseTextureResolution
  return texelFetch(noisetex, noiseCoord, 0);
}

vec4 getNoise(in vec2 texcoord, int frame){
  const float g = 1.6180339887498948482;
  float a1 = 1/g;
  float a2 = 1/pow(g, 2.0);

  vec2 offset = vec2(mod(0.5 + a1 * frame, 1.0), mod(0.5 + a2 * frame, 1.0));
  texcoord += offset;

  return getNoise(texcoord);
}