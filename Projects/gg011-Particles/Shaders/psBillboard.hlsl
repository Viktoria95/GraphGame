#include "billboard.hlsli"

RWByteAddressBuffer offsetBuffer;
RWStructuredBuffer<uint2> linkBuffer;

void doABuffer(GsosBillboard input)
{
	// Increment and get current pixel count.
	uint uPixelCount = linkBuffer.IncrementCounter();

	// Read and update Start Offset Buffer.
	uint uIndex = (uint)input.pos.y * (uint)windowWidth + (uint)input.pos.x;
	uint uStartOffsetAddress = 4 * uIndex;
	uint uOldStartOffset;
	offsetBuffer.InterlockedExchange(uStartOffsetAddress, uPixelCount, uOldStartOffset);

	// Create fragment data.    
	uint2 element;
	element.x = uOldStartOffset;
	element.y = input.id;

	// Store fragment link.
	linkBuffer[uPixelCount] = element;

}

void doSBuffer(GsosBillboard input) {

	const float height = 593.0;
	const float width = 1152.0;

	// Read and update Start Offset Buffer.
	uint uIndex = (uint)input.pos.y * (uint)width + (uint)input.pos.x;
	uint uDest = 4 * uIndex;
	uint uOldValue;
	offsetBuffer.InterlockedAdd(uDest, 1, uOldValue);
}

void psBillboard(GsosBillboard input)
{
	if (billboardsLoadAlgorithm == 1) {
		doABuffer(input);
	}

	if (billboardsLoadAlgorithm == 2) {
		doSBuffer(input);
	}
}
