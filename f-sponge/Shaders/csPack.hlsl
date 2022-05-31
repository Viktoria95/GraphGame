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
#define nElementsPerRow 32
#define nRowsPerPage 32
#define nPagesPerChunk 32
#define nChunks 32
#define groupDivisor 4

uint mortonMask(uint a) {
	return
		(a >> (maskOffsets & 0xff)) & 0x1 |
		(a >> ((maskOffsets & 0xff00) >> 8) << 1) & 0x2 |
		(a >> ((maskOffsets & 0xff0000) >> 16) << 2) & 0x4 |
		(a >> ((maskOffsets & 0xff000000) >> 24) << 3) & 0x8;
}

[RootSignature(SortSig)]
[numthreads(nElementsPerRow, nRowsPerPage / groupDivisor, 1)]
void csPack( uint3 tid : SV_GroupThreadID, uint3 gid : SV_GroupID)
{
	uint onpageindex = tid.x + (tid.y + gid.y * nRowsPerPage / groupDivisor) * nElementsPerRow;
	uint globalid = onpageindex + gid.x * nElementsPerRow * nRowsPerPage;

	uint key = input.Load(globalid << 2);
	uint pin = inputIndices.Load(globalid << 2);
	uint bucketid = mortonMask(key);

	uint target = onpageindex
		+ (bucketid ? perPageBucketCounts.Load(((bucketid    ) * nChunks * nPagesPerChunk - 1) << 2):0)
		+ (gid.x    ? perPageBucketCounts.Load(( bucketid      * nChunks * nPagesPerChunk + (gid.x-1)) << 2):0)
		- (bucketid ? perPageBucketCounts.Load(((bucketid - 1) * nChunks * nPagesPerChunk + gid.x) << 2):0)
		;
	/*
	onpageindex 
	  - mylocalbucketoffset : sat[bucketid-1, pageid+1] - sat[bucketid-1, pageid]
	  + myglobalbucketoffset: sat[bucketid-1, top] + sat[bucketid, pageid] - sat[bucketid-1, pageid]

	  ==

	  onpageindex + top[bucketid-1] + sat[bucketid, pageid-1] - sat[bucketid-1, pageid]
	     preceding global buckets - preceding local buckets
		*/
//	output.Store(onpageindex - mybucketoffsetperpage + wheredoesmyperpagebucketstartinglobal, );
/*	uint target = (
		bucketId ? 
			onpageindex - mybucketoffsetonpage
			+ bucketSat[bucketId - 1 + 31*16]  // my page's ppfcount in local bucket
			+ (gid.x?bucketSat[bucketId + (gid.x-1) * 16]:0) // excluding last: my page's offset in local bucket
			- (gid.x?bucketSat[bucketId - 1 + (gid.x-1) * 16]:0)
		:
			(
			onpageindex
		    + (gid.x?bucketSat[bucketId + (gid.x-1) * 16]:0)
			)
		) << 2;*/
	output.Store(target << 2, key);
	outputIndices.Store(target << 2, pin);
}