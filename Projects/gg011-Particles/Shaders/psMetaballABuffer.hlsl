#include "metaball.hlsli"
#include "particle.hlsli"

SamplerState ss;
TextureCube envTexture;

cbuffer metaballPSEyePosCB
{
	float4 eyePos;
};

StructuredBuffer<Particle> particles;
Buffer<uint> offsetBuffer;
StructuredBuffer<uint2> linkBuffer;

bool MetaBallTest_ABuffer(float3 p, float4 pos)
{
	const float minToHit = 1.0;
	const float r = 0.005;

	uint uIndex = (uint)pos.y * (uint)windowWidth + (uint)pos.x;

	uint offset = offsetBuffer[uIndex];

	float acc = 0.0;

	while (offset != 0)
	{
		uint2 element = linkBuffer[offset];
		offset = element.x;
		int i = element.y;

		acc += pow((length(p - float3(particles[i].position)) / r), -2.0);
		if (acc > minToHit)
		{
			return true;
		}
	}

	return false;
}

bool MetaBallTest(float3 p)
{
	const float minToHit = 0.9;
	const float r = 0.005;

	float acc = 1.0;

	for (int i = 0; i < particleCount; i++) {
		acc += pow((length(p - float3(particles[i].position)) / r), -2.0);
		if (acc > minToHit)
		{
			return true;
		}
	}

	return false;
}

bool BallTest(float3 p)
{
	const float r = 0.005;

	for (int i = 0; i < particleCount; i++)
	{
		if (length(p - float3(particles[i].position)) < r)
		{
			return true;
		}
	}

	return false;
}

float3 Grad_ABuffer(float3 p, float4 pos)
{
	float3 grad;
	const float r = 0.005;

	uint uIndex = (uint)pos.y * (uint)windowWidth + (uint)pos.x;

	uint offset = offsetBuffer[uIndex];

	while (offset != 0)
	{
		uint2 element = linkBuffer[offset];
		offset = element.x;
		int i = element.y;

		float weight = (pow((-2.0*r), 2.0) / pow(length(p - float3(particles[i].position)), 3.0)) * ((-1.0) / (2.0*length(p - float3(particles[i].position))));
		grad.x += (weight * (p.x - particles[i].position.x));
		grad.y += (weight * (p.y - particles[i].position.y));
		grad.z += (weight * (p.z - particles[i].position.z));

	}

	return grad;
}

uint Offset_ABuffer(float4 pos)
{
	float3 grad;
	const float r = 0.005;

	uint uIndex = (uint)pos.y * (uint)windowWidth + (uint)pos.x;

	uint offset = offsetBuffer[uIndex];
	return offset;
}

uint OffsetSecond_ABuffer(float4 pos)
{
	float3 grad;
	const float r = 0.005;

	uint uIndex = (uint)pos.y * (uint)windowWidth + (uint)pos.x;

	uint offset = offsetBuffer[uIndex];
	uint2 element = linkBuffer[offset];

	return element.x;
}

uint Length_ABuffer(float4 pos)
{
	uint uIndex = (uint)pos.y * (uint)windowWidth + (uint)pos.x;

	uint offset = offsetBuffer[uIndex];
	uint length = 0;

	while (offset != 0)
	{
		uint2 element = linkBuffer[offset];
		offset = element.x;
		int i = element.y;
		length++;
	}

	return length;
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

float4 psMetaballABuffer(VsosQuad input) : SV_Target
{
	const int stepCount = 10;
	const float boundarySideThreshold = boundarySide * 1.1;
	const float boundaryTopThreshold = boundaryTop * 1.1;
	const float boundaryBottomThreshold = boundaryBottom * 1.1;

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

		for (int i = 0; i<stepCount; i++)
		{
			if (MetaBallTest_ABuffer(p, input.pos))
			{
				return float4 (normalize(Grad_ABuffer(p, input.pos)), 1.0);
			}
			
			p += step;
		}
	}
	return envTexture.Sample(ss, d);
}



