#include "particle.hlsli"
#include "pbd.hlsli"

StructuredBuffer<ControlParticle> controlParticles;

cbuffer modelViewProjCB
{
	row_major float4x4 modelMatrix;
	row_major float4x4 modelViewProjMatrixInverse;
	row_major float4x4 modelMatrixInverse;
	row_major float4x4 viewProjMatrix;
};

cbuffer spongeCB
{
	float4 eyePos;
};

struct IaosTrafo
{
	float4 pos : POSITION;
	float2 tex : TEXCOORDS;
	uint particleId: PARTICLEID;
	float2 neighbourIds : NEIGHBOUR;
	float4 neighbourTexs: NEIGHBOURTEX;
};

struct VsosTrafo
{
	float4 pos : SV_POSITION;
	uint id: ID;
	float2 tex: TEXCOORDS;
	float4 eyePos: EYEPOS;
	float4 worldPos: WORLDPOS;
	float3 viewDir: VIEWDIR;
	float3 lightDir: LIGHTDIR;
	float3 normal: NORMAL;
	float3 tangent : TANGENT;
	float3 binormal : BINORMAL;
	float3 lightDirTS: LIGHTDIRTS;
	float3 viewDirTS: VIEWDIRTS;
};

VsosTrafo vsSponge(IaosTrafo input, uint vid : SV_VertexID)
{
	VsosTrafo output = (VsosTrafo)0;

	float4 worldPos = mul(modelMatrix, float4(controlParticles[input.particleId].position.xyz, 1.0f));
	float3 descartesPos = worldPos.xyz / worldPos.w;

	float4 lightPos = (0.0, 2.0, 0.5, 1.0);

	float3 lightDir = normalize(lightPos.xyz - descartesPos * lightPos.w);
	float3 viewDir = normalize(eyePos.xyz - descartesPos);

	float3 p0 = controlParticles[input.particleId].position.xyz;
	float3 p1 = controlParticles[(uint)input.neighbourIds.x].position.xyz;
	float3 p2 = controlParticles[(uint)input.neighbourIds.y].position.xyz;
	float3 v1 = (p1 - p0).xyz;
	float3 v2 = (p2 - p0).xyz;
	float3 N = normalize(cross(v2, v1));

	float2 tex0 = input.tex;
	float2 tex1 = input.neighbourTexs.xy;
	float2 tex2 = input.neighbourTexs.zw;

	float c2c1t = tex1.x - tex0.x;
	float c2c1b = tex1.y - tex0.y;
	float c3c1t = tex2.x - tex0.x;
	float c3c1b = tex2.y - tex0.y;

	float3 T = float3(c3c1b * v1.x - c2c1b * v2.x, c3c1b * v1.y - c2c1b * v2.y, c3c1b * v1.z - c2c1b * v2.z);
	float3 B = float3(-c3c1t * v1.x + c2c1t * v2.x, -c3c1t * v1.y + c2c1t * v2.y, -c3c1t * v1.z + c2c1t * v2.z);

	float3 t = normalize(mul(float4(T, 0.0), modelMatrixInverse).xyz);
	float3 b = normalize(mul(float4(B, 0.0), modelMatrixInverse).xyz);
	float3 n = normalize(mul(float4(N, 0.0), modelMatrixInverse).xyz);

	float3x3 tbn = { t, -b, n };

	output.pos = mul(worldPos, viewProjMatrix);
	output.id = vid;
	output.tex = input.tex;
	output.eyePos = eyePos;
	output.worldPos = worldPos;
	output.viewDir = viewDir;
	output.lightDir = lightDir;
	output.normal = n;
	output.tangent = t;
	output.binormal = -b;
	output.lightDirTS = mul(tbn, lightDir);
	output.viewDirTS = mul(tbn, viewDir);
	return output;
}
