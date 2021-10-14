#include "metaballHashSimple.hlsli"

float4 psMetaballHashSimpleRealistic(VsosQuad input) : SV_Target
{
	HashSimpleMetaballVisualizer hashMetaballVisualizer;

	RaytraceResult result = CalculateColor_Realistic(input.rayDir, input.pos, hashMetaballVisualizer);

	return float4 (result.color, 1.0);
}



