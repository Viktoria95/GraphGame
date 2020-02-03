#include "metaball.hlsli"
#include "particle.hlsli"
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

struct RayMarchHit
{
	float3 position;
	float3 direction;
	uint recursionDepth;
	float alfa;
};


float Fresnel(float3 inDir, float3 normal, float n)
{
	float cosa = abs(dot(-inDir, normal));	// 1
	float sina = sqrt(1 - cosa * cosa);		// 0
	float disc = 1 - sina * sina / (n*n);	// 1
	if (disc < 0) return 1;
	float cosd = sqrt(disc);				// 1
	float Rs = (cosa - n * cosd) / (cosa + n * cosd); // -0.2/2.2
	Rs *= Rs;
	float Rp = (cosd - n * cosa) / (cosd + n * cosa);
	Rp *= Rp;
	float fresnel = (Rs + Rp) / 2.0f;
	return saturate(fresnel);
}

float4 psMetaballABufferRealistic(VsosQuad input) : SV_Target
{
	const int stepCount = 20;
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

	float4 screenPosition = input.pos;

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
			bool startedInside = MetaBallTest_ABuffer(marchPos, screenPosition);
			float3 marchStep = marchDir * (tEnd - tStart) / float(stepCount);
			marchPos += marchDir * tStart;

			bool marchHit = false;
			for (int i = 0; i<stepCount && !marchHit; i++)
			{
				bool inside = MetaBallTest_ABuffer(marchPos, screenPosition);
				
				if (inside && !startedInside || !inside && startedInside)
				{
					marchHit = true;

					//screenPosition = mul(float4(marchPos, 1), modelViewProjMatrixInverse);

					float3 normal = normalize(-Grad_ABuffer(marchPos, screenPosition));
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



