#include "metaball.hlsli"
#include "particle.hlsli"
#include "window.hlsli"

SamplerState ss;
TextureCube envTexture;

cbuffer metaballPSEyePosCB
{
	float4 eyePos;
};

StructuredBuffer<ControlParticle> controlParticles;

bool BallTest(float3 p)
{
	const float r = 0.005;

	for (int i = 0; i < controlParticleCount; i++)
	{
		if (length(p - float3(controlParticles[i].position)) < r)
		{
			return true;
		}
	}

	return false;
}

float3 Grad(float3 p) {
	float3 grad;
	const float r = 0.005;

	for (int i = 0; i < controlParticleCount; i++) {
		float weight = (pow((-2.0*r), 2.0) / pow(length(p - float3(controlParticles[i].position)), 3.0)) * ((-1.0) / (2.0*length(p - float3(controlParticles[i].position))));
		grad.x += (weight * (p.x - controlParticles[i].position.x));
		grad.y += (weight * (p.y - controlParticles[i].position.y));
		grad.z += (weight * (p.z - controlParticles[i].position.z));
	}

	return grad;
}

float3 RandColor(float3 p) {
	const float r = 0.005;

	for (int i = 0; i < controlParticleCount; i++)
	{
		if (length(p - float3(controlParticles[i].position)) < r)
		{
			int div = i % 6;
			if (div == 0)
			{
				return float3 (1, 0, 0);
			}
			else if (div == 1)
			{
				return float3 (0, 1, 0);
			}
			else if (div == 2)
			{
				return float3 (0, 0, 1);
			}
			else if (div == 3)
			{
				return float3 (1, 1, 0);
			}
			else if (div == 4)
			{
				return float3 (1, 0, 1);
			}
			else if (div == 5)
			{
				return float3 (0, 1, 1);
			}
		}
	}

	return float3 (0,0,0);
}

void BoxIntersect(float3 rayOrigin, float3 rayDir, float3 minBox, float3 maxBox, out bool intersect, out float tStart, out float tEnd)
{
	float3 invDirection = rcp(rayDir);
	float3 t0 = float3 (minBox - rayOrigin) * invDirection;
	float3 t1 = float3 (maxBox - rayOrigin) * invDirection;
	float3 tMin = min(t0, t1);
	float3 tMax = max(t0, t1);
	float tMinMax = max(max(tMin.x, tMin.y), tMin.z);
	float tMaxMin = min(min(tMax.x, tMax.y), tMax.z);

	const float floatMax = 1000.0;
	intersect = (tMinMax <= tMaxMin) & (tMaxMin >= 0.0f) & (tMinMax <= floatMax);
	if (tMinMax < 0.0)
	{
		tMinMax = 0.0;
	}

	tStart = tMinMax;
	tEnd = tMaxMin;
}

float4 psControlParticleBall(VsosQuad input) : SV_Target
{
	const int stepCount = 50;
	const float boundarySideThreshold = boundarySide * 1.3;
	const float boundaryTopThreshold = boundaryTop * 1.3;
	const float boundaryBottomThreshold = boundaryBottom * 1.3;

	float3 d = normalize(input.rayDir);
	float3 p = eyePos;

	bool intersect;
	float tStart;
	float tEnd;
	BoxIntersect
	(
		p,
		d,
		float3 (-boundarySideThreshold, boundaryBottomThreshold, -boundarySideThreshold),
		float3 (boundarySideThreshold, boundaryTopThreshold, boundarySideThreshold),
		intersect,
		tStart,
		tEnd
	);

	if (intersect)
	{
		float3 step = d * (tEnd - tStart) / float(stepCount);
		p += d * tStart;

		for (int i = -3; i<stepCount + 3; i++)
		{
			if (BallTest(p))
			{
				return float4 ((RandColor(p)), 1.0);
			}

			p += step;
		}
	}
	return envTexture.Sample(ss, d) + float4(1, 1, 1, 0);

}



