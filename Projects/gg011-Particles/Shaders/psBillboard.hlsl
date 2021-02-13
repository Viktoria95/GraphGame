#include "billboard.hlsli"
#include "metaball.hlsli"

float4 psBillboard(GsosBillboard input) : SV_Target
{
	float2 offset = float2(0.5,0.5);
	float2 coord = float2(input.tex.x, input.tex.y) - offset;

	float s = step(length(coord), 0.1);

	if (s < 0.01)
		discard;

	float3 normal = float3(input.tex.x-0.5, input.tex.y-0.5, 0.0);
	normal.z = sqrt(pow(0.1, 2) - pow(normal.x, 2) - pow(normal.y, 2));

	float3 color = float3(s*input.tex.x, s*input.tex.y, s);

	color *= (1.0 / (length(eyePos.xyz - particles[input.id].position.xyz) / 10.0));

	return float4 (normalize(normal), 1.0);

}