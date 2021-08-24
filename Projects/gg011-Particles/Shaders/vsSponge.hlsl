#include "particle.hlsli"
#include "pbd.hlsli"

StructuredBuffer<ControlParticle> controlParticles;

cbuffer modelViewProjCB {
	row_major float4x4 modelMatrix;
	row_major float4x4 modelViewProjMatrixInverse;
	row_major float4x4 modelViewProjMatrix;
	row_major float4x4 rayDirMatrix;
};

struct IaosTrafo
{
	float4 pos : POSITION;
	uint particleId: PARTICLEID;
	float4 normal: NORMAL;
	//float4 norm: TEXCOORD0;
};

struct VsosTrafo
{
	float4 pos : SV_POSITION;
	uint id: ID;
	float3 normal : NORMAL;
};

VsosTrafo vsSponge(IaosTrafo input, uint vid : SV_VertexID)
{
	VsosTrafo output = (VsosTrafo)0;
	
	output.pos = mul(float4(controlParticles[input.particleId].position.xyz, 1.0), modelViewProjMatrix);
	output.id = vid;
	output.normal = input.normal.xyz;
	return output;
}
