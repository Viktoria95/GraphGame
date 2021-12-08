

#include "particle.hlsli"
#include "PBDSphere.hlsli"
#include "fluid.hlsli"

StructuredBuffer<float> massDensities;
RWStructuredBuffer<float4> positions;
RWStructuredBuffer<float4> velocities;
RWStructuredBuffer<float4> particleForce;
StructuredBuffer<Sphere> testMesh;

[numthreads(particlePerCore, 1, 1)]
void csFluidSimulationFinal (uint3 DTid : SV_GroupID, uint3 GTid : SV_GroupThreadID)
{
	unsigned int tid = DTid.x * particlePerCore + GTid;

	float3 sumForce = particleForce[tid].xyz;


	// V. Apply force
	if (length (sumForce) > 0.001) // TODO: Why?
	{
		velocities[tid].xyz += dt * sumForce / massDensities[tid];
		positions[tid].xyz += dt * velocities[tid].xyz;		
	}

	// VI. Check boundaries

	//const float boundary = 0.07;
	
	/*
	if (positions[tid].xyz.y < boundaryBottom)
	{
		positions[tid].xyz.y = boundaryBottom;
		velocities[tid].xyz.y = 0.0;
	}

	if (positions[tid].xyz.y > boundaryTop)
	{
		positions[tid].xyz.y = boundaryTop;
		velocities[tid].xyz.y = 0.0;
	}

	if (positions[tid].xyz.z > boundarySide)
	{
		positions[tid].xyz.z = boundarySide;
		velocities[tid].xyz.z = 0.0;
	}

	if (positions[tid].xyz.z < -boundarySide)
	{
		positions[tid].xyz.z = -boundarySide;
		velocities[tid].xyz.z = 0.0;
	}

	if (positions[tid].xyz.x > boundarySide)
	{
		positions[tid].xyz.x = boundarySide;
		velocities[tid].xyz.x = 0.0;
	}

	if (positions[tid].xyz.x < -boundarySide)
	{
		positions[tid].xyz.x = -boundarySide;
		velocities[tid].xyz.x = 0.0;
	}
	*/

	const float boundaryEps = 0.001;
	const float boundaryVelDec = 0.2;
	//const float boundaryVelDec = 0.0;

	float3 radDis = positions[tid].xyz - testMesh[0].pos.xyz;
	float sphereDist = length(radDis);
	float3 radNorm = normalize(radDis);
	if (sphereDist < sphereRadius) {
		positions[tid].xyz += radDis;
		velocities[tid].xyz = velocities[tid].xyz - radNorm * dot(radNorm, velocities[tid].xyz);
		velocities[tid].xyz *= 0.0;
	}

	if (positions[tid].xyz.y < boundaryBottom)
	{
		positions[tid].xyz.y = boundaryBottom + boundaryEps;
		velocities[tid].xyz *= boundaryVelDec;
		velocities[tid].xyz.y *= - 1.0;
	}

	if (positions[tid].xyz.y > boundaryTop)
	{
		positions[tid].xyz.y = boundaryTop - boundaryEps;
		velocities[tid].xyz *= boundaryVelDec;
		velocities[tid].xyz.y *= -1.0;
	}

	if (positions[tid].xyz.z > boundarySide)
	{
		positions[tid].xyz.z = boundarySide - boundaryEps;
		velocities[tid].xyz *= boundaryVelDec;
		velocities[tid].xyz.z *= -1.0;
	}

	if (positions[tid].xyz.z < -boundarySide)
	{
		positions[tid].xyz.z = -boundarySide + boundaryEps;
		velocities[tid].xyz *= boundaryVelDec;
		velocities[tid].xyz.z *= -1.0;
	}

	if (positions[tid].xyz.x > boundarySide)
	{
		positions[tid].xyz.x = boundarySide - boundaryEps;
		velocities[tid].xyz *= boundaryVelDec;
		velocities[tid].xyz.x *= -1.0;
	}

	if (positions[tid].xyz.x < -boundarySide)
	{
		positions[tid].xyz.x = -boundarySide + boundaryEps;
		velocities[tid].xyz *= boundaryVelDec;
		velocities[tid].xyz.x *= -1.0;
	}
}


