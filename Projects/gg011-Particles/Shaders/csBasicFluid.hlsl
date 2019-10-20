
#include "particle.hlsli"

RWStructuredBuffer<Particle> particles;

#define groupDim_x 40


[numthreads(1, 1, 1)]
void csFluid (uint3 DTid : SV_GroupID)
{
	unsigned int tid = DTid.x;

	float dt = 0.03;

	float speed = 1.0 / length(particles[tid].velocity.xyz);
	if (tid % 2 == 0)
	{
		speed *= -1.0;
	}

	matrix Identity =
	{
		{ cos(speed * dt),  0, sin(speed * dt), 0 },
		{ 0,				1, 0,				0 },
		{ -sin(speed * dt), 0, cos(speed * dt), 0 },
		{ 0,				0, 0,				1 }
	};

	float4 newPosition = mul(Identity,  particles[tid].position);
	particles[tid].position = newPosition;
}


