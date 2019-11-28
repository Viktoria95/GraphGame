#include "billboard.hlsli"

RWByteAddressBuffer offsetBuffer;

void psBillboardS1(GsosBillboard input)
{
	const float height = 720.0;
	const float width = 1280.0;

	uint uIndex = (uint)input.pos.y * (uint)width + (uint)input.pos.x;
	uint uDest = 4 * uIndex;
	uint uOldValue;
	offsetBuffer.InterlockedAdd(uDest, 1, uOldValue);
}
