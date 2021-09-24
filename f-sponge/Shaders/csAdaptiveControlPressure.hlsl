

#include "particle.hlsli"

StructuredBuffer<Particle> particles;
RWStructuredBuffer<ControlParticle> controlParticles;

#define pi 3.1415

float defaultSmoothingKernel(float3 deltaPos, float supportRadius)
{
	if (length(deltaPos) > supportRadius)
	{
		return 0.0;
	}
	else
	{
		return (315.0 / (64.0 * pi * pow(supportRadius, 9))) * pow((pow(supportRadius, 2) - dot(deltaPos, deltaPos)), 3);
	}
}

[numthreads(1, 1, 1)]
void csAdaptiveControlPressure(uint3 DTid : SV_GroupID)
{
	const float massPerParticle = 0.02;		// kg
	const float restMassDensity = 998.29;	// kg/m3
	const float supportRadius = 0.0457;	// m

	unsigned int tid = DTid.x;

	float massDensity = 0.0;
	for (int i = 0; i < particleCount; i++)
	{
		float3 deltaPos = controlParticles[tid].position - particles[i].position;
		massDensity += massPerParticle * defaultSmoothingKernel(deltaPos, supportRadius);
	}

	if (massDensity < restMassDensity * 0.8)
	{
		controlParticles[tid].controlPressureRatio = 1.0;
	}
	else if (massDensity > restMassDensity * 1.2)
	{
		controlParticles[tid].controlPressureRatio = 0.5;

	}

	
}

