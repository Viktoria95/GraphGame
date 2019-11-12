#define billboardsLoadAlgorithm 0 // 0 - Normal, 1 - ABuffer, 2 - SBuffer, 3 - SBuffer faster
#define windowHeight 593.0
#define windowWidth 1152.0

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


