#include "metaball.hlsli"
#include "window.hlsli"

SamplerState ss;
TextureCube envTexture;

cbuffer metaballPSEyePosCB
{
	float4 eyePos;
};

cbuffer metaballVSTransCB {
	row_major float4x4 modelMatrix;
	row_major float4x4 modelViewProjMatrixInverse;
	row_major float4x4 modelViewProjMatrix;
	row_major float4x4 rayDirMatrix;
};

StructuredBuffer<Particle> particles;
Buffer<uint> offsetBuffer;
StructuredBuffer<uint> idBuffer;

bool MetaBallTest(float3 p)
{
	float acc = 0.0;
	for (int i = 0; i < particleCount; i++) {
		float3 diff = p - particles[i].position;

		acc += 1.0 / (dot(diff, diff) * metaBallRadius * metaBallRadius);
		if (acc > metaBallMinToHit)
		{
			return true;
		}
	}

	return false;
}

float3 Grad(float3 p) {
	float3 grad;

	for (int i = 0; i < particleCount; i++) {
		float3 diff = p - particles[i].position;
		float s2 = dot(diff, diff) * metaBallRadius * metaBallRadius;
		float s4 = s2*s2;
		grad += diff * -2.0 / s4;
	}

	return grad;
}

bool MetaBallTest_SBuffer(float3 p, float4 pos) {
	uint uIndex = (uint)pos.y * (uint)windowWidth + (uint)pos.x;

	uint startIdx;
	if (uIndex > 0) {
		startIdx = offsetBuffer[uIndex - 1];
	}
	else
	{
		startIdx = 0;
	}

	uint endIdx = offsetBuffer[uIndex];
	
	const float minToHit = 1.0;
	const float r = 0.005;

	float acc = 0.0;

	for (uint i = startIdx; i < endIdx; i++) {
		uint j = idBuffer[i];

		acc += pow((length(p - float3(particles[j].position)) / r), -2.0);
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

float3 Grad_SBuffer(float3 p, float4 pos) {
	uint uIndex = (uint)pos.y * (uint)windowWidth + (uint)pos.x;

	uint startIdx;
	if (uIndex > 0) {
		startIdx = offsetBuffer[uIndex - 1];
	}
	else
	{
		startIdx = 0;
	}

	uint endIdx = offsetBuffer[uIndex];

	float3 grad;
	const float r = 0.005;

	for (int i = startIdx; i < endIdx; i++) {
		uint j = idBuffer[i];
		float weight = (pow((-2.0*r), 2.0) / pow(length(p - float3(particles[j].position)), 3.0)) * ((-1.0) / (2.0*length(p - float3(particles[j].position))));
		grad.x += (weight * (p.x - particles[j].position.x));
		grad.y += (weight * (p.y - particles[j].position.y));
		grad.z += (weight * (p.z - particles[j].position.z));
	}

	return grad;
}

float4 psMetaballSBufferGradient(VsosQuad input) : SV_Target
{
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
		float3 step = d * (tEnd - tStart) / float(marchCount);
		p += d * tStart;

		for (int i = 0; i<marchCount; i++)
		{			
			if (MetaBallTest_SBuffer(p, input.pos))
			{
				return float4 (normalize(Grad_SBuffer(p, input.pos)), 1.0);
			}		

			p += step;
		}
	}
	return envTexture.Sample(ss, d);
}



