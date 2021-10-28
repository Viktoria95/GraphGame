#define SortSig "RootFlags( 0 )," \
				"RootConstants(num32BitConstants=1, b0)," \
                "DescriptorTable(UAV(u0, numDescriptors=1), UAV(u1, numDescriptors=1), UAV(u2, numDescriptors=1), UAV(u3, numDescriptors=1))" 

//SRV(t0, numDescriptors=1), 
RWByteAddressBuffer input : register(u0);
RWByteAddressBuffer output : register(u1);
RWByteAddressBuffer inputIndices : register(u2);
RWByteAddressBuffer outputIndices : register(u3);
uint maskOffset : register(b0);

#define groupSize 32
#define batchSize 32

groupshared uint s[groupSize * batchSize]; // sort step buffer, then sorted rows
groupshared uint d[groupSize * batchSize]; // sort step buffer, then bucket counts for sorted rows
groupshared uint ls[groupSize * batchSize]; // lookup
groupshared uint ld[groupSize * batchSize]; // lookup

[RootSignature(SortSig)]
[numthreads(groupSize, batchSize, 1)]
void csLocalSort( uint3 tid : SV_GroupThreadID , uint3 gid : SV_GroupID )
{
	uint rowst = tid.y << 5;
	uint flatid = rowst | tid.x;
	uint initialElementIndex = flatid + gid.x * groupSize * batchSize;
	s[flatid] = input.Load(initialElementIndex << 2 );
	ls[flatid] = initialElementIndex;
	//scan on bit i
	for (uint i = maskOffset; i < maskOffset+4; i++) {
		uint imask = 0x1 << i;
		{
			bool pred = s[flatid] & imask;
			uint prefixBits = WavePrefixCountBits(pred);
			uint allBits = WaveActiveCountBits(pred);
			if (pred) {
				d[rowst | (groupSize - (allBits - prefixBits))] = s[flatid];
				ld[rowst | (groupSize - (allBits - prefixBits))] = ls[flatid];
			}
			else {
				d[flatid - prefixBits] = s[flatid];
				ld[flatid - prefixBits] = ls[flatid];
			}
		}
		i++;
		imask = 0x1 << i;
		{
			bool pred = d[flatid] & imask;
			uint prefixBits = WavePrefixCountBits(pred);
			uint allBits = WaveActiveCountBits(pred);
			if (pred) {
				s[rowst | (groupSize - (allBits - prefixBits))] = d[flatid];
				ls[rowst | (groupSize - (allBits - prefixBits))] = ld[flatid];
			}
			else {
				s[flatid - prefixBits] = d[flatid];
				ls[flatid - prefixBits] = ld[flatid];
			}
		}
	}
	//compute step

	uint sfm = (s[flatid] >> maskOffset)  & 0xf;
	d[flatid] = 0; // count goes here
	uint step = (tid.x == 31)?1:( ((s[flatid+1] >> maskOffset) & 0xf) - sfm);
	sfm += rowst;
	uint stepMask =  WaveActiveBallot(step).x;
	if (stepMask & (0x1 << tid.x)) {
		d[sfm] = 32 - firstbithigh(((stepMask << 1) | 0x1) << (31-tid.x));
	}

	GroupMemoryBarrierWithGroupSync();

	// d has count now (every second 16-segment is 0)
	// count': we scan the count matrix 32-length row by 32-length row, adding previous row sum sum
	uint crossid = (tid.x << 5) | tid.y;

	if (tid.y < 16)
		d[16 + crossid] = WavePrefixSum(d[crossid]);

	GroupMemoryBarrierWithGroupSync();
	if (tid.y == 1 && tid.x < 16) {
		uint perPageBucketCount = d[(32 * 31 + 16) + tid.x] + d[32 * 31 + tid.x];
//		bucketCounts.Store((tid.x | gid.x << 4) << 2, perPageBucketCount);
		d[tid.x + 16] = WavePrefixSum(perPageBucketCount);
	}
	// write these out to resource mem, per 1024-page

	GroupMemoryBarrierWithGroupSync();
	if (tid.x < 16)
		d[16 + flatid] += (tid.y?d[16 + tid.x]:0) - WavePrefixSum(d[flatid]);

	GroupMemoryBarrierWithGroupSync();
	uint bucketid = (s[flatid] >> maskOffset) & 0xf;
	uint target = d[16 + bucketid + (tid.y << 5)] + tid.x;

	input.Store((target + groupSize * batchSize * gid.x) << 2 , s[flatid]);
	inputIndices.Store((target + groupSize * batchSize * gid.x) << 2, ls[flatid]);
//	input.Store(flatid << 2, d[flatid]);
/*
	DeviceMemoryBarrierWithGroupSync();
	if (gid.x == 0) {
		if (pid.x < 16) { // pull in counts
			d[flatid] = bucketCounts.Load(tid.x | rowst);
		}
		GroupMemoryBarrierWithGroupSync();
		if (tid.y < 16) { // compute global offsets
			d[16 + crossid] = WavePrefixSum(d[crossid]);
		}
		GroupMemoryBarrierWithGroupSync();
		DeviceMemoryBarrierWithGroupSync();

		if (tid.y == 1 && tid.x < 16) {
			uint globalBucketCount = d[(32 * 31 + 16) + tid.x] + d[32 * 31 + tid.x];
			bucketCounts.Store((tid.x | gid.x << 4) << 2, globalBucketCount);
			d[tid.x + 16] = WavePrefixSum(globalBucketCount);
		}
	}
	DeviceMemoryBarrierWithGroupSync();
	//fetch bucketoffsets


	uint gtarget = d[bucketid + (tid.y << 5)] + target ;
	input.Store(gtarget << 2, s[flatid]);
*/
	//single group: columnwise prefix sum on per-page count matrix -> per-all bucket offset matrix
	//other group: rowwise prefix sum on per-page count matrix -> per-page offset matrix
	//all threads: compute target
	//scatter to target


//	//idea: put step into waveballot, shift by lane index, getfirstbit -> obtain next non-empty bucket start
//	if (step)
//		bucketOffsets.Store(s[tid.x] *4, tid.x+1);
}
// next pass:
// we have the offset matrix 32x16
// with substractions we get the count matrix 32x16
// write out count'[0] to meta-offset matrix
// count'': we subtract the offset matrix from the count' matrix
// for i in 0..31, j in 0..31 scatter to: count''[i][bucketOf(locally-sorted[i*32+j])] + j
// UNOPTIMZED would be: scatter destination: scanned-count[i][bucketOf(locally-sorted[i])] + i - offset[i][bucketOf(locally-sorted[i])]

//LAST pass: j in 0..1023
// offsets, counts can be as high as 1024