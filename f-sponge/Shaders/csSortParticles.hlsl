#include "particle.hlsli"

RWByteAddressBuffer sortedPins;
StructuredBuffer<float4> olds;
RWStructuredBuffer<float4> news;

[numthreads(32, 32, 1)]
void csSortParticles( uint3 DTid : SV_DispatchThreadID )
{
	uint tid = DTid.x;
	uint i = sortedPins.Load(tid << 2);

	news[i] = olds[tid];
}