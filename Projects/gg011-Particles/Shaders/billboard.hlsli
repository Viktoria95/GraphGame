
#include "window.hlsli"

#define counterSize 3

struct IaosBillboard {
	float3 pos : POSITION;
	uint id : VID;
};

typedef IaosBillboard VsosBillboard;

struct GsosBillboard
{
	float4 pos : SV_Position;
	float2 tex : TEXCOORD;
	uint id : VID;
};


