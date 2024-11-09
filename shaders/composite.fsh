#version 460

/* DRAWBUFFERS:0 */
layout(location = 0) out vec4 outColor0;

uniform sampler2D gcolor;
uniform sampler2D depthtex0;
uniform sampler2D voronoiNoise;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;

uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;

uniform float near;
uniform float far;

in vec2 texcoord;

#define ABSORPTION 1.0

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

float calcDensity(const vec3 rayPos)
{
	vec4 shape = texture(voronoiNoise, rayPos.xy);
	float density = max(shape.r * 0.1, 0);

	return density;
}

void main() {
    Ray ray;
	ray.origin = cameraPosition;
	vec4 target = gbufferProjectionInverse * vec4(texcoord.xy * 2 - 1, 1, 1);
	ray.dir = vec3(gbufferModelViewInverse * vec4(normalize(vec3(target) / target.w), 0));

	float nonLinearDepth = texture(depthtex0, texcoord).r;
	float depth = linearizeDepth(nonLinearDepth, near, 4*far);
	vec3 shadowLightDirection = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);

	const vec3 cloudPos = vec3(0.0,100.0,0.0);
	const vec3 cloudSize = vec3(5.0, 1.0, 5.0);

	const vec3 boundsMin = cloudPos - cloudSize / 2;
	const vec3 boundsMax = cloudPos + cloudSize / 2;

	vec2 hitPoints = BBoxIntersect(boundsMin, boundsMax, ray);

	vec3 startPoint = ray.origin + ray.dir * hitPoints.x;
	float distanceTravelled = 0;
	float maxDist = min(depth-hitPoints.x, hitPoints.y);

	const float stepSize = hitPoints.y / 11;
	float totalDensity = 0;
	vec3 rayPos = ray.origin;

	while (distanceTravelled < maxDist)
	{
		rayPos = startPoint + ray.dir * distanceTravelled;
		totalDensity += calcDensity(rayPos) * stepSize;
		distanceTravelled += stepSize;
	}

	float transmittance = exp(-totalDensity);

	vec3 albedo = texture2D(gcolor, texcoord).rgb;
	vec3 finalColor = albedo * transmittance;
	
    outColor0 = texture(voronoiNoise, texcoord);
}