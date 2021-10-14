#include "metaball.hlsli"

float4 psMetaballNormalRealistic(VsosQuad input) : SV_Target
{	
	NormalMetaballVisualizer normalMetaballVisualizer;

	RaytraceResult result = CalculateColor_Realistic(input.rayDir, input.pos, normalMetaballVisualizer);

	return float4 (result.color, 1.0);
}



