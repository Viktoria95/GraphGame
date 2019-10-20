#include "billboard.hlsli"
#include "particle.hlsli"

StructuredBuffer<Particle> particles;

VsosBillboard vsBillboard(uint vid : SV_VertexID)
{
	VsosBillboard output;
	output.pos = particles[vid].position.xyz;
	return output;
}



