#define ProxySig "RootFlags( 0 )," \
				"RootConstants(num32BitConstants=1, b0)," \
                "DescriptorTable(UAV(u0, numDescriptors=6))" 

uint maskOffset : register(b0);
RWByteAddressBuffer inputMortons : register(u0);
RWByteAddressBuffer sortedMortons : register(u1);
RWByteAddressBuffer starterCounts : register(u2);
RWByteAddressBuffer hlist : register(u3);
RWByteAddressBuffer particleSortingIndex : register(u4);
RWByteAddressBuffer cbegin : register(u5);
RWByteAddressBuffer hbegin : register(u6);

#define rowSize 32
#define nRowsPerPage 32

