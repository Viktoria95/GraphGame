#include "metaballABuffer.hlsli"

float4 psMetaballABufferRealistic(VsosQuad input) : SV_Target
{
	ABufferMetaballVisualizer abufferMetaballVisualizer;

	RaytraceResult result = CalculateColor_Realistic(input.rayDir, input.pos, abufferMetaballVisualizer);

	return float4 (result.color, 1.0);
}



