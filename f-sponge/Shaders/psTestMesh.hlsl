

struct VsosTrafo
{
	float4 pos	: SV_POSITION;
	float3 norm	: NORMAL;
};

float4 psTestMesh(VsosTrafo input) : SV_Target
{
	//return float4 (1.0, 0.0, 0.0, 1.0);
	return float4 (input.norm, 1.0);
}