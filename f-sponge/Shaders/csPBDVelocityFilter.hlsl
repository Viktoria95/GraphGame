
#include "particle.hlsli"
#include "PBDSphere.hlsli"

#define pi 3.1415

StructuredBuffer<ControlParticle> controlParticles;
Buffer<uint> controlParticleCounter;

StructuredBuffer<Particle> particles;

RWStructuredBuffer<float4> velocity;

float viscositySmoothingKernelLaplace(float3 deltaPos, float supportRadius)
{
	float lengthOfDeltaPos = length(deltaPos);
	if (lengthOfDeltaPos > supportRadius)
	{
		return 0.0;
	}
	else
	{
		return (45.0 / (pi * pow(supportRadius, 6))) * (supportRadius - lengthOfDeltaPos);
	}
}

[numthreads(1, 1, 1)]
void csPBDVelocityFilter(uint3 DTid : SV_GroupID) {
	float massPerParticle = 0.02;		// kg
	float restMassDensity = 998.29;	// kg/m3
	float supportRadius = 0.0457;	// m
	float gasStiffness = 3.0;		// J
	float viscosity = 3.5;		// Pa*s
	float surfaceTension = 0.0728;	// N/m

	unsigned int tid = DTid.x;

	if (tid < controlParticleCounter[0]) {

		// IV.b Viscosity force
		float3 viscosityForce = float3(0.0, 0.0, 0.0);
		{
			for (int i = 0; i < particleCount; i++)
			{
				//if (i != tid)
				{
					float3 deltaPos = controlParticles[tid].position - particles[i].position;
					//viscosityForce += (particles[i].velocity - velocity[tid].xyz) * (massPerParticle / particles[i].massDensity) * viscositySmoothingKernelLaplace(deltaPos, supportRadius);
					//viscosityForce += (particles[i].velocity - velocity[tid].xyz) * viscositySmoothingKernelLaplace(deltaPos, supportRadius);
					viscosityForce += particles[i].velocity * viscositySmoothingKernelLaplace(deltaPos, supportRadius) * 0.0000000003;

				}
			}
			viscosityForce *= viscosity;
		}

		velocity[tid].xyz += viscosityForce;
		//velocity[tid].xyz += float3 (0.0, 0.1, 0.0);

	}
}