

#include "particle.hlsli"
#include "fluid.hlsli"


RWStructuredBuffer<Particle> particles;
RWStructuredBuffer<float4> particleForce;

[numthreads(particlePerCore, 1, 1)]
void csFluidSimulationForces (uint3 DTid : SV_GroupID, uint3 GTid : SV_GroupThreadID)
{
	unsigned int tid = DTid.x * particlePerCore + GTid;

	// IV. Calc forces
	float3 sumForce = float3 (0.0, 0.0, 0.0);

	// IV.a Pressure force
	float3 pressureForce = float3(0.0, 0.0, 0.0);
	{
		for (int i = 0; i < particleCount; i++)
		{
			if (i != tid)
			{
				float3 deltaPos = particles[tid].position - particles[i].position;

				pressureForce +=	((particles[tid].pressure / pow(particles[tid].massDensity, 2)) + (particles[i].pressure / pow(particles[i].massDensity, 2)))
									* massPerParticle * pressureSmoothingKernelGradient (deltaPos, supportRadius_w);
			}
		}
		pressureForce *= -particles[tid].massDensity;
	}

	// IV.b Viscosity force
	float3 viscosityForce = float3(0.0, 0.0, 0.0);
	{
		for (int i = 0; i < particleCount; i++)
		{
			if (i != tid)
			{
				float3 deltaPos = particles[tid].position - particles[i].position;
				viscosityForce += (particles[i].velocity - particles[tid].velocity) * (massPerParticle / particles[i].massDensity) * viscositySmoothingKernelLaplace (deltaPos, supportRadius_w);
					
			}
		}
		viscosityForce *= viscosity;
	}

	// IV.c SurfaceTension force
	float3 surfaceTensionForce = float3(0.0, 0.0, 0.0);
	{
		float3 inwardSurfaceNormal = float3(0.0, 0.0, 0.0);
		for (int i = 0; i < particleCount; i++)
		{
			if (i != tid)
			{
				float3 deltaPos = particles[tid].position - particles[i].position;
				inwardSurfaceNormal += (massPerParticle / particles[i].massDensity) * defaultSmoothingKernelGradient (deltaPos, supportRadius_w);
			}
		}

		uint tempCount = 0;
		float surfaceTensionForceAmplitude = 0.0;
		for (int i = 0; i < particleCount; i++)
		{
			if (i != tid)
			{					
				float3 deltaPos = particles[tid].position - particles[i].position;
				surfaceTensionForceAmplitude += (massPerParticle / particles[i].massDensity) * defaultSmoothingKernelLaplace(deltaPos, supportRadius_w);
				if (length(deltaPos) < supportRadius_w)
				{
					tempCount++;
				}
			}
		}
		if (tempCount > 0)
		{
			surfaceTensionForce = -surfaceTension * normalize(inwardSurfaceNormal) * surfaceTensionForceAmplitude;
		}			
	}

	// IV.d Gravitational force
	float3 gravitationalForce = float3 (0.0, -g * particles[tid].massDensity, 0.0);


	// IV.e sum forces
	//sumForce = pressureForce + gravitationalForce;
	//sumForce = gravitationalForce;
	//sumForce = pressureForce + gravitationalForce;
		
	//sumForce = pressureForce + viscosityForce + gravitationalForce;
	//sumForce = pressureForce + viscosityForce + surfaceTensionForce;
	//sumForce = pressureForce + surfaceTensionForce + gravitationalForce;

	sumForce = pressureForce + viscosityForce + surfaceTensionForce + gravitationalForce;

	particleForce[tid].xyz = sumForce;
}


