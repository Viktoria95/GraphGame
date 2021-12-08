#include "proximity.hlsli"
#include "hhash.hlsli"

// uav offset @sortedMortons (#3)
RWByteAddressBuffer sorted : register(u0);
RWByteAddressBuffer starterCounts : register(u1);
RWByteAddressBuffer hlist : register(u2);
RWByteAddressBuffer cbegin : register(u3);

groupshared uint perRowStarterCount[nRowsPerPage];
groupshared uint perRowLeadingNonstarterCount[nRowsPerPage];
groupshared uint perPageStarterCountsSummed[32];
groupshared uint perRowStarterCountsSummed[32];

[RootSignature(ProxySig)]
[numthreads(rowSize, nRowsPerPage, 1)]
void csCreateCellList(uint3 tid : SV_GroupThreadID, uint3 gid : SV_GroupID)
{
	if (tid.y == 0) {
		uint perPageStarterCount = starterCounts.Load(tid.x << 2) & 0xffff;
		perPageStarterCountsSummed[tid.x] = WavePrefixSum(perPageStarterCount);
	}

	uint rowst = tid.y << 5;
	uint flatid = rowst | tid.x;
	uint initialElementIndex = flatid + gid.x * rowSize * nRowsPerPage;

	uint myMorton = sorted.Load(initialElementIndex << 2);
	uint prevMorton = initialElementIndex ? sorted.Load((initialElementIndex - 1) << 2) : 0xffffffff;
	bool meNonstarter = (myMorton == prevMorton);
	uint nonStartersUpToMe = WavePrefixCountBits(meNonstarter) + (meNonstarter ? 1 : 0);
	if (tid.x == 31) {
		perRowStarterCount[tid.y] = 32 - nonStartersUpToMe;
	}
	perRowLeadingNonstarterCount[tid.y] = 0;
	if (nonStartersUpToMe == (tid.x + 1)) { //if all are starters, this never happens
		perRowLeadingNonstarterCount[tid.y] = WaveActiveMax(tid.x + 1);
	}

	GroupMemoryBarrierWithGroupSync();

	if (tid.y == 0) {
		bool rowNotFull = perRowLeadingNonstarterCount[tid.x] != 32;
		uint notFullMask = WaveActiveBallot(rowNotFull).x >> (tid.x + 1);
		uint nFullRowsAfterMe = firstbitlow(notFullMask);
		if (!rowNotFull && nFullRowsAfterMe != 0xffffffff) {
			uint nextNonFullLeadingNonStarterCount = perRowLeadingNonstarterCount[tid.x + 1 + nFullRowsAfterMe];
			perRowLeadingNonstarterCount[tid.x] += nFullRowsAfterMe * 32 + nextNonFullLeadingNonStarterCount;
		}

		perRowStarterCountsSummed[tid.x] = WavePrefixSum(perRowStarterCount[tid.x]);
	}
	GroupMemoryBarrierWithGroupSync();

	uint compactIndex = tid.x + 1 - nonStartersUpToMe + perRowStarterCountsSummed[tid.y] + perPageStarterCountsSummed[gid.x];

	uint starterMask = WaveActiveBallot(!meNonstarter).x >> (tid.x + 1);
	uint clength = firstbitlow(starterMask) + 1;
	if (clength == 0) { // runs over row end
		clength = 32 - tid.x;
		clength += (tid.y==31) ? starterCounts.Load((gid.x+1)<<2)>>16 : perRowLeadingNonstarterCount[tid.y + 1];
	}
	if (!meNonstarter) {
		cbegin.Store(compactIndex, clength << 16 | initialElementIndex);
		hlist.Store(compactIndex, hhash(myMorton));
	}

}