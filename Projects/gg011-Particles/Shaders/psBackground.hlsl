#include "quad.hlsli"

TextureCube envTexture;
SamplerState ss;

float4 psBackground(VsosQuad input) : SV_Target
{
	return envTexture.Sample(ss, input.rayDir);
}


