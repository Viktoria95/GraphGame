
#include "particle.hlsli"

Buffer<uint> controlParticleCounter;
RWStructuredBuffer<float4> newPos;

[numthreads(1, 1, 1)]
void csPBDSphereCollision(uint3 DTid : SV_GroupID) {
	unsigned int tid = DTid.x;

	if (tid < controlParticleCounter[0]) {
		const float boundaryEps = 0.0001;

		float4 center = float4 (0.0, 0.0, 0.0, 1.0);
		float radius = 0.02;

		float3 radDis = newPos[tid].xyz - center.xyz;
		float length = (radDis);
		radDis = normalize(radDis);
		if (length < radius - boundaryEps) {
			newPos[tid].xyz += radDis * length / 2.0 * 0.01;
		}
	}
}