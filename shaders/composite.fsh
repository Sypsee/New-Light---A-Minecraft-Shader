#version 460

/* DRAWBUFFERS:0 */
layout(location = 0) out vec4 outColor0;

uniform sampler2D gcolor;
uniform sampler2D depthtex0;
uniform sampler2D noisetex;
uniform sampler3D cloudShapeTex;
uniform sampler3D cloudErosionTex;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;

uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;
uniform vec3 fogColor;

uniform float near;
uniform float far;
uniform float thunderStrength;
uniform float viewWidth;
uniform float viewHeight;
uniform int frameCounter;
uniform int worldTime;

in vec2 texcoord;

#define ABSORPTION 0.5
#define LIGHT_ABSORPTION 1.0
#define SHAPE_TEX_SIZE 512
#define EROSION_TEX_SIZE 256

float coverage = 0.2;
const float densityMultiplier = 0.5;
const vec3 cloudPos = vec3(0.0,200.0,0.0);
const vec3 cloudSize = vec3(1500.0, 30.0, 1500.0);

const vec3 boundsMin = cloudPos - cloudSize / 2;
const vec3 boundsMax = cloudPos + cloudSize / 2;

vec3 cloudOffset = vec3(0,0,0);
vec4 phaseParams = vec4(0.83, 0.3, 0.8, 0.15);

const int numStepsLight = 10;

struct Ray
{
	vec3 origin;
	vec3 dir;
};

vec2 BBoxIntersect(const vec3 boxMin, const vec3 boxMax, const Ray r) {
	vec3 t0 = (boxMin - r.origin) / r.dir;
	vec3 t1 = (boxMax - r.origin) / r.dir;
	vec3 tmin = min(t0, t1);
	vec3 tmax = max(t0, t1);
	
	float dstA = max(max(tmin.x, tmin.y), tmin.z);
	float dstB = min(tmax.x, min(tmax.y, tmax.z));

	// CASE 1: ray intersects box from outside (0 <= dstA <= dstB)
	// dstA is dst to nearest intersection, dstB dst to far intersection

	// CASE 2: ray intersects box from inside (dstA < 0 < dstB)
	// dstA is the dst to intersection behind the ray, dstB is dst to forward intersection

	// CASE 3: ray misses box (dstA > dstB)

	float dstToBox = max(0.0, dstA);
	float dstInsideBox = max(0.0, dstB - dstToBox);
	return vec2(dstToBox, dstInsideBox);
}

float linearizeDepth(float depth, float near, float far) {
    return (near * far) / (depth * (near - far) + far);
}

float hg(float a, float g) {
	float g2 = g*g;
	return (1-g2) / (4*3.1415*pow(1+g2-2*g*(a), 1.5));
}

float phase(float a) {
	float blend = .5;
	float hgBlend = hg(a,phaseParams.x) * (1-blend) + hg(a,-phaseParams.y) * blend;
	return phaseParams.z + hgBlend*phaseParams.w;
}

float calcDensity(vec3 rayPos)
{
	coverage = texture(noisetex, rayPos.xy + cloudSize.xy * worldTime * 100).r * 0.5;
	vec3 uvw = rayPos * cloudSize * 0.001 + cloudOffset * 0.01;
	float shapeDensity = texture(cloudShapeTex, uvw / SHAPE_TEX_SIZE).r;
	float density = max(shapeDensity - (1.0 - coverage), 0) * densityMultiplier;
	density *= 1.0 + (thunderStrength * 0.5);

	float erosionDensity = texture(cloudErosionTex, (uvw * 0.85) / EROSION_TEX_SIZE).r;
	density -= clamp(erosionDensity - 0.6, 0.0, 1.0);

	return density;
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

float calcLightning(vec3 rayPos, const vec3 celestialDir)
{
	Ray ray;
	ray.origin = rayPos;
	ray.dir = celestialDir;
	float dstInsideBox = BBoxIntersect(boundsMin, boundsMax, ray).y;

	float stepSize = dstInsideBox / numStepsLight;
	float totalDensity = 0.0;

	rayPos += ray.dir * stepSize * getNoise(texcoord, frameCounter).r;

	for (int step = 0; step < numStepsLight; step++)
	{
		rayPos += celestialDir * stepSize;
		totalDensity += max(0, calcDensity(rayPos) * stepSize);
	}

	float transmittance = exp(-totalDensity * LIGHT_ABSORPTION);
	return transmittance;
}

void main() {
    Ray ray;
	ray.origin = cameraPosition;
	vec4 target = gbufferProjectionInverse * vec4(texcoord.xy * 2 - 1, 1, 1);
	ray.dir = vec3(gbufferModelViewInverse * vec4(normalize(vec3(target) / target.w), 0));
	vec3 celestialPos = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);

	cloudOffset = vec3(worldTime * 10);

	float nonLinearDepth = texture(depthtex0, texcoord).r;
	float depth = linearizeDepth(nonLinearDepth, near, 4*far);

	vec2 hitPoints = BBoxIntersect(boundsMin, boundsMax, ray);

	vec3 startPoint = ray.origin + ray.dir * hitPoints.x;
	float distanceTravelled = 0;
	float maxDist = min(depth-hitPoints.x, hitPoints.y);

	const float stepSize = hitPoints.y / 11;
	float lightEnergy = 0;
	float totalTransmittance = 1;
	vec3 rayPos = ray.origin;
	rayPos += ray.dir * stepSize * getNoise(texcoord, frameCounter).r;

	float phaseVal = phase(dot(ray.dir, celestialPos));

	while (distanceTravelled < maxDist)
	{
		rayPos = startPoint + ray.dir * distanceTravelled;
		float density = calcDensity(rayPos);

		if (density > 0.0)
		{
			lightEnergy += density * stepSize * totalTransmittance * calcLightning(rayPos, celestialPos) * phaseVal;
			totalTransmittance *= exp(-density * stepSize * ABSORPTION);
		}

		if (totalTransmittance < 0.01)
		{
			break;
		}

		distanceTravelled += stepSize;
	}

	vec3 albedo = texture2D(gcolor, texcoord).rgb;
	vec3 finalColor = albedo * totalTransmittance + lightEnergy * (fogColor * 1.2);
	
    outColor0 = vec4(finalColor, 1.0);
}