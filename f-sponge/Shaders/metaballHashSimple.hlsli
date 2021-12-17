#include "metaball.hlsli"
//to12 #include "hash.hlsli"
#include "hhash.hlsli"

//to12 StructuredBuffer<uint> hashes;
//to12 RWByteAddressBuffer hlistBegin;
//to12 RWByteAddressBuffer hlistLength;
//to12 RWByteAddressBuffer clistBegin;
//to12 RWByteAddressBuffer clistLength;
ByteAddressBuffer hashes;
RWByteAddressBuffer cellLut;
RWByteAddressBuffer hashLut;

bool MetaBallTest_HashSimple(float3 p, IMetaballTester metaballTester)
{
	float2 pos = WorldToScreen(p);

	bool result = false;
	float acc = 0.0;

	//uint zHash = 0;

	const float displacementStep = 0.08;
	const int displacementDist = 1;

	int xDis;
	int yDis;
	int zDis;
	[loop]
	for (xDis = -displacementDist; xDis <= displacementDist; xDis++) {
		[loop]
		for (yDis = -displacementDist; yDis <= displacementDist; yDis++) {
			[loop]
			for (zDis = -displacementDist; zDis <= displacementDist; zDis++) {
				float3 testp = p.xyz + displacementStep * float3(float(xDis), float(yDis), float(zDis));

				uint zIndex = mortonHash(testp);
				uint zHash = hhash(zIndex);// % hashCount;

				//zHash = 0;

				uint hl = hashLut.Load(zHash * 4);
				uint cIdx = hl & 0xffff; //to12 hlistBegin.Load(zHash * 4);
				uint cIdxMax = cIdx + (hl >> 16);//to12cIdx + hlistLength.Load(zHash * 4);

				[loop]
				for (; cIdx < cIdxMax; cIdx++) {
					//to12 uint pIdx = clistBegin.Load(cIdx * 4);
					//to12 uint pIdxMax = pIdx + clistLength.Load(cIdx * 4);
					uint cl = cellLut.Load(cIdx * 4);
					uint pIdx = cl & 0xffff; //to12 hlistBegin.Load(zHash * 4);
					uint pIdxMax = pIdx + ( cl >> 16);//to12cIdx + hlistLength.Load(zHash * 4);

					[loop]
					for (; pIdx < pIdxMax; pIdx++) {
						//if (hashes.Load(pIdx*4) == zIndex) 
						{
							//acc += 0.0001; //to12 *(hlistBegin.Load(0) + hlistLength.Load(0) + clistBegin.Load(0) + clistLength.Load(0));
							if (metaballTester.testFunction(p, positions[pIdx].xyz, acc, acc) == true)
							{
								result = true;
								pIdx = pIdxMax;
								cIdx = cIdxMax;
								xDis = displacementDist;
								yDis = displacementDist;
								zDis = displacementDist;
							}
						}
					}
				}
			}
		}
	}

	return result;
}


float3 Grad_HashSimple(float3 p)
{
	float2 pos = WorldToScreen(p);

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
	/*
	const float displacementStep = 0.08;
	int displacementDist = 1;

	int xDis;
	int yDis;
	int zDis;
	[loop]
	for (xDis = -displacementDist; xDis <= displacementDist; xDis++) {
		[loop]
		for (yDis = -displacementDist; yDis <= displacementDist; yDis++) {
			[loop]
			for (zDis = -displacementDist; zDis <= displacementDist; zDis++) {

				float3 testp = p.xyz + displacementStep * float3(float(xDis), float(yDis), float(zDis));

				uint zIndex = mortonHash(testp);
				uint zHash = zIndex % hashCount;


				uint cIdx = hlistBegin.Load(zHash * 4);
				uint cIdxMax = cIdx + hlistLength.Load(zHash * 4);

				[loop]
				for (; cIdx < cIdxMax; cIdx++) {
					uint pIdx = clistBegin.Load(cIdx * 4);
					uint pIdxMax = pIdx + clistLength.Load(cIdx * 4);

					[loop]
					for (; pIdx < pIdxMax; pIdx++) {
						grad.x += 0.0001 * (hlistBegin.Load(0) + hlistLength.Load(0) + clistBegin.Load(0) + clistLength.Load(0));
						grad = calculateGrad(p, particles[pIdx].position, grad);
					}
				}
			}
		}
	}
	*/

	const float displacementStep = 0.08;
	const int displacementDist = 1;

	int xDis;
	int yDis;
	int zDis;
	[loop]
	for (xDis = -displacementDist; xDis <= displacementDist; xDis++) {
		[loop]
		for (yDis = -displacementDist; yDis <= displacementDist; yDis++) {
			[loop]
			for (zDis = -displacementDist; zDis <= displacementDist; zDis++) {
				float3 testp = p.xyz + displacementStep * float3(float(xDis), float(yDis), float(zDis));

				uint zIndex = mortonHash(testp);
				uint zHash = hhash(zIndex);//% hashCount;

				//zHash = 0;

				uint hl = 0x00010000;//hashLut.Load(zHash * 4);
				uint cIdx = hl & 0xffff; //to12 hlistBegin.Load(zHash * 4);
				uint cIdxMax = cIdx + (hl >> 16);//to12cIdx + hlistLength.Load(zHash * 4);

				//to12 uint cIdx = hlistBegin.Load(zHash * 4);
				//to12 uint cIdxMax = cIdx + hlistLength.Load(zHash * 4);

				[loop]
				for (; cIdx < cIdxMax; cIdx++) {
//					uint pIdx = clistBegin.Load(cIdx * 4);
//					uint pIdxMax = pIdx + clistLength.Load(cIdx * 4);
					uint cl = cellLut.Load(cIdx * 4);
					uint pIdx = cl & 0xffff; //to12 hlistBegin.Load(zHash * 4);
					uint pIdxMax = pIdx + (cl >> 16);//to12cIdx + hlistLength.Load(zHash * 4);

					[loop]
					for (; pIdx < pIdxMax; pIdx++) {
						//acc += 0.0001 * (hlistBegin.Load(0) + hlistLength.Load(0) + clistBegin.Load(0) + clistLength.Load(0));
						//if (metaballTester.testFunction(p, particles[pIdx].position, acc, acc) == true)
						//if (hashes.Load(pIdx*4) == zIndex) 
						{
							grad = calculateGrad(p, positions[pIdx].xyz, grad);
						}
							//result = true;
							//pIdx = pIdxMax;
							//cIdx = cIdxMax;
							//xDis = displacementDist;
							//yDis = displacementDist;
							//zDis = displacementDist;

					}
				}
			}
		}
	}

	return grad;
}

class HashSimpleMetaballVisualizer : IMetaballVisualizer
{
	bool callMetaballTestFunction(float3 p)
	{
		if (functionType == 2)
		{
			WyvillMetaballTester wyvillMetaballTester;
			return MetaBallTest_HashSimple(p, wyvillMetaballTester);
		}
		if (functionType == 3)
		{
			NishimuraMetaballTester nishimuraMetaballTester;
			return MetaBallTest_HashSimple(p, nishimuraMetaballTester);
		}
		if (functionType == 4)
		{
			MurakamiMetaballTester murakamiMetaballTester;
			return MetaBallTest_HashSimple(p, murakamiMetaballTester);
		}
		SimpleMetaballTester simpleMetaballTester;
		return MetaBallTest_HashSimple(p, simpleMetaballTester);
	}

	float3 callGradientCalculator(float3 p)
	{
		return Grad_HashSimple(p);
	}

	float3 doBinarySearch(bool startInside, float3 startPos, bool endInside, float3 endPos)
	{
		HashSimpleMetaballVisualizer hashMetaballVisualizer;

		return BinarySearch(startInside, startPos, endInside, endPos, hashMetaballVisualizer);
	}
};