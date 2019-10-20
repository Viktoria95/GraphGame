TextureCube envTexture;
Texture2D kd;
SamplerState ss;

cbuffer perFrame {
	float4 eyePos;
};

struct VsosTrafo
{
	float4 pos 		: SV_POSITION;
	float4 worldPos 	: WORLDPOS;
	float3 normal 		: NORMAL;
	float2 tex 		: TEXCOORD;
};

float4 psIdle(VsosTrafo input) : SV_Target{
	
	float3 reflDir = reflect(normalize(input.worldPos.xyz - eyePos.xyz), normalize(input.normal));
	return envTexture.Sample(ss, reflDir) * 0.5 + kd.Sample(ss, input.tex) * 0.5;
	}