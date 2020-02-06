
#include "particle.hlsli"

#define metaBallRadius 1.0 / 0.005
#define metaBallMinToHit 0.9
#define marchCount 20


struct IaosQuad
{
	float4  pos: POSITION;
	float2  tex: TEXCOORD0;
};

struct VsosQuad
{
	float4 pos: SV_POSITION;
	float2 tex: TEXCOORD0;
	float3 rayDir: TEXCOORD1;
};

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


