#include "proximity.hlsli"

RWByteAddressBuffer buffer : register(u0);

[RootSignature(ProxySig)]
[numthreads(rowSize, nRowsPerPage, 1)]
void csClearBuffer( uint3 tid : SV_GroupThreadID, uint3 gid : SV_GroupID)
{
	buffer.Store((tid.x | (tid.y << 5) | (gid.x << 10)) << 2, 0xffffffff);
}