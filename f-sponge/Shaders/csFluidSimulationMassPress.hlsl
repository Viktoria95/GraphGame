

#include "particle.hlsli"
#include "fluid.hlsli"

RWStructuredBuffer<Particle> particles;

[numthreads(particlePerCore, 1, 1)]
void csFluidSimulationMassPress (uint3 DTid : SV_GroupID, uint3 GTid : SV_GroupThreadID)
{
	unsigned int tid = DTid.x * particlePerCore + GTid;

	// I. Find close neighbors and II. calc mass density
	float massDensity = 0.0;
	for (int i = 0; i < particleCount; i++)
	{
		float3 deltaPos = particles[tid].position - particles[i].position;
		massDensity += massPerParticle * defaultSmoothingKernel(deltaPos, supportRadius_w);
	}
	particles[tid].massDensity = massDensity;

	// III. Calc pressure
	particles[tid].pressure = gasStiffness * (particles[tid].massDensity - restMassDensity);
}


