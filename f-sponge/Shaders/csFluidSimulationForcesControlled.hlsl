

#include "particle.hlsli"
#include "fluid.hlsli"


RWStructuredBuffer<Particle> particles;
RWStructuredBuffer<float4> particleForce;
StructuredBuffer<ControlParticle> controlParticles;
Buffer<uint> controlParticleCounter;

cbuffer controlParamsCB
{
	float4 controlParams[2];
};

[numthreads(particlePerCore, 1, 1)]
void csFluidSimulationForcesControlled(uint3 DTid : SV_GroupID, uint3 GTid : SV_GroupThreadID)
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

				pressureForce += ((particles[tid].pressure / pow(particles[tid].massDensity, 2)) + (particles[i].pressure / pow(particles[i].massDensity, 2)))
					* massPerParticle * pressureSmoothingKernelGradient(deltaPos, supportRadius_w);
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
				viscosityForce += (particles[i].velocity - particles[tid].velocity) * (massPerParticle / particles[i].massDensity) * viscositySmoothingKernelLaplace(deltaPos, supportRadius_w);

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
				inwardSurfaceNormal += (massPerParticle / particles[i].massDensity) * defaultSmoothingKernelGradient(deltaPos, supportRadius_w);
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

	// V. Control force
	float3 controlForce = float3(0.0, 0.0, 0.0);
	{
		for (int i = 0; i < controlParticleCounter[0]; i++)
		{
			//if (i != tid && controlParticles[i].pressure == 1.0)
			{
				float3 deltaPos = particles[tid].position - controlParticles[i].position + float3 (0, controlParams[1].w, 0);

				//controlForce += 0.9 * pressureSmoothingKernelGradient(deltaPos, supportRadius_w * 0.8);
				controlForce += controlParticles[i].controlPressureRatio * 0.9 * particles[i].massDensity * pressureSmoothingKernelGradient(deltaPos, supportRadius_w * 1.2);
			}
		}
	}

	float controlAmplitude = length(controlForce);
	if (controlAmplitude > 0.001)
	{
		gravitationalForce = float3(0.0, 0.0, 0.0);
		//controlForce *=  1.0 / length(controlForce);
	}

	const float maxConrtolForce = 50000.0;
	if (controlAmplitude > maxConrtolForce)
	{
		controlForce *= maxConrtolForce / controlAmplitude;
		particles[tid].velocity *= 0.9;
	}

	if (controlParams[0].x > 0.5)
	{
		sumForce += gravitationalForce;
	}
	if (controlParams[0].y > 0.5)
	{
		sumForce += pressureForce;
	}
	if (controlParams[0].z > 0.5)
	{
		sumForce += viscosityForce;
	}
	if (controlParams[0].w > 0.5)
	{
		//sumForce += surfaceTensionForce;
	}
	//if (controlParams[1].x > 0.5)
	{
		sumForce += controlForce;
	}



	// IV.e sum forces
	//sumForce = pressureForce + gravitationalForce;
	//sumForce = gravitationalForce;
	//sumForce = pressureForce + gravitationalForce;

	//sumForce = pressureForce + viscosityForce + gravitationalForce;
	//sumForce = pressureForce + viscosityForce + surfaceTensionForce;
	//sumForce = pressureForce + surfaceTensionForce + gravitationalForce;

	//sumForce = pressureForce + viscosityForce + surfaceTensionForce + gravitationalForce;

	particleForce[tid].xyz = sumForce;
}


