#define SortSig "RootFlags( 0 )," \
				"RootConstants(num32BitConstants=1, b0)," \
                "DescriptorTable(UAV(u0, numDescriptors=1), UAV(u1, numDescriptors=1), UAV(u2, numDescriptors=1), UAV(u3, numDescriptors=1), UAV(u4, numDescriptors=1))" 

// uav offset @mortons or @ (#0 or #4)
RWByteAddressBuffer input : register(u0);
RWByteAddressBuffer inputIndices : register(u1);
RWByteAddressBuffer perPageBucketCounts : register(u2);
RWByteAddressBuffer outputIndices : register(u3);
RWByteAddressBuffer output : register(u4);
uint maskOffsets : register(b0);

#define nBuckets 16
#define nRowsPerPage 32
#define nPagesPerChunk 32
#define nChunks 32

groupshared uint perChunkBucketOffsets[nChunks];

[RootSignature(SortSig)]
[numthreads(nChunks, nPagesPerChunk, 1)]
void csSumChunks(uint3 tid : SV_GroupThreadID, uint3 gid : SV_GroupID /*bucketid*/)
{
	if (tid.y == 0) {
		uint saddr = (31 + tid.x * nPagesPerChunk + gid.x * nPagesPerChunk * nChunks) << 2;
		uint perChunkBucketCount = perPageBucketCounts.Load(saddr);
		uint prefixPerChunkBucketCount = WavePrefixSum(perChunkBucketCount);
		perChunkBucketOffsets[tid.x] = prefixPerChunkBucketCount;
	}
	GroupMemoryBarrierWithGroupSync();
	
	uint saddr = (tid.x + tid.y * nPagesPerChunk + gid.x * nPagesPerChunk * nChunks) << 2;
	uint bucketCount = perPageBucketCounts.Load(saddr);
	perPageBucketCounts.Store(saddr, bucketCount + perChunkBucketOffsets[tid.y]);
}