cbuffer perObject {
	row_major float4x4 modelMatrix;
	row_major float4x4 modelMatrixInverse;
	row_major float4x4 modelViewProjMatrix;
	row_major float4x4 rayDirMatrix;
};

struct IaosTrafo
{
	float4 pos	: POSITION;
	float3 normal 	: NORMAL;
	float2 tex 	: TEXCOORD;
};

struct VsosTrafo
{
	float4 pos 		: SV_POSITION;
	float4 worldPos 	: WORLDPOS;
	float3 normal 		: NORMAL;
	float2 tex 		: TEXCOORD;
};

VsosTrafo vsTrafo(IaosTrafo input)
{
	VsosTrafo output = (VsosTrafo)0;
	output.pos = mul(input.pos,	modelViewProjMatrix);
	output.worldPos = mul(input.pos, modelMatrix);
	output.normal = mul(modelMatrixInverse,	float4(input.normal.xyz, 0.0));
	output.tex = input.tex;
	return output;
}
