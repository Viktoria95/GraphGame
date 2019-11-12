#include "billboard.hlsli"
#include "metaball.hlsli"

RWByteAddressBuffer offsetBuffer;
RWByteAddressBuffer resultBuffer;

void psPrefixSum(VsosQuad input)
{

	uint uIndex = (uint)input.pos.y * (uint)windowWidth + (uint)input.pos.x;

	uint groupIndex = 0;

	uint x = offsetBuffer.Load(uIndex * 4);

	uint temp, temp2;
	resultBuffer.InterlockedAdd(0, x, temp);
	offsetBuffer.InterlockedExchange(uIndex * 4, temp, temp2);

}
