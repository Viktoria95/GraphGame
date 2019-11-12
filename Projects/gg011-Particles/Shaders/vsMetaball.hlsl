#include "metaball.hlsli"

cbuffer metaballVSTransCB {
	row_major float4x4 modelMatrix;
	row_major float4x4 modelMatrixInverse;
	row_major float4x4 modelViewProjMatrix;
	row_major float4x4 rayDirMatrix;
};

VsosQuad vsMetaball(IaosQuad input) {
	VsosQuad output = (VsosQuad)0;
	output.pos = input.pos;
	output.pos.z = 0.001f;
	float4 hWorldPosMinusEye = mul(output.pos, rayDirMatrix);
	hWorldPosMinusEye /= hWorldPosMinusEye.w;
	output.rayDir = hWorldPosMinusEye.xyz;
	output.tex = input.tex;
	return output;
}


