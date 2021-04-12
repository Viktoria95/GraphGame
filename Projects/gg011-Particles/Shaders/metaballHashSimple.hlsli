#include "metaball.hlsli"
#include "hash.hlsli"

RWByteAddressBuffer hlistBegin;
RWByteAddressBuffer hlistLength;
RWByteAddressBuffer clistBegin;
RWByteAddressBuffer clistLength;

bool MetaBallTest_HashSimple(float3 p, float4 pos, IMetaballTester metaballTester)
{
	
	float acc = 0.0;

	uint zIndex = mortonHash(p.xyz);
	uint zHash = zIndex % hashCount;
	//zHash = 11;

	uint cIdx = hlistBegin.Load(zHash * 4);
	uint cIdxMax = cIdx + hlistLength.Load(zHash * 4);
	cIdx = 0;
	cIdxMax = 2048;
	bool result = false;
	[loop]
	for (; cIdx < cIdxMax; cIdx++) {
		uint pIdx = clistBegin.Load(cIdx * 4);
		uint pIdxMax = pIdx + clistLength.Load(cIdx * 4);
		//pIdx = 0;
		//pIdxMax = 2048;
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

	return result;
	

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