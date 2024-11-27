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
    vec3 fragShadowViewSpace = (shadowModelView * vec4(adjustedFragFeetPlayerSpace, 1.0)).xyz;
    vec4 fragHomegenousSpace = shadowProjection * vec4(fragShadowViewSpace, 1.0);
    vec3 fragShadowNDCSpace = fragHomegenousSpace.xyz / fragHomegenousSpace.w;
    float distanceFromPlayerShadowNDC = length(fragShadowNDCSpace.xy);
    vec3 distortedShadowNDCSpace = vec3(fragShadowNDCSpace.xy / (distanceFromPlayerShadowNDC + 0.1), fragShadowNDCSpace.z);
    vec3 fragShadowScreenSpace = distortedShadowNDCSpace * 0.5 + 0.5;

    vec3 reflectionDirection = reflect(shadowLightDirection, normalWorldSpace);
    vec3 viewDirection = normalize(cameraPosition - fragWorldSpace);

    float isInNonColoredShadow = step(fragShadowScreenSpace.z, texture(shadowtex1, fragShadowScreenSpace.xy).r);
    vec3 shadowColor = texture(shadowcolor0, fragShadowScreenSpace.xy).rgb;

    vec3 shadowMultiplier = vec3(1.0);
    const int shadowFilterSize = 1;
    float bias = max(0.05 * (1.0 - dot(normalWorldSpace, shadowLightDirection)), 0.005);

    float isInShadow = 0.0;
    vec2 texelSize = 1.0 / textureSize(shadowtex0, 0);
    for(int x = -shadowFilterSize/2; x <= shadowFilterSize/2; ++x)
    {
        for(int y = -shadowFilterSize/2; y <= shadowFilterSize/2; ++y)
        {
            vec2 offset = vec2(x, y) * texelSize;
            float depth = texture(shadowtex0, fragShadowScreenSpace.xy + offset).x;

            isInShadow += depth + bias > fragShadowScreenSpace.z ? 1.0 : 0.0;
        }
    }
    isInShadow /= float(pow(shadowFilterSize,2));

    if (isInShadow == 0.0 && length(viewSpacePosition) < 70)
    {
        if (isInNonColoredShadow == 0.0)
        {
            shadowMultiplier = vec3(isInShadow);
        }
        else
        {
            shadowMultiplier = shadowColor;
        }
    }

    vec3 ambientLightDirection = worldGeoNormal;
    vec3 ambientLight = (blockLight + 0.25 * skyLight) * max(dot(ambientLightDirection, normalWorldSpace), 0.0);

    vec3 finalColor = vec3(1.0);
    if (round(mcEntity.x) == 69 || round(mcEntity.x) == 72)
    {
        finalColor = albedo * skyLight * max(shadowMultiplier, ambientLight);
    }
    else
    {
        finalColor = albedo * ambientLight + skyLight * shadowMultiplier * brdf(shadowLightDirection, viewDirection, roughness, normalWorldSpace, albedo, metallic, reflectance);
    }
    finalColor = mix(fogColor, finalColor, calcFogFactor());

    return finalColor;
}