#include "window.hlsli"
#include "particle.hlsli"

//#define metaBallRadius 1.0 / 0.005
#define metaBallRadius 1.0 / 0.005
#define metaBallMinToHit 0.9
#define marchCount 25
#define binaryStepCount 3

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

struct RayMarchHit
{
	float3 position;
	float3 direction;
	uint recursionDepth;
	float alfa;
};

interface IMetaballVisualizer
{
	bool callMetaballTestFunction(float3 p, float4 pos);
	float3 callGradientCalculator(float3 p, float4 pos);
	float3 getDiffuseColor(float3 p, float4 pos, float ambientIntensity, float3 lightDir, float3 surfaceColor, float3 lightColor);
	float3 doBinarySearch(bool startInside, float3 startPos, bool endInside, float3 endPos, float4 pos);
};

interface IMetaballTester
{
	bool testFunction(float3 p, float3 position, float acc, out float accOut);
};

class SimpleMetaballTester : IMetaballTester
{
	bool testFunction(float3 p, float3 position, float acc, out float accOut)
	{
		float3 diff = p - position;
		accOut = acc + (1.0 / (dot(diff, diff) * metaBallRadius * metaBallRadius));
		if (accOut > metaBallMinToHit)
		{
			return true;
		}
		return false;
	}
};

class WyvillMetaballTester : IMetaballTester
{
	bool testFunction(float3 p, float3 position, float acc, out float accOut)
	{
		float r = 0.0;
		float a = 1.1;
		float b = 0.015;

		float3 diff = p - position;
		r = sqrt(dot(diff, diff));

		float res = 1 - (4 * pow(r, 6) / (9 * pow(b, 6))) + (17 * pow(r, 4) / (9 * pow(b, 4))) - (22 * pow(r, 2) / 9 * pow(b, 2));

		if (r < b) {
			accOut = acc + a*res;
		}

		if (accOut > metaBallMinToHit)
		{
			return true;
		}

		return false;
	}
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

float3 FresnelForMetals(float3 inDir, float3 normal, float3 n, float3 k)
{
	float cosTheta = abs(dot(-inDir, normal));
	float3 one = float3(1.0, 1.0, 1.0);

	return ((n-one*n-one) + 4.0*n*pow(1.0 - cosTheta, 5.0) + k*k) / ((n+one)*(n+one) + k*k);
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

// Metaball test functions

bool MetaBallTest(float3 p, IMetaballTester metaballTester)
{
	float acc = 0.0;
	for (int i = 0; i < particleCount; i++) {
		if (metaballTester.testFunction(p, particles[i].position, acc, acc) == true)
		{
			return true;
		}
	}

	return false;
}

// Gradient calculator funtions

float3 calculateGrad(float3 p, float3 position, float3 grad)
{
	float3 gradOut = grad;
	float weight = (pow((-2.0*metaBallRadius), 2.0) / pow(length(p - float3(position)), 3.0)) * ((-1.0) / (2.0*length(p - float3(position))));
	gradOut.x += (weight * (p.x - position.x));
	gradOut.y += (weight * (p.y - position.y));
	gradOut.z += (weight * (p.z - position.z));

	return gradOut;
}

float3 Grad(float3 p) {
	float3 grad;

	for (int i = 0; i < particleCount; i++) {
		grad = calculateGrad(p, particles[i].position, grad);
	}

	return grad;
}

// Binary search functions

float3 BinarySearch(bool startInside, float3 startPos, bool endInside, float3 endPos, float4 inputPos, IMetaballVisualizer metaballVisualizer)
{
	float3 newStart = startPos;
	float3 newEnd = endPos;

	int i;
	for (i = 0; i < binaryStepCount; i++)
	{
		float3 mid = (startPos + endPos) / 2.0;
		bool midInside = metaballVisualizer.callMetaballTestFunction(mid, inputPos);
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

// Visualizers

class NormalMetaballVisualizer : IMetaballVisualizer
{
	bool callMetaballTestFunction(float3 p, float4 pos)
	{
		WyvillMetaballTester wyvillMetaballTester;

		return MetaBallTest(p, wyvillMetaballTester);
	}

	float3 callGradientCalculator(float3 p, float4 pos)
	{
		return Grad(p);
	}

	float3 getDiffuseColor(float3 p, float4 pos, float ambientIntensity, float3 lightDir, float3 surfaceColor, float3 lightColor)
	{
		float3 normal = normalize(Grad(p));
		return surfaceColor * (ambientIntensity * lightColor + max(dot(normal, lightDir), 0.0) * lightColor);
	}

	float3 doBinarySearch(bool startInside, float3 startPos, bool endInside, float3 endPos, float4 pos)
	{
		NormalMetaballVisualizer normalMetaballVisualizer;

		return BinarySearch(startInside, startPos, endInside, endPos, pos, normalMetaballVisualizer);
	}
};

float4 CalculateColor_Gradient(float3 rayDir, float4 pos, IMetaballVisualizer metaballVisualizer)
{
	float ambientIntensity = 0.7;
	float3 lightDir = float3(1.0, 0.0, 0.0);
	float3 surfaceColor = float3(0.22745,  0.20000,  0.20000);
	float3 lightColor = float3(1.0, 1.0, 1.0);

	float3 goldEta = float3(0.17, 0.38, 1.5);
	float3 goldKappa = float3(3.7, 2.45, 1.85);

	float3 copperEta = float3(0.11, 0.8, 1.07);
	float3 copperKappa = float3(3.9, 2.72, 2.5);

	float3 aluminiumEta = float3(1.49, 1.02, 0.558);
	float3 aluminiumKappa = float3(7.82, 6.85, 5.2);

	float tStart, tEnd;
	float3 p = eyePos;
	float3 d = normalize(rayDir);

	const float boundarySideThreshold = boundarySide * 1.1;
	const float boundaryTopThreshold = boundaryTop * 1.1;
	const float boundaryBottomThreshold = boundaryBottom * 1.1;

	bool intersect;
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
			if (metaballVisualizer.callMetaballTestFunction(p, pos))
			{
				p = metaballVisualizer.doBinarySearch(false, p - step, true, p, pos);
				float3 normal = normalize(metaballVisualizer.callGradientCalculator(p, pos));
				float3 ref = reflect(normalize(rayDir), normal);
				
				float3 fresnel = FresnelForMetals(normalize(rayDir), normal, goldEta, goldKappa);
				float3 envColor = envTexture.SampleLevel(ss, ref, 0);
				//return float4(metaballVisualizer.getDiffuseColor(p, pos, ambientIntensity, lightDir, surfaceColor, lightColor), 1.0);
				//return float4(fresnel * envColor, 1.0);
				return float4(normalize(metaballVisualizer.callGradientCalculator(p, pos)), 1.0);
			}

			p += step;
		}
	}

	return envTexture.Sample(ss, d);
}

float4 CalculateColor_Realistic(float3 rayDir, float4 pos, IMetaballVisualizer metaballVisualizer)
{

	const float boundarySideThreshold = boundarySide * 1.1;
	const float boundaryTopThreshold = boundaryTop * 1.1;
	const float boundaryBottomThreshold = boundaryBottom * 1.1;

	RayMarchHit firstElem;
	firstElem.position = eyePos;
	firstElem.direction = normalize(rayDir);
	firstElem.recursionDepth = 0;
	firstElem.alfa = 1.0;

	RayMarchHit stack[16];
	uint stackSize = 1;
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

		float tStart, tEnd;
		bool intersect;
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
			bool startedInside = metaballVisualizer.callMetaballTestFunction(marchPos, pos);
			float3 start = marchPos;
			float3 marchStep = marchDir * (tEnd - tStart) / float(marchCount);
			marchPos += marchDir * tStart;

			bool marchHit = false;
			for (int i = 0; i<marchCount && !marchHit; i++)
			{
				bool inside = metaballVisualizer.callMetaballTestFunction(marchPos, pos);
				if (inside && !startedInside || !inside && startedInside)
				{
					marchHit = true;
					marchPos = metaballVisualizer.doBinarySearch(startedInside, start, inside, marchPos, pos);

					float distance = length(marchPos - stack[stackSize].position);
					float i0 = startedInside ? exp(-distance * 0.0000000001) : 0.0;
					i0 = 0.0f;
					//i0 = 0.0;

					float3 normal = normalize(-metaballVisualizer.callGradientCalculator(marchPos, pos));
					float refractiveIndex = 1.4;
					if (dot(normal, marchDir) > 0) {
						normal = -normal;
						refractiveIndex = 1.0 / refractiveIndex;
					}
					float fresnelAlfa = Fresnel(normalize(marchDir), normalize(normal), refractiveIndex);
					float reflectAlfa = fresnelAlfa * marchAlfa * (1.0-i0);
					float refractAlfa = (1.0 - fresnelAlfa) * marchAlfa * (1.0 - i0);

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
