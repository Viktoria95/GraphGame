#include "billboard.hlsli"


float4 psBillboard(GsosBillboard input) : SV_Target
{
	return input.tex.xyyy;
}
