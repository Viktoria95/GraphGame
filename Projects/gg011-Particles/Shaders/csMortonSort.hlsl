

#include "particle.hlsli"

RWStructuredBuffer<Particle> particles;

[numthreads(1, 1, 1)]
void csSimpleSortEven(uint3 DTid : SV_GroupID)
{
	unsigned int tid = DTid.x;
	unsigned int firstIdx = tid * 2 + 1;
	unsigned int secondIdx = firstIdx + 1;

	if (particles[firstIdx].position.x > particles[secondIdx].position.x)
	{
		Particle temp = particles[firstIdx];
		particles[firstIdx] = particles[secondIdx];
		particles[secondIdx] = temp;
	}
}


