struct IaosQuad
{
	float4  pos: POSITION;
	float2  tex: TEXCOORD0;
};

struct VsosQuad
{
	float4 pos: SV_POSITION;
	float2 tex: TEXCOORD0;
	float3 rayDir: TEXCOORD1;
};


