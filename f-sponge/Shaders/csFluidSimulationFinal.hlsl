

#include "particle.hlsli"
#include "PBDSphere.hlsli"
#include "fluid.hlsli"


RWStructuredBuffer<Particle> particles;
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
		particles[tid].velocity += dt * sumForce / particles[tid].massDensity;
		particles[tid].position += dt * particles[tid].velocity;		
	}

	// VI. Check boundaries

	//const float boundary = 0.07;
	
	/*
	if (particles[tid].position.y < boundaryBottom)
	{
		particles[tid].position.y = boundaryBottom;
		particles[tid].velocity.y = 0.0;
	}

	if (particles[tid].position.y > boundaryTop)
	{
		particles[tid].position.y = boundaryTop;
		particles[tid].velocity.y = 0.0;
	}

	if (particles[tid].position.z > boundarySide)
	{
		particles[tid].position.z = boundarySide;
		particles[tid].velocity.z = 0.0;
	}

	if (particles[tid].position.z < -boundarySide)
	{
		particles[tid].position.z = -boundarySide;
		particles[tid].velocity.z = 0.0;
	}

	if (particles[tid].position.x > boundarySide)
	{
		particles[tid].position.x = boundarySide;
		particles[tid].velocity.x = 0.0;
	}

	if (particles[tid].position.x < -boundarySide)
	{
		particles[tid].position.x = -boundarySide;
		particles[tid].velocity.x = 0.0;
	}
	*/

	const float boundaryEps = 0.001;
	const float boundaryVelDec = 0.2;
	//const float boundaryVelDec = 0.0;

	float3 radDis = particles[tid].position - testMesh[0].pos.xyz;
	float sphereDist = length(radDis);
	radDis = normalize(radDis);
	if (sphereDist < sphereRadius) {
		particles[tid].position += radDis;
	}

	if (particles[tid].position.y < boundaryBottom)
	{
		particles[tid].position.y = boundaryBottom + boundaryEps;
		particles[tid].velocity *= boundaryVelDec;
		particles[tid].velocity.y *= - 1.0;
	}

	if (particles[tid].position.y > boundaryTop)
	{
		particles[tid].position.y = boundaryTop - boundaryEps;
		particles[tid].velocity *= boundaryVelDec;
		particles[tid].velocity.y *= -1.0;
	}

	if (particles[tid].position.z > boundarySide)
	{
		particles[tid].position.z = boundarySide - boundaryEps;
		particles[tid].velocity *= boundaryVelDec;
		particles[tid].velocity.z *= -1.0;
	}

	if (particles[tid].position.z < -boundarySide)
	{
		particles[tid].position.z = -boundarySide + boundaryEps;
		particles[tid].velocity *= boundaryVelDec;
		particles[tid].velocity.z *= -1.0;
	}

	if (particles[tid].position.x > boundarySide)
	{
		particles[tid].position.x = boundarySide - boundaryEps;
		particles[tid].velocity *= boundaryVelDec;
		particles[tid].velocity.x *= -1.0;
	}

	if (particles[tid].position.x < -boundarySide)
	{
		particles[tid].position.x = -boundarySide + boundaryEps;
		particles[tid].velocity *= boundaryVelDec;
		particles[tid].velocity.x *= -1.0;
	}
}


