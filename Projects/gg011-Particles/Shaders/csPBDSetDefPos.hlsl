

#include "particle.hlsli"
#include "PBD.hlsli"

StructuredBuffer<ControlParticle> controlParticles;
Buffer<uint> controlParticleCounter;
RWStructuredBuffer<float4> defPos;

[numthreads(1, 1, 1)]
void csPBDSetDefPos(uint3 DTid : SV_GroupID) {
	unsigned int tid = DTid.x;
	if (tid < controlParticleCounter[0]) {
		defPos[tid] = float4 (controlParticles[tid].position, 1.0);
	}	
}