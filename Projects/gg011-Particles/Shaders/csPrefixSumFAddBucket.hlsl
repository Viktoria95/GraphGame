
#include "particle.hlsli"

RWByteAddressBuffer offsetBuffer;
RWByteAddressBuffer resultBuffer;

#define groupthreads 256

// scan in each bucket
[numthreads(groupthreads, 1, 1)]
void csPrefixSumFAddBucket(uint3 DTid : SV_DispatchThreadID, uint3 GTid : SV_GroupThreadID, uint GI : SV_GroupIndex, uint3 Gid : SV_GroupID)
{
	uint prevResult = 0;
	if (GI != 0) {
		prevResult = resultBuffer.Load((GI - 1) * 4);
	}	
	uint temp;
	offsetBuffer.InterlockedAdd(DTid.x * 4, prevResult, temp);
}