#include "metaball.hlsli"
#include "particle.hlsli"
#include "window.hlsli"

SamplerState ss;
TextureCube envTexture;

cbuffer metaballPSEyePosCB
{
	float4 eyePos;
};

StructuredBuffer<Particle> particles;

bool MetaBallTest(float3 p)
{
	const float minToHit = 0.9;
	const float r = 1.0/0.005;

	float acc = 0.0;

	for (int i = 0; i < particleCount; i++) {
		float3 diff = p - particles[i].position;

		acc += 1.0 / (dot(diff, diff) * r * r);
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

float3 Grad(float3 p) {
	float3 grad;
	const float r = 1.0/0.005;

	for (int i = 0; i < particleCount; i++) {
		float3 diff = p - particles[i].position;
		float s2 = dot(diff, diff) * r * r;
		float s4 = s2*s2;
		grad += diff * -2.0 / s4;
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

/*
float4 psMetaballNormal(VsosQuad input) : SV_Target
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
if (MetaBallTest(p))
{
return float4 (normalize(Grad(p)), 1.0);
}

p += step;
}
}
return envTexture.Sample(ss, d);
}
*/

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
	float Rp = (cosd - n * cosa) / (cosd +  n * cosa);
	Rp *= Rp;
	float fresnel = (Rs + Rp) / 2.0f;
	return saturate(fresnel);
}

float4 psMetaballNormalRealistic(VsosQuad input) : SV_Target
{
	const int stepCount = 20;
	const float boundarySideThreshold = boundarySide * 1.1;
	const float boundaryTopThreshold = boundaryTop * 1.1;
	const float boundaryBottomThreshold = boundaryBottom * 1.1;

	//const float refractionIndex = 1.5f;
	//const float kappa = 0.01;

	RayMarchHit stack[16];
	uint stackSize = 1;

	RayMarchHit firstElem;
	firstElem.position = eyePos;
	firstElem.direction = normalize(input.rayDir);
	firstElem.recursionDepth = 0;
	firstElem.alfa = 1.0;
	stack[0] = firstElem;

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
			bool startedInside = MetaBallTest(marchPos);
			float3 marchStep = marchDir * (tEnd - tStart) / float(stepCount);
			marchPos += marchDir * tStart;

			bool marchHit = false;
			for (int i = 0; i<stepCount && !marchHit; i++)
			{
				bool inside = MetaBallTest(marchPos);
				if (inside && !startedInside || !inside && startedInside)
				{
					marchHit = true;

					float3 normal = normalize(-Grad(marchPos));
					float refractiveIndex = 1.4;
					if (dot(normal, marchDir) > 0) {
						normal = -normal;
						refractiveIndex = 1.0 / refractiveIndex;
					}
					float fresnelAlfa = Fresnel(normalize(marchDir), normalize(normal), refractiveIndex);
					float reflectAlfa = fresnelAlfa * marchAlfa;
					float refractAlfa = (1.0 - fresnelAlfa) * marchAlfa;

					float3 refractDir = refract(marchDir, normal, 1.0 / refractiveIndex);
					
					//if (length(refractDir) < 0.01 && refractAlfa > 0.01)
					//{
					//	return float4(1.0, 0.0, 0.0, 1.0);
					//}

					if (reflectAlfa > 0.01)
					{
						RayMarchHit reflectElem;
						reflectElem.direction = reflect(marchDir, normal);
						reflectElem.position = marchPos + normal * 0.1;
						reflectElem.recursionDepth = marchRecursionDepth + 1;
						reflectElem.alfa =  reflectAlfa;
					
						stack[stackSize] = reflectElem;
						stackSize++;
					}

					if (refractAlfa > 0.01)
					{
						RayMarchHit refractElem;
						refractElem.direction = refractDir;
						refractElem.position = marchPos;// -normal * marchStep * 2.0;
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
				//color += float4(1, 1, 1, 1)/*envTexture.Sample(ss, marchDir)*/ * marchAlfa;
				color += envTexture.SampleLevel(ss, marchDir, 0) * marchAlfa;
			}
		}
		else
		{
			color += envTexture.SampleLevel(ss, marchDir, 0) * marchAlfa;
		}
	}

	if (killer == 0)
	{
		//return float4 (1.0, 0.0, 0.0, 1.0);
	}

	return float4 (color, 1.0);

}



