#include "particle.hlsli"

RWByteAddressBuffer offsetBuffer;
RWByteAddressBuffer resultBuffer;

#define groupthreads 512

// add the bucket scanned result to each bucket to get the final result
[numthreads(groupthreads, 1, 1)]
void csScanAddBucketResult2(uint3 Gid : SV_GroupID, uint3 DTid : SV_DispatchThreadID, uint3 GTid : SV_GroupThreadID, uint GI : SV_GroupIndex)
{
	uint temp;
	uint i = resultBuffer.Load((512 + Gid.x) * 4);
	offsetBuffer.InterlockedAdd((DTid.x + (512 * 512) + 1) * 4, i, temp);
}
