

#include "particle.hlsli"

RWStructuredBuffer<Particle> particles;

uint mortonHash(float3 pos) {
	uint x = (pos.x + boundarySide) / (2.0f * boundarySide) * 1023.0;
	uint z = (pos.z + boundarySide) / (2.0f * boundarySide) * 1023.0;
	uint y = (pos.y - boundaryBottom) / (boundaryBottom + boundaryTop) * 1023.0;

	uint hash = 0;
	uint i;
	for (i = 0; i < 3; ++i)
	{
		hash |= ((x & (1 << i)) << 2 * i)  |  ((z & (1 << i)) << (2 * i + 1))  |  ((y & (1 << i)) << (2 * i + 2));
	}

	return hash;
}

[numthreads(1, 1, 1)]
void csMortonHash(uint3 DTid : SV_GroupID)
{
	unsigned int tid = DTid.x;
	particles[tid].zindex = mortonHash(particles[tid].position);
}


