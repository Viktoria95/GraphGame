#define SortSig "RootFlags( 0 )," \
				"RootConstants(num32BitConstants=1, b0)," \
                "DescriptorTable(UAV(u0, numDescriptors=1), UAV(u1, numDescriptors=1), UAV(u2, numDescriptors=1), UAV(u3, numDescriptors=1))" 

// uav offset @mortons or @ (#0 or #4)
RWByteAddressBuffer input : register(u0);
RWByteAddressBuffer inputIndices : register(u1);
RWByteAddressBuffer outputIndices : register(u2);
RWByteAddressBuffer output : register(u3);

#define groupSize 32

groupshared uint inpipe[32*32];
groupshared uint linpipe[32 * 32];
groupshared uint loutpipe[32];
groupshared uint outpipe[32];
groupshared uint inprog[32];
groupshared uint op;
groupshared uint outprog;

[RootSignature(SortSig)]
[numthreads(groupSize, 1, 1)]
void csMerge( uint3 tid : SV_GroupThreadID)
{
	outprog = 0;
	inprog[tid.x] = 0;
	uint ip = 0x20;
	//while (WaveActiveAny(inprog[tid.x] < 32 * 32)) {
	while (outprog < 32 * 32 * 32) {
		uint emptyPipes = WaveActiveBallot(ip == 0x20 && inprog[tid.x] < 32 * 32).x;
		while (emptyPipes) {
			uint emptyPipeIndex = firstbitlow(emptyPipes);
			uint snoopy = (emptyPipeIndex * 32 * 32 + inprog[emptyPipeIndex] + tid.x) << 2;
			inpipe[emptyPipeIndex * 32 + tid.x] = input.Load(snoopy);
//			linpipe[emptyPipeIndex * 32 + tid.x] = inputIndices.Load(snoopy);
			if (tid.x == emptyPipeIndex) {
				inprog[emptyPipeIndex] += 32;
				ip = 0;
			}
			emptyPipes = WaveActiveBallot(ip == 0x20 && inprog[tid.x] < 32 * 32).x;
		}
		DeviceMemoryBarrierWithGroupSync();
		uint candidate = inpipe[ip | (tid.x << 5)];
		uint winner = WaveActiveMin(candidate);
		if (candidate == winner) {
			if (WaveIsFirstLane()) {
				outpipe[op] = winner;
//				loutpipe[op] = linpipe[ip | (tid.x << 5)];
				loutpipe[op] = ip | (tid.x << 5);
				op++;
				ip++;
			}
		}
		if (op == 0x20) {
			output.Store((outprog + tid.x) << 2, outpipe[tid.x] );
			outputIndices.Store((outprog + tid.x) << 2, loutpipe[tid.x]);
			outprog += 0x20;
			op = 0;
		}
	}
//	output.Store(tid.x, outpipe[tid.x]*/);
}