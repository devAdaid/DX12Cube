//*********************************************************
//
// Copyright (c) Microsoft. All rights reserved.
// This code is licensed under the MIT License (MIT).
// THIS CODE IS PROVIDED *AS IS* WITHOUT WARRANTY OF
// ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY
// IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR
// PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.
//
//*********************************************************

cbuffer ObjectConstantBuffer : register(b0)
{
    float4x4 gWorldViewProj;
    float3 gEyePos;
};

struct PSInput
{
    float4 position : SV_POSITION;
    float3 normal : NORMAL;
};

struct Material
{
    float4 DiffuseAlbedo;
    float3 FresnelR0;
    float Shininess;
};

float4 ComputeDirectLight(float3 lightStrength, float3 lightDirection, float3 normal, float3 toEye, Material mat);
float3 BlinnPhong(float3 lightStrength, float3 lightVec, float3 normal, float3 toEye, Material mat);
float3 SchlickFresnel(float3 R0, float3 normal, float3 lightVec);

PSInput VSMain(float4 position : POSITION, float3 normal : NORMAL)
{
    PSInput result;

    result.position = mul(position, gWorldViewProj);
    result.normal = mul(normal, (float3x3)gWorldViewProj);

    return result;
}

float4 PSMain(PSInput input) : SV_TARGET
{
    const float4 ambientLight = float4(0.0f,0.2f,0.0f,1.0f);
    const float4 diffuseAlbedo = float4(1.0f,1.0f,1.0f,1.0f);
    const float3 fresnelR0 = float3(0.04f,0.04f,0.04f);
    const float roughness = 0.25f;

    const float3 lightStrength = float3(0.3f, 0.3f, 0.3f);
    const float3 lightDirection = float3(1.5f, -1.0f, 1.5f);

    input.normal = normalize(input.normal);

    // Vector from point being lit to eye. 
    float3 toEyeW = normalize(gEyePos - input.position);

    // Indirect lighting.
    float4 ambient = ambientLight * diffuseAlbedo;

    const float shininess = 1.0f - roughness;
    Material mat = { diffuseAlbedo, fresnelR0, shininess };

    float4 directLight = ComputeDirectLight(lightStrength, lightDirection, input.normal, toEyeW, mat);

    float4 litColor = ambient + directLight;

    // Common convention to take alpha from diffuse material.
    litColor.a = diffuseAlbedo.a;

    return litColor;
}

float4 ComputeDirectLight(float3 lightStrength, float3 lightDirection, float3 normal, float3 toEye, Material mat)
{
    // The light vector aims opposite the direction the light rays travel.
    float3 lightVec = -lightDirection;

    // Scale light down by Lambert's cosine law.
    float ndotl = max(dot(lightVec, normal), 0.0f);
    float3 scaleStrength = lightStrength * ndotl;

    float3 color = BlinnPhong(scaleStrength, lightVec, normal, toEye, mat);

    return float4(color, 0.0f);
}

float3 BlinnPhong(float3 lightStrength, float3 lightVec, float3 normal, float3 toEye, Material mat)
{
    const float m = mat.Shininess * 256.0f;
    float3 halfVec = normalize(toEye + lightVec);

    float roughnessFactor = (m + 8.0f) * pow(max(dot(halfVec, normal), 0.0f), m) / 8.0f;
    float3 fresnelFactor = SchlickFresnel(mat.FresnelR0, halfVec, lightVec);

    float3 specAlbedo = fresnelFactor * roughnessFactor;

    // Our spec formula goes outside [0,1] range, but we are 
    // doing LDR rendering.  So scale it down a bit.
    specAlbedo = specAlbedo / (specAlbedo + 1.0f);

    return (mat.DiffuseAlbedo.rgb + specAlbedo) * lightStrength;
}

float3 SchlickFresnel(float3 R0, float3 normal, float3 lightVec)
{
    float cosIncidentAngle = saturate(dot(normal, lightVec));

    float f0 = 1.0f - cosIncidentAngle;
    float3 reflectPercent = R0 + (1.0f - R0) * (f0 * f0 * f0 * f0 * f0);

    return reflectPercent;
}