#include "utils.glsl"

mat3 tbnNormalTangent(vec3 normal, vec3 tangent)
{
    vec3 bitangent = cross(tangent, normal);
    return mat3(tangent, bitangent, normal);
}

vec3 brdf(vec3 lightDir, vec3 viewDir, float roughness, vec3 normal, vec3 albedo, float metallic, vec3 reflectance)
{
    float alpha = pow(roughness, 2);
    
    vec3 H = normalize(lightDir + viewDir);

    float NdotV = max(dot(normal, viewDir), 0.001);
    float NdotL = max(dot(normal, lightDir), 0.001);
    float NdotH = max(dot(normal, H), 0.001);
    float VdotH = max(dot(viewDir, H), 0.001);

    vec3 F0 = reflectance;
    vec3 fresnelReflectance = F0 + (1.0 - F0) * pow(1.0 - VdotH, 5.0);

    vec3 rhoD = albedo;
    rhoD *= (vec3(1.0) - fresnelReflectance);
    // rhoD *= (1-metallic); // TODO: uncomment when having reflections

    float k = alpha/2;
    float geometry = (NdotL / (NdotL*(1-k)+k)) * (NdotV / (NdotV*(1-k)+k));

    float lowerTerm = pow(NdotH, 2) * (pow(alpha, 2) - 1.0) + 1.0;
    float normalDistributionFunctionGGX = pow(alpha, 2) / (3.14159 * pow(lowerTerm, 2));

    vec3 phongDiffuse = rhoD;
    vec3 cookTorrance = (fresnelReflectance * normalDistributionFunctionGGX * geometry);
    vec3 BRDF = (phongDiffuse + cookTorrance) * NdotL;
    
    return BRDF;
}

float calcFogFactor()
{
    float fragDist = length(viewSpacePosition);
    float dstRatio = 4.0 * fragDist / FOG_END;
    float fogFactor = exp2((1.0 - dstRatio - rainStrength) * FOG_DENSITY * (cameraPosition.y * 0.01) * (RAIN_FOG_STRENGTH + rainStrength));

    return clamp(fogFactor, 0.0, 1.0);
}

#define SHADOW_QUALITY 2
#define SHADOW_SOFTNESS 4

vec3 distortShadowClipPos(vec3 shadowClipPos)
{
    float distortionFactor = length(shadowClipPos.xy);  
    distortionFactor += 0.1;

    shadowClipPos.xy /= distortionFactor;
    shadowClipPos.z *= 0.5;
    return shadowClipPos;
}

vec3 getShadow(vec3 shadowScreenPos)
{
    float transparentShadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r);
    
    if(transparentShadow == 1.0)
    {
        return vec3(1.0);
    }

    float opaqueShadow = step(shadowScreenPos.z, texture(shadowtex1, shadowScreenPos.xy).r);

    if(opaqueShadow == 0.0)
    {
        return vec3(0.0);
    }

    vec4 shadowColor = texture(shadowcolor0, shadowScreenPos.xy);
    return shadowColor.rgb * (1.0 - shadowColor.a);
}

vec3 getSoftShadow(vec4 shadowClipPos)
{
  const float range = SHADOW_SOFTNESS / 2; // how far away from the original position we take our samples from
  const float increment = range / SHADOW_QUALITY; // distance between each sample

  float noise = getNoise(texCoord).r;

  float theta = noise * radians(360.0); // random angle using noise value
  float cosTheta = cos(theta);
  float sinTheta = sin(theta);

  mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta); // matrix to rotate the offset around the original position by the angle

  vec3 shadowAccum = vec3(0.0); // sum of all shadow samples
  int samples = 0;

  for(float x = -range; x <= range; x += increment){
    for (float y = -range; y <= range; y+= increment){
      vec2 offset = rotation * vec2(x, y) / shadowMapResolution; // offset in the rotated direction by the specified amount. We divide by the resolution so our offset is in terms of pixels
      vec4 offsetShadowClipPos = shadowClipPos + vec4(offset, 0.0, 0.0); // add offset
      offsetShadowClipPos.z -= 0.001; // apply bias
      offsetShadowClipPos.xyz = distortShadowClipPos(offsetShadowClipPos.xyz); // apply distortion
      vec3 shadowNDCPos = offsetShadowClipPos.xyz / offsetShadowClipPos.w; // convert to NDC space
      vec3 shadowScreenPos = shadowNDCPos * 0.5 + 0.5; // convert to screen space
      shadowAccum += getShadow(shadowScreenPos); // take shadow sample
      samples++;
    }
  }

  return shadowAccum / float(samples); // divide sum by count, getting average shadow
}

vec3 lightningCalc(vec3 albedo)
{
    vec4 specularData = texture(specular, texCoord);
    vec3 blockLight = texture(lightmap, vec2(lightMapCoord.x, 1.0/32.0)).rgb;
    vec3 skyLight = texture(lightmap, vec2(1.0/32.0, lightMapCoord.y)).rgb;
    skyLight = pow(skyLight, vec3(1.6));    // makes the sky light fall off quick.
    blockLight = 1.2 * pow(blockLight, vec3(4.0)); // makes the block light fall off quick.
    vec4 normalData = texture(normals, texCoord)*2.0-1.0;

    vec3 normalNormalSpace = vec3(normalData.xy, sqrt(1.0 - dot(normalData.xy, normalData.xy)));
    vec3 worldGeoNormal = normalize(mat3(gbufferModelViewInverse) * geoNormal);
    vec3 worldTangent = mat3(gbufferModelViewInverse) * tangent.xyz;
    mat3 TBN = tbnNormalTangent(worldGeoNormal, worldTangent);
    vec3 normalWorldSpace = TBN * normalNormalSpace;
    vec3 shadowLightDirection = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);

    float perceptualSmoothness = specularData.r;
    float subsurfaceScattering = clamp(specularData.b, 0.0, 1.0);   // range 65 - 256
    float roughness = pow(1.0 - perceptualSmoothness, 2.0);
    float smoothness = 1-roughness;
    float metallic = 0.0;
    vec3 reflectance = vec3(0);
    if (specularData.g*255 > 229)
    {
        metallic = 1.0;
        reflectance = albedo;
    }
    else
    {
        reflectance = vec3(specularData.g);
    }

    // Space Conversion
    vec3 fragFeetPlayerSpace = vec3(gbufferModelViewInverse * vec4(viewSpacePosition, 1.0));
    vec3 fragWorldSpace = fragFeetPlayerSpace + cameraPosition;
    vec3 adjustedFragFeetPlayerSpace = fragFeetPlayerSpace + 0.3 * worldGeoNormal;

    vec3 reflectionDirection = reflect(shadowLightDirection, normalWorldSpace);
    vec3 viewDirection = normalize(cameraPosition - fragWorldSpace);
    vec3 shadowViewPos = (shadowModelView * vec4(fragFeetPlayerSpace, 1.0)).xyz;
    vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);

    vec3 shadow = getSoftShadow(shadowClipPos);

    vec3 ambientLightDirection = worldGeoNormal;
    vec3 ambientLight = (blockLight + 0.25 * skyLight) * max(dot(ambientLightDirection, normalWorldSpace), 0.0);

    vec3 finalColor = vec3(1.0);
    if (round(mcEntity.x) == 69 || round(mcEntity.x) == 72)
    {
        finalColor = albedo * skyLight * max(shadow, ambientLight);
    }
    else
    {
        finalColor = albedo * ambientLight + skyLight * shadow * brdf(shadowLightDirection, viewDirection, roughness, normalWorldSpace, albedo, metallic, reflectance);
    }
    finalColor = mix(fogColor, finalColor, calcFogFactor());

    return finalColor;
}