

RWByteAddressBuffer clistBegin;
RWByteAddressBuffer clistLength;

[numthreads(1, 1, 1)]
void csCListLength(uint3 DTid : SV_GroupID)
{
	unsigned int tid = DTid.x;

	clistLength.Store(tid * 4, clistBegin.Load ((tid + 1) * 4) - clistBegin.Load(tid * 4));
}


