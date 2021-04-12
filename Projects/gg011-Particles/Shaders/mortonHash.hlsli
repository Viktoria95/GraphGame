

uint mortonHash(float3 pos) {
	//uint x = (pos.x + boundarySide) / (2.0f * boundarySide) * 1023.0;
	//uint z = (pos.z + boundarySide) / (2.0f * boundarySide) * 1023.0;
	//uint y = (pos.y - boundaryBottom) / (boundaryBottom + boundaryTop) * 1023.0;

	//const float maxIndex = 1023.0;
	const float maxIndex = 15.0;
	uint x = (pos.x + boundarySide) / (2.0f * boundarySide) * maxIndex;
	uint z = (pos.z + boundarySide) / (2.0f * boundarySide) * maxIndex;
	uint y = (pos.y - boundaryBottom) / (boundaryBottom + boundaryTop) * maxIndex;
	//if (pos.z < 100000.0) {
		//x = y = z = 0;
	//}
	

	uint hash = 0;
	uint i;
	for (i = 0; i < 7; ++i)
	{
		hash |= ((x & (1 << i)) << 2 * i) | ((z & (1 << i)) << (2 * i + 1)) | ((y & (1 << i)) << (2 * i + 2));
	}

	return hash;
}

