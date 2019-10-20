#include "quad.hlsli"

cbuffer perObject {
	row_major float4x4 modelMatrix;
	row_major float4x4 modelMatrixInverse;
	row_major float4x4 modelViewProjMatrix;
	row_major float4x4 rayDirMatrix;
};

VsosQuad vsQuad(IaosQuad input) {
	VsosQuad output = (VsosQuad)0;

	output.pos = input.pos;
	float4 hWorldPosMinusEye = mul(input.pos, rayDirMatrix);
	hWorldPosMinusEye /= hWorldPosMinusEye.w;
	output.rayDir = hWorldPosMinusEye.xyz;
	output.tex = input.tex;
	return output;
}


