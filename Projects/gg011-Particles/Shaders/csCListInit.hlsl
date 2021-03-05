

#include "particle.hlsli"

StructuredBuffer<Particle> particles;
RWByteAddressBuffer clist;

[numthreads(1, 1, 1)]
void csCListInit(uint3 DTid : SV_GroupID)
{
	unsigned int tid = DTid.x;

	if (tid == 0)
	{
		//clist[0] = 0;
		clist.Store(0,0);
	}
	else 
	{
		if (tid == particleCount - 1)
		{
			//clist[tid + 1] = particleCount;
			clist.Store((tid + 1)*4, particleCount);
		}		

		if (particles[tid - 1].zindex == particles[tid].zindex)
		{
			//clist[tid] = 0;
			clist.Store((tid) * 4, 0);
		}
		else
		{
			//clist[tid] = tid;
			clist.Store((tid) * 4, tid);
		}
	}
}


