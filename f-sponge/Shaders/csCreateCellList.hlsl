#include "proximity.hlsli"
#include "hhash.hlsli"

// sortedMortons => starterCounts

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

	uint myMorton = sortedMortons.Load(initialElementIndex << 2);
	uint prevMorton = initialElementIndex ? sortedMortons.Load((initialElementIndex - 1) << 2) : 0xffffffff;
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
		clength += (tid.y==31)?starterCounts.Load((gid.x+1)<<2)>>16:perRowLeadingNonstarterCount[tid.y + 1];
		// ^^TODO full rows need to be gathered
	}
	if (!meNonstarter) {
		cbegin.Store(compactIndex, clength << 16 | initialElementIndex);
		hlist.Store(compactIndex, hhash(myMorton));
	}

	if (tid.y == 0) {
		uint nonstarterCount = perRowLeadingNonstarterCount[tid.x];
		//		uint hasStarterMask = (WaveActiveBallot(nonstarterCount != 32) << (32-tid.x)) | 0x1;
		//		uint precedingRowsWithNoStarterCount = (tid.x)?firstbithigh(hasStarterMask):0;
		uint hasStarterMask = WaveActiveBallot(nonstarterCount != 32).x;
		uint firstNotEmpty = firstbitlow(hasStarterMask); // no starter on entire page would be weird
		uint leadingNonStarterCount = firstNotEmpty * 32 + perRowLeadingNonstarterCount[firstNotEmpty];

		uint perPageStarterCount = WavePrefixSum(perRowStarterCount[tid.x]) + perRowStarterCount[31];
		if (tid.x == 31) {
			starterCounts.Store(gid.x << 2, (leadingNonStarterCount << 16) | perPageStarterCount);
		}
	}
}