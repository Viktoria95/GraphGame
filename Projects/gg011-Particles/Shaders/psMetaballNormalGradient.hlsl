#include "metaball.hlsli"
#include "window.hlsli"

SamplerState ss;
TextureCube envTexture;

cbuffer metaballPSEyePosCB
{
	float4 eyePos;
};

StructuredBuffer<Particle> particles;

//Wyvill
bool MetaBallTest_W(float3 p)
{
	float acc = 0.0;
	float r = 0.0;
	float a = 1.1;
	float b = 0.015;

	for (int i = 0; i < particleCount; i++) {
		float3 diff = p - particles[i].position;
		r = sqrt(dot(diff, diff));

		float res = 1 - (4 * pow(r, 6) / (9 * pow(b, 6))) + (17 * pow(r, 4) / (9 * pow(b, 4))) - (22 * pow(r, 2) / 9 * pow(b, 2));

		if (r < b) {
			acc += a*res;
		}

		if (acc > metaBallMinToHit)
		{
			return true;
		}
	}

	return false;
}

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

float3 BinarySearch(bool startInside, float3 startPos, bool endInside, float3 endPos)
{
	float3 newStart = startPos;
	float3 newEnd = endPos;

	int i;
	for (i = 0; i < binaryStepCount; i++)
	{
		float3 mid = (startPos + endPos) / 2.0;
		bool midInside = MetaBallTest_W(mid);
		if (midInside == startInside)
		{
			newStart = mid;
		}
		if (midInside == endInside)
		{
			newEnd = mid;
		}
	}

	return newEnd;
}

float4 psMetaballNormalGradient(VsosQuad input) : SV_Target
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
			if (MetaBallTest_W(p))
			{
				p = BinarySearch(false, p - step, true, p);
				return float4 (normalize(Grad(p)), 1.0);
			}

			p += step;
		}
	}

	return envTexture.Sample(ss, d);
}



