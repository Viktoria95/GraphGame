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

bool MetaBallTest_SBuffer(float3 p, float2 pos) {
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

float3 Grad_SBuffer(float3 p, float2 pos) {
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

float2 WorldToNDC(float3 wp)
{
	float4 worldPos = mul(float4(wp, 1.0), modelViewProjMatrix);
	worldPos /= worldPos.w;
	float2 screenPos = float2(0.0, 0.0);
	screenPos.x = ((worldPos.x + 1.0)*windowWidth) / 2.0;
	screenPos.y = ((worldPos.y - 1.0)*windowHeight) / -2.0;
	return screenPos;
}

float3 BinarySearch(bool startInside, float3 startPos, bool endInside, float3 endPos, float2 inputPos)
{
	float3 newStart = startPos;
	float3 newEnd = endPos;

	int i;
	for (i = 0; i < 3; i++)
	{
		float3 mid = (startPos + endPos) / 2.0;
		bool midInside = MetaBallTest_SBuffer(mid, inputPos);
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

float4 psMetaballSBufferRealistic(VsosQuad input) : SV_Target
{
	const float boundarySideThreshold = boundarySide * 1.1;
	const float boundaryTopThreshold = boundaryTop * 1.1;
	const float boundaryBottomThreshold = boundaryBottom * 1.1;

	RayMarchHit stack[16];
	uint stackSize = 1;

	RayMarchHit firstElem;
	firstElem.position = eyePos;
	firstElem.direction = normalize(input.rayDir);
	firstElem.recursionDepth = 0;
	firstElem.alfa = 1.0;
	stack[0] = firstElem;

	float2 screenPosition = input.pos.xy;

	float3 color = float3(0.0, 0.0, 0.0);
	uint killer = 10;
	[loop]
	while (stackSize > 0 && killer > 0)
	{
		killer--;

		stackSize--;
		float3 marchPos = stack[stackSize].position;
		float3 marchDir = stack[stackSize].direction;
		uint marchRecursionDepth = stack[stackSize].recursionDepth;
		float marchAlfa = stack[stackSize].alfa;

		bool intersect;
		float tStart;
		float tEnd;
		BoxIntersect
		(
			marchPos,
			marchDir,
			float3 (-boundarySideThreshold, boundaryBottomThreshold, -boundarySideThreshold),
			float3 (boundarySideThreshold, boundaryTopThreshold, boundarySideThreshold),
			intersect,
			tStart,
			tEnd
		);

		if (intersect && marchRecursionDepth < 4)
		{
			bool startedInside = MetaBallTest_SBuffer(marchPos, screenPosition);
			float3 start = marchPos;
			float3 marchStep = marchDir * (tEnd - tStart) / float(marchCount);
			marchPos += marchDir * tStart;

			bool marchHit = false;
			for (int i = 0; i<marchCount && !marchHit; i++)
			{
				bool inside = MetaBallTest_SBuffer(marchPos, screenPosition);

				if (inside && !startedInside || !inside && startedInside)
				{
					marchHit = true;
					marchPos = BinarySearch(startedInside, start, inside, marchPos, screenPosition);

					screenPosition.xy = WorldToNDC(marchPos);

					float3 normal = normalize(-Grad_SBuffer(marchPos, screenPosition));
					float refractiveIndex = 1.4;
					if (dot(normal, marchDir) > 0) {
						normal = -normal;
						refractiveIndex = 1.0 / refractiveIndex;
					}
					float fresnelAlfa = Fresnel(normalize(marchDir), normalize(normal), refractiveIndex);
					float reflectAlfa = fresnelAlfa * marchAlfa;
					float refractAlfa = (1.0 - fresnelAlfa) * marchAlfa;

					float3 refractDir = refract(marchDir, normal, 1.0 / refractiveIndex);

					if (reflectAlfa > 0.01)
					{
						RayMarchHit reflectElem;
						reflectElem.direction = reflect(marchDir, normal);
						reflectElem.position = marchPos + normal * 0.1;
						reflectElem.recursionDepth = marchRecursionDepth + 1;
						reflectElem.alfa = reflectAlfa;

						stack[stackSize] = reflectElem;
						stackSize++;
					}

					if (refractAlfa > 0.01)
					{
						RayMarchHit refractElem;
						refractElem.direction = refractDir;
						refractElem.position = marchPos;
						refractElem.recursionDepth = marchRecursionDepth + 1;
						refractElem.alfa = refractAlfa;

						stack[stackSize] = refractElem;
						stackSize++;
					}
				}

				marchPos += marchStep;
			}

			if (!marchHit)
			{
				color += envTexture.SampleLevel(ss, marchDir, 0) * marchAlfa;
			}
		}
		else
		{
			color += envTexture.SampleLevel(ss, marchDir, 0) * marchAlfa;
		}
	}

	return float4 (color, 1.0);
}



