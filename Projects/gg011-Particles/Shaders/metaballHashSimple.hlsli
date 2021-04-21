#include "metaball.hlsli"
#include "hash.hlsli"

RWByteAddressBuffer hlistBegin : register(u1);
RWByteAddressBuffer hlistLength : register(u2);
RWByteAddressBuffer clistBegin : register(u3);
RWByteAddressBuffer clistLength : register(u4);

bool MetaBallTest_HashSimple(float3 p, float4 pos, IMetaballTester metaballTester)
{
	
	float acc = 0.0;

	uint zIndex = mortonHash(p.xyz);
	uint zHash = zIndex % hashCount;

	uint cIdx = hlistBegin.Load(zHash * 4);
	uint cIdxMax = cIdx + hlistLength.Load(zHash * 4);
	bool result = false;
	[loop]
	for (; cIdx < cIdxMax; cIdx++) {
		uint pIdx = clistBegin.Load(cIdx * 4);
		uint pIdxMax = pIdx + clistLength.Load(cIdx * 4);
//		pIdx = 244;
//		pIdxMax = pIdx + 2;
		[loop]
		for (; pIdx < pIdxMax; pIdx++) {
//			if (metaballTester.testFunction(p, particles[pIdx].position, acc, acc) == true)
			float3 diff = (p - particles[pIdx].position) / (0.6 /*boundarysize*/ / 16.0 /*hash maxindex*/);
			float r2 = dot(diff, diff);
			if (r2 < 1.0) {
				float r4 = r2 * r2;
				float r6 = r4 * r2;
				acc += (-4.0 / 9.0) * r6 + (17.0 / 9.0) * r4 - (22.0 / 9.0) * r2 + 1;
				if (acc > 0.5)
				{
					result = true;
					pIdx = pIdxMax;
					cIdx = cIdxMax;
				}
			}
		}
	}
	return result;

	
/*	bool result = false;
	for (uint pIdx=0; pIdx < 2048; pIdx++) {
		if (metaballTester.testFunction(p, particles[pIdx].position, acc, acc) == true)
		{
			result = true;
			pIdx = 2048;
		}
	}
	return result;*/

	//uint zIndex = mortonHash(pos.xyz);
	//uint zHash = zIndex % hashCount;
	
	/*
	uint zHash = 0;
	bool result = false;
	[loop]
	for (; zHash < hashCount; zHash++) {
		float acc = 0.0;



		uint cIdx = hlistBegin.Load(zHash * 4);
		uint cIdxMax = cIdx + hlistLength.Load(zHash * 4);

		
		[loop]
		for (; cIdx < cIdxMax; cIdx++) {
			uint pIdx = clistBegin.Load(cIdx * 4);
			uint pIdxMax = pIdx + clistLength.Load(cIdx * 4);
			[loop]
			for (; pIdx < pIdxMax; pIdx++) {
				if (metaballTester.testFunction(p, particles[pIdx].position, acc, acc) == true)
				{
					result = true;
					pIdx = pIdxMax;
					cIdx = cIdxMax;
				}
			}
		}
	}
	return result;*/
	
	
}


float3 Grad_HashSimple(float3 p, float4 pos)
{
	float3 grad = float3 (0.0, 0.0, 0.0);
	/*
	uint zIndex = mortonHash(pos.xyz);
	uint zHash = zIndex % hashCount;

	uint cIdx = hlistBegin.Load(zHash * 4);
	uint cIdxMax = cIdx + hlistLength.Load(zHash * 4);
	for (; cIdx < cIdxMax; cIdx++) {
		uint pIdx = clistBegin.Load(cIdx * 4);
		uint pIdxMax = pIdx + clistLength.Load(cIdx * 4);
		for (; pIdx < pIdxMax; pIdx++) {
			grad = calculateGrad(p, particles[pIdx].position, grad);
		}
	}
	*/
	return grad;	
}

class HashSimpleMetaballVisualizer : IMetaballVisualizer
{
	bool callMetaballTestFunction(float3 p, float4 pos)
	{
		if (functionType == 2)
		{
			WyvillMetaballTester wyvillMetaballTester;
			return MetaBallTest_HashSimple(p, pos, wyvillMetaballTester);
		}
		if (functionType == 3)
		{
			NishimuraMetaballTester nishimuraMetaballTester;
			return MetaBallTest_HashSimple(p, pos, nishimuraMetaballTester);
		}
		if (functionType == 4)
		{
			MurakamiMetaballTester murakamiMetaballTester;
			return MetaBallTest_HashSimple(p, pos, murakamiMetaballTester);
		}
		SimpleMetaballTester simpleMetaballTester;
		return MetaBallTest_HashSimple(p, pos, simpleMetaballTester);
	}

	float3 callGradientCalculator(float3 p, float4 pos)
	{
		return Grad_HashSimple(p, pos);
	}

	float3 doBinarySearch(bool startInside, float3 startPos, bool endInside, float3 endPos, float4 pos)
	{
		HashSimpleMetaballVisualizer hashMetaballVisualizer;

		return BinarySearch(startInside, startPos, endInside, endPos, pos, hashMetaballVisualizer);
	}
};