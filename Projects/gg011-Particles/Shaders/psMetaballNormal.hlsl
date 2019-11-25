#include "metaball.hlsli"
#include "particle.hlsli"

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
	const float r = 0.005;

	float acc = 0.0;

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

float3 Grad(float3 p) {
	float3 grad;
	const float r = 0.005;

	for (int i = 0; i < particleCount; i++) {
		float weight = (pow((-2.0*r), 2.0) / pow(length(p - float3(particles[i].position)), 3.0)) * ((-1.0) / (2.0*length(p - float3(particles[i].position))));
		grad.x += (weight * (p.x - particles[i].position.x));
		grad.y += (weight * (p.y - particles[i].position.y));
		grad.z += (weight * (p.z - particles[i].position.z));
	}

	return grad;
}

/*float SortColor (float3 p, float4 pos)
{
const float height = 593.0;
const float width = 1152.0;

uint uIndex = (uint)pos.y * (uint)width + (uint)pos.x;

uint offset = offsetBuffer[uIndex];

const float r = 0.005;

float intensity = 0.0;
int hitCount = 0;

while (offset != 0)
{
uint2 element = linkBuffer[offset];
offset = element.x;
int i = element.y;

if (length(p - float3(particles[i].position)) < r)
{
intensity += float(i);
hitCount++;
}
}

return intensity / hitCount / particleCount;
}*/

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

/*
vec3 Fresnel(vec3 inDir, vec3 normal, vec3 n, vec3 kappa)
{
	float cosa = -dot(inDir, normal);
	vec3 one = vec3(1.0, 1.0, 1.0);
	vec3 F0 = ((n - one)*(n - one) + kappa*kappa) /
		((n + one)*(n + one) + kappa*kappa);
	return F0 + (one - F0) * pow(1.0 - cosa, 5.0);
}
*/

float Fresnel(float3 inDir, float3 normal, float n, float kappa)
{
	float cosa = -dot(inDir, normal);
	float one = 1.0;
	float F0 = ((n - one)*(n - one) + kappa*kappa) / ((n + one)*(n + one) + kappa*kappa);
	return F0 + (one - F0) * pow(1.0 - cosa, 5.0);
}

float4 psMetaballNormal(VsosQuad input) : SV_Target
{
	const int stepCount = 20;
	const float boundarySideThreshold = boundarySide * 1.1;
	const float boundaryTopThreshold = boundaryTop * 1.1;
	const float boundaryBottomThreshold = boundaryBottom * 1.1;

	const float refractionIndex = 1.4f;
	const float kappa = 0.01;

	RayMarchHit stack[16];
	uint stackSize = 1;

	RayMarchHit firstElem;
	firstElem.position = eyePos;
	firstElem.direction = normalize(input.rayDir);
	firstElem.recursionDepth = 0;
	firstElem.alfa = 1.0;
	stack[0] = firstElem;

	float3 color = float3(0.0, 0.0, 0.0);
	uint killer = 32;
	[unroll (32)]
	while (stackSize > 0 && killer > 0)
	{
		killer--;

		stackSize--;
		float3 marchPos = stack[stackSize].position;
		float3 marchDir = stack[stackSize].direction;
		uint marchRecursionDepth = stack[stackSize].recursionDepth;
		float marchAlfa = stack[stackSize].alfa;;

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

		if (intersect)
		{
			float3 marchStep = marchDir * (tEnd - tStart) / float(stepCount);
			marchPos += marchDir * tStart;

			bool marchHit = false;
			for (int i = 0; i<stepCount && !marchHit; i++)
			{
				// From outside
				if (marchRecursionDepth % 2 == 0)
				{
					if (MetaBallTest(marchPos))
					{
						marchHit = true;

						float3 normal = normalize(-Grad(marchPos));

						RayMarchHit reflectElem;
						reflectElem.direction = reflect(marchDir, normal);
						reflectElem.position = marchPos + normal * 0.1;
						reflectElem.recursionDepth = marchRecursionDepth + 1;
						reflectElem.alfa = marchAlfa * Fresnel(marchDir, normal, refractionIndex, kappa);

						if (reflectElem.alfa > 0.01)
						{
							stack[stackSize] = reflectElem;
							stackSize++;
						}

						float3 refractDir = refract(marchDir, normal, refractionIndex);
						if (length(refractDir) < 0.1)
						{
							color += marchAlfa * (1.0 - Fresnel(marchDir, normal, refractionIndex, kappa)) * float3 (0.0, 1.0, 0.0);
						}
						else
						{
							RayMarchHit refractElem;
							refractElem.direction = refractDir;
							refractElem.position = marchPos - normal * 0.1;
							refractElem.recursionDepth = marchRecursionDepth + 1;
							refractElem.alfa = marchAlfa * (1.0 - Fresnel(marchDir, normal, refractionIndex, kappa));

							if (refractElem.alfa > 0.01)
							{
								stack[stackSize] = refractElem;
								stackSize++;
							}
						}

					}
				}
				// From inside
				else 
				{
					//color += marchAlfa * float3 (0.0, 0.0, 1.0);
					if (!MetaBallTest(marchPos))
					{
						marchHit = true;

						float3 normal = normalize(Grad(marchPos));

						RayMarchHit reflectElem;
						reflectElem.direction = reflect(marchDir, normal);
						reflectElem.position = marchPos + normal * 0.1;
						reflectElem.recursionDepth = marchRecursionDepth + 1;
						reflectElem.alfa = marchAlfa * Fresnel(marchDir, normal, 1.0 / refractionIndex, 1.0/ kappa);

						if (reflectElem.alfa > 0.01)
						{
							stack[stackSize] = reflectElem;
							stackSize++;
						}						

						float3 refractDir = refract(marchDir, normal, 1.0 / refractionIndex);
						if (length(refractDir) < 0.1)
						{
							color += marchAlfa * (1.0 - Fresnel(marchDir, normal, 1.0 / refractionIndex, 1.0 / kappa)) * float3 (0.0, 1.0, 0.0);
						}
						else
						{
							RayMarchHit refractElem;
							refractElem.direction = refractDir;
							refractElem.position = marchPos - normal * 0.1;
							refractElem.recursionDepth = marchRecursionDepth + 1;
							refractElem.alfa = marchAlfa * (1.0 - Fresnel(marchDir, normal,1.0/ refractionIndex, 1.0 / kappa));

							if (refractElem.alfa > 0.01)
							{
								stack[stackSize] = refractElem;
								stackSize++;
							}
						}

					}
				}
			
				marchPos += marchStep;
			}

			if (!marchHit)
			{
				color += envTexture.Sample(ss, marchDir) * marchAlfa;
			}
		}
		else
		{
			color += envTexture.Sample(ss, marchDir)  * marchAlfa;
		}
	}

	if (killer == 0)
	{
		return float4 (1.0, 0.0, 0.0, 1.0);
	}

	return float4 (color, 1.0);

}



