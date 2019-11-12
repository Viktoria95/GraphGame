
#include "particle.hlsli"

RWByteAddressBuffer offsetBuffer;
RWByteAddressBuffer resultBuffer;

#define groupthreads 256

// scan in each bucket
[numthreads(groupthreads, 1, 1)]
void csPrefixSumF(uint3 DTid : SV_DispatchThreadID, uint3 GTid : SV_GroupThreadID, uint GI : SV_GroupIndex, uint3 Gid : SV_GroupID)
{
	// egyszamlalos megvalositas
	/*uint x = offsetBuffer.Load(DTid.x * 4);

	uint prev;
	resultBuffer.InterlockedAdd(0, x, prev);

	uint2 element;
	element.x = x;
	element.y = prev;

	uint2 temp;
	offsetBuffer.InterlockedExchange(DTid.x * 4, element, temp);*/
}