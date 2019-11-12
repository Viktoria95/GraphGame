
#define billboardsLoadAlgorithm 0 // 0 - Normal, 1 - ABuffer, 2 - SBuffer, 3 - SBuffer faster
#define windowHeight 593.0
#define windowWidth 1152.0

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


