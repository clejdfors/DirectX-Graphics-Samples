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

#ifndef INLINE_RAYTRACING_HLSL
#define INLINE_RAYTRACING_HLSL

#define HLSL
#include "RaytracingHlslCompat.h"

RaytracingAccelerationStructure Scene : register(t0, space0);
RWTexture2D<float4> RenderTarget : register(u0);
ByteAddressBuffer Indices : register(t1, space0);
StructuredBuffer<Vertex> Vertices : register(t2, space0);

ConstantBuffer<SceneConstantBuffer> g_sceneCB : register(b0);
ConstantBuffer<CubeConstantBuffer> g_cubeCB : register(b1);

static const float2 screenSize = float2(1280, 720);

inline void GenerateCameraRay(uint2 index, out float3 origin, out float3 direction)
{
    float2 xy = index + 0.5f; // center in the middle of the pixel.
    float2 screenPos = (xy / screenSize) * 2 - 1.0;

    // Invert Y for DirectX-style coordinates.
    screenPos.y = -screenPos.y;

    // Unproject the pixel coordinate into a ray.
    float4 world = mul(float4(screenPos, 0, 1), g_sceneCB.projectionToWorld);

    world.xyz /= world.w;
    origin = g_sceneCB.cameraPosition.xyz;
    direction = normalize(world.xyz - origin);
}

[numthreads(8, 8, 1)]
void main(uint3 dispatchId : SV_DispatchThreadID)
{
	// RenderTarget[dispatchId.xy] = float4(dispatchId.xy, 0, 1);

    float3 rayDir;
    float3 origin;

    // Generate a ray for a camera pixel corresponding to an index from the dispatched 2D grid.
	GenerateCameraRay(dispatchId.xy, origin, rayDir);

    RayDesc ray;
    ray.Origin = origin;
    ray.Direction = rayDir;
    ray.TMin = 0.001;
    ray.TMax = 10000.0;

#if 0
    // RenderTarget[dispatchId.xy] = float4(dispatchId.xy / screenSize, 0, 1);
    RenderTarget[dispatchId.xy] = float4(rayDir.xyz, 1);
#else

    RayQuery<RAY_FLAG_NONE> q;
	q.TraceRayInline(Scene, RAY_FLAG_CULL_BACK_FACING_TRIANGLES, ~0, ray);
    q.Proceed();

    if (q.CommittedStatus() == COMMITTED_TRIANGLE_HIT)
    {
        RenderTarget[dispatchId.xy] = float4(dispatchId.xy / screenSize, 0, 1);
        //RenderTarget[dispatchId.xy] = float4(q.CandidateTriangleBarycentrics(), 0, 1);
    }
    else
    {
        RenderTarget[dispatchId.xy] = float4(0.2, 0.2, 0.2, 1);
    }
#endif
}

#endif // INLINE_RAYTRACING_HLSL