#include "metaballSBuffer.hlsli"

struct PS_OUT
{
	float4 color : SV_Target;
	float depth : SV_Depth;
};

PS_OUT psMetaballSBufferRealistic(VsosQuad input)
{
	SBufferMetaballVisualizer sbufferMetaballVisualizer;

	RaytraceResult result = CalculateColor_Realistic(input.rayDir, input.pos, sbufferMetaballVisualizer);


	PS_OUT output;
	output.depth = 1.0;
	if (result.discarded)
	{		
		output.color = float4 (1.0, 0.0, 0.0, 1.0);;
		//discard;
	}
	else
	{
		output.color = float4 (result.color, 1.0);
	}

	return output;
}



