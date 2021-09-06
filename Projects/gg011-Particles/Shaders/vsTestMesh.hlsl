
#include "PBDSphere.hlsli"

Buffer<float4> testMeshPos;

cbuffer modelViewProjCB {
	row_major float4x4 modelMatrix;
	row_major float4x4 modelViewProjMatrixInverse;
	row_major float4x4 modelViewProjMatrix;
	row_major float4x4 rayDirMatrix;
};

struct IaosTrafo
{
	float4 pos : POSITION;
	float4 norm: TEXCOORD0;
};

struct VsosTrafo
{
	float4 pos : SV_POSITION;
	float3 norm: NORMAL;
};

VsosTrafo vsTestMesh(IaosTrafo input)
{
	VsosTrafo output = (VsosTrafo)0;
	output.pos = mul(float4(input.pos.xyz * sphereRadius + testMeshPos[0].xyz, 1.0), modelViewProjMatrix);
	output.norm = input.norm;
	//output.pos = input.pos;
	return output;
}
