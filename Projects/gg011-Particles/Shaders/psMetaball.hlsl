#include "metaball.hlsli"
#include "particle.hlsli"

SamplerState ss;


cbuffer metaballPSEyePosCB
{
	float4 eyePos;
};

StructuredBuffer<Particle> particles;


float f(float3 p)
{
	float A_m = 1.0;

	const float r = 0.005;

	float fr = -A_m;
	for (int i = 0; i < particleCount; i++) {
		float eredmeny = pow((length(p - float3(particles[i].position.x, particles[i].position.y, particles[i].position.z)) / r), -2.0);
		fr += eredmeny;
	}

	return fr;
}

float3 fGrad(float3 p)
{

	float3 eredmeny;
	float A = 1.0;

	const float r = 0.005;


	for (int i = 0; i < particleCount; i++) {
		eredmeny.x += ((pow((-2.0*r), 2.0) / pow(length(p - float3(particles[i].position.x, particles[i].position.y, particles[i].position.z)), 3.0)) * ((-1.0) / (2.0*length(p - float3(particles[i].position.x, particles[i].position.y, particles[i].position.z)))) * (p.x - particles[i].position.x));
		eredmeny.y += ((pow((-2.0*r), 2.0) / pow(length(p - float3(particles[i].position.x, particles[i].position.y, particles[i].position.z)), 3.0)) * ((-1.0) / (2.0*length(p - float3(particles[i].position.x, particles[i].position.y, particles[i].position.z)))) * (p.y - particles[i].position.y));
		eredmeny.z += ((pow((-2.0*r), 2.0) / pow(length(p - float3(particles[i].position.x, particles[i].position.y, particles[i].position.z)), 3.0)) * ((-1.0) / (2.0*length(p - float3(particles[i].position.x, particles[i].position.y, particles[i].position.z)))) * (p.z - particles[i].position.z));
	}

	return eredmeny;

}

float4 psMetaball(VsosQuad input) : SV_Target
{
	float3 d = normalize(input.rayDir);
	float3 p = eyePos;//+ d;
	float3 step =	3.0 *  d / 500.0;

	p += step * 40;
	float h;
	for (int i = 0; i<40; i++)
	{
		h = f(p);
		if (h > 0.0) {
			break;
		}
		p += step;
	}

	float3 gradient = fGrad(p);
	float3 gradnormalize = normalize(gradient);

	float find = 0.0;
	if (h>0.0) find = 1.0;

	float3 normal = normalize(eyePos - gradnormalize);
	float3 reflDir = reflect(normalize(input.rayDir), gradnormalize);


	if (find>0.1)
	{
		return  float4 (gradnormalize.xyz, 1.0f);
	}
	else
	{
		return  float4 (0.0f, 0.0f, 1.0f, 1.0f);
	}
}



