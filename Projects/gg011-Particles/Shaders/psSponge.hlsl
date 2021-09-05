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

SamplerState ss : register(s0);

Texture2D diffuseTex : register(t0);
Texture2D normalTex : register(t1);
Texture2D bumpTex : register(t2);

float4 psSponge(VsosTrafo input) : SV_Target
{

	float3 l = normalize(input.lightDirTS);
	float3 v = normalize(input.viewDirTS);
	float3 h = normalize(l + v);

	float bumpMax = 0.05;
	float3 step = (v / v.z) * bumpMax;
	step *= 0.5;
	float3 ptex = float3(input.tex, 0) + step;
	for (int i = 0; i < 16; i++) {
		step *= 0.5;
		float bumpHeight = bumpTex.Sample(ss, ptex).r * bumpMax;
		//bumpHeight *= 10.0;
		//return float4(bumpHeight*10.0, bumpHeight*10.0, bumpHeight*10.0, 1.0);
		if (bumpHeight < ptex.z) {
			ptex -= step;
			if (i == 1) {
				//return float4(1.0, 0.0, 0.0, 1.0);
			}
		}
		else {
			ptex += step;
			if (i == 1) {
				//return float4(0.0, 1.0, 0.0, 1.0);
			}
		}
	}

	//return float4(ptex.zzz, 1.0);

	//if (ptex.z < bumpMax * v.z * 5.5)
	//	discard;

	float3 n = normalize(normalTex.Sample(ss, ptex).xyz - float3(0.5f, 0.5f, 0.0f));

	float ndotl = saturate(dot(n, l));
	float ndoth = saturate(dot(n, h));

	ndoth = pow(ndoth, 80);

	float3 kd = diffuseTex.Sample(ss, ptex).xyz;

	float3x3 tbn = { input.tangent, input.binormal, input.normal };
	float3 worldNormal = normalize(mul(n, tbn));

	return float4(
		(kd * ndotl + float3(1, 1, 1) * ndoth) * 0.7 +
		float3(0.1f, 0.1f, 0.1f) * 0.3
		, 1);

	return float4((kd + ndoth) * ndotl, 1);
}