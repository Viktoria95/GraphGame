
#include "particle.hlsli"
#include "mortonHash.hlsli"

StructuredBuffer<float4> positions;
RWStructuredBuffer<uint> hashes;

[numthreads(1, 1, 1)]
void csMortonHash(uint3 DTid : SV_GroupID)
{
	unsigned int tid = DTid.x;
	hashes[tid] = mortonHash(positions[tid].xyz);
}


