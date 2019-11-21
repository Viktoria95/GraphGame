#include "billboard.hlsli"

RWByteAddressBuffer offsetBuffer;
RWStructuredBuffer<uint2> linkBuffer;

void psBillboardS(GsosBillboard input)
{
	//const float height = 593.0;
	//const float width = 1152.0;

	const float height = 720.0;
	const float width = 1280.0;

	// Read and update Start Offset Buffer.
	uint uIndex = (uint)input.pos.y * (uint)width + (uint)input.pos.x;
	uint uDest = 4 * uIndex;
	uint uOldValue;
	offsetBuffer.InterlockedAdd(uDest, 1, uOldValue);
}
