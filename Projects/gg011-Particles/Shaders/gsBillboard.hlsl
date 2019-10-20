#include "billboard.hlsli"

cbuffer billboardGSTransCB {
	row_major float4x4 modelMatrix;
	row_major float4x4 modelMatrixInverse;
	row_major float4x4 modelViewProjMatrix;
	row_major float4x4 rayDirMatrix;
};

cbuffer billboardGSSizeCB {
	float4 billboardSize;
}

[maxvertexcount(4)]
void gsBillboard(point VsosBillboard input[1], inout TriangleStream<GsosBillboard> stream) {
	float4 hndcPos = mul(float4(input[0].pos, 1), modelViewProjMatrix);

	GsosBillboard output;
	output.pos = hndcPos;
	output.pos.x += billboardSize.x;
	output.pos.y += billboardSize.y;
	output.tex = float2(1, 0);
	stream.Append(output);

	output.pos = hndcPos;
	output.pos.x += billboardSize.x;
	output.pos.y -= billboardSize.y;
	output.tex = float2(1, 1);
	stream.Append(output);

	output.pos = hndcPos;
	output.pos.x -= billboardSize.x;
	output.pos.y += billboardSize.y;
	output.tex = float2(0, 0);
	stream.Append(output);

	output.pos = hndcPos;
	output.pos.x -= billboardSize.x;
	output.pos.y -= billboardSize.y;
	output.tex = float2(0, 1);
	stream.Append(output);
}
