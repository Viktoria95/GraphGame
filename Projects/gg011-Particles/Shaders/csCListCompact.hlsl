

RWByteAddressBuffer clist;
RWByteAddressBuffer clistNonZero;
RWByteAddressBuffer clistBegin;

[numthreads(1, 1, 1)]
void csCListCompact(uint3 DTid : SV_GroupID)
{
	unsigned int tid = DTid.x;

	uint originalValue = clist.Load(tid * 4);
	if (originalValue != 0)
	{
		clistBegin.Store(clistNonZero.Load(tid * 4) * 4, originalValue);
	}
}


