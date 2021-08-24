struct VsosTrafo
{
	float4 pos	: SV_POSITION;
	uint id: ID;
	float3 normal	: NORMAL;
};

float4 psSponge(VsosTrafo input) : SV_Target
{
	return float4 (normalize(input.pos.xyz), 1.0);
}