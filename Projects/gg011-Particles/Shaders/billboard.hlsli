
struct IaosBillboard {
	float3 pos : POSITION;
};

typedef IaosBillboard VsosBillboard;

struct GsosBillboard {
	float4 pos : SV_Position;
	float2 tex : TEXCOORD;
};


