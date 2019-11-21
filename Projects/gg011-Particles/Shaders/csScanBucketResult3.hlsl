#include "particle.hlsli"

RWByteAddressBuffer offsetBuffer;
RWByteAddressBuffer resultBuffer;

#define groupthreads 512
groupshared uint2 bucket[groupthreads];

void CSScan(uint3 DTid, uint GI, uint x, uint f)
{
	bucket[GI].x = x;
	bucket[GI].y = 0;

	// Up sweep    
	[unroll]
	for (uint stride = 2; stride <= groupthreads; stride <<= 1)
	{
		GroupMemoryBarrierWithGroupSync();

		if ((GI & (stride - 1)) == (stride - 1))
		{
			bucket[GI].x += bucket[GI - stride / 2].x;
		}
	}

	if (GI == (groupthreads - 1))
	{
		bucket[GI].x = 0;
	}

	// Down sweep
	bool n = true;
	[unroll]
	for (stride = groupthreads / 2; stride >= 1; stride >>= 1)
	{
		GroupMemoryBarrierWithGroupSync();

		uint a = stride - 1;
		uint b = stride | a;

		if (n)        // ping-pong between passes
		{
			if ((GI & b) == b)
			{
				bucket[GI].y = bucket[GI - stride].x + bucket[GI].x;
			}
			else
				if ((GI & a) == a)
				{
					bucket[GI].y = bucket[GI + stride].x;
				}
				else
				{
					bucket[GI].y = bucket[GI].x;
				}
		}
		else
		{
			if ((GI & b) == b)
			{
				bucket[GI].x = bucket[GI - stride].y + bucket[GI].y;
			}
			else
				if ((GI & a) == a)
				{
					bucket[GI].x = bucket[GI + stride].y;
				}
				else
				{
					bucket[GI].x = bucket[GI].y;
				}
		}

		n = !n;
	}
	uint temp;
	uint l = resultBuffer.Load(1023 * 4);
	resultBuffer.InterlockedExchange((DTid.x + 512 + 512) * 4, l + bucket[GI].y + x, temp);
}

// record and scan the sum of each bucket
[numthreads(groupthreads, 1, 1)]
void csScanBucketResult3(uint3 DTid : SV_DispatchThreadID, uint3 GTid : SV_GroupThreadID, uint GI : SV_GroupIndex)
{
	uint x1 = offsetBuffer.Load((DTid.x*groupthreads+(512*512)+(512 * 512) - 1) * 4);   // Change the type of x here if scan other types
	CSScan(DTid, GI, x1, 3);
}
