
#include "particle.hlsli"

RWStructuredBuffer<Particle> particles;

#define groupDim_x 256

#define pi 3.1415

float defaultSmoothingKernel (float3 deltaPos, float supportRadius)
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

float3 defaultSmoothingKernelGradient (float3 deltaPos, float supportRadius)
{
	if (length(deltaPos) > supportRadius)
	{
		return float3 (0.0, 0.0, 0.0);
	}
	else
	{
		return (-945.0 / (32.0 * pi * pow(supportRadius, 9))) * deltaPos * pow((pow(supportRadius, 2) - dot(deltaPos, deltaPos)), 2);
	}
}

float defaultSmoothingKernelLaplace (float3 deltaPos, float supportRadius)
{
	if (length(deltaPos) > supportRadius)
	{
		return 0.0;
	}
	else
	{
		return (-945.0 / (32.0 * pi * pow(supportRadius, 9))) * deltaPos * (pow(supportRadius, 2) - dot(deltaPos, deltaPos)) * (3.0 * pow(supportRadius, 2) - 7.0 * dot(deltaPos, deltaPos));
	}
}

float pressureSmoothingKernel(float3 deltaPos, float supportRadius)
{
	float lengthOfDeltaPos = length(deltaPos);
	if (lengthOfDeltaPos > supportRadius)
	{
		return 0.0;
	}
	else
	{
		return (15.0 / (pi * pow(supportRadius, 6))) * pow(supportRadius - lengthOfDeltaPos, 3);
	}
}

float3 pressureSmoothingKernelGradient (float3 deltaPos, float supportRadius)
{
	float lengthOfDeltaPos = length(deltaPos);
	if (lengthOfDeltaPos > supportRadius)
	{
		return float3 (0.0, 0.0, 0.0);
	}
	else
	{
		return (-45.0 / (pi * pow(supportRadius, 6))) * (deltaPos/ lengthOfDeltaPos) * pow(supportRadius - lengthOfDeltaPos, 2);
	}
}

float viscositySmoothingKernelLaplace (float3 deltaPos, float supportRadius)
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
void csAnimation (uint3 DTid : SV_GroupID)
{
	float dt	= 0.01; // s
	float g		= 9.82; // m/s2

	// Water
	float massPerParticle	= 0.02;		// kg
	float restMassDensity	= 998.29;	// kg/m3
	float supportRadius		= 0.0457;	// m
	float gasStiffness		= 3.0;		// J
	float viscosity			= 3.5;		// Pa*s
	float surfaceTension	= 0.0728;	// N/m

	unsigned int tid = DTid.x;

	// I. Find close neighbors and II. calc mass density
	{
		float massDensity = 0.0;
		for (int i = 0; i < particleCount; i++)
		{
			float3 deltaPos = particles[tid].position - particles[i].position;
			massDensity += massPerParticle * defaultSmoothingKernel(deltaPos, supportRadius);
		}
		particles[tid].massDensity = massDensity;
	}

	// III. Calc pressure
	{
		particles[tid].pressure = gasStiffness * (particles[tid].massDensity - restMassDensity);
	}
	
	AllMemoryBarrierWithGroupSync();

	// IV. Calc forces
	float3 sumForce = float3 (0.0, 0.0, 0.0);
	{
		// IV.a Pressure force
		float3 pressureForce = float3(0.0, 0.0, 0.0);
		{
			for (int i = 0; i < particleCount; i++)
			{
				if (i != tid)
				{
					float3 deltaPos = particles[tid].position - particles[i].position;

					pressureForce +=	((particles[tid].pressure / pow(particles[tid].massDensity, 2)) + (particles[i].pressure / pow(particles[i].massDensity, 2)))
										* massPerParticle * pressureSmoothingKernelGradient (deltaPos, supportRadius);
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
					viscosityForce += (particles[i].velocity - particles[tid].velocity) * (massPerParticle / particles[i].massDensity) * viscositySmoothingKernelLaplace (deltaPos, supportRadius);
					
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
					inwardSurfaceNormal += (massPerParticle / particles[i].massDensity) * defaultSmoothingKernelGradient (deltaPos, supportRadius);
				}
			}

			float surfaceTensionForceAmplitude = 0.0;
			for (int i = 0; i < particleCount; i++)
			{
				if (i != tid)
				{
					float3 deltaPos = particles[tid].position - particles[i].position;
					surfaceTensionForceAmplitude += (massPerParticle / particles[i].massDensity) * defaultSmoothingKernelLaplace(deltaPos, supportRadius);
				}
			}
			surfaceTensionForce = -surfaceTension * normalize(inwardSurfaceNormal) * surfaceTensionForceAmplitude;
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
	}

	// V. Apply force
	if (length (sumForce) > 0.001) // TODO: Why?
	{
		particles[tid].velocity += dt * sumForce / particles[tid].massDensity;
		particles[tid].position += dt * particles[tid].velocity;		
	}

	// VI. Check boundaries

	const float boundary = 0.07;
	
	if (particles[tid].position.y < 0.0)
	{
		particles[tid].position.y = 0.0;
		particles[tid].velocity.y = 0.0;
	}

	if (particles[tid].position.z > boundary)
	{
		particles[tid].position.z = boundary;
		particles[tid].velocity.z = 0.0;
	}

	if (particles[tid].position.z < -boundary)
	{
		particles[tid].position.z = -boundary;
		particles[tid].velocity.z = 0.0;
	}

	if (particles[tid].position.x > boundary)
	{
		particles[tid].position.x = boundary;
		particles[tid].velocity.x = 0.0;
	}

	if (particles[tid].position.x < -boundary)
	{
		particles[tid].position.x = -boundary;
		particles[tid].velocity.x = 0.0;
	}
	
	/*
	if (tid % 4 != 0)
	{
		if (particles[tid].position.y < -1.0)
		{
			particles[tid].position.y = -1.0;
			particles[tid].velocity.y = 0.0;
		}
	}
	else
	{
		if (particles[tid].position.y < -5.0)
		{
			particles[tid].position.y = 5.0;
			particles[tid].velocity.y = 0.0;
		}
	}
	*/

	//particles[tid].velocity = sumForce;

	//particles[tid].velocity += 0.001 * dt * sumForce;

	




	




	//float massPerParticle = 1.0;
	//float restDens = 20.0;
	//float dt = 0.001;
	//float close = 10.0;
	//float minDist = 0.1;
	//float stiffness = 1.0;
	//float viscosity = 10.0;

	//unsigned int tid = DTid.x;

	//float massDens = 1.0;
	//for (int i = 0; i < particleCount; i++)
	//{
	//	// I. Find close neighbors and II. calc mass density
	//	float distance = length(particles[tid].position - particles[i].position);
	//	if (distance < close && distance > minDist && tid != i)
	//	{
	//		massDens += massPerParticle * (1.0 / distance);
	//	}
	//}
	//// III. Calc pressure
	//float pressure = stiffness * (pow (massDens / restDens, 7) - 1.0);

	//particles[tid].velocity.w = pressure;
	////particles[tid].velocity.x = 0.0;
	////particles[tid].velocity.y = 0.0;
	////particles[tid].velocity.z = 0.0;
	//particles[tid].position.w = massDens;

	//AllMemoryBarrierWithGroupSync ();

	//// IV. Calc and use Forces
	//float3 pressureGrad = float3 (0.0, 0.0, 0.0);
	//float3 velocityGradX = float3 (0.0, 0.0, 0.0);
	//float3 velocityGradY = float3 (0.0, 0.0, 0.0);
	//float3 velocityGradZ = float3 (0.0, 0.0, 0.0);
	//for (int i = 0; i < particleCount; i++)
	//{
	//	float3 deltaPos = particles[i].position - particles[tid].position;
	//	float distance = length(deltaPos);
	//	if (distance <close && distance > minDist && tid != i)
	//	{
	//		pressureGrad += deltaPos * particles[i].velocity.w / distance;
	//		velocityGradX += deltaPos.x * particles[i].velocity.xyz / distance;
	//		velocityGradY += deltaPos.y * particles[i].velocity.xyz / distance;
	//		velocityGradZ += deltaPos.z * particles[i].velocity.xyz / distance;
	//	}
	//}
	//particles[tid].temp1.xyz = velocityGradX;
	//particles[tid].temp2.xyz = velocityGradY;
	//particles[tid].temp3.xyz = velocityGradZ;

	//AllMemoryBarrierWithGroupSync();

	//float3 velocityGradGrad = float3 (0.0, 0.0, 0.0);
	//for (int i = 0; i < particleCount; i++)
	//{
	//	float3 deltaPos = particles[i].position - particles[tid].position;
	//	float distance = length(deltaPos);
	//	if (distance <close && distance > minDist && tid != i)
	//	{
	//		velocityGradGrad += deltaPos  * (particles[i].temp1.x, particles[i].temp2.y, particles[i].temp3.z) / distance;
	//	}
	//}
	//
	//float3 viscF = viscosity * massPerParticle * velocityGradGrad;
	//float3 pressureF = -pressureGrad * massPerParticle / massDens;
	//float3 gravityF = 9.81 * massPerParticle * float3 (0.0, -1.0, 0.0);


	//float3 sumF = pressureF + gravityF/* + viscF*/;


	//float3 deltaV = sumF * dt / massPerParticle;
	//particles[tid].velocity = float4 (particles[tid].velocity.xyz + deltaV, particles[tid].velocity.w);	

	//float3 newPos = particles[tid].position.xyz + particles[tid].velocity.xyz + dt;
	//particles[tid].position = float4 (newPos, particles[tid].position.w);

	//if (tid % 4 == 0)
	//{
	//	if (particles[tid].position.y < -5.0)
	//	{
	//		particles[tid].position.y = 5.0;
	//		particles[tid].velocity.y = 0.0;
	//	}
	//}
	//else
	//{
	//	if (particles[tid].position.y < 0.0)
	//	{
	//		particles[tid].position.y = 0.0;
	//		particles[tid].velocity.y = 0.0;
	//	}
	//}	
	//



	//// Viscosity helyett
	//particles[tid].velocity = float4 (particles[tid].velocity.xyz * 0.9, particles[tid].velocity.w);

	////float3 newPos = particles[tid].velocity.xyz * dt;

	////particles[tid].position.x = newPos.x;
	////particles[tid].position.y = newPos.y;
	////particles[tid].position.z = newPos.z;


	////particles[tid].position = float4 (particles[tid].position.xyz - deltaV, particles[tid].position.w);



}


