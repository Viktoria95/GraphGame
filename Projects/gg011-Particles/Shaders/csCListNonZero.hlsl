

RWByteAddressBuffer clist;
RWByteAddressBuffer clistNonZero;

[numthreads(1, 1, 1)]
void csCListNonZero(uint3 DTid : SV_GroupID)
{
	unsigned int tid = DTid.x;

	if (clist.Load (tid * 4) == 0)
	{
		clistNonZero.Store(tid * 4, 0);
	}
	else
	{
		clistNonZero.Store(tid * 4, 1);
	}	
}


